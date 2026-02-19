# Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         Internet / Client                        │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ HTTPS
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Lambda Function URL                           │
│                  (No API Gateway needed)                         │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ Invocation
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                      AWS Lambda Function                         │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │              Lambda Runtime (provided.al2023)              │ │
│  └────────────────────────┬───────────────────────────────────┘ │
│                           │                                      │
│                           │ Executes                             │
│                           ▼                                      │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │           Go Bootstrap (Layer - Raw TCP Client)            │ │
│  │                                                             │ │
│  │  • Fetches events from Runtime API                         │ │
│  │  • Passes payload to handler                               │ │
│  │  • Returns response to Runtime API                         │ │
│  │  • Minimal overhead (~50KB)                                │ │
│  └────────────────────────┬───────────────────────────────────┘ │
│                           │                                      │
│                           │ Invokes                              │
│                           ▼                                      │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │              Shell Handler (handler.sh)                    │ │
│  │                                                             │ │
│  │  run() {                                                   │ │
│  │    curl -sS "https://api.example.com/data" \              │ │
│  │    | jq '{ result: .items }'                              │ │
│  │  }                                                         │ │
│  └────────────────────────┬───────────────────────────────────┘ │
│                           │                                      │
│                           │ Uses                                 │
│                           ▼                                      │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │              Optional jq Layer                             │ │
│  │                                                             │ │
│  │  • Statically linked jq binary                            │ │
│  │  • JSON processing and transformation                     │ │
│  │  • Available in /opt/bin/jq                               │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
└───────────────────────────┬───────────────────────────────────────┘
                            │
                            │ Calls
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Upstream APIs                               │
│                                                                   │
│  • GitHub API                                                    │
│  • Stripe API                                                    │
│  • Internal services                                             │
│  • Any HTTP endpoint                                             │
└─────────────────────────────────────────────────────────────────┘
```

## Execution Flow

```
1. Client Request
   │
   ├─→ Lambda Function URL receives HTTPS request
   │
2. Lambda Invocation
   │
   ├─→ Lambda Runtime starts (provided.al2023)
   │
3. Bootstrap Execution
   │
   ├─→ Go bootstrap fetches event from Runtime API (raw TCP)
   │
4. Handler Invocation
   │
   ├─→ Bootstrap executes handler.sh
   │   │
   │   ├─→ Handler calls upstream APIs (curl)
   │   │
   │   ├─→ Handler processes data (jq)
   │   │
   │   └─→ Handler returns JSON
   │
5. Response
   │
   ├─→ Bootstrap sends response to Runtime API
   │
   └─→ Client receives JSON response
```

## Component Sizes

```
┌──────────────────────┬──────────┬─────────────┐
│ Component            │ Size     │ Cold Start  │
├──────────────────────┼──────────┼─────────────┤
│ Go Bootstrap         │ ~50KB    │ ~20ms       │
│ Shell Handler        │ ~1-5KB   │ ~10ms       │
│ jq Layer (optional)  │ ~1MB     │ ~50ms       │
│ Total Package        │ ~50KB    │ ~80ms       │
└──────────────────────┴──────────┴─────────────┘

Compare to:
┌──────────────────────┬──────────┬─────────────┐
│ Node.js + deps       │ ~2-5MB   │ ~150ms      │
│ Python + deps        │ ~5-10MB  │ ~200ms      │
│ Container Image      │ ~500MB   │ ~300ms      │
└──────────────────────┴──────────┴─────────────┘
```

## Data Flow Example

```
GitHub Traffic Aggregator:

Client
  │
  │ GET /
  ▼
Lambda Function URL
  │
  │ Invoke
  ▼
handler.sh
  │
  │ curl https://api.github.com/repos/ql4b/ecosystem/traffic/views
  ▼
GitHub API
  │
  │ Returns traffic data
  ▼
handler.sh
  │
  │ jq '{ total: .count, uniques: .uniques, ... }'
  ▼
Client
  │
  │ Receives aggregated JSON
  └─→ {
        "total_views": 1234,
        "unique_visitors": 567,
        "summary": { ... }
      }
```

## Cost Flow

```
Request → Lambda Function URL (FREE)
       ↓
       Lambda Compute (arm64, 128MB, 200ms)
       • $0.0000000333 per request
       ↓
       Lambda Request
       • $0.0000002 per request
       ↓
       Total: $0.0000002333 per request
       
1M requests = $0.53/month

vs

Request → API Gateway ($3.50/1M)
       ↓
       Lambda Compute ($0.33/1M)
       ↓
       Lambda Request ($0.20/1M)
       ↓
       Total: $4.12/month (677% more expensive)
```

## Security Layers

```
┌─────────────────────────────────────────────────────────────┐
│                        Client Request                        │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              Optional: CloudFront + WAF                      │
│  • DDoS protection                                           │
│  • Geographic restrictions                                   │
│  • Rate limiting                                             │
│  • Caching                                                   │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              Lambda Function URL                             │
│  • IAM authentication (optional)                             │
│  • CORS configuration                                        │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              Handler Security                                │
│  • Shared secret validation                                  │
│  • Input validation                                          │
│  • Rate limiting logic                                       │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              IAM Permissions                                 │
│  • Secrets Manager access                                    │
│  • S3 access (if needed)                                     │
│  • CloudWatch Logs                                           │
└─────────────────────────────────────────────────────────────┘
```

## Deployment Architecture

```
Development                Production
    │                          │
    │ git push                 │
    ▼                          │
GitHub Actions                 │
    │                          │
    ├─→ Build bootstrap        │
    │                          │
    ├─→ Build layers           │
    │                          │
    ├─→ Run tests              │
    │                          │
    └─→ Terraform apply ───────┤
                               │
                               ▼
                    ┌──────────────────────┐
                    │   Lambda Function    │
                    │   (Version N)        │
                    └──────────┬───────────┘
                               │
                    ┌──────────┴───────────┐
                    │                      │
                    ▼                      ▼
            ┌──────────────┐      ┌──────────────┐
            │ Alias: live  │      │ Alias: stage │
            │ (90% traffic)│      │ (10% traffic)│
            └──────────────┘      └──────────────┘
                    │                      │
                    └──────────┬───────────┘
                               │
                               ▼
                    Lambda Function URL
```

## Monitoring Architecture

```
Lambda Function
    │
    ├─→ CloudWatch Logs
    │   • Execution logs
    │   • Error logs
    │   • Custom structured logs
    │
    ├─→ CloudWatch Metrics
    │   • Duration
    │   • Errors
    │   • Invocations
    │   • Throttles
    │
    ├─→ Custom Metrics
    │   • Upstream API latency
    │   • Business metrics
    │   • Cache hit rates
    │
    └─→ CloudWatch Alarms
        • Error rate > threshold
        • Duration > threshold
        • Throttle rate > threshold
        │
        └─→ SNS Topic → Email/Slack/PagerDuty
```

## Why This Architecture Works

1. **Minimal Layers**: Only what's needed (runtime → bootstrap → handler)
2. **Small Packages**: ~50KB vs 2-5MB for traditional approaches
3. **Fast Cold Starts**: ~80ms vs 150-300ms for alternatives
4. **Low Cost**: No API Gateway, minimal compute
5. **Simple Debugging**: Shell scripts are inspectable
6. **Flexible**: Can call any upstream API or service
7. **Scalable**: Lambda handles scaling automatically
8. **Maintainable**: Clear separation of concerns
