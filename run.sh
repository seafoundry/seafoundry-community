#!/bin/bash

# SeaFoundry Flutter Run Script
# This script generates dart_defines.json from .env and runs the Flutter app

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${RED}Error: .env file not found!${NC}"
    echo -e "${YELLOW}Please copy .env.example to .env and configure your environment variables.${NC}"
    echo "Run: cp .env.example .env"
    exit 1
fi

# Generate dart_defines.json from .env
echo -e "${GREEN}Generating dart_defines.json from .env...${NC}"
npm run generate-dart-env --silent
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to generate dart_defines.json${NC}"
    exit 1
fi

# Parse command line arguments
DEVICE=""
BUILD_MODE=""
EXTRA_ARGS=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--device)
            DEVICE="--device-id=$2"
            shift 2
            ;;
        --debug)
            BUILD_MODE="--debug"
            shift
            ;;
        --profile)
            BUILD_MODE="--profile"
            shift
            ;;
        --release)
            BUILD_MODE="--release"
            shift
            ;;
        *)
            EXTRA_ARGS="$EXTRA_ARGS $1"
            shift
            ;;
    esac
done

# Build the flutter run command with dart-define-from-file
# Default tier for this (community) branch; can be overridden by env SF_TIER
DEFAULT_TIER=${SF_TIER:-community}
FLUTTER_CMD="flutter run --dart-define-from-file=dart_defines.json --dart-define=SF_TIER=$DEFAULT_TIER"

# Add device, build mode, and extra arguments
FLUTTER_CMD="$FLUTTER_CMD $DEVICE $BUILD_MODE $EXTRA_ARGS"

# Display the command being run
echo -e "${GREEN}Running: $FLUTTER_CMD${NC}"
echo ""

# Run the Flutter app
eval $FLUTTER_CMD
