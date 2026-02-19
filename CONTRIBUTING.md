# Contributing

Contributions welcome. Keep it minimal.

## Development Setup

```bash
git clone https://github.com/ql4b/lambda-shell-endpoint
cd lambda-shell-endpoint
cp .env.example .env
# Edit .env with your AWS config
source ./activate
```

## Building

### Bootstrap

```bash
cd runtime
./build.sh
cd ..
```

### jq Layer

```bash
cd layers/jq
./build.sh arm64
cd ../..
```

## Testing

### Local Tests

```bash
./test/local.sh
```

### Manual Testing

```bash
# Build and start
docker build -t lambda-test -f Dockerfile.test .
docker run -d --rm -p 9000:8080 --name lambda-test lambda-test

# Invoke
curl -X POST "http://localhost:9000/2015-03-31/functions/function/invocations" \
  -d @test/payloads/basic.json | jq

# Cleanup
docker stop lambda-test
```

## Adding Examples

1. Create handler in `examples/your-example.sh`
2. Follow the pattern:
   ```bash
   #!/bin/bash
   set -euo pipefail
   
   run() {
       # Your logic here
   }
   ```
3. Document in `examples/README.md`
4. Add test payload if needed

## Documentation

- Keep it concise
- Show working code
- Real examples over theory
- Update cost numbers with sources

## Pull Requests

1. Fork the repo
2. Create a feature branch
3. Make your changes
4. Test locally
5. Submit PR with clear description

**PR Guidelines:**
- One feature per PR
- Include tests if applicable
- Update docs if needed
- Keep commits atomic

## Code Style

**Shell:**
- Use `set -euo pipefail`
- Quote variables: `"$var"`
- Prefer `local` for function variables
- Use `jq` for JSON manipulation

**Terraform:**
- Follow existing module patterns
- Use variables for configurability
- Document inputs/outputs
- Keep it minimal

## Release Process

Releases are automated via GitHub Actions:

1. Tag a release: `git tag v1.0.0`
2. Push: `git push origin v1.0.0`
3. GitHub Actions builds and publishes layers

## Questions?

Open an issue or discussion.

## License

MIT
