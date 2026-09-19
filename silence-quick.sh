#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Quick Alertmanager Silence Script
# Usage: ./silence-quick.sh [duration_in_minutes] [comment]
# ============================================

NAMESPACE="${NAMESPACE:-monitoring}"
INGRESS_NAME="${INGRESS_NAME:-}"
HTTPROUTE_NAME="${HTTPROUTE_NAME:-${INGRESS_NAME:-alertmanager}}"
DURATION="${1:-60}"  # Default 1 hour
COMMENT="${2:-Global silence via script}"

# Get Ingress URL
echo "🔍 Retrieving Alertmanager URL..."
if HOST=$(kubectl get httproutes.gateway.networking.k8s.io "$HTTPROUTE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.hostnames[0]}' 2>/dev/null); then
    if [[ -z "$HOST" ]]; then
        echo "❌ HttpRoute '$HTTPROUTE_NAME' has no hostname in '$NAMESPACE'" >&2
        exit 1
    fi

    PARENT_GATEWAY=$(kubectl get httproutes.gateway.networking.k8s.io "$HTTPROUTE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.parentRefs[0].name}' 2>/dev/null) || true
    PARENT_NAMESPACE=$(kubectl get httproutes.gateway.networking.k8s.io "$HTTPROUTE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.parentRefs[0].namespace}' 2>/dev/null) || true
    SECTION_NAME=$(kubectl get httproutes.gateway.networking.k8s.io "$HTTPROUTE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.parentRefs[0].sectionName}' 2>/dev/null) || true
    PARENT_NAMESPACE="${PARENT_NAMESPACE:-$NAMESPACE}"

    if [[ -z "$PARENT_GATEWAY" ]]; then
        echo "❌ HttpRoute '$HTTPROUTE_NAME' has no Gateway parent in '$NAMESPACE'" >&2
        exit 1
    fi

    GATEWAY_JSON=$(kubectl get gateways.gateway.networking.k8s.io "$PARENT_GATEWAY" -n "$PARENT_NAMESPACE" -o json 2>/dev/null) || true
    PROTOCOL=$(printf '%s' "$GATEWAY_JSON" | jq -r --arg section "$SECTION_NAME" '
        if $section != "" then
            [.spec.listeners[]? | select(.name == $section) | .protocol][0] // ""
        else
            ([.spec.listeners[]?.protocol] | if index("HTTPS") != null then "HTTPS" elif index("HTTP") != null then "HTTP" else "" end)
        end')

    if [[ "$PROTOCOL" == "HTTPS" ]]; then
        URL="https://$HOST"
    elif [[ "$PROTOCOL" == "HTTP" ]]; then
        URL="http://$HOST"
    else
        echo "❌ Cannot determine protocol from Gateway '$PARENT_GATEWAY' for HttpRoute '$HTTPROUTE_NAME'" >&2
        exit 1
    fi
elif [[ -n "$INGRESS_NAME" ]] && HOST=$(kubectl get ingress "$INGRESS_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.rules[0].host}' 2>/dev/null); then
    if [[ -z "$HOST" ]]; then
        echo "❌ Ingress '$INGRESS_NAME' has no host in '$NAMESPACE'" >&2
        exit 1
    fi

    TLS=$(kubectl get ingress "$INGRESS_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.tls}' 2>/dev/null) || true

    if [[ -n "$TLS" ]]; then
        URL="https://$HOST"
    else
        URL="http://$HOST"
    fi
else
    echo "❌ Cannot find HttpRoute '$HTTPROUTE_NAME'${INGRESS_NAME:+ or Ingress '$INGRESS_NAME'} in '$NAMESPACE'" >&2
    exit 1
fi

echo "✅ URL: $URL"

# Calculate timestamps
if date --version 2>&1 | grep -q "GNU"; then
    START=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    END=$(date -u -d "+${DURATION} minutes" +"%Y-%m-%dT%H:%M:%SZ")
else
    START=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    END=$(date -u -v "+${DURATION}M" +"%Y-%m-%dT%H:%M:%SZ")
fi

# Create payload
PAYLOAD=$(jq -n \
    --arg start "$START" \
    --arg end "$END" \
    --arg comment "$COMMENT" \
    '{
        matchers: [{name: "alertname", value: ".+", isRegex: true}],
        startsAt: $start,
        endsAt: $end,
        createdBy: "quick-silence-script",
        comment: $comment
    }')

# Send request
echo "🔕 Creating silence for $DURATION minutes..."
RESPONSE=$(curl -sk -X POST "$URL/api/v2/silences" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")

echo "✅ Silence created until: $END"
echo "$RESPONSE" | jq -C '.'
