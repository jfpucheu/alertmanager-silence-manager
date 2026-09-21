#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Alertmanager Silence Management
# ============================================

NAMESPACE="${NAMESPACE:-monitoring}"
INGRESS_NAME="${INGRESS_NAME:-}"
HTTPROUTE_NAME="${HTTPROUTE_NAME:-${INGRESS_NAME:-alertmanager}}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_success() { printf "%b\n" "${GREEN}✅ $1${NC}"; }
print_info() { printf "%b\n" "${BLUE}ℹ️  $1${NC}"; }
print_error() { printf "%b\n" "${RED}❌ $1${NC}" >&2; }
print_warning() { printf "%b\n" "${YELLOW}⚠️  $1${NC}"; }

# Get Alertmanager URL
get_url() {
    local host
    if host=$(kubectl get httproutes.gateway.networking.k8s.io "$HTTPROUTE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.hostnames[0]}' 2>/dev/null); then
        if [[ -z "$host" ]]; then
            print_error "HttpRoute '$HTTPROUTE_NAME' has no hostname in '$NAMESPACE'"
            exit 1
        fi

        local parent_gateway parent_namespace section_name gateway_json protocol
        parent_gateway=$(kubectl get httproutes.gateway.networking.k8s.io "$HTTPROUTE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.parentRefs[0].name}' 2>/dev/null) || true
        parent_namespace=$(kubectl get httproutes.gateway.networking.k8s.io "$HTTPROUTE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.parentRefs[0].namespace}' 2>/dev/null) || true
        section_name=$(kubectl get httproutes.gateway.networking.k8s.io "$HTTPROUTE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.parentRefs[0].sectionName}' 2>/dev/null) || true
        parent_namespace="${parent_namespace:-$NAMESPACE}"

        if [[ -z "$parent_gateway" ]]; then
            print_error "HttpRoute '$HTTPROUTE_NAME' has no Gateway parent in '$NAMESPACE'"
            exit 1
        fi

        gateway_json=$(kubectl get gateways.gateway.networking.k8s.io "$parent_gateway" -n "$parent_namespace" -o json 2>/dev/null) || true
        protocol=$(printf '%s' "$gateway_json" | jq -r --arg section "$section_name" '
            if $section != "" then
                [.spec.listeners[]? | select(.name == $section) | .protocol][0] // ""
            else
                ([.spec.listeners[]?.protocol] | if index("HTTPS") != null then "HTTPS" elif index("HTTP") != null then "HTTP" else "" end)
            end')

        if [[ "$protocol" == "HTTPS" ]]; then
            echo "https://$host"
        elif [[ "$protocol" == "HTTP" ]]; then
            echo "http://$host"
        else
            print_error "Cannot determine protocol from Gateway '$parent_gateway' for HttpRoute '$HTTPROUTE_NAME'"
            exit 1
        fi
    elif [[ -n "$INGRESS_NAME" ]] && host=$(kubectl get ingress "$INGRESS_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.rules[0].host}' 2>/dev/null); then
        if [[ -z "$host" ]]; then
            print_error "Ingress '$INGRESS_NAME' has no host in '$NAMESPACE'"
            exit 1
        fi

        local tls
        tls=$(kubectl get ingress "$INGRESS_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.tls}' 2>/dev/null) || true

        if [[ -n "$tls" ]]; then
            echo "https://$host"
        else
            echo "http://$host"
        fi
    else
        print_error "Cannot find HttpRoute '$HTTPROUTE_NAME'${INGRESS_NAME:+ or Ingress '$INGRESS_NAME'} in '$NAMESPACE'"
        exit 1
    fi
}

# List all silences
list_silences() {
    local url="$1"
    
    print_info "Fetching active silences..."
    echo
    
    local response
    response=$(curl -sk "$url/api/v2/silences" 2>/dev/null)
    
    # Count silences
    local count
    count=$(echo "$response" | jq '. | length')
    
    if [[ "$count" -eq 0 ]]; then
        print_warning "No active silences"
        return
    fi
    
    print_success "$count silence(s) found"
    echo
    
    # Display silences in table format
    echo "$response" | jq -r '
        ["ID", "CREATED BY", "START", "END", "STATUS", "COMMENT"],
        ["──────────────────────────────────────", "──────────────", "─────────────────────", "─────────────────────", "──────────", "─────────────────────────"],
        (.[] | [
            .id[0:36],
            .createdBy[0:14],
            .startsAt[0:19],
            .endsAt[0:19],
            .status.state,
            .comment[0:25]
        ]) | @tsv
    ' | column -t -s $'\t'
    
    echo
    
    # Full details if requested
    if [[ "${VERBOSE:-}" == "true" ]]; then
        echo
        print_info "Full details:"
        echo "$response" | jq -C '.'
    fi
}

# Delete a silence
delete_silence() {
    local url="$1"
    local silence_id="$2"
    
    print_warning "Deleting silence: $silence_id"
    
    local http_code
    http_code=$(curl -sk -o /dev/null -w "%{http_code}" -X DELETE "$url/api/v2/silence/$silence_id")
    
    if [[ "$http_code" == "200" ]]; then
        print_success "Silence deleted successfully"
    else
        print_error "Failed to delete silence (HTTP $http_code)"
        exit 1
    fi
}

# Delete all silences
delete_all_silences() {
    local url="$1"
    
    print_warning "⚠️  WARNING: You are about to delete ALL active silences!"
    read -r -p "Are you sure? (type YES in capital letters): " confirm
    
    if [[ "$confirm" != "YES" ]]; then
        print_info "Cancelled"
        exit 0
    fi
    
    local response
    response=$(curl -sk "$url/api/v2/silences")
    
    local ids
    ids=$(echo "$response" | jq -r '.[].id')
    
    if [[ -z "$ids" ]]; then
        print_warning "No silences to delete"
        return
    fi
    
    local count=0
    while IFS= read -r id; do
        print_info "Deleting: $id"
        delete_silence "$url" "$id"
        ((count++))
    done <<< "$ids"
    
    echo
    print_success "$count silence(s) deleted"
}

# Show silence details
show_silence() {
    local url="$1"
    local silence_id="$2"
    
    print_info "Silence details: $silence_id"
    echo
    
    local response
    response=$(curl -sk "$url/api/v2/silence/$silence_id")
    
    echo "$response" | jq -C '.'
}

# Main menu
show_menu() {
    echo
    echo "╔═══════════════════════════════════════════════╗"
    echo "║  🔕 Alertmanager Silence Management           ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo
    echo "  1) 📋 List all silences"
    echo "  2) 🔍 View silence details"
    echo "  3) 🗑️  Delete a specific silence"
    echo "  4) 💥 Delete ALL silences"
    echo "  5) 🚪 Exit"
    echo
}

main() {
    # Check requirements
    for cmd in kubectl curl jq; do
        if ! command -v "$cmd" &> /dev/null; then
            print_error "Required command: $cmd"
            exit 1
        fi
    done
    
    # Get URL
    URL=$(get_url)
    print_success "Alertmanager: $URL"
    
    # Main loop
    while true; do
        show_menu
        read -r -p "👉 Your choice [1-5]: " choice
        echo
        
        case "$choice" in
            1)
                list_silences "$URL"
                ;;
            2)
                read -r -p "Silence ID: " silence_id
                show_silence "$URL" "$silence_id"
                ;;
            3)
                read -r -p "Silence ID to delete: " silence_id
                delete_silence "$URL" "$silence_id"
                ;;
            4)
                delete_all_silences "$URL"
                ;;
            5)
                print_info "Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid choice"
                ;;
        esac
        
        echo
        read -r -p "Press Enter to continue..."
    done
}

# Command line mode
if [[ $# -gt 0 ]]; then
    URL=$(get_url)
    
    case "$1" in
        list|ls)
            list_silences "$URL"
            ;;
        delete|del|rm)
            if [[ -z "${2:-}" ]]; then
                print_error "Usage: $0 delete SILENCE_ID"
                exit 1
            fi
            delete_silence "$URL" "$2"
            ;;
        show|get)
            if [[ -z "${2:-}" ]]; then
                print_error "Usage: $0 show SILENCE_ID"
                exit 1
            fi
            show_silence "$URL" "$2"
            ;;
        delete-all|clean)
            delete_all_silences "$URL"
            ;;
        *)
            echo "Usage: $0 {list|show|delete|delete-all} [SILENCE_ID]"
            echo
            echo "Commands:"
            echo "  list          - List all silences"
            echo "  show ID       - Show silence details"
            echo "  delete ID     - Delete a silence"
            echo "  delete-all    - Delete all silences"
            echo
            echo "Or run without arguments for interactive mode"
            exit 1
            ;;
    esac
else
    main
fi
