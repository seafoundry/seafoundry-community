#!/bin/bash
# Development script to run the app with Firebase Emulators
# Seeds community-tier demo data for local development

set -e

echo "Starting Firebase Emulators..."

# Check if emulators are already running
EMULATORS_ALREADY_RUNNING=false
if lsof -Pi :9555 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "Firebase Emulators are already running"
    EMULATORS_ALREADY_RUNNING=true
else
    echo "Starting emulators in background..."
    firebase emulators:start --only auth,firestore,storage,functions > firebase-emulator.log 2>&1 &
    EMULATOR_PID=$!
    echo "Emulator PID: $EMULATOR_PID"

    # Wait for emulators to be ready
    echo "Waiting for emulators to be ready..."
    sleep 5

    if ! lsof -Pi :9555 -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo "Failed to start emulators. Check firebase-emulator.log for details."
        exit 1
    fi
    echo "Firebase Emulators started successfully"
fi

# Ensure seed scripts target the emulator (admin SDK uses these env vars)
export FIRESTORE_EMULATOR_HOST=localhost:58080
export FIREBASE_AUTH_EMULATOR_HOST=localhost:9555
export FIREBASE_STORAGE_EMULATOR_HOST=localhost:59199

# Seed community demo data
if [ "$EMULATORS_ALREADY_RUNNING" = false ]; then
    echo ""
    echo "Seeding community demo data..."
    node scripts/seed-demo.js --reset
    echo "Demo data seeded successfully"
fi

echo ""
echo "Starting Flutter app with emulator connection..."
echo "   Auth Emulator: http://localhost:9555"
echo "   Firestore Emulator: http://localhost:58080"
echo "   Storage Emulator: http://localhost:59199"
echo "   Functions Emulator: http://localhost:5001"
echo "   Emulator UI: http://localhost:54001"
echo ""

# Run Flutter app with emulator flag
flutter run -d chrome \
    --dart-define=USE_FIREBASE_EMULATOR=true

# Note: When you stop the Flutter app, the emulators will continue running.
# To stop emulators, run: firebase emulators:stop
# Or kill the process manually
