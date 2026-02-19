#!/bin/bash
set -euo pipefail

# Error Handling Pattern
# Shows proper error handling and fallback strategies

run() {
    local result error_response
    
    # Attempt primary API call with timeout
    if result=$(curl -sS --fail --max-time 10 "https://api.example.com/data" 2>&1); then
        echo "$result" | jq '{
            status: "success",
            data: .items,
            timestamp: now | todate
        }'
    else
        # Fallback to cached or default response
        error_response=$(echo "$result" | head -n 1)
        
        jq -n \
            --arg error "$error_response" \
            '{
                status: "error",
                error: $error,
                data: [],
                timestamp: now | todate,
                fallback: true
            }'
        
        return 1
    fi
}
