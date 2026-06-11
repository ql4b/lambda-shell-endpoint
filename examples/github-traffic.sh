#!/bin/bash
set -euo pipefail

# GitHub Repository Traffic Aggregator
# Requires: GITHUB_TOKEN environment variable

run() {
    local repo="${REPO:-ql4b/ecosystem}"
    
    curl -sS --fail \
        "https://api.github.com/repos/${repo}/traffic/views" \
        -H "Authorization: token ${GITHUB_TOKEN}" \
    | jq '{
        repository: $repo,
        total_views: .count,
        unique_visitors: .uniques,
        last_14_days: .views | map({
            date,
            views: .count,
            unique: .uniques
        }),
        summary: {
            avg_daily_views: (.views | map(.count) | add / length | floor),
            peak_day: (.views | max_by(.count) | {date, views: .count})
        }
    }' --arg repo "$repo"
}
