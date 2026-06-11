# FAQ

## General

### Why shell instead of Node/Python?

For simple JSON endpoints that aggregate or transform data:
- Shell + curl + jq is sufficient
- No framework overhead
- Smaller package size (50KB vs 2-5MB)
- Faster cold starts (80ms vs 150-300ms)
- 677% cheaper at scale

See [cost comparison](COST.md) for details.

### Is this production-ready?

Yes. This pattern is used in production for:
- qm4il email API (24K+ emails processed)
- Echo service (load testing infrastructure)
- Internal observability endpoints

See [production guide](PRODUCTION.md) for deployment best practices.

### What about performance?

**Benchmarks:**
- Cold start: ~80ms
- Warm execution: ~20ms + upstream API time
- Package size: ~50KB
- Memory usage: 30-50MB typical

The Go bootstrap uses raw TCP to minimize overhead.

## Architecture

### Why raw TCP instead of AWS SDK?

The AWS Lambda Runtime API is a simple HTTP interface. Using raw TCP:
- Eliminates SDK dependencies
- Reduces binary size
- Minimizes cold start overhead
- Keeps the system inspectable

See the [research article](https://cloudless.sh/log/lambda-container-images-beat-zip-packages/) for benchmarks.

### Why a layer instead of bundling bootstrap?

Layers are:
- Reusable across functions
- Cached by Lambda
- Separately versioned
- Smaller deployment packages

### Can I use other languages in the handler?

Yes. The bootstrap executes `handler.sh`, which can call:
- Python scripts
- Node.js scripts
- Compiled binaries
- Any executable in the Lambda environment

Example:
```bash
run() {
    python3 /var/task/process.py | jq '.'
}
```

## Development

### How do I debug locally?

Use the Lambda Runtime Interface Emulator:

```bash
docker build -t lambda-test -f Dockerfile.test .
docker run -p 9000:8080 lambda-test

# In another terminal
curl -X POST "http://localhost:9000/2015-03-31/functions/function/invocations" \
  -d '{}' | jq
```

See [testing guide](TESTING.md) for details.

### How do I add dependencies?

**For shell tools:**
1. Build a Lambda layer (see `layers/jq/` example)
2. Add layer to Terraform config
3. Use in handler

**For system packages:**
```bash
# In handler.sh
if ! command -v tool &> /dev/null; then
    yum install -y tool
fi
```

### Can I use environment variables?

Yes. Set in Terraform:

```hcl
environment = {
  variables = {
    API_KEY = var.api_key
    TIMEOUT = "30"
  }
}
```

Access in handler:
```bash
run() {
    curl -H "Authorization: Bearer ${API_KEY}" \
        --max-time "${TIMEOUT}" \
        https://api.example.com/data
}
```

### How do I handle secrets?

Use AWS Secrets Manager:

```bash
get_secret() {
    aws secretsmanager get-secret-value \
        --secret-id "$1" \
        --query SecretString \
        --output text
}

run() {
    local api_key
    api_key=$(get_secret "prod/api-key")
    # Use api_key
}
```

Add IAM permissions in Terraform:
```hcl
policy_statements = {
  secrets = {
    effect = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = ["arn:aws:secretsmanager:*:*:secret:prod/*"]
  }
}
```

## Deployment

### How do I deploy to multiple regions?

Use Terraform providers:

```hcl
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

provider "aws" {
  alias  = "eu_west_1"
  region = "eu-west-1"
}

module "lambda_us" {
  source = "./infra"
  providers = {
    aws = aws.us_east_1
  }
}

module "lambda_eu" {
  source = "./infra"
  providers = {
    aws = aws.eu_west_1
  }
}
```

### How do I version my API?

Use Lambda aliases:

```hcl
resource "aws_lambda_alias" "v1" {
  name             = "v1"
  function_name    = module.lambda.function_name
  function_version = module.lambda.version
}

resource "aws_lambda_alias" "v2" {
  name             = "v2"
  function_name    = module.lambda.function_name
  function_version = module.lambda.version
}
```

### How do I rollback?

Lambda versions are immutable. Update alias to previous version:

```bash
aws lambda update-alias \
  --function-name my-function \
  --name live \
  --function-version 42
```

## Security

### Is Function URL secure?

By default, Function URLs are public. Secure them:

**Option 1: IAM Authentication**
```hcl
authorization_type = "AWS_IAM"
```

**Option 2: Shared Secret**
```bash
run() {
    if [[ "${AWS_LAMBDA_HTTP_HEADERS_authorization:-}" != "Bearer ${API_SECRET}" ]]; then
        echo '{"error":"unauthorized"}' >&2
        return 1
    fi
    # Process request
}
```

**Option 3: CloudFront + WAF**
```hcl
# Add CloudFront distribution with WAF rules
```

See [production guide](PRODUCTION.md) for details.

### How do I restrict CORS?

Configure in Terraform:

```hcl
cors = {
  allow_origins = ["https://yourdomain.com"]
  allow_methods = ["GET", "POST"]
  allow_headers = ["content-type"]
  max_age      = 86400
}
```

### Should I use VPC?

Only if you need:
- Private API access (RDS, ElastiCache, etc.)
- IP-based security controls
- Network-level isolation

VPC adds cold start latency (~1-2 seconds). For public APIs, skip VPC.

## Cost

### How much does this cost?

**1 million requests/month:**
- Lambda compute: $0.33
- Lambda requests: $0.20
- Function URL: $0.00
- **Total: $0.53**

vs Node.js + API Gateway: $4.12 (677% more expensive)

See [cost analysis](COST.md) for detailed breakdown.

### How do I reduce costs?

1. **Use arm64** (20% cheaper than x86_64)
2. **Right-size memory** (128MB sufficient for most cases)
3. **Add caching** (CloudFront in front)
4. **Batch requests** (process multiple items per invocation)
5. **Monitor usage** (CloudWatch metrics)

### What about data transfer costs?

- First 100GB/month: Free
- After: $0.09/GB

For typical JSON responses (<10KB), data transfer is negligible.

## Troubleshooting

### Lambda times out

Increase timeout in Terraform:
```hcl
timeout = 30  # seconds
```

Check upstream API latency:
```bash
time curl https://api.example.com/data
```

### Out of memory

Increase memory:
```hcl
memory_size = 256  # MB
```

Check actual usage in CloudWatch Logs:
```
REPORT RequestId: xxx Duration: 123ms Memory Size: 128 MB Max Memory Used: 45 MB
```

### Handler not found

Ensure handler.sh:
1. Is executable: `chmod +x handler.sh`
2. Has shebang: `#!/bin/bash`
3. Defines `run()` function
4. Is in `/var/task/` in the Lambda package

### jq not found

Build and deploy jq layer:
```bash
cd layers/jq
./build.sh arm64
cd ../..
tf apply
```

### Permission denied

Add IAM permissions in Terraform:
```hcl
policy_statements = {
  s3 = {
    effect = "Allow"
    actions = ["s3:GetObject"]
    resources = ["arn:aws:s3:::bucket/*"]
  }
}
```

## Comparison

### vs API Gateway + Lambda

**Advantages:**
- 677% cheaper
- Simpler architecture
- No API Gateway limits
- Faster deployment

**Disadvantages:**
- No built-in request validation
- No usage plans/API keys
- No request transformation

### vs Container Images

**Advantages:**
- 10x smaller package
- 3x faster cold start
- Simpler build process
- No ECR costs

**Disadvantages:**
- Limited to shell + system tools
- No complex dependencies
- No custom OS packages

### vs Step Functions

**Advantages:**
- Lower latency
- Simpler debugging
- Lower cost for simple workflows

**Disadvantages:**
- No visual workflow
- No built-in retry logic
- No state management

## Getting Help

- **Issues:** [GitHub Issues](https://github.com/ql4b/lambda-shell-endpoint/issues)
- **Discussions:** [GitHub Discussions](https://github.com/ql4b/lambda-shell-endpoint/discussions)
- **Examples:** See [examples/](examples/) directory
- **Docs:** See [docs/](docs/) directory
