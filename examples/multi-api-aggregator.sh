#!/bin/bash
set -euo pipefail

# Multi-API Aggregator
# Fetches data from multiple endpoints and combines results

run() {
    local service1 service2 service3
    
    service1=$(curl -sS --fail --max-time 5 "https://api.example.com/status" || echo '{"status":"error"}')
    service2=$(curl -sS --fail --max-time 5 "https://api.example.com/metrics" || echo '{"metrics":[]}')
    service3=$(curl -sS --fail --max-time 5 "https://api.example.com/health" || echo '{"healthy":false}')
    
    jq -n \
        --argjson s1 "$service1" \
        --argjson s2 "$service2" \
        --argjson s3 "$service3" \
        '{
            timestamp: now | todate,
            services: {
                api: $s1,
                metrics: $s2,
                health: $s3
            },
            overall_status: (
                if ($s1.status == "ok" and $s3.healthy == true) 
                then "healthy" 
                else "degraded" 
                end
            )
        }'
}
