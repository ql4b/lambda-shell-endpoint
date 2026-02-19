.PHONY: help build test clean deploy destroy logs bootstrap jq-layer docker-build docker-test local-test integration-test all

# Default target
.DEFAULT_GOAL := help

# Variables
ARCH ?= arm64
PLATFORM := $(if $(filter arm64,$(ARCH)),linux/arm64,linux/amd64)
FUNCTION_NAME := $(shell cd infra && terraform output -raw function_name 2>/dev/null || echo "")
FUNCTION_URL := $(shell cd infra && terraform output -raw function_url 2>/dev/null || echo "")

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

all: clean build test ## Clean, build, and test everything

bootstrap: ## Build the Go bootstrap binary
	@echo "Building bootstrap for $(ARCH)..."
	@cd runtime && ./build.sh
	@echo "Bootstrap built successfully"

jq-layer: ## Build the jq layer
	@echo "Building jq layer for $(ARCH)..."
	@cd layers/jq && ARCH=$(ARCH) ./build.sh
	@echo "jq layer built successfully"

build: bootstrap jq-layer ## Build bootstrap and all layers

docker-build: ## Build Docker test image
	@echo "Building Docker test image..."
	@docker build -t lambda-shell-test -f Dockerfile.test .
	@echo "Docker image built successfully"

docker-test: docker-build ## Build and run Docker container for testing
	@echo "Starting Lambda container..."
	@docker run -d --rm -p 9000:8080 --name lambda-shell-test lambda-shell-test
	@sleep 3
	@echo "Testing Lambda invocation..."
	@curl -sS -X POST "http://localhost:9000/2015-03-31/functions/function/invocations" -d '{}' | jq '.' || true
	@echo ""
	@echo "Stopping container..."
	@docker stop lambda-shell-test

local-test: ## Run local tests with Docker
	@./test/local.sh

integration-test: ## Run integration tests
	@./test/integration.sh

test: local-test ## Run all tests

clean: ## Clean build artifacts
	@echo "Cleaning build artifacts..."
	@rm -rf runtime/build/bootstrap
	@rm -rf layers/jq/layer
	@rm -f layers/jq/jq-layer.zip
	@docker rm -f lambda-shell-test 2>/dev/null || true
	@docker rmi lambda-shell-test 2>/dev/null || true
	@echo "Clean complete"

tf-init: ## Initialize Terraform
	@echo "Initializing Terraform..."
	@cd infra && terraform init

tf-plan: ## Run Terraform plan
	@echo "Running Terraform plan..."
	@cd infra && terraform plan

tf-apply: build ## Build and deploy with Terraform
	@echo "Deploying with Terraform..."
	@cd infra && terraform apply

deploy: tf-apply ## Alias for tf-apply

tf-destroy: ## Destroy infrastructure
	@echo "Destroying infrastructure..."
	@cd infra && terraform destroy

destroy: tf-destroy ## Alias for tf-destroy

tf-output: ## Show Terraform outputs
	@cd infra && terraform output

logs: ## Tail Lambda function logs
	@if [ -z "$(FUNCTION_NAME)" ]; then \
		echo "Error: Function not deployed or terraform output not available"; \
		exit 1; \
	fi
	@echo "Tailing logs for $(FUNCTION_NAME)..."
	@aws logs tail /aws/lambda/$(FUNCTION_NAME) --follow

invoke: ## Invoke the deployed Lambda function
	@if [ -z "$(FUNCTION_URL)" ]; then \
		echo "Error: Function URL not available"; \
		exit 1; \
	fi
	@echo "Invoking function at $(FUNCTION_URL)..."
	@curl -sS "$(FUNCTION_URL)" | jq '.'

watch-logs: ## Watch logs in real-time while invoking
	@if [ -z "$(FUNCTION_NAME)" ]; then \
		echo "Error: Function not deployed"; \
		exit 1; \
	fi
	@aws logs tail /aws/lambda/$(FUNCTION_NAME) --follow --since 1m

info: ## Show deployment information
	@echo "Function Name: $(FUNCTION_NAME)"
	@echo "Function URL:  $(FUNCTION_URL)"
	@echo "Architecture:  $(ARCH)"
	@echo "Platform:      $(PLATFORM)"

validate: ## Validate handler syntax
	@echo "Validating handler syntax..."
	@bash -n app/src/handler.sh && echo "Handler syntax OK"

format: ## Format shell scripts
	@echo "Formatting shell scripts..."
	@find . -name "*.sh" -type f ! -path "./infra/.terraform/*" -exec shfmt -w {} \; 2>/dev/null || echo "shfmt not installed, skipping"

lint: ## Lint shell scripts
	@echo "Linting shell scripts..."
	@find . -name "*.sh" -type f ! -path "./infra/.terraform/*" -exec shellcheck {} \; 2>/dev/null || echo "shellcheck not installed, skipping"

dev: build docker-test ## Quick development cycle: build and test

ci: clean build test validate ## CI pipeline: clean, build, test, validate

install-tools: ## Install development tools (macOS)
	@echo "Installing development tools..."
	@command -v shfmt >/dev/null 2>&1 || brew install shfmt
	@command -v shellcheck >/dev/null 2>&1 || brew install shellcheck
	@command -v jq >/dev/null 2>&1 || brew install jq
	@echo "Tools installed"

.PHONY: bootstrap-info
bootstrap-info: ## Show bootstrap binary information
	@if [ -f runtime/build/bootstrap ]; then \
		echo "Bootstrap binary:"; \
		ls -lh runtime/build/bootstrap; \
		file runtime/build/bootstrap; \
	else \
		echo "Bootstrap not built. Run 'make bootstrap' first."; \
	fi

.PHONY: layer-info
layer-info: ## Show layer information
	@if [ -f layers/jq/jq-layer.zip ]; then \
		echo "jq layer:"; \
		ls -lh layers/jq/jq-layer.zip; \
	else \
		echo "jq layer not built. Run 'make jq-layer' first."; \
	fi
