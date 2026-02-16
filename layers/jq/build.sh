#!/bin/bash

set -e

LAYER_NAME="jq"
LAYER_DIR="$(dirname "$0")"
BUILD_DIR="$LAYER_DIR/layer"

echo "Building $LAYER_NAME layer..."

# Clean previous builds
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Get target architecture (default to current platform)
ARCH=${ARCH:-$(uname -m)}
if [[ "$ARCH" == "x86_64" ]]; then
    PLATFORM="linux/amd64"
else
    PLATFORM="linux/arm64"
fi

echo "Building for platform: $PLATFORM"

# Build Docker image and extract binary
docker build --platform $PLATFORM -t lambda-layer-$LAYER_NAME "$LAYER_DIR"

# Create temporary container and copy binary
CONTAINER_ID=$(docker create --platform $PLATFORM lambda-layer-$LAYER_NAME)
docker cp "$CONTAINER_ID:/opt" "$BUILD_DIR/"
docker rm "$CONTAINER_ID"

# Verify binary
echo "Verifying jq binary..."
file "$BUILD_DIR/opt/bin/jq"

# Only test execution if we're on the same architecture
if file "$BUILD_DIR/opt/bin/jq" | grep -q "$(uname -m)"; then
    "$BUILD_DIR/opt/bin/jq" --version
else
    echo "Cross-compiled binary - skipping execution test"
fi

# Create layer zip (opt/ should be in root of zip)
cd "$BUILD_DIR"
zip -r "../$LAYER_NAME-layer.zip" opt/
cd ..

echo "✓ Layer built: $LAYER_NAME-layer.zip"
echo "✓ Size: $(du -h "$LAYER_NAME-layer.zip" | cut -f1)"

# Test the binary in Docker environment
echo "Testing jq in Docker environment..."
docker run --entrypoint /bin/sh --rm lambda-layer-$LAYER_NAME -c "echo '{\"key\": \"value\"}' | /opt/bin/jq .key && echo '✓ jq test passed'"