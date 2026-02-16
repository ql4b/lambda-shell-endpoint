#!/bin/bash

set -euo pipefail

run () {
    curl -Ss https://api.github.com/events \
    | jq '{
        generated_at: now | todate,
        events: map({
            type,
            repo: .repo.name,
            actor: .actor.login,
            created_at
        })
      }'

}