#!/bin/bash
set -euo pipefail

ENDPOINT="${ENDPOINT:-http://localhost:9000/2015-03-31/functions/function/invocations}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

test_basic_invocation() {
    local response
    
    echo "Testing basic invocation..."
    response=$(curl -sS -X POST "$ENDPOINT" -d @"$SCRIPT_DIR/payloads/basic.json")
    
    if echo "$response" | jq -e '.' > /dev/null 2>&1; then
        pass "Basic invocation returned valid JSON"
        return 0
    else
        fail "Basic invocation failed"
        echo "$response"
        return 1
    fi
}

test_response_structure() {
    local response
    
    echo "Testing response structure..."
    response=$(curl -sS -X POST "$ENDPOINT" -d @"$SCRIPT_DIR/payloads/basic.json")
    
    # Check if response has expected structure (adjust based on your handler)
    if echo "$response" | jq -e 'type == "object"' > /dev/null 2>&1; then
        pass "Response has valid structure"
        return 0
    else
        fail "Response structure invalid"
        echo "$response" | jq
        return 1
    fi
}

test_performance() {
    local start end duration
    
    echo "Testing performance..."
    start=$(date +%s%N)
    curl -sS -X POST "$ENDPOINT" -d @"$SCRIPT_DIR/payloads/basic.json" > /dev/null
    end=$(date +%s%N)
    
    duration=$(( (end - start) / 1000000 ))
    
    if [ "$duration" -lt 5000 ]; then
        pass "Response time: ${duration}ms"
        return 0
    else
        fail "Response too slow: ${duration}ms"
        return 1
    fi
}

main() {
    local failed=0
    
    echo "Running integration tests against: $ENDPOINT"
    echo ""
    
    test_basic_invocation || ((failed++))
    test_response_structure || ((failed++))
    test_performance || ((failed++))
    
    echo ""
    if [ $failed -eq 0 ]; then
        echo -e "${GREEN}All tests passed${NC}"
        return 0
    else
        echo -e "${RED}$failed test(s) failed${NC}"
        return 1
    fi
}

main "$@"
