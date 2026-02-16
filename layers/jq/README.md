# jq Layer

> JSON processing for Lambda shell functions

Pre-built Lambda layer containing the `jq` command-line JSON processor, optimized for AWS Lambda with ARM64 architecture.

## Usage

### With Serverless Framework

```yaml
functions:
  handler:
    runtime: provided.al2023
    layers:
      - arn:aws:lambda:${aws:region}:${aws:accountId}:layer:ql4b-shell-jq:1
    environment:
      PATH: "/opt/bin:${env:PATH}"
```

### With Terraform

```hcl
resource "aws_lambda_function" "handler" {
  layers = [
    "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:layer:ql4b-shell-jq:1"
  ]
  
  environment {
    variables = {
      PATH = "/opt/bin:${env:PATH}"
    }
  }
}
```

## Examples

### Basic JSON Processing

```bash
#!/bin/bash
# handler.sh

api_handler() {
    local event="$1"
    
    # Parse JSON event
    local name=$(echo "$event" | jq -r '.name // "World"')
    local count=$(echo "$event" | jq -r '.count // 1')
    
    # Build JSON response
    local response=$(jq -n \
        --arg name "$name" \
        --argjson count "$count" \
        '{
            statusCode: 200,
            body: {
                message: ("Hello, " + $name),
                count: $count,
                timestamp: now
            }
        }')
    
    echo "$response"
}
```

### API Gateway Integration

```bash
#!/bin/bash
# api-handler.sh

process_request() {
    local event="$1"
    
    # Extract query parameters
    local params=$(echo "$event" | jq -r '.queryStringParameters // {}')
    local filter=$(echo "$params" | jq -r '.filter // "all"')
    
    # Process data
    local data='[{"id":1,"name":"Alice"},{"id":2,"name":"Bob"}]'
    local filtered=$(echo "$data" | jq --arg f "$filter" '
        if $f == "all" then . 
        else map(select(.name | contains($f)))
        end')
    
    # Return API Gateway response
    jq -n \
        --argjson data "$filtered" \
        '{
            statusCode: 200,
            headers: {"Content-Type": "application/json"},
            body: ($data | tostring)
        }'
}
```

### Data Transformation

```bash
#!/bin/bash
# transform.sh

transform_data() {
    local input="$1"
    
    # Complex jq transformation
    echo "$input" | jq '
        .items 
        | map({
            id: .id,
            name: .name | ascii_upcase,
            tags: .tags | sort,
            created: (.timestamp | strftime("%Y-%m-%d")),
            active: (.status == "enabled")
        })
        | sort_by(.name)
    '
}
```

## Building

```bash
# Build the layer
./build.sh

# Deploy to AWS
aws lambda publish-layer-version \
  --layer-name ql4b-shell-jq \
  --zip-file fileb://dist/jq-layer.zip \
  --compatible-runtimes provided.al2023 \
  --compatible-architectures arm64
```

## Layer Details

- **Runtime**: `provided.al2023`
- **Architecture**: `arm64` and `x86_64`
- **Binary location**: `/opt/bin/jq`
- **Version**: jq 1.7.1
- **Size**: ~2MB (statically linked)

## Integration with lambda-shell-runtime

This layer works perfectly with [lambda-shell-runtime](https://github.com/ql4b/lambda-shell-runtime):

```dockerfile
# In your Lambda function
FROM ghcr.io/ql4b/lambda-shell-runtime:tiny

# Your function code
COPY handler.sh .
CMD ["handler.api_handler"]
```

```yaml
# serverless.yml
functions:
  api:
    image:
      name: lambda-runtime
    layers:
      - arn:aws:lambda:${aws:region}:${aws:accountId}:layer:ql4b-shell-jq:1
```

## Why This Layer?

**Performance**: Statically linked binary with no dependencies  
**Size**: Minimal footprint (~2MB)  
**Compatibility**: Works with any shell-based Lambda runtime  
**Reliability**: Built from official jq source with proven build process  

---

*Part of the [lambda-shell-layers](https://github.com/ql4b/lambda-shell-layers) collection.*