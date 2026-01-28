#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Alertmanager Silence Creator
# ============================================
# Version: 2.0.0
# Description: Create silences in Alertmanager via CLI or interactive mode
# ============================================

# Colors for display (disabled if not a terminal)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Configuration with environment variable defaults
NAMESPACE="${NAMESPACE:-monitoring}"
INGRESS_NAME="${INGRESS_NAME:-prometheus-kube-prometheus-alertmanager}"
CURL_TIMEOUT="${CURL_TIMEOUT:-5}"
CURL_INSECURE="${CURL_INSECURE:-false}"

# Script version
VERSION="2.0.0"

# CLI arguments (initialized empty)
ARG_DURATION=""
ARG_COMMENT=""
ARG_URL=""
ARG_NAMESPACE=""
ARG_INGRESS=""
ARG_INSECURE="false"
ARG_VERBOSE="false"
ARG_DRY_RUN="false"
ARG_INTERACTIVE="true"

# ============================================
# Utility Functions
# ============================================

print_success() { printf "%b\n" "${GREEN}✅ $1${NC}"; }
print_info() { printf "%b\n" "${BLUE}ℹ️  $1${NC}"; }
print_error() { printf "%b\n" "${RED}❌ $1${NC}" >&2; }
print_warning() { printf "%b\n" "${YELLOW}⚠️  $1${NC}"; }
print_debug() { 
    if [[ "$ARG_VERBOSE" == "true" ]]; then
        printf "%b\n" "${YELLOW}[DEBUG] $1${NC}" >&2
    fi
}

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Create silences in Alertmanager to suppress all alerts for a specified duration.

OPTIONS:
    -d, --duration MINUTES   Silence duration in minutes (required for non-interactive mode)
    -c, --comment TEXT       Comment for the silence (default: auto-generated)
    -u, --url URL            Alertmanager URL (auto-detected from Ingress if not provided)
    -n, --namespace NS       Kubernetes namespace (default: $NAMESPACE)
    -i, --ingress NAME       Ingress name (default: $INGRESS_NAME)
    -k, --insecure           Allow insecure SSL connections (skip certificate verification)
    -t, --timeout SECONDS    Curl timeout in seconds (default: $CURL_TIMEOUT)
    --dry-run                Show what would be done without actually creating the silence
    -v, --verbose            Enable verbose/debug output
    -V, --version            Show version information
    -h, --help               Show this help message and exit

ENVIRONMENT VARIABLES:
    NAMESPACE                Default namespace (default: monitoring)
    INGRESS_NAME             Default ingress name (default: prometheus-kube-prometheus-alertmanager)
    CURL_TIMEOUT             Default curl timeout in seconds (default: 5)
    CURL_INSECURE            Set to 'true' to skip SSL verification (default: false)

EXAMPLES:
    # Interactive mode
    $(basename "$0")

    # Non-interactive: 1 hour silence
    $(basename "$0") -d 60 -c "Scheduled maintenance"

    # With custom URL and insecure mode
    $(basename "$0") -d 30 -u https://alertmanager.example.com -k

    # Dry-run mode (show what would happen without creating silence)
    $(basename "$0") -d 60 --dry-run

    # Using environment variables
    NAMESPACE=observability $(basename "$0") -d 120

EOF
    exit 0
}

