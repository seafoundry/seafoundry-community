#!/bin/bash
# Script to clear Firebase emulator data
# Usage: ./clear_emulator.sh

PROJECT_ID=$(cat .firebaserc 2>/dev/null | grep -o '"default": "[^"]*"' | sed 's/"default": "\([^"]*\)"/\1/')
PROJECT_ID=${PROJECT_ID:-seafoundry-community}

curl -X DELETE "http://localhost:8080/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents" 2>&1 | head -5
echo "Emulator data cleared (project: ${PROJECT_ID})"
