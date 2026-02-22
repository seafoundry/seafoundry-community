#!/bin/bash

# SeaFoundry Integration Test Runner
# This script starts Firebase Emulator, seeds test data, and runs integration tests

set -euo pipefail  # Exit on any error and fail on unset vars

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
EMULATOR_HOST="localhost"
EMULATOR_PORT_AUTH=9555
EMULATOR_PORT_FIRESTORE=58080
EMULATOR_PORT_STORAGE=59199
EMULATOR_UI_PORT=54001

DEFAULT_LOG_ROOT="tmp/test_logs/integration"
CUSTOM_LOG_ROOT=""
RUN_LOG_DIR=""
EMULATOR_LOG=""
SEED_LOG=""
TEST_LOG=""
EMULATOR_PID=""

TEST_TARGET=""
NO_SEED=false
KEEP_EMULATOR=false
declare -a FLUTTER_ARGS=()
REQUIRED_JAVA_VERSION=17

configure_java_from_known_locations() {
    local candidates=(
        "/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home"
        "/Library/Java/JavaVirtualMachines/temurin.jdk/Contents/Home"
        "/Library/Java/JavaVirtualMachines/temurin-25.jdk/Contents/Home"
        "/Library/Java/JavaVirtualMachines/adoptopenjdk-17.jdk/Contents/Home"
    )

    for candidate in "${candidates[@]}"; do
        if [ -x "$candidate/bin/java" ]; then
            export JAVA_HOME="$candidate"
            export PATH="$JAVA_HOME/bin:$PATH"
            return 0
        fi
    done

    return 1
}

ensure_java_runtime() {
    if ! command -v java >/dev/null 2>&1; then
        configure_java_from_known_locations || true
    fi

    local version_line version_string major
    version_line=$(java -version 2>&1 | head -n 1 || true)
    if [[ "$version_line" == *"Unable to locate a Java Runtime"* || -z "$version_line" ]]; then
        configure_java_from_known_locations || true
        version_line=$(java -version 2>&1 | head -n 1 || true)
    fi

    if [[ "$version_line" == *"Unable to locate a Java Runtime"* || -z "$version_line" ]]; then
        echo -e "${RED}❌ Java runtime not found. The Firebase emulator requires Java ${REQUIRED_JAVA_VERSION}+.${NC}"
        echo "Run: npm install  # triggers scripts/provision_java.js to install Temurin/OpenJDK"
        echo "If Temurin is already installed, export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home before rerunning."
        exit 1
    fi

    version_string=$(echo "$version_line" | sed -n 's/.*version "\(.*\)".*/\1/p')

    if [[ -z "$version_string" ]]; then
        echo -e "${RED}❌ Unable to determine Java version from: $version_line${NC}"
        exit 1
    fi

    if [[ "$version_string" == 1.* ]]; then
        major=$(echo "$version_string" | cut -d. -f2)
    else
        major=$(echo "$version_string" | cut -d. -f1)
    fi
    major=${major%%[^0-9]*}

    if [[ -z "$major" ]]; then
        echo -e "${RED}❌ Unable to parse Java major version from: $version_string${NC}"
        exit 1
    fi

    if (( major < REQUIRED_JAVA_VERSION )); then
        echo -e "${RED}❌ Java ${REQUIRED_JAVA_VERSION}+ required. Detected version $version_string.${NC}"
        echo "Install a newer runtime via: npm install  # re-runs the Java provisioner"
        exit 1
    fi

    echo -e "${GREEN}☕ Java runtime detected ($version_string).${NC}"
}
set_emulator_env() {
    export FIRESTORE_EMULATOR_HOST=$EMULATOR_HOST:$EMULATOR_PORT_FIRESTORE
    export FIREBASE_AUTH_EMULATOR_HOST=$EMULATOR_HOST:$EMULATOR_PORT_AUTH
    export FIREBASE_STORAGE_EMULATOR_HOST=$EMULATOR_HOST:$EMULATOR_PORT_STORAGE
}

initialize_logs() {
    local root="${CUSTOM_LOG_ROOT:-$DEFAULT_LOG_ROOT}"
    RUN_LOG_DIR="$root/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$RUN_LOG_DIR"

    EMULATOR_LOG="$RUN_LOG_DIR/firebase_emulator.log"
    SEED_LOG="$RUN_LOG_DIR/seed.log"
    TEST_LOG="$RUN_LOG_DIR/flutter_test.log"
}