show_version() {
    echo "alertmanager-silence.sh version $VERSION"
    exit 0
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--duration)
                ARG_DURATION="$2"
                ARG_INTERACTIVE="false"
                shift 2
                ;;
            -c|--comment)
                ARG_COMMENT="$2"
                shift 2
                ;;
            -u|--url)
                ARG_URL="$2"
                shift 2
                ;;
            -n|--namespace)
                ARG_NAMESPACE="$2"
                shift 2
                ;;
            -i|--ingress)
                ARG_INGRESS="$2"
                shift 2
                ;;
            -k|--insecure)
                ARG_INSECURE="true"
                shift
                ;;
            -t|--timeout)
                CURL_TIMEOUT="$2"
                shift 2
                ;;
            --dry-run)
                ARG_DRY_RUN="true"
                ARG_INTERACTIVE="false"
                shift
                ;;
            -v|--verbose)
                ARG_VERBOSE="true"
                shift
                ;;
            -V|--version)
                show_version
                ;;
            -h|--help)
                usage
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information."
                exit 1
                ;;
        esac
    done

    # Apply argument overrides
    if [[ -n "$ARG_NAMESPACE" ]]; then
        NAMESPACE="$ARG_NAMESPACE"
    fi
    if [[ -n "$ARG_INGRESS" ]]; then
        INGRESS_NAME="$ARG_INGRESS"
    fi
    if [[ "$ARG_INSECURE" == "true" ]] || [[ "$CURL_INSECURE" == "true" ]]; then
        ARG_INSECURE="true"
    fi

    print_debug "NAMESPACE=$NAMESPACE"
    print_debug "INGRESS_NAME=$INGRESS_NAME"
    print_debug "CURL_TIMEOUT=$CURL_TIMEOUT"
    print_debug "ARG_INSECURE=$ARG_INSECURE"
    print_debug "ARG_DRY_RUN=$ARG_DRY_RUN"
    print_debug "ARG_INTERACTIVE=$ARG_INTERACTIVE"
}

validate_duration() {
    local duration="$1"
    
    if [[ ! "$duration" =~ ^[0-9]+$ ]]; then
        print_error "Duration must be a positive integer (got: '$duration')"
        return 1
    fi
    
    if [[ "$duration" -le 0 ]]; then
        print_error "Duration must be greater than 0 (got: $duration)"
        return 1
    fi
    
    if [[ "$duration" -gt 525600 ]]; then  # 1 year in minutes
        print_warning "Duration is very long (${duration} minutes = $((duration / 1440)) days)"
    fi
    
    return 0
}

check_requirements() {
    local missing=0
    
    for cmd in kubectl curl jq date; do
        if ! command -v "$cmd" &> /dev/null; then
            print_error "Required command missing: $cmd"
            ((missing++)) || true
        fi
    done
    
    if [[ $missing -gt 0 ]]; then
        exit 1
    fi
    
    print_debug "All required commands are available"
}

