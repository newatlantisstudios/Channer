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
DESTINATION="${DESTINATION:-generic/platform=iOS Simulator}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_PATH="${SCRIPT_DIR}/${WORKSPACE}"
PROJECT_PATH="${SCRIPT_DIR}/Channer.xcodeproj"

# Use a local cache root to avoid permission issues with system cache dirs.
CACHE_ROOT="${SCRIPT_DIR}/build/.xcode-cache"
HOME_PATH="${CACHE_ROOT}/home"
XDG_CACHE_HOME_PATH="${CACHE_ROOT}/cache"
TMPDIR_PATH="${CACHE_ROOT}/tmp"
DERIVED_DATA_PATH="${CACHE_ROOT}/DerivedData"
SOURCE_PACKAGES_PATH="${CACHE_ROOT}/SourcePackages"

mkdir -p \
    "$HOME_PATH/Library/Caches" \
    "$HOME_PATH/.cache/clang/ModuleCache" \
    "$XDG_CACHE_HOME_PATH" \
    "$TMPDIR_PATH" \
    "$DERIVED_DATA_PATH" \
    "$SOURCE_PACKAGES_PATH"

XCODEBUILD_ENV=(HOME="$HOME_PATH" XDG_CACHE_HOME="$XDG_CACHE_HOME_PATH" TMPDIR="$TMPDIR_PATH")

if [ -d "$WORKSPACE_PATH" ] && [ -f "$WORKSPACE_PATH/contents.xcworkspacedata" ] \
    && env "${XCODEBUILD_ENV[@]}" xcodebuild -list -workspace "$WORKSPACE_PATH" >/dev/null 2>&1; then
    XCODEBUILD_ARGS=(-workspace "$WORKSPACE_PATH")
else
    echo -e "${YELLOW}Workspace not found or invalid. Falling back to project.${NC}"
    XCODEBUILD_ARGS=(-project "$PROJECT_PATH")
fi

echo -e "${GREEN}Building $SCHEME...${NC}"

# Build with xcodebuild and pipe through xcbeautify
env "${XCODEBUILD_ENV[@]}" xcodebuild \
    "${XCODEBUILD_ARGS[@]}" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -sdk "$SDK" \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_PATH" \
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
