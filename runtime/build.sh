#!/bin/sh 

CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build \
  -ldflags="-s -w -extldflags '-static'" \
  -trimpath \
  -buildmode=exe \
  -a \
  -installsuffix cgo \
  -o build/bootstrap main.go

ls -lh build/bootstrap

# ** WORST FOR cold start ** 
# UPX compression (install with: brew install upx)
# if command -v upx >/dev/null 2>&1; then
#   upx --best --lzma build/bootstrap 2>/dev/null || true
# fi