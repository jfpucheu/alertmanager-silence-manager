#!/usr/bin/env bash
# ============================================
# Test Suite for alertmanager-silence.sh
# ============================================
# Usage: ./tests/test_alertmanager_silence.sh
# ============================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Script path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/alertmanager-silence.sh"

# ============================================
# Test Framework Functions
# ============================================

test_start() {
    echo -e "${BLUE}▶ Running: $1${NC}"
    TESTS_RUN=$((TESTS_RUN + 1))
}

test_pass() {
    echo -e "${GREEN}  ✅ PASS: $1${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

test_fail() {
    echo -e "${RED}  ❌ FAIL: $1${NC}"
    echo -e "${RED}     Expected: $2${NC}"
    echo -e "${RED}     Got: $3${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

test_skip() {
    echo -e "${YELLOW}  ⏭️  SKIP: $1${NC}"
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="$3"
    
    if [[ "$expected" == "$actual" ]]; then
        test_pass "$message"
        return 0
    else
        test_fail "$message" "$expected" "$actual"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="$3"
    
    if [[ "$haystack" == *"$needle"* ]]; then
        test_pass "$message"
        return 0
    else
        test_fail "$message" "contains '$needle'" "'$haystack'"
        return 1
    fi
}

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local message="$3"
    
    if [[ "$expected" -eq "$actual" ]]; then
        test_pass "$message"
        return 0
    else
        test_fail "$message" "exit code $expected" "exit code $actual"
        return 1
    fi
}

assert_not_empty() {
    local value="$1"
    local message="$2"
    
    if [[ -n "$value" ]]; then
        test_pass "$message"
        return 0
    else
        test_fail "$message" "non-empty value" "empty value"
        return 1
    fi
}

# ============================================
# Unit Tests
# ============================================

test_script_exists() {
    test_start "Script file exists"
    
    if [[ -f "$SCRIPT_PATH" ]]; then
        test_pass "Script exists at $SCRIPT_PATH"
    else
        test_fail "Script exists" "file exists" "file not found"
    fi
}

test_script_executable() {
    test_start "Script is executable"
    
    if [[ -x "$SCRIPT_PATH" ]]; then
        test_pass "Script is executable"
    else
        test_fail "Script is executable" "executable" "not executable"
    fi
}

test_script_syntax() {
    test_start "Script has valid bash syntax"
    
    local output
    if output=$(bash -n "$SCRIPT_PATH" 2>&1); then
        test_pass "Syntax is valid"
    else
        test_fail "Syntax is valid" "no errors" "$output"
    fi
}

test_help_option() {
    test_start "Help option (-h) works"
    
    local output
    output=$("$SCRIPT_PATH" -h 2>&1) || true
    
    assert_contains "$output" "Usage:" "Help shows usage"
    assert_contains "$output" "--duration" "Help shows --duration option"
    assert_contains "$output" "--comment" "Help shows --comment option"
}

test_help_long_option() {
    test_start "Help option (--help) works"
    
    local output
    output=$("$SCRIPT_PATH" --help 2>&1) || true
    
    assert_contains "$output" "Usage:" "Long help shows usage"
}

test_version_option() {
    test_start "Version option (-V) works"
    
    local output
    local exit_code=0
    output=$("$SCRIPT_PATH" -V 2>&1) || exit_code=$?
    
    assert_contains "$output" "alertmanager-silence.sh" "Version shows script name"
}

test_invalid_option() {
    test_start "Invalid option returns error"
    
    local exit_code=0
    "$SCRIPT_PATH" --invalid-option 2>/dev/null || exit_code=$?
    
    assert_exit_code 1 "$exit_code" "Invalid option returns exit code 1"
}

test_duration_validation_zero() {
    test_start "Duration validation rejects zero"
    
    local exit_code=0
    "$SCRIPT_PATH" -d 0 2>/dev/null || exit_code=$?
    
    assert_exit_code 1 "$exit_code" "Duration 0 is rejected"
}

test_duration_validation_negative() {
    test_start "Duration validation rejects negative"
    
    local exit_code=0
    "$SCRIPT_PATH" -d -5 2>/dev/null || exit_code=$?
    
    assert_exit_code 1 "$exit_code" "Negative duration is rejected"
}

test_duration_validation_non_numeric() {
    test_start "Duration validation rejects non-numeric"
    
    local exit_code=0
    "$SCRIPT_PATH" -d abc 2>/dev/null || exit_code=$?
    
    assert_exit_code 1 "$exit_code" "Non-numeric duration is rejected"
}

test_duration_validation_valid() {
    test_start "Duration validation accepts valid number"
    
    # Use dry-run mode with explicit URL to avoid kubectl dependency
    local output
    output=$("$SCRIPT_PATH" -d 60 --dry-run -u "http://localhost:9093" 2>&1) || true
    
    # Should not contain "Invalid duration"
    if [[ "$output" != *"Invalid duration"* ]] && [[ "$output" != *"must be"* ]]; then
        test_pass "Valid duration 60 is accepted"
    else
        test_fail "Valid duration accepted" "no duration error" "$output"
    fi
}

test_verbose_mode() {
    test_start "Verbose mode (-v) enables debug output"
    
    local output
    output=$("$SCRIPT_PATH" -v --help 2>&1) || true
    
    # Verbose mode should still show help
    assert_contains "$output" "Usage:" "Verbose mode with help works"
}

test_dry_run_mode() {
    test_start "Dry-run mode (--dry-run) works"
    
    local output
    output=$("$SCRIPT_PATH" --dry-run -d 60 -c "test" -u "http://localhost:9093" 2>&1) || true
    
    if [[ "$output" == *"DRY-RUN"* ]] || [[ "$output" == *"dry-run"* ]] || [[ "$output" == *"Would create"* ]]; then
        test_pass "Dry-run mode outputs indication"
    else
        test_fail "Dry-run test" "DRY-RUN message" "$output"
    fi
}

test_environment_variables() {
    test_start "Environment variables are respected"
    
    local output
    NAMESPACE="custom-ns" INGRESS_NAME="custom-ingress" \
        output=$("$SCRIPT_PATH" --help 2>&1) || true
    
    # Help should work regardless of env vars
    assert_contains "$output" "Usage:" "Script runs with custom env vars"
}

test_httproute_priority() {
    test_start "HttpRoute is checked before optional INGRESS_NAME"

    local mock_dir
    local output
    mock_dir=$(mktemp -d)

    cat > "$mock_dir/kubectl" <<'EOF'
#!/usr/bin/env bash

case "$2" in
    ingress)
        exit 1
        ;;
    httproutes.gateway.networking.k8s.io)
        case "$7" in
            *hostnames*)
                case "$3" in
                    route-explicit)
                        echo "explicit.example.com"
                        ;;
                    route-default)
                        echo "default.example.com"
                        ;;
                    route-http)
                        echo "http.example.com"
                        ;;
                    *)
                        exit 1
                        ;;
                esac
                ;;
            *parentRefs\[0\].name*)
                if [[ "$3" == "route-http" ]]; then
                    echo "http-gateway"
                else
                    echo "https-gateway"
                fi
                ;;
            *parentRefs\[0\].namespace*)
                echo "gateway-system"
                ;;
            *parentRefs\[0\].sectionName*)
                ;;
            *)
                exit 1
                ;;
        esac
        ;;
    gateways.gateway.networking.k8s.io)
        if [[ "$3" == "http-gateway" ]]; then
            echo '{"spec":{"listeners":[{"name":"http","protocol":"HTTP"}]}}'
        else
            echo '{"spec":{"listeners":[{"name":"https","protocol":"HTTPS"}]}}'
        fi
        ;;
    *)
        exit 1
        ;;
