#!/bin/bash
set -euo pipefail

# Stripe Revenue Summary
# Requires: STRIPE_API_KEY environment variable

run() {
    local charges
    
    charges=$(curl -sS --fail \
        "https://api.stripe.com/v1/charges?limit=100" \
        -u "${STRIPE_API_KEY}:" \
        -H "Content-Type: application/x-www-form-urlencoded")
    
    echo "$charges" | jq '{
        period: "last_100_charges",
        summary: {
            total_revenue: ([.data[] | select(.status == "succeeded") | .amount] | add / 100),
            successful_charges: ([.data[] | select(.status == "succeeded")] | length),
            failed_charges: ([.data[] | select(.status == "failed")] | length),
            currency: (.data[0].currency // "usd")
        },
        by_status: (
            .data | group_by(.status) | map({
                status: .[0].status,
                count: length,
                total: (map(.amount) | add / 100)
            })
        )
    }'
}
