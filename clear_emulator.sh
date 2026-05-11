#!/bin/bash
# Script to clear Firebase emulator data
# Usage: ./clear_emulator.sh

curl -X DELETE "http://localhost:8080/emulator/v1/projects/seafoundryapp/databases/(default)/documents" 2>&1 | head -5
echo "Emulator data cleared"
