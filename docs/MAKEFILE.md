# Makefile Guide

The Makefile provides a convenient interface for all common development, testing, and deployment tasks.

## Quick Start

```bash
# Show all available commands
make help

# Complete workflow
make build    # Build bootstrap and layers
make test     # Test locally
make deploy   # Deploy to AWS
```

## Common Workflows

### Development Cycle

```bash
# Quick iteration
make dev      # Build and test in one command

# Or step by step
make build
make test
make validate
```

### Deployment

```bash
# First time
make tf-init
make deploy

# Updates
make deploy

# Check status
make info
make logs
```

### Testing

```bash
# Local testing
make test              # Run all tests
make local-test        # Docker-based testing
make integration-test  # Integration tests only

# Deployed function
make invoke            # Invoke once
make logs              # View logs
make watch-logs        # Real-time logs
```

### Cleanup

```bash
make clean    # Clean build artifacts
make destroy  # Destroy AWS infrastructure
```

## All Available Commands

### Build Commands

- `make bootstrap` - Build the Go bootstrap binary
- `make jq-layer` - Build the jq Lambda layer
- `make build` - Build bootstrap and all layers
- `make docker-build` - Build Docker test image

### Test Commands

- `make test` - Run all tests (local-test)
- `make local-test` - Run tests with Docker
- `make integration-test` - Run integration tests
- `make docker-test` - Build and test in Docker
- `make validate` - Validate handler syntax

### Deploy Commands

- `make tf-init` - Initialize Terraform
- `make tf-plan` - Run Terraform plan
- `make tf-apply` - Build and deploy with Terraform
- `make deploy` - Alias for tf-apply
- `make tf-output` - Show Terraform outputs

### Runtime Commands

- `make invoke` - Invoke the deployed function
- `make logs` - Tail Lambda function logs
- `make watch-logs` - Watch logs in real-time
- `make info` - Show deployment information

### Cleanup Commands

- `make clean` - Clean build artifacts
- `make tf-destroy` - Destroy infrastructure
- `make destroy` - Alias for tf-destroy

### Info Commands

- `make help` - Show all available commands
- `make info` - Show deployment info
- `make bootstrap-info` - Show bootstrap binary info
- `make layer-info` - Show layer info

### Quality Commands

- `make validate` - Validate handler syntax
- `make lint` - Lint shell scripts (requires shellcheck)
- `make format` - Format shell scripts (requires shfmt)

### Workflow Commands

- `make all` - Clean, build, and test everything
- `make dev` - Quick development cycle (build + test)
- `make ci` - CI pipeline (clean + build + test + validate)

### Tool Commands

- `make install-tools` - Install development tools (macOS)

## Configuration

### Architecture

Set the target architecture (default: arm64):

```bash
make build ARCH=arm64    # ARM64 (default)
make build ARCH=x86_64   # x86_64
```

### Environment Variables

The Makefile respects your `.env` file and Terraform configuration.

## Examples

### First Time Setup

```bash
# Clone and setup
git clone <repo>
cd lambda-shell-endpoint
cp .env.example .env
# Edit .env

# Build and deploy
make build
make tf-init
make deploy

# Test
make invoke
```

### Update Handler

```bash
# Edit handler
vim app/src/handler.sh

# Test locally
make test

# Deploy
make deploy

# Verify
make invoke
make logs
```

### Development Workflow

```bash
# Make changes
vim app/src/handler.sh

# Quick test
make dev

# If tests pass, deploy
make deploy
```

### CI/CD Pipeline

```bash
# Run full CI pipeline
make ci

# If successful, deploy
make deploy
```

### Troubleshooting

```bash
# Check build artifacts
make bootstrap-info
make layer-info

# Validate handler
make validate

# Test locally
make test

# Check deployment
make info

# View logs
make logs
```

### Cleanup

```bash
# Clean local artifacts
make clean

# Destroy AWS resources
make destroy
```

## Tips

1. **Use `make help`** to see all available commands
2. **Use `make dev`** for quick iteration during development
3. **Use `make ci`** to run the full CI pipeline locally
4. **Use `make info`** to quickly see deployment details
5. **Use `make validate`** before committing changes

## Integration with Documentation

The Makefile is referenced in:
- [README.md](../README.md) - Quick Start section
- [GETTING_STARTED.md](../GETTING_STARTED.md) - Step-by-step guide
- [docs/QUICKREF.md](QUICKREF.md) - Quick reference

## Requirements

### Required
- bash
- docker
- terraform (or use `./tf` wrapper)
- aws CLI (for logs and invoke commands)

### Optional
- jq (for JSON formatting)
- shellcheck (for linting)
- shfmt (for formatting)

Install optional tools on macOS:
```bash
make install-tools
```

## Troubleshooting

### "Function not deployed"

Run `make deploy` first, or check that Terraform has been applied.

### "Docker not running"

Start Docker Desktop and try again.

### "terraform: command not found"

Use the included wrapper: `./tf` instead of `terraform`, or install Terraform.

### Build fails

```bash
# Clean and rebuild
make clean
make build
```

### Tests fail

```bash
# Check Docker
docker info

# Validate handler
make validate

# Check build artifacts
make bootstrap-info
make layer-info
```
