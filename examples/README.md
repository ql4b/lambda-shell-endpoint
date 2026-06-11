# Handler Examples

Complete working examples for common use cases.

## GitHub Traffic Aggregator

**File:** `github-traffic.sh`

Aggregates GitHub repository traffic data with daily breakdowns and summary statistics.

**Environment Variables:**
- `GITHUB_TOKEN` - GitHub personal access token
- `REPO` - Repository in format `owner/repo` (default: `ql4b/ecosystem`)

**Response:**
```json
{
  "repository": "ql4b/ecosystem",
  "total_views": 1234,
  "unique_visitors": 567,
  "last_14_days": [...],
  "summary": {
    "avg_daily_views": 88,
    "peak_day": {"date": "2025-01-15", "views": 234}
  }
}
```

## Multi-API Aggregator

**File:** `multi-api-aggregator.sh`

Fan-out pattern: calls multiple APIs in parallel and aggregates results.

**Features:**
- Timeout protection (5s per endpoint)
- Graceful degradation on failures
- Overall health status calculation

**Use Case:** Service health dashboards, monitoring aggregation

## Stripe Revenue Summary

**File:** `stripe-summary.sh`

Summarizes Stripe charges with revenue calculations and status breakdowns.

**Environment Variables:**
- `STRIPE_API_KEY` - Stripe secret key

**Response:**
```json
{
  "period": "last_100_charges",
  "summary": {
    "total_revenue": 12345.67,
    "successful_charges": 95,
    "failed_charges": 5,
    "currency": "usd"
  },
  "by_status": [...]
}
```

## Error Handling Pattern

**File:** `error-handling.sh`

Demonstrates proper error handling with fallback strategies.

**Features:**
- Timeout protection
- Graceful error responses
- Fallback data patterns
- Proper exit codes

## Using These Examples

1. Copy the example to `app/src/handler.sh`
2. Set required environment variables in Terraform
3. Deploy with `tf apply`
4. Test with `curl`

**Example Terraform configuration:**

```hcl
environment = {
  variables = {
    GITHUB_TOKEN = var.github_token
    REPO         = "ql4b/ecosystem"
  }
}
```
