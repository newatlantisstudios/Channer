#!/bin/bash

# Quick test build script - minimal output for CI/testing
# Exit codes: 0 = success, 1 = failure

WORKSPACE="Channer.xcworkspace"
SCHEME="Channer"

# Build with minimal output
xcodebuild \
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -sdk iphonesimulator \
    -quiet \
    build \
    > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "BUILD SUCCEEDED"
    exit 0
else
    echo "BUILD FAILED"
    exit 1
fi