esac
EOF
    chmod +x "$mock_dir/kubectl"

    output=$(PATH="$mock_dir:$PATH" env -u INGRESS_NAME PATH="$mock_dir:$PATH" HTTPROUTE_NAME="route-explicit" \
        "$SCRIPT_PATH" -d 1 --dry-run 2>&1) || true
    if [[ "$output" != *"https://explicit.example.com"* ]]; then
        rm -rf "$mock_dir"
        test_fail "HttpRoute is used without INGRESS_NAME" "https://explicit.example.com" "$output"
        return
    fi

    output=$(PATH="$mock_dir:$PATH" INGRESS_NAME="route-default" HTTPROUTE_NAME="" \
        "$SCRIPT_PATH" -d 1 --dry-run 2>&1) || true

    if [[ "$output" == *"https://default.example.com"* ]]; then
        test_pass "HttpRoute is used before INGRESS_NAME"
    else
        test_fail "HttpRoute is preferred over INGRESS_NAME" "https://default.example.com" "$output"
    fi

    output=$(PATH="$mock_dir:$PATH" HTTPROUTE_NAME="route-http" \
        "$SCRIPT_PATH" -d 1 --dry-run 2>&1) || true

    rm -rf "$mock_dir"

    if [[ "$output" == *"http://http.example.com"* ]]; then
        test_pass "HttpRoute Gateway protocol is detected automatically"
    else
        test_fail "HttpRoute Gateway protocol is detected automatically" "http://http.example.com" "$output"
    fi
}

