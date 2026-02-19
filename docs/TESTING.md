# Local Testing

Test your Lambda functions locally before deploying to AWS.

## Using AWS Lambda Runtime Interface Emulator (RIE)

The RIE allows you to test Lambda functions locally with the same runtime behavior as AWS.

### Prerequisites

```bash
# Install Docker
# macOS: Docker Desktop
# Linux: docker.io package
```

### Setup

1. **Create a test Dockerfile:**

```dockerfile
FROM public.ecr.aws/lambda/provided:al2023-arm64

# Copy bootstrap layer
COPY runtime/build/bootstrap /opt/bootstrap

# Copy jq layer (if needed)
COPY layers/jq/layer/opt/bin/jq /opt/bin/jq

# Copy handler
COPY app/src/handler.sh /var/task/handler.sh

# Set handler
ENV LAMBDA_TASK_ROOT=/var/task
ENV PATH=/opt/bin:$PATH

CMD ["/opt/bootstrap"]
```

2. **Build the test image:**

```bash
docker build -t lambda-shell-test -f Dockerfile.test .
```

3. **Run with RIE:**

```bash
docker run --rm \
  -p 9000:8080 \
  -e GITHUB_TOKEN="${GITHUB_TOKEN}" \
  -e REPO="ql4b/ecosystem" \
  lambda-shell-test
```

4. **Invoke the function:**

```bash
curl -X POST "http://localhost:9000/2015-03-31/functions/function/invocations" \
  -d '{}'
```

## Testing Without Docker

For rapid iteration, test the handler directly:

```bash
cd app/src
export GITHUB_TOKEN="your_token"
export REPO="ql4b/ecosystem"

# Source and run
source handler.sh
run | jq
```

## Mock Payloads

Create test payloads in `test/payloads/`:

**test/payloads/basic.json:**
```json
{
  "httpMethod": "GET",
  "path": "/",
  "headers": {},
  "body": null
}
```

**test/payloads/with-params.json:**
```json
{
  "httpMethod": "GET",
  "path": "/",
  "queryStringParameters": {
    "repo": "ql4b/echo"
  }
}
```

Invoke with:
```bash
curl -X POST "http://localhost:9000/2015-03-31/functions/function/invocations" \
  -d @test/payloads/basic.json
```

## Integration Tests

**test/integration.sh:**

```bash
#!/bin/bash
set -euo pipefail

ENDPOINT="${ENDPOINT:-http://localhost:9000/2015-03-31/functions/function/invocations}"

test_basic_invocation() {
    local response
    response=$(curl -sS -X POST "$ENDPOINT" -d '{}')
    
    if echo "$response" | jq -e '.status == "success"' > /dev/null; then
        echo "[PASS] Basic invocation passed"
        return 0
    else
        echo "[FAIL] Basic invocation failed"
        echo "$response" | jq
        return 1
    fi
}

test_error_handling() {
    local response
    # Test with invalid token
    response=$(curl -sS -X POST "$ENDPOINT" \
        -e GITHUB_TOKEN="invalid" \
        -d '{}')
    
    if echo "$response" | jq -e '.status == "error"' > /dev/null; then
        echo "[PASS] Error handling passed"
        return 0
    else
        echo "[FAIL] Error handling failed"
        return 1
    fi
}

main() {
    echo "Running integration tests..."
    test_basic_invocation
    test_error_handling
    echo "All tests passed"
}

main
```

Run tests:
```bash
chmod +x test/integration.sh
./test/integration.sh
```

## Performance Testing

Measure cold start and execution time:

```bash
#!/bin/bash

for i in {1..10}; do
    echo "Invocation $i:"
    time curl -sS -X POST \
        "http://localhost:9000/2015-03-31/functions/function/invocations" \
        -d '{}' > /dev/null
    
    # Wait between invocations to simulate cold starts
    sleep 2
done
```

## Debugging

Enable verbose logging:

```bash
docker run --rm \
  -p 9000:8080 \
  -e AWS_LAMBDA_LOG_LEVEL=debug \
  -e GITHUB_TOKEN="${GITHUB_TOKEN}" \
  lambda-shell-test
```

View handler output:
```bash
# Add to handler.sh for debugging
echo "Debug: Processing request" >&2
```

## CI/CD Integration

**GitHub Actions example:**

```yaml
name: Test Lambda

on: [push]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build test image
        run: docker build -t lambda-test -f Dockerfile.test .
      
      - name: Start Lambda
        run: |
          docker run -d --rm \
            -p 9000:8080 \
            --name lambda-test \
            -e GITHUB_TOKEN="${{ secrets.GITHUB_TOKEN }}" \
            lambda-test
      
      - name: Run tests
        run: ./test/integration.sh
      
      - name: Stop Lambda
        run: docker stop lambda-test
```
