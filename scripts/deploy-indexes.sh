#!/bin/bash
# Deploy Firestore indexes to Firebase
# Usage: ./scripts/deploy-indexes.sh [project-name]
#
# Default project: seafoundryapp
# Alternative: seafoundry-staging

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get project name from argument or use default
PROJECT=${1:-seafoundryapp}

echo -e "${BLUE}=== Firestore Index Deployment ===${NC}"
echo ""
echo -e "${YELLOW}Project:${NC} $PROJECT"
echo -e "${YELLOW}File:${NC} firestore.indexes.json"
echo -e "${YELLOW}Total Indexes:${NC} 26 composite + 2 field overrides"
echo ""

# Check if firestore.indexes.json exists
if [ ! -f "firestore.indexes.json" ]; then
    echo -e "${RED}Error: firestore.indexes.json not found${NC}"
    exit 1
fi

# Validate JSON syntax
echo -e "${BLUE}1. Validating JSON syntax...${NC}"
if python3 -m json.tool firestore.indexes.json > /dev/null 2>&1; then
    echo -e "${GREEN}✓ JSON is valid${NC}"
else
    echo -e "${RED}✗ JSON is invalid${NC}"
    exit 1
fi

# Check Firebase CLI
echo ""
echo -e "${BLUE}2. Checking Firebase CLI...${NC}"
if ! command -v firebase &> /dev/null; then
    echo -e "${RED}✗ Firebase CLI not found${NC}"
    echo "Install: npm install -g firebase-tools"
    exit 1
fi
echo -e "${GREEN}✓ Firebase CLI found ($(firebase --version))${NC}"

# Check authentication
echo ""
echo -e "${BLUE}3. Checking authentication...${NC}"
if firebase projects:list --project "$PROJECT" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Authenticated${NC}"
else
    echo -e "${YELLOW}⚠ Not authenticated${NC}"
    echo ""
    echo "Please run: firebase login --reauth"
    echo "Then run this script again."
    exit 1
fi

# Confirm deployment
echo ""
echo -e "${YELLOW}=== READY TO DEPLOY ===${NC}"
echo ""
echo "This will deploy 26 composite indexes to: $PROJECT"
echo ""
echo "New indexes to be created:"
echo "  1. eventTypeId + assignedUserId + createdAt"
echo "  2. eventTypeId + completedAt"
echo "  3. eventTypeId + healthIssueTypeId + createdAt"
echo "  4. recordId + eventTypeId + createdAt"
echo "  5. eventTypeId + priorityId + createdAt"
echo ""
echo "Estimated time: 5-30 minutes (indexes build in background)"
echo "Cost impact: Negligible (< $0.01/month)"
echo ""
read -p "Continue with deployment? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Deployment cancelled${NC}"
    exit 0
fi

# Deploy indexes
echo ""
echo -e "${BLUE}4. Deploying indexes...${NC}"
if firebase deploy --only firestore:indexes --project "$PROJECT"; then
    echo -e "${GREEN}✓ Deployment initiated successfully${NC}"
else
    echo -e "${RED}✗ Deployment failed${NC}"
    echo "Check firebase-debug.log for details"
    exit 1
fi

# Show next steps
echo ""
echo -e "${GREEN}=== DEPLOYMENT INITIATED ===${NC}"
echo ""
echo "Indexes are now building in the background (5-30 minutes)."
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo ""
echo "1. Monitor index build status:"
echo "   firebase firestore:indexes --project $PROJECT"
echo ""
echo "2. Check Firebase Console:"
echo "   https://console.firebase.google.com/project/$PROJECT/firestore/indexes"
echo ""
echo "3. Wait for all indexes to show 'Enabled' status"
echo ""
echo "4. Test in app:"
echo "   - Open ObservationsSpreadsheet"
echo "   - Open HusbandryTasksSpreadsheet"
echo "   - Verify fast loading (<1 second)"
echo ""
echo "5. Check for warnings:"
echo "   firebase functions:log --project $PROJECT | grep -i index"
echo ""
echo -e "${GREEN}Deployment script complete!${NC}"