echo -e "${BLUE}🧪 SeaFoundry Integration Test Runner${NC}"
echo "=================================="

# Function to check if port is in use
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null ; then
        return 0  # Port is in use
    else
        return 1  # Port is free
    fi
}

# Function to wait for emulator to be ready
wait_for_emulator() {
    echo -e "${YELLOW}⏳ Waiting for Firebase Emulator to be ready...${NC}"
    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if curl -s http://$EMULATOR_HOST:$EMULATOR_PORT_FIRESTORE > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Firebase Emulator is ready${NC}"
            return 0
        fi

        echo "Attempt $attempt/$max_attempts - waiting 2 seconds..."
        sleep 2
        ((attempt++))
    done

    echo -e "${RED}❌ Firebase Emulator failed to start within timeout${NC}"
    return 1
}

# Function to stop emulator
stop_emulator() {
    echo -e "${YELLOW}🛑 Stopping Firebase Emulator...${NC}"

    # Kill emulator process if running
    if [ -n "${EMULATOR_PID:-}" ]; then
        kill "$EMULATOR_PID" 2>/dev/null || true
        wait "$EMULATOR_PID" 2>/dev/null || true
        EMULATOR_PID=""
    fi

    # Kill any processes using our ports
    for port in $EMULATOR_PORT_AUTH $EMULATOR_PORT_FIRESTORE $EMULATOR_PORT_STORAGE $EMULATOR_UI_PORT; do
        if check_port $port; then
            echo "Killing process on port $port..."
            lsof -ti:$port | xargs kill -9 2>/dev/null || true
        fi
    done

    sleep 2
    echo -e "${GREEN}✅ Firebase Emulator stopped${NC}"
}

cleanup() {
    local status=$?
    trap - EXIT INT TERM
    stop_emulator
    exit $status
}

trap cleanup EXIT
trap cleanup INT TERM

# Function to start emulator
start_emulator() {
    echo -e "${BLUE}🔥 Starting Firebase Emulator...${NC}"
    echo "  ↳ Logs: $EMULATOR_LOG"

    # Check if emulator is already running
    if check_port $EMULATOR_PORT_FIRESTORE; then
        echo -e "${YELLOW}⚠️  Firebase Emulator already running, stopping it first...${NC}"
        stop_emulator
    fi

    # Start emulator in background
    firebase emulators:start --only auth,firestore,storage --project=seafoundryapp \
        > >(tee -a "$EMULATOR_LOG") \
        2> >(tee -a "$EMULATOR_LOG" >&2) &
    EMULATOR_PID=$!

    # Wait for emulator to be ready
    if ! wait_for_emulator; then
        stop_emulator
        exit 1
    fi
}

# Function to seed test data
seed_test_data() {
    echo -e "${BLUE}🌱 Seeding test data...${NC}"
    echo "  ↳ Logs: $SEED_LOG"

    # Run seeder
    if node scripts/seed-emulator.js \
        > >(tee "$SEED_LOG") \
        2> >(tee -a "$SEED_LOG" >&2); then
        echo -e "${GREEN}✅ Test data seeded successfully${NC}"
    else
        echo -e "${RED}❌ Failed to seed test data${NC}"
        echo "See $SEED_LOG for details."
        stop_emulator
        exit 1
    fi
}

