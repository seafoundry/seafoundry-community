#!/bin/bash
# SeaFoundry Web Deployment Script
# Builds and deploys Flutter web to Firebase Hosting
#
# Usage:
#   ./scripts/deploy-web.sh [options]
#
# Options:
#   --dry-run       Show commands without executing
#   --skip-build    Skip Flutter web build
#   --project       Firebase project (default: seafoundryapp)
#   --env-file      Environment file to source (default: .env)
#   --dart-defines-file  Path to dart-define JSON file for Firebase overrides
#
# Prerequisites:
#   - Firebase CLI installed: npm install -g firebase-tools
#   - Firebase login: firebase login
#   - Flutter installed

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
DRY_RUN=false
SKIP_BUILD=false
PROJECT="seafoundryapp"
ENV_FILE=".env"
DART_DEFINES_FILE=""

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true ;;
        --skip-build) SKIP_BUILD=true ;;
        --project) PROJECT="$2"; shift ;;
        --project=*) PROJECT="${1#*=}" ;;
        --env-file) ENV_FILE="$2"; shift ;;
        --env-file=*) ENV_FILE="${1#*=}" ;;
        --dart-defines-file) DART_DEFINES_FILE="$2"; shift ;;
        --dart-defines-file=*) DART_DEFINES_FILE="${1#*=}" ;;
        -h|--help)
            head -16 "$0" | grep "^#" | sed 's/^# //' | sed 's/^#//'
            exit 0
            ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
    esac
    shift
done

# Function to run or show command
run_cmd() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${CYAN}Would run:${NC} $*"
    else
        echo -e "${CYAN}Running:${NC} $*"
        eval "$@"
    fi
}

# Header
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           SeaFoundry Web Deployment                            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}DRY RUN MODE - No actual changes will be made${NC}"
    echo ""
fi

# Show configuration
echo -e "${YELLOW}Configuration:${NC}"
echo -e "  Project:    ${GREEN}$PROJECT${NC}"
echo -e "  Skip Build: ${GREEN}$SKIP_BUILD${NC}"
echo -e "  Env File:   ${GREEN}$ENV_FILE${NC}"
if [[ -n "$DART_DEFINES_FILE" ]]; then
    echo -e "  Dart Defines: ${GREEN}$DART_DEFINES_FILE${NC}"
fi
echo ""

# Load environment variables from .env if present
if [[ -f "$ENV_FILE" ]]; then
    echo -e "${GREEN}✓ Loading environment from ${ENV_FILE}${NC}"
    # shellcheck disable=SC1090
    set -a
    source "$ENV_FILE"
    set +a
else
    echo -e "${YELLOW}⚠ No ${ENV_FILE} found; using existing environment variables${NC}"
fi

# Step 1: Validate prerequisites
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Step 1: Validating prerequisites...${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Check Firebase CLI
if ! command -v firebase &> /dev/null; then
    echo -e "${RED}✗ Firebase CLI not found${NC}"
    echo "  Install: npm install -g firebase-tools"
    exit 1
fi
echo -e "${GREEN}✓ Firebase CLI: $(firebase --version)${NC}"

# Check Flutter
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}✗ Flutter not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Flutter: $(flutter --version | head -1)${NC}"

echo ""

# Step 2: Build Flutter Web
if [[ "$SKIP_BUILD" == "false" ]]; then
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Step 2: Building Flutter web...${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    BUILD_CMD="flutter build web --release --tree-shake-icons"
    if [[ -n "$DART_DEFINES_FILE" ]]; then
        if [[ ! -f "$DART_DEFINES_FILE" ]]; then
            echo -e "${RED}✗ Dart defines file not found: $DART_DEFINES_FILE${NC}"
            exit 1
        fi
        BUILD_CMD="$BUILD_CMD --dart-define-from-file=$DART_DEFINES_FILE"
    fi
    if [[ -n "$SHAKE_API_KEY" ]]; then
        BUILD_CMD="$BUILD_CMD --dart-define=SHAKE_API_KEY=$SHAKE_API_KEY"
    else
        echo -e "${YELLOW}⚠ SHAKE_API_KEY not set; crash reporting disabled${NC}"
    fi

    run_cmd "$BUILD_CMD"

    echo ""
fi

# Step 3: Deploy to Firebase Hosting
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Step 3: Deploying to Firebase Hosting...${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

run_cmd "firebase deploy --only hosting:seafoundryapp --project $PROJECT"

echo ""

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Web deployment complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Deployed to:${NC}"
echo -e "  Web App: ${CYAN}https://${PROJECT}.web.app${NC}"
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}Run without --dry-run to execute the actual deployment${NC}"
fi
