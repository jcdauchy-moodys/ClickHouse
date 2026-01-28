#!/bin/bash
set -e  # Exit on error

# ClickHouse Build Script for WSL/Docker
# This script automates building ClickHouse server using Docker

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
BUILD_TYPE="${1:-amd_release}"  # Default to amd_release, can be overridden
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/ci/tmp"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}ClickHouse Build Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Build type: ${BUILD_TYPE}"
echo "Script directory: ${SCRIPT_DIR}"
echo "Output directory: ${OUTPUT_DIR}"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command_exists docker; then
    echo -e "${RED}Error: Docker is not installed or not in PATH${NC}"
    exit 1
fi

if ! command_exists python3; then
    echo -e "${RED}Error: Python3 is not installed or not in PATH${NC}"
    exit 1
fi

# Check Docker daemon
if ! docker ps >/dev/null 2>&1; then
    echo -e "${RED}Error: Docker daemon is not running${NC}"
    exit 1
fi

echo -e "${GREEN}✓ All prerequisites met${NC}"
echo ""

# Fix Docker config if needed (remove credsStore that causes issues in WSL)
echo -e "${YELLOW}Checking Docker configuration...${NC}"
if [ -f ~/.docker/config.json ]; then
    if grep -q "credsStore" ~/.docker/config.json; then
        echo "Fixing Docker config (removing credsStore)..."
        echo '{"auths": {}}' > ~/.docker/config.json
    fi
fi
echo -e "${GREEN}✓ Docker configuration OK${NC}"
echo ""

# Navigate to repository root
cd "${SCRIPT_DIR}"

# Available build types
echo -e "${YELLOW}Available build types:${NC}"
echo "  - amd_debug      : AMD64 debug build with tests"
echo "  - amd_release    : AMD64 release build (optimized, default)"
echo "  - amd_asan       : AMD64 with AddressSanitizer"
echo "  - amd_tsan       : AMD64 with ThreadSanitizer"
echo "  - amd_msan       : AMD64 with MemorySanitizer"
echo "  - amd_ubsan      : AMD64 with UndefinedBehaviorSanitizer"
echo "  - arm_release    : ARM64 release build"
echo "  - arm_asan       : ARM64 with AddressSanitizer"
echo ""

# Clean previous build artifacts (optional)
if [ "$2" == "--clean" ]; then
    echo -e "${YELLOW}Cleaning previous build artifacts...${NC}"
    rm -rf "${OUTPUT_DIR}"
    echo -e "${GREEN}✓ Cleaned${NC}"
    echo ""
fi

# Start the build
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Starting ClickHouse Build${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "This will take 1-2 hours depending on your system."
echo "Build output: ${OUTPUT_DIR}"
echo ""

# Run the build using praktika
python3 -m ci.praktika run "Build (${BUILD_TYPE})"

BUILD_EXIT_CODE=$?

if [ $BUILD_EXIT_CODE -eq 0 ]; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Build completed successfully!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Build artifacts location: ${OUTPUT_DIR}"
    echo ""
    echo "Key artifacts:"
    if [ -d "${OUTPUT_DIR}/build" ]; then
        echo "  - Binary: ${OUTPUT_DIR}/build/programs/clickhouse"
        echo "  - Server binary: ${OUTPUT_DIR}/build/programs/clickhouse-server"
        echo "  - Client binary: ${OUTPUT_DIR}/build/programs/clickhouse-client"
    fi
    if [ -d "${OUTPUT_DIR}/packages" ]; then
        echo "  - Packages: ${OUTPUT_DIR}/packages/"
    fi
    echo ""
    echo "To run ClickHouse server locally:"
    echo "  cd ${OUTPUT_DIR}/build/programs"
    echo "  ./clickhouse server"
else
    echo ""
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}Build failed with exit code: ${BUILD_EXIT_CODE}${NC}"
    echo -e "${RED}========================================${NC}"
    echo ""
    echo "Check the build log for errors."
    exit $BUILD_EXIT_CODE
fi
