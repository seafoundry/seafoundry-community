#!/bin/bash
# Community Build Validation Script
# Validates that the community build is ready for deployment
#
# Validation Steps:
#   1. Check Flutter installation
#   2. Install dependencies (flutter pub get)
#   3. Run flutter analyze - REQUIRES 0 errors (warnings are non-blocking)
#   4. Validate .env file exists with TIER=community
#   5. Build web release to verify no build errors
#
# Exit codes: 0 = success, 1 = failure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Track validation status
VALIDATION_FAILED=0

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}SeaFoundry Community Build Validator${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Step 1: Check Flutter installation
echo -e "${YELLOW}[1/5]${NC} Checking Flutter installation..."
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}ERROR: Flutter is not installed or not in PATH${NC}"
    exit 1
fi
echo -e "${GREEN}Flutter found: $(flutter --version | head -n 1)${NC}"
echo ""

# Step 2: Run flutter pub get
echo -e "${YELLOW}[2/5]${NC} Running flutter pub get..."
if ! flutter pub get; then
    echo -e "${RED}ERROR: flutter pub get failed${NC}"
    exit 1
fi
echo -e "${GREEN}Dependencies installed successfully${NC}"
echo ""

# Step 3: Run flutter analyze
echo -e "${YELLOW}[3/5]${NC} Running flutter analyze..."
ANALYZE_OUTPUT=$(flutter analyze 2>&1)
ANALYZE_EXIT_CODE=$?

# Count errors and warnings
ERROR_COUNT=$(echo "$ANALYZE_OUTPUT" | grep -E "^   error •" | wc -l | xargs)
WARNING_COUNT=$(echo "$ANALYZE_OUTPUT" | grep -E "^   warning •" | wc -l | xargs)

echo "$ANALYZE_OUTPUT"
echo ""

if [ $ANALYZE_EXIT_CODE -ne 0 ] || [ "$ERROR_COUNT" != "0" ]; then
    echo -e "${RED}ERROR: flutter analyze found $ERROR_COUNT error(s) and $WARNING_COUNT warning(s)${NC}"
    echo -e "${RED}Community builds require 0 errors${NC}"
    VALIDATION_FAILED=1
else
    echo -e "${GREEN}flutter analyze passed with 0 errors${NC}"
    if [ "$WARNING_COUNT" != "0" ]; then
        echo -e "${YELLOW}Warning: $WARNING_COUNT warning(s) found (non-blocking)${NC}"
    fi
fi
echo ""

# Step 4: Check for .env file
echo -e "${YELLOW}[4/5]${NC} Checking environment configuration..."
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}WARNING: .env file not found${NC}"
    echo -e "${YELLOW}Please copy .env.community.example to .env and configure${NC}"
    VALIDATION_FAILED=1
else
    # Check for required environment variables
    if ! grep -q "TIER=community" .env; then
        echo -e "${RED}ERROR: TIER=community not set in .env${NC}"
        echo -e "${RED}Community builds MUST have TIER=community${NC}"
        VALIDATION_FAILED=1
    fi
    if ! grep -q "FIREBASE_PROJECT_ID=" .env; then
        echo -e "${YELLOW}WARNING: FIREBASE_PROJECT_ID not set in .env${NC}"
    fi
    if [ $VALIDATION_FAILED -eq 0 ]; then
        echo -e "${GREEN}Environment file configured correctly${NC}"
    fi

    # Load environment variables for build step
    # shellcheck disable=SC1091
    set -a
    source ".env"
    set +a
fi
echo ""

# Step 5: Run flutter build web (release mode)
echo -e "${YELLOW}[5/5]${NC} Building web release..."
BUILD_CMD="flutter build web --release"
if [ -n "$SHAKE_API_KEY" ]; then
    BUILD_CMD="$BUILD_CMD --dart-define=SHAKE_API_KEY=$SHAKE_API_KEY"
else
    echo -e "${YELLOW}⚠ SHAKE_API_KEY not set; crash reporting disabled${NC}"
fi

if ! eval "$BUILD_CMD"; then
    echo -e "${RED}ERROR: flutter build web --release failed${NC}"
    VALIDATION_FAILED=1
else
    echo -e "${GREEN}Web build completed successfully${NC}"

    # Check build output
    if [ -d "build/web" ]; then
        BUILD_SIZE=$(du -sh build/web | cut -f1)
        echo -e "${GREEN}Build output size: $BUILD_SIZE${NC}"
    fi
fi
echo ""

# Final validation summary
echo -e "${BLUE}========================================${NC}"
if [ $VALIDATION_FAILED -eq 0 ]; then
    echo -e "${GREEN}VALIDATION PASSED${NC}"
    echo -e "${GREEN}Community build is ready for deployment${NC}"
    exit 0
else
    echo -e "${RED}VALIDATION FAILED${NC}"
    echo -e "${RED}Please fix the errors above before deploying${NC}"
    exit 1
fi
