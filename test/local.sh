#!/bin/bash
set -euo pipefail

echo "Lambda Shell Endpoint - Local Test"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "[ERROR] Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check if bootstrap exists
if [ ! -f "runtime/build/bootstrap" ]; then
    echo "Building bootstrap..."
    cd runtime
    ./build.sh
    cd ..
fi

# Build test image
echo "Building test image..."
docker build -t lambda-shell-test -f Dockerfile.test . --quiet

# Start Lambda
echo "Starting Lambda..."
docker run -d --rm \
    -p 9000:8080 \
    --name lambda-shell-test \
    lambda-shell-test > /dev/null

# Wait for Lambda to be ready
echo "Waiting for Lambda to be ready..."
sleep 2

# Run tests
echo ""
./test/integration.sh

# Cleanup
echo ""
echo "Cleaning up..."
docker stop lambda-shell-test > /dev/null

echo "Done"
