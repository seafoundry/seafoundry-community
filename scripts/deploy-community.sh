#!/bin/bash
# Community Edition Deployment Script
# Builds and deploys the SeaFoundry Community Edition to Firebase
#
# Prerequisites:
#   - Firebase CLI installed (npm install -g firebase-tools)
#   - Logged in to Firebase (firebase login)
#   - Valid firebase.community.json configuration
#   - Built web app in build/web/ (unless using --skip-validation)
#
# Usage:
#   ./scripts/deploy-community.sh [OPTIONS]
#
# Options:
#   --skip-validation    Skip build validation (not recommended)
#   --rules-only         Deploy only Firestore rules
#   --hosting-only       Deploy only hosting (requires pre-built web)
#   --help               Show help message

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
FIREBASE_CONFIG="firebase.community.json"

# Validate Firebase config exists
if [ ! -f "$FIREBASE_CONFIG" ]; then
    echo -e "${RED}ERROR: Firebase configuration not found: $FIREBASE_CONFIG${NC}"
    exit 1
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}SeaFoundry Community Deployment${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Parse command line arguments
SKIP_VALIDATION=false
DEPLOY_TARGET="all"

while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-validation)
      SKIP_VALIDATION=true
      shift
      ;;
    --rules-only)
      DEPLOY_TARGET="rules"
      shift
      ;;
    --hosting-only)
      DEPLOY_TARGET="hosting"
      shift
      ;;
    --help)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --skip-validation    Skip build validation (not recommended)"
      echo "  --rules-only         Deploy only Firestore rules"
      echo "  --hosting-only       Deploy only hosting (requires pre-built web)"
      echo "  --help               Show this help message"
      echo ""
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      exit 1
      ;;
  esac
done

# Check Firebase CLI
if ! command -v firebase &> /dev/null; then
    echo -e "${RED}ERROR: Firebase CLI is not installed${NC}"
    echo -e "${YELLOW}Install with: npm install -g firebase-tools${NC}"
    exit 1
fi

# Check if logged in to Firebase
if ! firebase projects:list &> /dev/null; then
    echo -e "${RED}ERROR: Not logged in to Firebase${NC}"
    echo -e "${YELLOW}Run: firebase login${NC}"
    exit 1
fi

# Validate build (unless skipped)
if [ "$SKIP_VALIDATION" = false ] && [ "$DEPLOY_TARGET" != "rules" ]; then
    echo -e "${YELLOW}Running build validation...${NC}"
    if ! ./scripts/validate-community-build.sh; then
        echo -e "${RED}Build validation failed. Deployment aborted.${NC}"
        exit 1
    fi
    echo ""
fi

# Deploy based on target
case $DEPLOY_TARGET in
  "rules")
    echo -e "${YELLOW}Deploying Firestore rules only...${NC}"
    firebase deploy --only firestore:rules --config "$FIREBASE_CONFIG"
    ;;
  "hosting")
    echo -e "${YELLOW}Deploying hosting only...${NC}"
    if [ ! -d "build/web" ]; then
        echo -e "${RED}ERROR: build/web directory not found${NC}"
        echo -e "${YELLOW}Run: flutter build web --release${NC}"
        exit 1
    fi
    firebase deploy --only hosting --config "$FIREBASE_CONFIG"
    ;;
  "all")
    echo -e "${YELLOW}Deploying Firestore rules and hosting...${NC}"
    firebase deploy --only firestore:rules,hosting --config "$FIREBASE_CONFIG"
    ;;
esac

# Success message
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}DEPLOYMENT COMPLETE${NC}"
echo -e "${BLUE}========================================${NC}"

# Get project info
PROJECT_ID=$(grep -o '"projectId": "[^"]*"' "$FIREBASE_CONFIG" | sed 's/"projectId": "\([^"]*\)"/\1/')
if [ -n "$PROJECT_ID" ]; then
    echo -e "${GREEN}Deployed to: https://$PROJECT_ID.web.app${NC}"
fi

echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Visit your deployed site"
echo "  2. Test authentication and core features"
echo "  3. Verify Firestore rules in Firebase Console"
echo "  4. Monitor Cloud Functions logs if applicable"
echo ""
