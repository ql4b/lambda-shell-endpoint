# Quick Reference

## Make Commands

```bash
make help              # Show all available commands
make build             # Build bootstrap and layers
make test              # Run local tests
make deploy            # Deploy to AWS
make logs              # Tail Lambda logs
make invoke            # Invoke deployed function
make clean             # Clean build artifacts
make info              # Show deployment info
```

## Handler Template

```bash
#!/bin/bash
set -euo pipefail

run() {
    # Your logic here
    curl -sS "https://api.example.com/data" | jq '.'
}
```

## Common Patterns

### Error Handling
```bash
run() {
    local result
    if result=$(curl -sS --fail "https://api.example.com/data" 2>&1); then
        echo "$result" | jq '.'
    else
        jq -n --arg error "$result" '{status: "error", message: $error}'
        return 1
    fi
}
```

### Environment Variables
```bash
run() {
    local api_key="${API_KEY:?API_KEY required}"
    curl -H "Authorization: Bearer $api_key" \
        "https://api.example.com/data" | jq '.'
}
```

### Timeout Protection
```bash
run() {
    curl -sS --fail --max-time 10 \
        "https://api.example.com/data" | jq '.'
}
```

### Multi-API Aggregation
```bash
run() {
    local api1 api2
    api1=$(curl -sS "https://api1.example.com/data")
    api2=$(curl -sS "https://api2.example.com/data")
    
    jq -n \
        --argjson a1 "$api1" \
        --argjson a2 "$api2" \
        '{api1: $a1, api2: $a2}'
}
```

### Secrets from AWS Secrets Manager
```bash
get_secret() {
    aws secretsmanager get-secret-value \
        --secret-id "$1" \
        --query SecretString \
        --output text
}

run() {
    local token
    token=$(get_secret "prod/api-token")
    curl -H "Authorization: Bearer $token" \
        "https://api.example.com/data" | jq '.'
}
```

## Local Testing

### Quick Test
```bash
./test/local.sh
```

### Manual Test
```bash
# Build
docker build -t lambda-test -f Dockerfile.test .

# Run
docker run -d --rm -p 9000:8080 --name lambda-test lambda-test

# Invoke
curl -X POST "http://localhost:9000/2015-03-31/functions/function/invocations" \
  -d '{}' | jq

# Stop
docker stop lambda-test
```

### Direct Handler Test
```bash
cd app/src
source handler.sh
run | jq
```

## Deployment

### Using Make
```bash
make build    # Build bootstrap and layers
make deploy   # Deploy to AWS
make logs     # View logs
make invoke   # Test the function
```

### Manual Deployment

### Initial Deploy
```bash
source ./activate
cd runtime && ./build.sh && cd ..
cd layers/jq && ./build.sh arm64 && cd ../..
tf init
tf apply
```

### Update Handler Only
```bash
tf apply -target=module.lambda
```

### View Logs
```bash
aws logs tail /aws/lambda/$(tf output -raw function_name) --follow
```

### Get Function URL
```bash
tf output function_url
```

## Terraform Snippets

### Environment Variables
```hcl
environment = {
  variables = {
    API_KEY = var.api_key
    TIMEOUT = "30"
  }
}
```

### IAM Permissions
```hcl
policy_statements = {
  s3 = {
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::bucket/*"]
  }
}
```

### Memory and Timeout
```hcl
memory_size = 256
timeout     = 30
```

### CORS
```hcl
cors = {
  allow_origins = ["https://yourdomain.com"]
  allow_methods = ["GET", "POST"]
  allow_headers = ["content-type"]
}
```

### IAM Auth
```hcl
authorization_type = "AWS_IAM"
```

## Monitoring

### CloudWatch Logs Query
```bash
aws logs filter-log-events \
  --log-group-name /aws/lambda/your-function \
  --filter-pattern "ERROR"
```

### Metrics
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Duration \
  --dimensions Name=FunctionName,Value=your-function \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

## Troubleshooting

### Check Handler Syntax
```bash
bash -n app/src/handler.sh
```

### Test jq Expression
```bash
echo '{"test": "data"}' | jq '.test'
```

### View Lambda Environment
```bash
aws lambda get-function-configuration \
  --function-name your-function \
  --query Environment
```

### Invoke Directly
```bash
aws lambda invoke \
  --function-name your-function \
  --payload '{}' \
  response.json
cat response.json | jq
```

## Cost Estimation

```bash
# Monthly requests
REQUESTS=1000000

# Execution time (ms)
EXEC_TIME=200

# Memory (MB)
MEMORY=128

# Calculate (arm64)
COMPUTE=$(echo "scale=2; $REQUESTS * ($EXEC_TIME / 1000) * ($MEMORY / 1024) * 0.0000133334" | bc)
REQUEST=$(echo "scale=2; $REQUESTS * 0.0000002" | bc)
TOTAL=$(echo "scale=2; $COMPUTE + $REQUEST" | bc)

echo "Monthly cost: \$$TOTAL"
```

## Common Commands

### Using Make (Recommended)
```bash
make build             # Build bootstrap and layers
make test              # Run local tests
make deploy            # Deploy to AWS
make logs              # Tail function logs
make invoke            # Invoke function
make clean             # Clean artifacts
make info              # Show deployment info
make validate          # Validate handler syntax
```

### Manual Commands
```bash
# Build bootstrap
cd runtime && ./build.sh && cd ..

# Build jq layer
cd layers/jq && ./build.sh arm64 && cd ../..

# Deploy
tf apply

# Update function
tf apply -target=module.lambda

# View logs
aws logs tail /aws/lambda/$(tf output -raw function_name) --follow

# Test locally
./test/local.sh

# Run integration tests
./test/integration.sh

# Get function URL
tf output function_url

# Destroy
tf destroy
```
