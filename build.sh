#!/bin/bash

# Build script for Channer with xcbeautify
# Ensures clean output and easier error detection

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if xcbeautify is installed
if ! command -v xcbeautify &> /dev/null; then
    echo -e "${YELLOW}xcbeautify not found. Installing via Homebrew...${NC}"
    if ! command -v brew &> /dev/null; then
        echo -e "${RED}Homebrew not found. Please install Homebrew first.${NC}"
        exit 1
    fi
    brew install xcbeautify
fi

# Configuration
WORKSPACE="Channer.xcworkspace"
SCHEME="Channer"
CONFIGURATION="Debug"
SDK="iphonesimulator"

echo -e "${GREEN}Building $SCHEME...${NC}"

# Build with xcodebuild and pipe through xcbeautify
xcodebuild \
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -sdk "$SDK" \
    -quiet \
    clean build \
    | xcbeautify

# Check build result
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo -e "${GREEN}✓ Build succeeded${NC}"
else
    echo -e "${RED}✗ Build failed${NC}"
    exit 1
fi