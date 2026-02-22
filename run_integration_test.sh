#!/bin/bash
# Script to run a single integration test file with proper configuration
# Usage: ./run_integration_test.sh <test_file> [--kill-after SECONDS] [--device DEVICE_ID]
# Example: ./run_integration_test.sh integration_test/navigation_test.dart
# Example: ./run_integration_test.sh integration_test/navigation_test.dart --kill-after 90
# Example: ./run_integration_test.sh integration_test/navigation_test.dart --device "iPhone 16 Pro"
# Set DEFAULT_INTEGRATION_DEVICE=chrome (or macos/ios/android) to control the default target.

KILL_AFTER=""
TEST_FILE=""
DEVICE_ID=""
DEFAULT_DEVICE="${DEFAULT_INTEGRATION_DEVICE:-chrome}"

export FLUTTER_SKIP_UPDATE_CHECK=1
export FLUTTER_SUPPRESS_ANALYTICS=1
export FLUTTER_ALREADY_UPDATING=1

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --kill-after)
      KILL_AFTER="$2"
      shift 2
      ;;
    --device)
      DEVICE_ID="$2"
      shift 2
      ;;
    *)
      TEST_FILE="$1"
      shift
      ;;
  esac
done

if [ -z "$TEST_FILE" ]; then
  echo "Usage: ./run_integration_test.sh <test_file> [--kill-after SECONDS] [--device DEVICE_ID]"
  echo "Example: ./run_integration_test.sh integration_test/navigation_test.dart"
  echo "Example: ./run_integration_test.sh integration_test/navigation_test.dart --kill-after 90"
  echo "Example: ./run_integration_test.sh integration_test/navigation_test.dart --device \"iPhone 16 Pro\""
  exit 1
fi

# Optionally request Codex network permission upfront
if [ "${ALLOW_NETWORK:-0}" = "1" ]; then
  echo "Requesting network access before launching integration test..."
  ./scripts/request_network_access.sh || true
fi

# Build flutter test command
FLUTTER_CMD="flutter test \"$TEST_FILE\" --dart-define=INTEGRATION_TEST=true"

# Add device if specified, otherwise fall back to DEFAULT_DEVICE to avoid
# platform-specific setup surprises (e.g., CocoaPods on macOS).
if [ -n "$DEVICE_ID" ]; then
  FLUTTER_CMD="$FLUTTER_CMD -d \"$DEVICE_ID\""
elif [ -n "$DEFAULT_DEVICE" ]; then
  FLUTTER_CMD="$FLUTTER_CMD -d \"$DEFAULT_DEVICE\""
fi

if [ -n "$KILL_AFTER" ]; then
  # Run with timeout
  eval $FLUTTER_CMD &
  TEST_PID=$!

  # Wait for specified time, then kill if still running
  sleep "$KILL_AFTER"
  if ps -p $TEST_PID > /dev/null; then
    echo "Test timed out after ${KILL_AFTER}s, killing..."
    pkill -P $TEST_PID 2>/dev/null
    kill $TEST_PID 2>/dev/null
  fi
  wait $TEST_PID 2>/dev/null
else
  # Run normally
  eval $FLUTTER_CMD
fi
