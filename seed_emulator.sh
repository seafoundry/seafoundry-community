#!/bin/bash
# Script to seed Firebase emulator with test data
# Usage: ./seed_emulator.sh

export FIRESTORE_EMULATOR_HOST=localhost:8080
node scripts/seed-emulator.js
