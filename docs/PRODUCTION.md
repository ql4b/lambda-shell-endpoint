# Production Deployment

Best practices for deploying lambda-shell-endpoint to production.

## Pre-Deployment Checklist

- [ ] Handler tested locally with RIE
- [ ] Environment variables configured
- [ ] IAM permissions reviewed
- [ ] Error handling implemented
- [ ] Logging strategy defined
- [ ] Monitoring alerts configured
- [ ] Cost estimates validated

## Security Configuration

### IAM Authentication

For internal APIs, use IAM authentication:

```hcl
# infra/main.tf
module "lambda" {
  # ... other config
  
  authorization_type = "AWS_IAM"
}
```

Invoke with AWS credentials:
```bash
aws lambda invoke-url \
  --function-url https://xxx.lambda-url.region.on.aws/ \
  --region us-east-1 \
  response.json
```

### Shared Secret

For external APIs, add header validation:

```bash
# handler.sh
run() {
    local auth_header="${AWS_LAMBDA_HTTP_HEADERS_authorization:-}"
    local expected="Bearer ${API_SECRET}"
    
    if [[ "$auth_header" != "$expected" ]]; then
        echo '{"error":"unauthorized"}' >&2
        return 1
    fi
    
    # Process request
    curl -sS "https://api.example.com/data" | jq '.'
}
```

Set secret in Terraform:
```hcl
environment = {
  variables = {
    API_SECRET = var.api_secret
  }
}
```

### CORS Configuration

```hcl
cors = {
  allow_origins     = ["https://yourdomain.com"]
  allow_methods     = ["GET", "POST"]
  allow_headers     = ["content-type", "authorization"]
  max_age          = 86400
}
```

## Environment Variables

Organize by environment:

```hcl
# infra/variables.tf
variable "environment" {
  type    = string
  default = "production"
}

variable "github_token" {
  type      = string
  sensitive = true
}

# infra/main.tf
environment = {
  variables = {
    ENVIRONMENT   = var.environment
    GITHUB_TOKEN  = var.github_token
    LOG_LEVEL     = var.environment == "production" ? "info" : "debug"
  }
}
```

Use AWS Secrets Manager for sensitive data:

```bash
# handler.sh
get_secret() {
    aws secretsmanager get-secret-value \
        --secret-id "$1" \
        --query SecretString \
        --output text
}

run() {
    local api_key
    api_key=$(get_secret "prod/api-key")
    
    curl -sS "https://api.example.com/data" \
        -H "Authorization: Bearer $api_key" \
    | jq '.'
}
```

## Monitoring

### CloudWatch Logs

Structured logging pattern:

```bash
log() {
    local level="$1"
    local message="$2"
    
    jq -n \
        --arg level "$level" \
        --arg message "$message" \
        --arg request_id "${AWS_REQUEST_ID:-unknown}" \
        '{
            timestamp: now | todate,
            level: $level,
            message: $message,
            request_id: $request_id
        }' >&2
}

run() {
    log "INFO" "Processing request"
    
    local result
    if result=$(curl -sS --fail "https://api.example.com/data"); then
        log "INFO" "Request successful"
        echo "$result" | jq '.'
    else
        log "ERROR" "Request failed"
        return 1
    fi
}
```

### CloudWatch Alarms

```hcl
resource "aws_cloudwatch_metric_alarm" "errors" {
  alarm_name          = "${var.namespace}-${var.name}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  
  dimensions = {
    FunctionName = module.lambda.function_name
  }
  
  alarm_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "duration" {
  alarm_name          = "${var.namespace}-${var.name}-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Average"
  threshold           = 5000  # 5 seconds
  
  dimensions = {
    FunctionName = module.lambda.function_name
  }
  
  alarm_actions = [aws_sns_topic.alerts.arn]
}
```

### Custom Metrics

```bash
put_metric() {
    local metric_name="$1"
    local value="$2"
    
    aws cloudwatch put-metric-data \
        --namespace "CustomMetrics/${NAMESPACE}" \
        --metric-name "$metric_name" \
        --value "$value" \
        --dimensions Function="${AWS_LAMBDA_FUNCTION_NAME}"
}

run() {
    local start_time end_time duration
    start_time=$(date +%s)
    
    curl -sS "https://api.example.com/data" | jq '.'
    
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    put_metric "UpstreamLatency" "$duration"
}
```

