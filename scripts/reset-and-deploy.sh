#!/bin/bash
# Complete database reset and redeploy script
# Usage: ./scripts/reset-and-deploy.sh [--dry-run]
#        ./scripts/reset-and-deploy.sh --project seafoundry-staging

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if dry run
DRY_RUN=false
PROJECT=""
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    echo -e "${YELLOW}🔍 DRY RUN MODE - No actual changes will be made${NC}"
fi

# Parse args
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --project)
            PROJECT="$2"
            shift 2
            ;;
        --project=*)
            PROJECT="${1#*=}"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

PROJECT_FLAG=""
if [[ -n "$PROJECT" ]]; then
    PROJECT_FLAG="--project $PROJECT"
fi

echo -e "${BLUE}🚀 SeaFoundry Database Reset and Deploy${NC}"
echo "================================================"

# Step 1: Clear existing data
echo -e "\n${YELLOW}Step 1: Clearing existing data...${NC}"
if [[ "$DRY_RUN" == "true" ]]; then
    echo "Would run: npm run clear:all"
else
    echo "Running: npm run clear:all -- --force"
    npm run clear:all -- --force
fi

# Step 2: Deploy Firestore indexes
echo -e "\n${YELLOW}Step 2: Deploying Firestore indexes...${NC}"
if [[ "$DRY_RUN" == "true" ]]; then
    echo "Would run: firebase deploy --only firestore:indexes"
else
    echo "Running: firebase deploy --only firestore:indexes $PROJECT_FLAG"
    firebase deploy --only firestore:indexes $PROJECT_FLAG
fi

# Step 3: Deploy Firestore rules
echo -e "\n${YELLOW}Step 3: Deploying Firestore rules...${NC}"
if [[ "$DRY_RUN" == "true" ]]; then
    echo "Would run: firebase deploy --only firestore:rules"
else
    echo "Running: firebase deploy --only firestore:rules $PROJECT_FLAG"
    firebase deploy --only firestore:rules $PROJECT_FLAG
fi

# Step 4: Verify deployment
echo -e "\n${YELLOW}Step 4: Verifying deployment...${NC}"
if [[ "$DRY_RUN" == "true" ]]; then
    echo "Would run: firebase firestore:indexes"
    echo "Would run: firebase projects:list"
else
    echo "Current Firestore indexes:"
    firebase firestore:indexes $PROJECT_FLAG
    echo -e "\nProject status:"
    firebase projects:list
fi

echo -e "\n${GREEN}✅ Database reset and deploy complete!${NC}"

if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}💡 Run without --dry-run to execute the actual commands${NC}"
fi
