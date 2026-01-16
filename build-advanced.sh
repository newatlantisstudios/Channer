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
DESTINATION=""
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
        -m|--maccatalyst)
            SDK="macosx"
            DESTINATION="generic/platform=macOS,variant=Mac Catalyst"
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
        -t|--destination)
            DESTINATION="$2"
            shift 2
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
            echo "  -m, --maccatalyst  Build for Mac Catalyst"
            echo "  -r, --release      Build in Release configuration (default: Debug)"
            echo "  -d, --device       Build for device instead of simulator"
            echo "  -t, --destination  Override the xcodebuild destination"
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

# Default destination based on SDK if not explicitly provided.
if [ -z "$DESTINATION" ]; then
    if [ "$SDK" = "iphoneos" ]; then
        DESTINATION="generic/platform=iOS"
    elif [ "$SDK" = "macosx" ]; then
        DESTINATION="generic/platform=macOS,variant=Mac Catalyst"
    else
        DESTINATION="generic/platform=iOS Simulator"
    fi
fi

# Prepare local cache locations.
mkdir -p \
    "$HOME_PATH/Library/Caches" \
    "$HOME_PATH/.cache/clang/ModuleCache" \
    "$XDG_CACHE_HOME_PATH" \
    "$TMPDIR_PATH" \
    "$DERIVED_DATA_PATH" \
    "$SOURCE_PACKAGES_PATH"

XCODEBUILD_ENV=(HOME="$HOME_PATH" XDG_CACHE_HOME="$XDG_CACHE_HOME_PATH" TMPDIR="$TMPDIR_PATH")

# Mac Catalyst builds need codesigning disabled and a shared build dir.
if [ "$SDK" = "macosx" ]; then
    CODESIGNING_ARGS=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=)
    PLATFORM_ARGS=(EFFECTIVE_PLATFORM_NAME_MAC_CATALYST_USE_DISTINCT_BUILD_DIR=NO)
else
    CODESIGNING_ARGS=()
    PLATFORM_ARGS=()
fi

# Resolve workspace/project path so the script can run from any directory.
if [ -d "$WORKSPACE_PATH" ] && [ -f "$WORKSPACE_PATH/contents.xcworkspacedata" ] \
    && env "${XCODEBUILD_ENV[@]}" xcodebuild -list -workspace "$WORKSPACE_PATH" >/dev/null 2>&1; then
    XCODEBUILD_ARGS=(-workspace "$WORKSPACE_PATH")
else
    echo -e "${YELLOW}Workspace not found or invalid. Falling back to project.${NC}"
    XCODEBUILD_ARGS=(-project "$PROJECT_PATH")
fi

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
echo "  Destination: $DESTINATION"
echo "  Clean: ${CLEAN:-No}"
echo "  Verbose: ${VERBOSE:-No}"
echo ""

# Start timer
START_TIME=$(date +%s)

# Build command
echo -e "${GREEN}Building $SCHEME...${NC}"

if [ -n "$VERBOSE" ]; then
    # Verbose build
    env "${XCODEBUILD_ENV[@]}" xcodebuild \
        "${XCODEBUILD_ARGS[@]}" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -sdk "$SDK" \
        -destination "$DESTINATION" \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_PATH" \
        "${CODESIGNING_ARGS[@]}" \
        "${PLATFORM_ARGS[@]}" \
        $CLEAN build
else
    # Quiet build with xcbeautify
    env "${XCODEBUILD_ENV[@]}" xcodebuild \
        "${XCODEBUILD_ARGS[@]}" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -sdk "$SDK" \
        -destination "$DESTINATION" \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_PATH" \
        "${CODESIGNING_ARGS[@]}" \
        "${PLATFORM_ARGS[@]}" \
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