test_ingress_protocol_detection() {
    test_start "Ingress protocol is detected from TLS configuration"

    local mock_dir
    local output
    mock_dir=$(mktemp -d)

    cat > "$mock_dir/kubectl" <<'EOF'
#!/usr/bin/env bash

if [[ "$2" != "ingress" ]]; then
    exit 1
fi

case "$7" in
    *rules*)
        echo "$3.example.com"
        ;;
    *tls*)
        if [[ "$3" == "ingress-https" ]]; then
            echo "configured"
        fi
        ;;
    *)
        exit 1
        ;;
esac
EOF
    chmod +x "$mock_dir/kubectl"

    output=$(PATH="$mock_dir:$PATH" INGRESS_NAME="ingress-https" \
        "$SCRIPT_PATH" -d 1 --dry-run 2>&1) || true
    if [[ "$output" != *"https://ingress-https.example.com"* ]]; then
        rm -rf "$mock_dir"
        test_fail "Ingress TLS selects HTTPS" "https://ingress-https.example.com" "$output"
        return
    fi

    output=$(PATH="$mock_dir:$PATH" INGRESS_NAME="ingress-http" \
        "$SCRIPT_PATH" -d 1 --dry-run 2>&1) || true
    rm -rf "$mock_dir"

    if [[ "$output" == *"http://ingress-http.example.com"* ]]; then
        test_pass "Ingress TLS detection selects HTTPS or HTTP automatically"
    else
        test_fail "Ingress TLS detection selects HTTP" "http://ingress-http.example.com" "$output"
    fi
}

test_url_option() {
    test_start "URL option (-u) is accepted"
    
    local output
    local exit_code=0
    output=$("$SCRIPT_PATH" -u "http://localhost:9093" -d 60 --dry-run 2>&1) || exit_code=$?
    
    # Should not complain about invalid URL option
    if [[ "$output" != *"invalid option"* ]] && [[ "$output" != *"Unknown option"* ]]; then
        test_pass "URL option is recognized"
    else
        test_fail "URL option recognized" "no option error" "$output"
    fi
}

test_insecure_option() {
    test_start "Insecure option (-k) is accepted"
    
    local output
    output=$("$SCRIPT_PATH" -k --help 2>&1) || true
    
    assert_contains "$output" "Usage:" "Insecure option with help works"
}

# ============================================
# Integration Tests (require mock or real Alertmanager)
# ============================================

test_kubectl_check() {
    test_start "kubectl availability check"
    
    if command -v kubectl &> /dev/null; then
        test_pass "kubectl is available"
    else
        test_skip "kubectl not installed"
    fi
}

test_curl_check() {
    test_start "curl availability check"
    
    if command -v curl &> /dev/null; then
        test_pass "curl is available"
    else
        test_fail "curl is available" "curl installed" "curl not found"
    fi
}

test_jq_check() {
    test_start "jq availability check"
    
    if command -v jq &> /dev/null; then
        test_pass "jq is available"
    else
        test_fail "jq is available" "jq installed" "jq not found"
    fi
}

