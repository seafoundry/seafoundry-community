#!/bin/bash
# SeaFoundry Staging Deployment Script
# Builds and deploys Flutter web + Firebase resources to staging.
#
# Usage:
#   ./scripts/deploy-staging.sh [options]
#
# Options:
#   --project              Firebase project (default: seafoundry-staging)
#   --env-file             Env file for dart defines (default: .env.staging)
#   --dart-defines-output  Output path for dart defines JSON (default: dart_defines.staging.json)
#   --skip-build           Skip Flutter web build
#   --skip-web             Skip hosting deploy
#   --skip-rules           Skip Firestore rules deploy
#   --skip-indexes         Skip Firestore indexes deploy
#   --skip-storage         Skip Storage rules deploy
#   --skip-functions       Skip Cloud Functions deploy
#   --skip-seed            Skip demo data seeding
#   --dry-run              Print commands without executing
#
# Notes:
# - Seeding requires FIREBASE_SERVICE_ACCOUNT or GOOGLE_APPLICATION_CREDENTIALS
#   pointing at the staging service account JSON.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Defaults
PROJECT="seafoundry-staging"
ENV_FILE=".env.staging"
DART_DEFINES_OUTPUT="dart_defines.staging.json"
SKIP_BUILD=false
SKIP_WEB=false
SKIP_RULES=false
SKIP_INDEXES=false
SKIP_STORAGE=false
SKIP_FUNCTIONS=false
SKIP_SEED=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --project) PROJECT="$2"; shift 2 ;;
    --project=*) PROJECT="${1#*=}"; shift ;;
    --env-file) ENV_FILE="$2"; shift 2 ;;
    --env-file=*) ENV_FILE="${1#*=}"; shift ;;
    --dart-defines-output) DART_DEFINES_OUTPUT="$2"; shift 2 ;;
    --dart-defines-output=*) DART_DEFINES_OUTPUT="${1#*=}"; shift ;;
    --skip-build) SKIP_BUILD=true; shift ;;
    --skip-web) SKIP_WEB=true; shift ;;
    --skip-rules) SKIP_RULES=true; shift ;;
    --skip-indexes) SKIP_INDEXES=true; shift ;;
    --skip-storage) SKIP_STORAGE=true; shift ;;
    --skip-functions) SKIP_FUNCTIONS=true; shift ;;
    --skip-seed) SKIP_SEED=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help)
      head -28 "$0" | grep "^#" | sed 's/^# //' | sed 's/^#//'
      exit 0
      ;;
    *) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
  esac
done

run_cmd() {
  if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${CYAN}Would run:${NC} $*"
  else
    echo -e "${CYAN}Running:${NC} $*"
    eval "$@"
  fi
}

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           SeaFoundry Staging Deployment                        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}Configuration:${NC}"
echo -e "  Project:          ${GREEN}$PROJECT${NC}"
echo -e "  Env File:         ${GREEN}$ENV_FILE${NC}"
echo -e "  Dart Defines:     ${GREEN}$DART_DEFINES_OUTPUT${NC}"
echo -e "  Skip Build:       ${GREEN}$SKIP_BUILD${NC}"
echo -e "  Skip Web:         ${GREEN}$SKIP_WEB${NC}"
echo -e "  Skip Rules:       ${GREEN}$SKIP_RULES${NC}"
echo -e "  Skip Indexes:     ${GREEN}$SKIP_INDEXES${NC}"
echo -e "  Skip Storage:     ${GREEN}$SKIP_STORAGE${NC}"
echo -e "  Skip Functions:   ${GREEN}$SKIP_FUNCTIONS${NC}"
echo -e "  Skip Seed:        ${GREEN}$SKIP_SEED${NC}"
echo ""

# Validate tooling
if ! command -v firebase &> /dev/null; then
  echo -e "${RED}✗ Firebase CLI not found${NC}"
  exit 1
fi

if ! command -v flutter &> /dev/null; then
  echo -e "${RED}✗ Flutter not found${NC}"
  exit 1
fi

# Generate dart defines if env file exists
if [[ -f "$ENV_FILE" ]]; then
  run_cmd "ENV_FILE=$ENV_FILE DART_DEFINES_OUTPUT=$DART_DEFINES_OUTPUT npm run generate-dart-env --silent"
else
  echo -e "${YELLOW}⚠ Env file not found (${ENV_FILE}); skipping dart defines generation${NC}"
fi

if [[ "$SKIP_WEB" == "false" ]]; then
  WEB_CMD="./scripts/deploy-web.sh --project $PROJECT --env-file $ENV_FILE"
  if [[ "$SKIP_BUILD" == "true" ]]; then
    WEB_CMD="$WEB_CMD --skip-build"
  fi
  if [[ -f "$DART_DEFINES_OUTPUT" ]]; then
    WEB_CMD="$WEB_CMD --dart-defines-file $DART_DEFINES_OUTPUT"
  fi
  if [[ "$DRY_RUN" == "true" ]]; then
    WEB_CMD="$WEB_CMD --dry-run"
  fi
  run_cmd "$WEB_CMD"
fi

if [[ "$SKIP_INDEXES" == "false" ]]; then
  run_cmd "firebase deploy --only firestore:indexes --project $PROJECT"
fi

if [[ "$SKIP_RULES" == "false" ]]; then
  run_cmd "firebase deploy --only firestore:rules --project $PROJECT"
fi

if [[ "$SKIP_STORAGE" == "false" ]]; then
  run_cmd "firebase deploy --only storage --project $PROJECT"
fi

if [[ "$SKIP_FUNCTIONS" == "false" ]]; then
  run_cmd "firebase deploy --only functions --project $PROJECT"
fi

if [[ "$SKIP_SEED" == "false" ]]; then
  SERVICE_ACCOUNT_PATH="${FIREBASE_SERVICE_ACCOUNT:-${FIREBASE_SERVICE_ACCOUNT_PATH:-$GOOGLE_APPLICATION_CREDENTIALS}}"
  if [[ -z "$SERVICE_ACCOUNT_PATH" ]]; then
    echo -e "${RED}✗ Missing FIREBASE_SERVICE_ACCOUNT / GOOGLE_APPLICATION_CREDENTIALS for seeding${NC}"
    echo -e "${YELLOW}Set FIREBASE_SERVICE_ACCOUNT to your staging service account JSON file.${NC}"
    exit 1
  fi

  if [[ ! -f "$SERVICE_ACCOUNT_PATH" ]]; then
    echo -e "${RED}✗ Service account not found: $SERVICE_ACCOUNT_PATH${NC}"
    exit 1
  fi

  run_cmd "FIREBASE_SERVICE_ACCOUNT=$SERVICE_ACCOUNT_PATH npm run seed:taxonomy"
  run_cmd "FIREBASE_SERVICE_ACCOUNT=$SERVICE_ACCOUNT_PATH node scripts/seed-demo.js --seed-all-tiers --reset"
fi

echo ""
echo -e "${GREEN}✅ Staging deployment complete!${NC}"
echo -e "${CYAN}https://${PROJECT}.web.app${NC}"
echo ""
