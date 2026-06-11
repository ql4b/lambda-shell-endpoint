# Getting Started Checklist

## Prerequisites

- [ ] AWS CLI installed and configured
- [ ] Docker installed (for local testing)
- [ ] Terraform installed
- [ ] Basic shell scripting knowledge

## Setup (5 minutes)

- [ ] Clone repository
- [ ] Copy `.env.example` to `.env`
- [ ] Edit `.env` with your AWS profile and region
- [ ] Run `source ./activate`

## Build (2 minutes)

### Using Make (Recommended)
- [ ] Build everything: `make build`

### Manual Build
- [ ] Build bootstrap: `cd runtime && ./build.sh && cd ..`
- [ ] Build jq layer (optional): `cd layers/jq && ./build.sh arm64 && cd ../..`

## Develop (10 minutes)

- [ ] Choose an example from `examples/` or write your own
- [ ] Copy to `app/src/handler.sh`
- [ ] Set required environment variables in `.env`
- [ ] Test locally: `make test` (or `./test/local.sh`)

## Deploy (2 minutes)

### Using Make (Recommended)
- [ ] Deploy: `make deploy`
- [ ] Get Function URL: `make info`

### Manual Deploy
- [ ] Initialize Terraform: `tf init`
- [ ] Review plan: `tf plan`
- [ ] Deploy: `tf apply`
- [ ] Save Function URL from output

## Test (1 minute)

- [ ] Test endpoint: `make invoke` (or `curl $(tf output -raw function_url) | jq`)
- [ ] Check logs: `make logs` (or `aws logs tail /aws/lambda/$(tf output -raw function_name) --follow`)

## Production Ready

- [ ] Review [Production Guide](docs/PRODUCTION.md)
- [ ] Configure security (IAM auth or shared secret)
- [ ] Set up CloudWatch alarms
- [ ] Add CORS if needed
- [ ] Configure caching if applicable
- [ ] Document your endpoint

## Total Time: ~20 minutes from zero to production

## Quick Commands

### Using Make
```bash
# Complete setup and deploy
make build
make deploy

# Test
make invoke

# View logs
make logs

# Update handler
# Edit app/src/handler.sh
make deploy

# Clean up
make destroy
```

### Manual Commands
```bash
# Complete setup and deploy
source ./activate
cd runtime && ./build.sh && cd ..
tf init && tf apply

# Test
curl $(tf output -raw function_url) | jq

# View logs
aws logs tail /aws/lambda/$(tf output -raw function_name) --follow

# Update handler
# Edit app/src/handler.sh
tf apply -target=module.lambda

# Destroy
tf destroy
```

## Need Help?

- **Examples:** See [examples/](examples/)
- **Testing:** See [docs/TESTING.md](docs/TESTING.md)
- **Production:** See [docs/PRODUCTION.md](docs/PRODUCTION.md)
- **FAQ:** See [docs/FAQ.md](docs/FAQ.md)
- **Quick Ref:** See [docs/QUICKREF.md](docs/QUICKREF.md)