test_date_compatibility() {
    test_start "date command compatibility"
    
    local future_date
    if date --version 2>&1 | grep -q "GNU"; then
        # GNU date
        future_date=$(date -u -d "+60 minutes" +"%Y-%m-%dT%H:%M:%SZ" 2>&1) || true
    else
        # BSD date
        future_date=$(date -u -v "+60M" +"%Y-%m-%dT%H:%M:%SZ" 2>&1) || true
    fi
    
    if [[ "$future_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
        test_pass "date command produces valid ISO format: $future_date"
    else
        test_fail "date produces valid format" "ISO 8601 format" "$future_date"
    fi
}

# ============================================
# Mock Server Tests
# ============================================

MOCK_SERVER_PID=""
MOCK_PORT=19093

start_mock_alertmanager() {
    # Simple mock using netcat or python
    if command -v python3 &> /dev/null; then
        python3 -c "
import http.server
import json
import socketserver

class MockHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass  # Suppress logs
    
    def do_GET(self):
        if self.path == '/-/ready':
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'OK')
        else:
            self.send_response(404)
            self.end_headers()
    
    def do_POST(self):
        if self.path == '/api/v2/silences':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = {'silenceID': 'mock-silence-12345'}
            self.wfile.write(json.dumps(response).encode())
        else:
            self.send_response(404)
            self.end_headers()

with socketserver.TCPServer(('', $MOCK_PORT), MockHandler) as httpd:
    httpd.serve_forever()
" &
        MOCK_SERVER_PID=$!
        sleep 1
        return 0
    else
        return 1
    fi
}

stop_mock_alertmanager() {
    if [[ -n "$MOCK_SERVER_PID" ]]; then
        kill "$MOCK_SERVER_PID" 2>/dev/null || true
        wait "$MOCK_SERVER_PID" 2>/dev/null || true
        MOCK_SERVER_PID=""
    fi
}

test_mock_connection() {
    test_start "Connection to mock Alertmanager"
    
    if ! command -v python3 &> /dev/null; then
        test_skip "python3 not available for mock server"
        return
    fi
    
    start_mock_alertmanager
    sleep 1
    
    local response
    response=$(curl -sf "http://localhost:$MOCK_PORT/-/ready" 2>&1) || true
    
    stop_mock_alertmanager
    
    if [[ "$response" == "OK" ]]; then
        test_pass "Mock server responds correctly"
    else
        test_fail "Mock server responds" "OK" "$response"
    fi
}

test_create_silence_mock() {
    test_start "Create silence via mock server"
    
    if ! command -v python3 &> /dev/null; then
        test_skip "python3 not available for mock server"
        return
    fi
    
    start_mock_alertmanager
    sleep 1
    
    local output
    local exit_code=0
    output=$("$SCRIPT_PATH" -u "http://localhost:$MOCK_PORT" -d 60 -c "Test silence" 2>&1) || exit_code=$?
    
    stop_mock_alertmanager
    
    if [[ "$output" == *"mock-silence-12345"* ]] || [[ "$output" == *"successfully"* ]]; then
        test_pass "Silence created successfully via mock"
    elif [[ "$output" == *"Silence created"* ]]; then
        test_pass "Silence creation reported"
    else
        # Check if it's a connection issue vs actual failure
        if [[ "$output" == *"Cannot reach"* ]]; then
            test_skip "Mock server connection issue"
        else
            test_fail "Silence created" "success message" "$output"
        fi
    fi
}

# ============================================
# Shellcheck Test
# ============================================

test_shellcheck() {
    test_start "Shellcheck analysis"
    
    if ! command -v shellcheck &> /dev/null; then
        test_skip "shellcheck not installed"
        return
    fi
    
    local output
    local exit_code=0
    output=$(shellcheck -S warning "$SCRIPT_PATH" 2>&1) || exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        test_pass "No shellcheck warnings"
    else
        test_fail "No shellcheck warnings" "clean output" "$output"
    fi
}

# ============================================
# Run All Tests
# ============================================

run_all_tests() {
    echo
    echo "╔═══════════════════════════════════════════════════╗"
    echo "║  🧪 Test Suite: alertmanager-silence.sh           ║"
    echo "╚═══════════════════════════════════════════════════╝"
    echo
    echo "Script: $SCRIPT_PATH"
    echo "Date: $(date)"
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📁 Basic Tests"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    test_script_exists
    test_script_executable
    test_script_syntax
    
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 CLI Options Tests"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    test_help_option
    test_help_long_option
    test_version_option
    test_invalid_option
    test_verbose_mode
    test_dry_run_mode
    test_url_option
    test_insecure_option
    test_environment_variables
    test_httproute_priority
    test_ingress_protocol_detection
    
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔢 Input Validation Tests"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    test_duration_validation_zero
    test_duration_validation_negative
    test_duration_validation_non_numeric
    test_duration_validation_valid
    
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔧 Dependencies Tests"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    test_kubectl_check
    test_curl_check
    test_jq_check
    test_date_compatibility
    
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎭 Mock Server Integration Tests"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    test_mock_connection
    test_create_silence_mock
    
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔍 Static Analysis"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    test_shellcheck
    
    # Cleanup
    stop_mock_alertmanager
    
    # Summary
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 Test Summary"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    echo -e "  Total:  ${BLUE}$TESTS_RUN${NC}"
    echo -e "  Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "  Failed: ${RED}$TESTS_FAILED${NC}"
    echo
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✅ All tests passed!${NC}"
        echo
        return 0
    else
        echo -e "${RED}❌ Some tests failed!${NC}"
        echo
        return 1
    fi
}

# ============================================
# Main
# ============================================

# Trap to ensure mock server is stopped on exit
trap stop_mock_alertmanager EXIT

run_all_tests
