#!/bin/bash
# Script to review all skipped integration tests
# Usage: ./review_skipped_tests.sh

echo "========================================"
echo "Integration Test Skip Status Review"
echo "========================================"
echo ""

for file in integration_test/dialogs/*_test.dart; do
  echo "=== $(basename $file) ==="
  grep -n "skip:" "$file" | head -20
  echo ""
done

echo "========================================"
echo "Summary"
echo "========================================"
echo ""
echo "Total dialog test files: $(find integration_test/dialogs -name "*_test.dart" -type f | wc -l | xargs)"
echo "Tests with skip flags: $(grep -r "skip:" integration_test/dialogs/*.dart 2>/dev/null | wc -l | xargs)"