get_alertmanager_url() {
    # If URL provided via CLI, use it directly
    if [[ -n "$ARG_URL" ]]; then
        print_debug "Using provided URL: $ARG_URL"
        echo "$ARG_URL"
        return 0
    fi
    
    print_info "Looking for Alertmanager URL from Ingress '$INGRESS_NAME'..."
    
    # Get host from Ingress
    local host
    host=$(kubectl get ingress "$INGRESS_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.rules[0].host}' 2>/dev/null) || true
    
    if [[ -z "$host" ]]; then
        print_error "Cannot find Ingress '$INGRESS_NAME' in namespace '$NAMESPACE'"
        print_info "Available Ingresses:"
        kubectl get ingress -n "$NAMESPACE" 2>/dev/null || true
        exit 1
    fi
    
    print_debug "Found host from Ingress: $host"
    
    # Check if TLS is configured
    local tls_enabled
    tls_enabled=$(kubectl get ingress "$INGRESS_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.tls}' 2>/dev/null) || true
    
    if [[ -n "$tls_enabled" ]]; then
        print_debug "TLS is enabled"
        echo "https://$host"
    else
        print_debug "TLS is not enabled"
        echo "http://$host"
    fi
}

test_alertmanager_connection() {
    local url="$1"
    local curl_opts=("-sf" "--max-time" "$CURL_TIMEOUT")
    
    # Add insecure flag only if explicitly requested
    if [[ "$ARG_INSECURE" == "true" ]]; then
        curl_opts+=("-k")
        print_debug "SSL verification disabled (insecure mode)"
    fi
    
    print_info "Testing connection to Alertmanager..."
    print_debug "Curl options: ${curl_opts[*]}"
    
    if curl "${curl_opts[@]}" "$url/-/ready" &> /dev/null; then
        print_success "Alertmanager accessible: $url"
        return 0
    else
        print_error "Cannot reach Alertmanager at $url"
        print_warning "Check that the Ingress is properly configured and accessible"
        if [[ "$ARG_INSECURE" != "true" ]]; then
            print_info "If using self-signed certificates, try with -k/--insecure option"
        fi
        return 1
    fi
}

calculate_timestamps() {
    local duration_minutes="$1"
    local start_ts
    local end_ts
    
    # Start timestamp (now in UTC)
    start_ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # End timestamp (now + duration)
    if date --version 2>&1 | grep -q "GNU"; then
        # GNU date (Linux)
        end_ts=$(date -u -d "+${duration_minutes} minutes" +"%Y-%m-%dT%H:%M:%SZ")
    else
        # BSD date (macOS)
        end_ts=$(date -u -v "+${duration_minutes}M" +"%Y-%m-%dT%H:%M:%SZ")
    fi
    
    print_debug "Start timestamp: $start_ts"
    print_debug "End timestamp: $end_ts"
    
    # Return values via global variables (documented behavior)
    SILENCE_START="$start_ts"
    SILENCE_END="$end_ts"
}

dry_run_silence() {
    local url="$1"
    local duration="$2"
    local comment="${3:-Global silence created via script}"
    
    calculate_timestamps "$duration"
    
    print_warning "DRY-RUN MODE - No silence will be created"
    echo
    echo "Would create silence with the following parameters:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Alertmanager URL:  $url"
    echo "  Duration:          $duration minutes"
    echo "  Start:             $SILENCE_START"
    echo "  End:               $SILENCE_END"
    echo "  Comment:           $comment"
    echo "  Created by:        alertmanager-silence-script"
    echo "  Matcher:           alertname =~ .+"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    
    # Show the JSON payload that would be sent (compatible with old jq versions)
    local payload
    payload=$(build_silence_payload "$SILENCE_START" "$SILENCE_END" "$comment")
    
    echo "JSON Payload:"
    echo "$payload" | jq -C '.' 2>/dev/null || echo "$payload"
    echo
    print_info "Run without --dry-run to actually create the silence"
}

# Build JSON payload - compatible with old jq versions (Ubuntu 18.04)
build_silence_payload() {
    local start="$1"
    local end="$2"
    local comment="$3"
    
    # Escape special characters in comment for JSON
    local escaped_comment
    escaped_comment=$(printf '%s' "$comment" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g')
    
    cat <<EOF
{
  "matchers": [
    {
      "name": "alertname",
      "value": ".+",
      "isRegex": true
    }
  ],
  "startsAt": "${start}",
  "endsAt": "${end}",
  "createdBy": "alertmanager-silence-script",
  "comment": "${escaped_comment}"
}
EOF
}

create_silence() {
    local url="$1"
    local duration="$2"
    local comment="${3:-Global silence created via script}"
    local curl_opts=("-s" "--max-time" "$CURL_TIMEOUT")
    
    # Add insecure flag only if explicitly requested
    if [[ "$ARG_INSECURE" == "true" ]]; then
        curl_opts+=("-k")
    fi
    
    calculate_timestamps "$duration"
    
    print_info "Creating silence for $duration minutes (until $SILENCE_END)..."
    
    # Create JSON payload (compatible with old jq versions)
    local payload
    payload=$(build_silence_payload "$SILENCE_START" "$SILENCE_END" "$comment")
    
    print_debug "Payload: $payload"
    
    # Send request
    local response
    local http_code
    local body
    
    response=$(curl "${curl_opts[@]}" -w "\n%{http_code}" -X POST "$url/api/v2/silences" \
        -H "Content-Type: application/json" \
        -d "$payload")
    
    http_code=$(echo "$response" | tail -n 1)
    # Use sed for better portability instead of head -n -1
    body=$(echo "$response" | sed '$d')
    
    print_debug "HTTP response code: $http_code"
    
    if [[ "$http_code" == "200" ]] || [[ "$http_code" == "201" ]]; then
        print_success "Silence created successfully!"
        echo
        echo "$body" | jq -C '.' 2>/dev/null || echo "$body"
        echo
        print_success "Silence active until: $SILENCE_END"
        
        # Extract and display silenceID if available
        local silence_id
        silence_id=$(echo "$body" | jq -r '.silenceID // empty' 2>/dev/null) || true
        if [[ -n "$silence_id" ]]; then
            print_info "Silence ID: $silence_id"
        fi
    else
        print_error "Failed to create silence (HTTP $http_code)"
        echo
        echo "Response:"
        echo "$body" | jq -C '.' 2>/dev/null || echo "$body"
        exit 1
    fi
}

show_menu() {
    echo
    echo "╔════════════════════════════════════════╗"
    echo "║   Alertmanager Silence Duration        ║"
    echo "╚════════════════════════════════════════╝"
    echo
    echo "  1) 30 minutes"
    echo "  2) 1 hour"
    echo "  3) 2 hours"
    echo "  4) 4 hours"
    echo "  5) 8 hours"
    echo "  6) 12 hours"
    echo "  7) 24 hours"
    echo "  8) Custom duration"
    echo
}

get_user_choice() {
    local choice
    read -r -p "👉 Your choice [1-8]: " choice
    
    case "$choice" in
        1) echo "30" ;;
        2) echo "60" ;;
        3) echo "120" ;;
        4) echo "240" ;;
        5) echo "480" ;;
        6) echo "720" ;;
        7) echo "1440" ;;
        8) 
            local custom_duration
            read -r -p "   Duration in minutes: " custom_duration
            if validate_duration "$custom_duration"; then
                echo "$custom_duration"
            else
                exit 1
            fi
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
}