## Performance Tuning

### Memory Optimization

Test different memory settings:

```bash
# Test script
for memory in 128 256 512 1024; do
    echo "Testing with ${memory}MB"
    
    aws lambda update-function-configuration \
        --function-name "$FUNCTION_NAME" \
        --memory-size "$memory"
    
    sleep 10  # Wait for update
    
    # Run load test
    for i in {1..100}; do
        curl -sS "$FUNCTION_URL" > /dev/null
    done
    
    # Check average duration
    aws cloudwatch get-metric-statistics \
        --namespace AWS/Lambda \
        --metric-name Duration \
        --dimensions Name=FunctionName,Value="$FUNCTION_NAME" \
        --start-time "$(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S)" \
        --end-time "$(date -u +%Y-%m-%dT%H:%M:%S)" \
        --period 300 \
        --statistics Average
done
```

### Timeout Configuration

```hcl
timeout = 30  # Adjust based on upstream API latency
```

### Provisioned Concurrency

For latency-sensitive endpoints:

```hcl
resource "aws_lambda_provisioned_concurrency_config" "this" {
  function_name                     = module.lambda.function_name
  provisioned_concurrent_executions = 2
  qualifier                         = module.lambda.version
}
```

## Caching Strategy

### CloudFront Distribution

```hcl
resource "aws_cloudfront_distribution" "api" {
  enabled = true
  
  origin {
    domain_name = replace(module.lambda.function_url, "https://", "")
    origin_id   = "lambda"
    
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }
  
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "lambda"
    viewer_protocol_policy = "redirect-to-https"
    
    forwarded_values {
      query_string = true
      headers      = ["Authorization"]
      
      cookies {
        forward = "none"
      }
    }
    
    min_ttl     = 0
    default_ttl = 300   # 5 minutes
    max_ttl     = 3600  # 1 hour
  }
  
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
```

### Response Headers

```bash
# handler.sh - Add cache headers
run() {
    local response
    response=$(curl -sS "https://api.example.com/data" | jq '.')
    
    # Add cache control
    echo "$response" | jq '. + {
        headers: {
            "Cache-Control": "public, max-age=300",
            "Content-Type": "application/json"
        }
    }'
}
```

## Deployment Strategies

### Blue/Green Deployment

```hcl
resource "aws_lambda_alias" "live" {
  name             = "live"
  function_name    = module.lambda.function_name
  function_version = module.lambda.version
}

resource "aws_lambda_alias" "staging" {
  name             = "staging"
  function_name    = module.lambda.function_name
  function_version = module.lambda.version
}
```

### Canary Deployment

```hcl
resource "aws_lambda_alias" "live" {
  name             = "live"
  function_name    = module.lambda.function_name
  function_version = module.lambda.version
  
  routing_config {
    additional_version_weights = {
      (module.lambda.version) = 0.1  # 10% traffic to new version
    }
  }
}
```

## Rollback Procedure

```bash
# Get previous version
PREVIOUS_VERSION=$(aws lambda list-versions-by-function \
    --function-name "$FUNCTION_NAME" \
    --query 'Versions[-2].Version' \
    --output text)

# Update alias
aws lambda update-alias \
    --function-name "$FUNCTION_NAME" \
    --name live \
    --function-version "$PREVIOUS_VERSION"
```

## Disaster Recovery

### Backup Strategy

Lambda functions are automatically versioned. Keep:
- Last 10 versions
- All production releases
- Tagged releases indefinitely

### Multi-Region Deployment

```hcl
# Deploy to multiple regions
module "lambda_us_east_1" {
  source = "./infra"
  providers = {
    aws = aws.us_east_1
  }
}

module "lambda_eu_west_1" {
  source = "./infra"
  providers = {
    aws = aws.eu_west_1
  }
}

# Route53 health checks and failover
resource "aws_route53_health_check" "primary" {
  fqdn              = module.lambda_us_east_1.function_url
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30
}
```

## Compliance

### Logging Retention

```hcl
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${module.lambda.function_name}"
  retention_in_days = 30  # Adjust for compliance requirements
}
```

### Encryption

```hcl
environment = {
  variables = {
    # ... your variables
  }
}

kms_key_arn = aws_kms_key.lambda.arn
```

### VPC Configuration

For private API access:

```hcl
vpc_config = {
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [aws_security_group.lambda.id]
}
```
