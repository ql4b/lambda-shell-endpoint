# Lambda Shell Endpoint

> Minimal serverless JSON endpoints using Bash on AWS Lambda (`provided.al2023`) with a Go bootstrap layer.

## What This Actually Is

This is not just a Bash Lambda template.

This boilerplate embeds a **compiled Go bootstrap** (packaged as a Lambda layer) that communicates with the Lambda Runtime API using **raw TCP**, and delegates execution to shell handlers.

This project builds on the research documented in the Cloudless article:

[Lambda Performance Deep Dive: Container Images, Raw TCP, and the UPX Trap](https://cloudless.sh/log/lambda-container-images-beat-zip-packages/)

That article explains the runtime design decisions and benchmark results in detail.

That research concluded:

- The fastest and most predictable approach for shell-based Lambdas
- Is a compiled Go bootstrap
- Using raw TCP to communicate with the Lambda Runtime API
- Packaged as a layer
- Combined with `provided.al2023`

This repository operationalizes that conclusion.

## Why This Exists

Sometimes you don’t need:

- A framework
- A container image
- Node or Python runtimes
- A database
- A data pipeline

Sometimes you just need:

> A small, deterministic JSON endpoint that shapes data and returns it.

This repository provides:

- Shell-based Lambda functions
- Compiled Go bootstrap (raw TCP runtime client)
- Optional `jq` layer for data shaping
- Terraform infrastructure (function + layer + function URL)
- Minimal deployment surface
- Extremely small function packages (often <1KB)

## The Architecture

### Runtime Model

- Runtime: `provided.al2023`
- Architecture: `arm64`
- Custom Go bootstrap (compiled binary)
- Shell handler (`handler.sh`)
- Optional `jq` layer
- Lambda Function URL (no API Gateway required)

### Execution Flow

```
Lambda Runtime API
        ↓
Go bootstrap (raw TCP client)
        ↓
Shell handler.sh
        ↓
curl / jq / system tools
        ↓
JSON response
```

The bootstrap handles:

- Fetching invocation events
- Passing payload to the shell handler
- Writing responses back to the Runtime API
- Minimal overhead, no SDKs

The shell handles:

- Calling upstream APIs
- Aggregating or normalizing data
- Returning JSON

## Why Raw TCP?

- The standard Lambda runtime client adds avoidable overhead.
- SDK-based implementations increase cold start size and complexity.
- Container images introduce unnecessary weight.
- UPX compression can degrade real performance.

A small compiled Go binary speaking directly over raw TCP:

- Minimizes runtime overhead
- Avoids heavy dependencies
- Keeps cold starts predictable
- Keeps the system inspectable

For benchmark details and performance comparisons, refer to:

> [*Lambda Performance Deep Dive: Container Images, Raw TCP, and the UPX Trap*](https://cloudless.sh/log/lambda-container-images-beat-zip-packages/)

This repository is the production-ready evolution of that research.

## Repository Structure

```
├── activate
├── app
│   └── src
│       └── handler.sh
├── infra
│   ├── main.tf
│   ├── output.tf
│   ├── terraform.tf
│   ├── variables.tf
│   └── versions.tf
├── layers
│   └── jq
│       ├── build.sh
│       ├── Dockerfile
│       ├── layer
│       └── README.md
├── README.md
├── runtime
│   ├── build
│   │   └── bootstrap
│   ├── build.sh
│   ├── go.mod
│   └── main.go
└── tf
```

Infrastructure leverages existing QL4B Terraform modules:

- `terraform-aws-lambda-function`
- `terraform-aws-lambda-layer`

This keeps the Terraform surface minimal.

## The optional `jq` layer

If your endpoint uses jq for shaping or aggregation, you must build a Lambda-compatible layer for the target architecture.

Lambda supports:
* arm64
* x86_64

Because binaries must match the Lambda architecture, the jq layer is built per architecture.

The layers/jq directory contains:
* Dockerfile — multi-stage build producing a statically-linked binary
* build.sh — packages the layer in the correct /opt structure
* layer/ — final Lambda layer layout


To build the layer

```
cd layers/jq
./build.sh arm64    # or x86_64
```

The build process produces a Lambda-ready layer compatible with provided.al2023.

This layer is derived from the broader CLI layer collection maintained in:

https://github.com/ql4b/lambda-shell-layers

That repository contains additional optional tools (htmlq, yq, http-cli, uuid, etc.) built using the same pattern and compatible with this runtime model.


## The Pattern

This template is ideal for:

```
REST API
   ↓
Shell + curl
   ↓
jq (aggregate / normalize)
   ↓
JSON
   ↓
Grafana / dashboards / other systems
```

Typical use cases:

- GitHub traffic aggregation
- Stripe summaries
- Multi-endpoint API fan-out
- Lightweight observability adapters
- Rapid data prototypes
- Internal tooling

No ingestion.  
No persistence.  
No ceremony.


## Quick Start

### 1. Clone

```
git clone <repo>
cd lambda-shell-endpoint
```

### 1.1 Environment variables 

```
cp .env.example .emv
```

Edit the `.env` and

```
source ./activate
```

### 2. Build the bootstrap

```
cd runtime
./build.sh
cd ..
```

### 2.1 Build `jq`

```
cd layers/jq
./build 
```

### 3. Deploy

```
tf init
tf apply
```

Terraform outputs a Lambda Function URL:

```
https://xxxx.lambda-url.<region>.on.aws/
```

### 4. Test

```
curl https://xxxx.lambda-url.<region>.on.aws/ | jq
```

Done.

## Writing an Endpoint

Inside `handler.sh`, define a function that:

1. Reads the invocation payload
2. Calls upstream APIs
3. Shapes data with `jq`
4. Returns a JSON document

Example:

```
run () {
    curl -sS "https://api.example.com/data" \
    | jq '{ result: .items }'
}
```

Keep the logic:

- Deterministic
- Stateless
- Inspectable
- Small

## Security Notes

By default, Lambda Function URL may be public.

You should consider:

- `authorization_type = "AWS_IAM"`
- Adding a shared secret header check
- Restricting CORS origins
- Adding lightweight response caching

The template stays minimal.  
Security posture is intentionally configurable.

## When To Use This

Use this when:

- You need fast iteration
- You need a thin data-shaping layer
- You are building observability surfaces
- You want deterministic minimal infrastructure

Do not use this when:

- You need persistent state
- You need heavy compute
- You require complex authentication systems
- You are building a full application backend


## Philosophy

This is aligned with the Cloudless approach:

- Infrastructure that gets out of your way
- Compiled where necessary, interpreted where useful
- Small, composable primitives
- Clear contracts
- Minimal moving parts

Shell as data engine.  
Go as runtime spine.  
Lambda as distribution layer.  
JSON as contract.



