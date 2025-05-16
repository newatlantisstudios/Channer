#!/bin/bash

# Advanced build script for Channer with multiple options
# Usage: ./build-advanced.sh [options]
# Options:
#   -c, --clean        Clean before building
#   -r, --release      Build in Release configuration (default: Debug)
#   -d, --device       Build for device instead of simulator
#   -v, --verbose      Show verbose output
#   -h, --help         Show this help message

# Default values
WORKSPACE="Channer.xcworkspace"
SCHEME="Channer"
CONFIGURATION="Debug"
SDK="iphonesimulator"
CLEAN=""
VERBOSE=""
QUIET="-quiet"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--clean)
            CLEAN="clean"
            shift
            ;;
        -r|--release)
            CONFIGURATION="Release"
            shift
            ;;
        -d|--device)
            SDK="iphoneos"
            shift
            ;;
        -v|--verbose)
            VERBOSE="1"
            QUIET=""
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  -c, --clean        Clean before building"
            echo "  -r, --release      Build in Release configuration (default: Debug)"
            echo "  -d, --device       Build for device instead of simulator"
            echo "  -v, --verbose      Show verbose output"
            echo "  -h, --help         Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Check if xcbeautify is installed (only if not verbose)
if [ -z "$VERBOSE" ] && ! command -v xcbeautify &> /dev/null; then
    echo -e "${YELLOW}xcbeautify not found. Installing via Homebrew...${NC}"
    if ! command -v brew &> /dev/null; then
        echo -e "${RED}Homebrew not found. Please install Homebrew first.${NC}"
        echo "Visit: https://brew.sh"
        exit 1
    fi
    brew install xcbeautify
fi

# Build info
echo -e "${BLUE}Build Configuration:${NC}"
echo "  Workspace: $WORKSPACE"
echo "  Scheme: $SCHEME"
echo "  Configuration: $CONFIGURATION"
echo "  SDK: $SDK"
echo "  Clean: ${CLEAN:-No}"
echo "  Verbose: ${VERBOSE:-No}"
echo ""

# Start timer
START_TIME=$(date +%s)

# Build command
echo -e "${GREEN}Building $SCHEME...${NC}"

if [ -n "$VERBOSE" ]; then
    # Verbose build
    xcodebuild \
        -workspace "$WORKSPACE" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -sdk "$SDK" \
        $CLEAN build
else
    # Quiet build with xcbeautify
    xcodebuild \
        -workspace "$WORKSPACE" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -sdk "$SDK" \
        $QUIET \
        $CLEAN build \
        | xcbeautify
fi

# Check build result
BUILD_RESULT=${PIPESTATUS[0]}

# End timer
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

if [ $BUILD_RESULT -eq 0 ]; then
    echo -e "${GREEN}✓ Build succeeded in ${DURATION}s${NC}"
else
    echo -e "${RED}✗ Build failed after ${DURATION}s${NC}"
    exit 1
fi