# ============================================
# Main
# ============================================

main() {
    # Parse command line arguments
    parse_args "$@"
    
    echo
    echo "╔═══════════════════════════════════════════════╗"
    echo "║  🔕 Alertmanager Silence Creator              ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo
    
    # Pre-checks
    check_requirements
    
    # Get Alertmanager URL
    local alertmanager_url
    alertmanager_url=$(get_alertmanager_url)
    
    # Test connection (skip in dry-run mode)
    if [[ "$ARG_DRY_RUN" != "true" ]]; then
        if ! test_alertmanager_connection "$alertmanager_url"; then
            exit 1
        fi
    else
        print_info "Dry-run mode: skipping connection test"
    fi
    
    local duration
    local comment
    
    # Interactive or non-interactive mode
    if [[ "$ARG_INTERACTIVE" == "true" ]]; then
        # Interactive mode: Menu and user choice
        show_menu
        duration=$(get_user_choice)
        
        # Ask for optional comment
        echo
        read -r -p "💬 Comment (optional): " comment
        if [[ -z "$comment" ]]; then
            comment="Global silence for ${duration} minutes"
        fi
    else
        # Non-interactive mode: Use CLI arguments
        if [[ -z "$ARG_DURATION" ]]; then
            print_error "Duration is required in non-interactive mode. Use -d/--duration option."
            echo "Use --help for usage information."
            exit 1
        fi
        
        if ! validate_duration "$ARG_DURATION"; then
            exit 1
        fi
        
        duration="$ARG_DURATION"
        
        if [[ -n "$ARG_COMMENT" ]]; then
            comment="$ARG_COMMENT"
        else
            comment="Global silence for ${duration} minutes"
        fi
        
        print_info "Non-interactive mode: duration=${duration}min, comment='${comment}'"
    fi
    
    # Create silence (or dry-run)
    echo
    if [[ "$ARG_DRY_RUN" == "true" ]]; then
        dry_run_silence "$alertmanager_url" "$duration" "$comment"
    else
        create_silence "$alertmanager_url" "$duration" "$comment"
    fi
    
    echo
    print_success "Operation completed!"
}

# Run the script
main "$@"
