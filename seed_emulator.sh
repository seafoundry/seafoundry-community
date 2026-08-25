#!/bin/bash
# Script to seed Firebase emulator with test data
# Usage: ./seed_emulator.sh

export FIRESTORE_EMULATOR_HOST="${FIRESTORE_EMULATOR_HOST:-localhost:58080}"
export FIREBASE_AUTH_EMULATOR_HOST="${FIREBASE_AUTH_EMULATOR_HOST:-localhost:9555}"
node scripts/seed-emulator.js
