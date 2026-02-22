#!/bin/bash
# SeaFoundry Landing Page Deployment Script
# Deploys the static landing page to Firebase Hosting (seafoundry-landing site)
#
# Usage:
#   ./scripts/deploy-landing.sh [options]
#
# Options:
#   --dry-run    Show commands without executing
#   --project    Firebase project (default: seafoundryapp)
#
# Prerequisites:
#   - Firebase CLI installed: npm install -g firebase-tools
#   - Firebase login: firebase login
#   - Hosting site created: firebase hosting:sites:create seafoundry-landing

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

DRY_RUN=false
PROJECT="seafoundryapp"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true ;;
        --project) PROJECT="$2"; shift ;;
        --project=*) PROJECT="${1#*=}" ;;
        -h|--help)
            head -14 "$0" | grep "^#" | sed 's/^# //' | sed 's/^#//'
            exit 0
            ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
    esac
    shift
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
echo -e "${BLUE}SeaFoundry Landing Page Deploy${NC}"
echo -e "${YELLOW}Site:${NC} seafoundry-landing"
echo -e "${YELLOW}Project:${NC} $PROJECT"
echo ""

if ! command -v firebase &> /dev/null; then
    echo -e "${RED}Firebase CLI not found. Install: npm install -g firebase-tools${NC}"
    exit 1
fi

run_cmd "firebase deploy --only hosting:seafoundry-landing --project $PROJECT"

echo ""
echo -e "${GREEN}Landing page deployed!${NC}"
echo -e "  Preview: ${CYAN}https://seafoundry-landing.web.app${NC}"
echo ""
