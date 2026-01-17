#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Alertmanager Silence Creator
# ============================================

# Colors for display
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="${NAMESPACE:-monitoring}"
INGRESS_NAME="${INGRESS_NAME:-alertmanager}"

# ============================================
# Utility Functions
# ============================================

print_success() { printf "%b\n" "${GREEN}✅ $1${NC}"; }
print_info() { printf "%b\n" "${BLUE}ℹ️  $1${NC}"; }
print_error() { printf "%b\n" "${RED}❌ $1${NC}" >&2; }
print_warning() { printf "%b\n" "${YELLOW}⚠️  $1${NC}"; }

check_requirements() {
    local missing=0
    
    for cmd in kubectl curl jq date; do
        if ! command -v "$cmd" &> /dev/null; then
            print_error "Required command missing: $cmd"
            ((missing++))
        fi
    done
    
    if [[ $missing -gt 0 ]]; then
        exit 1
    fi
}

get_alertmanager_url() {
    print_info "Looking for Alertmanager URL from Ingress '$INGRESS_NAME'..."
    
    # Get host from Ingress
    local host
    host=$(kubectl get ingress "$INGRESS_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.rules[0].host}' 2>/dev/null)
    
    if [[ -z "$host" ]]; then
        print_error "Cannot find Ingress '$INGRESS_NAME' in namespace '$NAMESPACE'"
        print_info "Available Ingresses:"
        kubectl get ingress -n "$NAMESPACE" 2>/dev/null || true
        exit 1
    fi
    
    # Check if TLS is configured
    local tls_enabled
    tls_enabled=$(kubectl get ingress "$INGRESS_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.tls}' 2>/dev/null)
    
    if [[ -n "$tls_enabled" ]]; then
        echo "https://$host"
    else
        echo "http://$host"
    fi
}

test_alertmanager_connection() {
    local url="$1"
    
    print_info "Testing connection to Alertmanager..."
    
    if curl -sf --max-time 5 "$url/-/ready" &> /dev/null || \
       curl -skf --max-time 5 "$url/-/ready" &> /dev/null; then
        print_success "Alertmanager accessible: $url"
        return 0
    else
        print_error "Cannot reach Alertmanager at $url"
        print_warning "Check that the Ingress is properly configured and accessible"
        return 1
    fi
}

calculate_timestamps() {
    local duration_minutes="$1"
    
    # Start timestamp (now in UTC)
    START=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # End timestamp (now + duration)
    if date --version 2>&1 | grep -q "GNU"; then
        # GNU date (Linux)
        END=$(date -u -d "+${duration_minutes} minutes" +"%Y-%m-%dT%H:%M:%SZ")
    else
        # BSD date (macOS)
        END=$(date -u -v "+${duration_minutes}M" +"%Y-%m-%dT%H:%M:%SZ")
    fi
}

create_silence() {
    local url="$1"
    local duration="$2"
    local comment="${3:-Global silence created via script}"
    
    calculate_timestamps "$duration"
    
    print_info "Creating silence for $duration minutes (until $END)..."
    
    # Create JSON payload
    local payload
    payload=$(jq -n \
        --arg start "$START" \
        --arg end "$END" \
        --arg comment "$comment" \
        '{
            matchers: [
                {
                    name: "alertname",
                    value: ".+",
                    isRegex: true
                }
            ],
            startsAt: $start,
            endsAt: $end,
            createdBy: "alertmanager-silence-script",
            comment: $comment
        }')
    
    # Send request
    local response
    local http_code
    
    response=$(curl -sk -w "\n%{http_code}" -X POST "$url/api/v2/silences" \
        -H "Content-Type: application/json" \
        -d "$payload")
    
    http_code=$(echo "$response" | tail -n 1)
    local body=$(echo "$response" | head -n -1)
    
    if [[ "$http_code" == "200" ]] || [[ "$http_code" == "201" ]]; then
        print_success "Silence created successfully!"
        echo
        echo "$body" | jq -C '.'
        echo
        print_success "Silence active until: $END"
        
        # Extract and display silenceID if available
        local silence_id
        silence_id=$(echo "$body" | jq -r '.silenceID // empty')
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
            read -r -p "   Duration in minutes: " custom_duration
            if [[ "$custom_duration" =~ ^[0-9]+$ ]]; then
                echo "$custom_duration"
            else
                print_error "Invalid duration"
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
    echo
    echo "╔═══════════════════════════════════════════════╗"
    echo "║  🔕 Alertmanager Silence Creator             ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo
    
    # Pre-checks
    check_requirements
    
    # Get Alertmanager URL
    ALERTMANAGER_URL=$(get_alertmanager_url)
    
    # Test connection
    if ! test_alertmanager_connection "$ALERTMANAGER_URL"; then
        exit 1
    fi
    
    # Menu and user choice
    show_menu
    DURATION=$(get_user_choice)
    
    # Ask for optional comment
    echo
    read -r -p "💬 Comment (optional): " COMMENT
    if [[ -z "$COMMENT" ]]; then
        COMMENT="Global silence for ${DURATION} minutes"
    fi
    
    # Create silence
    echo
    create_silence "$ALERTMANAGER_URL" "$DURATION" "$COMMENT"
    
    echo
    print_success "Operation completed!"
}

# Run the script
main "$@"