# Function to run integration tests
run_tests() {
    echo -e "${BLUE}🧪 Running Integration Tests...${NC}"
    echo "  ↳ Logs: $TEST_LOG"

    # Set environment variables for Flutter
    export INTEGRATION_TEST=true

    # Run integration tests
    local target=${TEST_TARGET:-integration_test/}
    local cmd=(flutter test "$target" --dart-define=INTEGRATION_TEST=true)
    if [ ${#FLUTTER_ARGS[@]} -ne 0 ]; then
        cmd+=("${FLUTTER_ARGS[@]}")
    fi

    echo "  ↳ Command: ${cmd[*]}"

    if "${cmd[@]}" \
        > >(tee "$TEST_LOG") \
        2> >(tee -a "$TEST_LOG" >&2); then
        echo -e "${GREEN}✅ Integration tests passed${NC}"
        return 0
    else
        echo -e "${RED}❌ Integration tests failed${NC}"
        echo "See $TEST_LOG for details."
        return 1
    fi
}

# Main execution
main() {
    local test_result=0

    ensure_java_runtime

    # Check if Firebase CLI is available
    if ! command -v firebase &> /dev/null; then
        echo -e "${RED}❌ Firebase CLI not found. Please install it first:${NC}"
        echo "npm install -g firebase-tools"
        exit 1
    fi

    # Check if Flutter is available
    if ! command -v flutter &> /dev/null; then
        echo -e "${RED}❌ Flutter not found. Please install Flutter first.${NC}"
        exit 1
    fi

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-seed)
                NO_SEED=true
                ;;
            --keep-emulator)
                KEEP_EMULATOR=true
                ;;
            --log-dir)
                if [[ $# -lt 2 ]]; then
                    echo -e "${RED}❌ --log-dir requires a path${NC}"
                    exit 1
                fi
                CUSTOM_LOG_ROOT="$2"
                shift
                ;;
            --flutter-*=*)
                FLUTTER_ARGS+=("--${1#--flutter-}")
                ;;
            --flutter-*)
                local flag="--${1#--flutter-}"
                FLUTTER_ARGS+=("$flag")
                if [[ $# -gt 1 ]]; then
                    local next="$2"
                    if [[ "$next" != --* && "$next" != --flutter-* ]]; then
                        FLUTTER_ARGS+=("$next")
                        shift
                    fi
                fi
                ;;
            --help)
                echo "Usage: $0 [options] [test_target]"
                echo ""
                echo "Options:"
                echo "  --no-seed            Skip seeding test data"
                echo "  --keep-emulator      Keep emulator running after tests"
                echo "  --log-dir <path>     Directory to store log files (default: $DEFAULT_LOG_ROOT)"
                echo "  --flutter-<flag>     Forward additional flutter test flags (e.g. --flutter-verbose)"
                echo "  --help               Show this help message"
                echo ""
                echo "test_target defaults to integration_test/"
                exit 0
                ;;
            --)
                shift
                if [[ $# -gt 0 && -z "$TEST_TARGET" ]]; then
                    TEST_TARGET="$1"
                    shift
                fi
                while [[ $# -gt 0 ]]; do
                    FLUTTER_ARGS+=("$1")
                    shift
                done
                break
                ;;
            --*)
                echo -e "${RED}❌ Unknown option: $1${NC}"
                exit 1
                ;;
            *)
                if [[ -n "$TEST_TARGET" ]]; then
                    echo -e "${RED}❌ Multiple test targets provided (already set to $TEST_TARGET)${NC}"
                    exit 1
                fi
                TEST_TARGET="$1"
                ;;
        esac
        shift
    done

    initialize_logs

    echo -e "${BLUE}📋 Configuration:${NC}"
    echo "  Auth Emulator: $EMULATOR_HOST:$EMULATOR_PORT_AUTH"
    echo "  Firestore Emulator: $EMULATOR_HOST:$EMULATOR_PORT_FIRESTORE"
    echo "  Storage Emulator: $EMULATOR_HOST:$EMULATOR_PORT_STORAGE"
    echo "  UI: $EMULATOR_HOST:$EMULATOR_UI_PORT"
    echo "  Test Target: ${TEST_TARGET:-integration_test/}"
    echo "  Logs Directory: $RUN_LOG_DIR"
    echo ""

    # Start emulator
    start_emulator

    # Export emulator environment variables
    set_emulator_env

    # Seed test data (unless skipped)
    if [ "$NO_SEED" != "true" ]; then
        seed_test_data
    fi

    # Run tests
    if run_tests; then
        test_result=0
        echo -e "${GREEN}🎉 All integration tests passed!${NC}"
    else
        test_result=1
        echo -e "${RED}💥 Integration tests failed!${NC}"
    fi

    # Keep emulator running if requested
    if [ "$KEEP_EMULATOR" = "true" ]; then
        echo -e "${YELLOW}🔥 Keeping Firebase Emulator running...${NC}"
        echo "  Firestore UI: http://$EMULATOR_HOST:$EMULATOR_UI_PORT"
        echo "  Press Ctrl+C to stop"
        wait $EMULATOR_PID
    fi

    return $test_result
}

# Run main function
main "$@"
