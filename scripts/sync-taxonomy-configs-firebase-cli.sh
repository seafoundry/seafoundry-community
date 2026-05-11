#!/bin/bash
# Sync taxonomy configs for all organizations using Firebase CLI
# 
# This script uses Firebase CLI authentication and queries Firestore
# to get all organization IDs, then runs the sync script.
#
# Usage:
#   ./scripts/sync-taxonomy-configs-firebase-cli.sh [--updatedBy=<userId>]
#   npm run sync:taxonomy-configs:firebase-cli -- --updatedBy=<userId>

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
UPDATED_BY=""
for arg in "$@"; do
  if [[ $arg == --updatedBy=* ]]; then
    UPDATED_BY="${arg#*=}"
  fi
done

# If no updatedBy provided, use system user
if [ -z "$UPDATED_BY" ]; then
  UPDATED_BY="${USER:-${USERNAME:-cli_sync}}"
fi

echo -e "${BLUE}🌊 Syncing taxonomy configs for all organizations using Firebase CLI${NC}"
echo "================================================================================"
echo ""

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo -e "${RED}❌ Firebase CLI not found${NC}"
    echo "Please install it: npm install -g firebase-tools"
    exit 1
fi

echo -e "${GREEN}✓ Firebase CLI found ($(firebase --version))${NC}"

# Check if user is authenticated
echo -e "\n${BLUE}Checking Firebase authentication...${NC}"
if ! firebase projects:list &> /dev/null; then
    echo -e "${YELLOW}⚠️  Not authenticated. Please run: firebase login${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Authenticated with Firebase${NC}"

# Set project to seafoundryapp
PROJECT_ID="seafoundryapp"
echo -e "\n${BLUE}Setting Firebase project to: $PROJECT_ID${NC}"
firebase use "$PROJECT_ID" || {
    echo -e "${RED}❌ Failed to set project to $PROJECT_ID${NC}"
    echo "Please ensure you have access to this project and run: firebase use $PROJECT_ID"
    exit 1
}

echo -e "${GREEN}✓ Using project: $PROJECT_ID${NC}"

# Note: Taxonomy configs are global defaults shared across all organizations
# The sync will update the global taxonomy_overrides collection that all orgs use
echo -e "\n${BLUE}ℹ️  Note: Taxonomy configs are global defaults shared across all organizations${NC}"
echo -e "   The sync will update the global taxonomy_overrides collection."
echo ""

# Build sync command (Node + Firebase Admin, no Flutter required)
SYNC_CMD="node scripts/sync_taxonomy_configs.js --updatedBy=$UPDATED_BY"

echo -e "${BLUE}🔄 Running taxonomy config sync...${NC}"
echo -e "   Command: ${SYNC_CMD}"
echo -e "   Updated by: ${UPDATED_BY}"
echo ""

# Execute the sync script
if eval "$SYNC_CMD"; then
    echo ""
    echo -e "${GREEN}✨ Done! Taxonomy configs synced for all organizations.${NC}"
    echo -e "   Note: Taxonomy configs are global defaults shared across all orgs."
else
    echo ""
    echo -e "${RED}❌ Error running sync script${NC}"
    exit 1
fi
