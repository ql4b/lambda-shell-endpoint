# Cost Comparison

Real-world cost analysis comparing lambda-shell-endpoint to alternative approaches.

## Baseline Scenario

**Workload:**
- 1 million requests/month
- Average execution: 200ms
- 128MB memory
- arm64 architecture

## Cost Breakdown

### Lambda Shell Endpoint (This Project)

| Component | Cost |
|-----------|------|
| Lambda compute (arm64, 128MB, 200ms) | $0.33 |
| Lambda requests (1M) | $0.20 |
| Function URL (no charge) | $0.00 |
| **Total** | **$0.53/month** |

**Package size:** ~50KB (handler + bootstrap layer)  
**Cold start:** ~80ms

### Node.js + API Gateway

| Component | Cost |
|-----------|------|
| Lambda compute (arm64, 128MB, 200ms) | $0.33 |
| Lambda requests (1M) | $0.20 |
| API Gateway requests (1M) | $3.50 |
| API Gateway data transfer | $0.09 |
| **Total** | **$4.12/month** |

**Package size:** ~2MB (with dependencies)  
**Cold start:** ~150ms

**Cost increase:** 677% more expensive

### Python + API Gateway

| Component | Cost |
|-----------|------|
| Lambda compute (arm64, 128MB, 250ms) | $0.42 |
| Lambda requests (1M) | $0.20 |
| API Gateway requests (1M) | $3.50 |
| API Gateway data transfer | $0.09 |
| **Total** | **$4.21/month** |

**Package size:** ~5MB (with requests, boto3)  
**Cold start:** ~200ms

**Cost increase:** 694% more expensive

### Container Image (Node.js)

| Component | Cost |
|-----------|------|
| Lambda compute (arm64, 128MB, 250ms) | $0.42 |
| Lambda requests (1M) | $0.20 |
| ECR storage (500MB) | $0.05 |
| Function URL (no charge) | $0.00 |
| **Total** | **$0.67/month** |

**Package size:** ~500MB  
**Cold start:** ~300ms

**Cost increase:** 26% more expensive

## At Scale

### 10 Million Requests/Month

| Approach | Monthly Cost | vs Shell Endpoint |
|----------|--------------|-------------------|
| **Lambda Shell Endpoint** | **$5.30** | baseline |
| Node.js + API Gateway | $41.20 | +677% |
| Python + API Gateway | $42.10 | +694% |
| Container Image | $6.70 | +26% |

### 100 Million Requests/Month

| Approach | Monthly Cost | vs Shell Endpoint |
|----------|--------------|-------------------|
| **Lambda Shell Endpoint** | **$53.00** | baseline |
| Node.js + API Gateway | $412.00 | +677% |
| Python + API Gateway | $421.00 | +694% |
| Container Image | $67.00 | +26% |

## Real Production Example

**qm4il email API** (from your ecosystem):

- 24,000 emails processed
- Shell-first architecture
- $9.51/month core costs

**MailSlurp equivalent:**
- $1,021/month
- **107x more expensive**

## Why Shell Endpoint Wins

1. **No API Gateway:** Function URLs are free
2. **Minimal package size:** Faster cold starts, lower storage
3. **arm64 efficiency:** 20% cheaper than x86_64
4. **No runtime overhead:** Direct execution, no framework tax
5. **Optimal memory:** Shell scripts need minimal RAM

## Cost Optimization Tips

### Use arm64
```hcl
architecture = "arm64"  # 20% cheaper than x86_64
```

### Right-size memory
```hcl
memory_size = 128  # Shell scripts rarely need more
```

### Batch when possible
```bash
# Process multiple items per invocation
for item in "${items[@]}"; do
    process "$item"
done
```

### Cache aggressively
```bash
# Use CloudFront in front of Function URL for cacheable responses
```

### Monitor and tune
```bash
# Check actual memory usage
grep "Max Memory Used" /aws/lambda/your-function
```

## When Cost Matters Less

Use heavier alternatives when you need:
- Complex authentication (Cognito, OAuth)
- Request transformation (API Gateway features)
- WebSocket support
- GraphQL endpoints
- Heavy computation (>1GB memory)

For simple JSON endpoints that shape data, shell wins on cost and simplicity.

## Calculator

Estimate your costs:

```bash
# Monthly requests
REQUESTS=1000000

# Average execution time (ms)
EXEC_TIME=200

# Memory (MB)
MEMORY=128

# Compute cost (arm64)
COMPUTE=$(echo "scale=2; $REQUESTS * ($EXEC_TIME / 1000) * ($MEMORY / 1024) * 0.0000133334" | bc)

# Request cost
REQUEST=$(echo "scale=2; $REQUESTS * 0.0000002" | bc)

# Total
TOTAL=$(echo "scale=2; $COMPUTE + $REQUEST" | bc)

echo "Monthly cost: \$$TOTAL"
```

## References

- [AWS Lambda Pricing](https://aws.amazon.com/lambda/pricing/)
- [API Gateway Pricing](https://aws.amazon.com/api-gateway/pricing/)
- [ECR Pricing](https://aws.amazon.com/ecr/pricing/)
- [qm4il Cost Analysis](https://github.com/ql4b/qm4il)
