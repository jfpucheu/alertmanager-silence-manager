#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Quick Alertmanager Silence Script
# Usage: ./silence-quick.sh [duration_in_minutes] [comment]
# ============================================

NAMESPACE="${NAMESPACE:-monitoring}"
INGRESS_NAME="${INGRESS_NAME:-alertmanager}"
DURATION="${1:-60}"  # Default 1 hour
COMMENT="${2:-Global silence via script}"

# Get Ingress URL
echo "🔍 Retrieving Alertmanager URL..."
HOST=$(kubectl get ingress "$INGRESS_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.rules[0].host}')
TLS=$(kubectl get ingress "$INGRESS_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.tls}')

if [[ -n "$TLS" ]]; then
    URL="https://$HOST"
else
    URL="http://$HOST"
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
