#!/bin/bash

# Test runner script for SeaFoundry comprehensive test suite

set -e

export FLUTTER_SKIP_UPDATE_CHECK=1
export FLUTTER_SUPPRESS_ANALYTICS=1
export FLUTTER_ALREADY_UPDATING=1

echo "🧪 Starting SeaFoundry Test Suite"
echo "=================================="
echo "Note: Commands are sharded so each flutter test run stays below Codex CLI's 6-minute limit."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Optionally trigger Codex network approval upfront by setting ALLOW_NETWORK=1
if [ "${ALLOW_NETWORK:-0}" = "1" ]; then
    echo -e "${YELLOW}Requesting network access before running tests…${NC}"
    ./scripts/request_network_access.sh || true
fi

# Function to run tests with category
run_tests() {
    local category=$1
    local path=$2
    local description=$3

    echo -e "\n${YELLOW}Running $category Tests${NC}"
    echo "Description: $description"
    echo "Path: $path"

    if [ -d "$path" ] && [ "$(ls -A $path 2>/dev/null)" ]; then
        flutter test --concurrency=1 $path
        echo -e "${GREEN}✅ $category tests completed${NC}"
    else
        echo -e "${YELLOW}⚠️  No $category tests found (directory empty or doesn't exist)${NC}"
    fi
}

# Clean and get dependencies
echo "📦 Getting dependencies..."
flutter clean
flutter pub get

# Generate mocks if needed
echo "🏭 Generating mocks..."
flutter packages pub run build_runner build --delete-conflicting-outputs || true

echo -e "\n🎯 Test Execution Plan:"
echo "1. Unit Tests - Core business logic"
echo "2. Widget Tests - UI components"
echo "3. Integration Tests - E2E flows"

# Run different test categories
run_tests "Unit" "test/unit/" "Testing core business logic, repositories, models, and form validation"

run_tests "Widget" "test/widget/" "Testing UI components, dialogs, and widget interactions"

run_tests "Integration" "integration_test/" "Testing end-to-end user flows and dialog interactions"

# Generate coverage report
if [ "${SKIP_COVERAGE}" = "1" ]; then
    echo -e "\n${YELLOW}⏭️  Coverage generation skipped (SKIP_COVERAGE=1)${NC}"
else
    echo -e "\n📊 Generating test coverage..."
    flutter test --coverage
    if [ -f "coverage/lcov.info" ]; then
        echo -e "${GREEN}✅ Coverage report generated at coverage/lcov.info${NC}"
    else
        echo -e "${YELLOW}⚠️  Coverage report not generated${NC}"
    fi
fi

echo -e "\n${GREEN}🎉 Test suite execution completed!${NC}"
echo "=================================="
