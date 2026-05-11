#!/bin/bash
# Proactively trigger the Codex CLI network access prompt by attempting to
# contact the Firebase emulator (and falling back to a public endpoint).
#
# Usage:
#   scripts/request_network_access.sh
#
# This script intentionally ignores connection failures because the goal is
# simply to issue a network request that the CLI can intercept and approve.

set -u

# Default emulator endpoints (match firebase_emulator_config.dart defaults)
: "${FIREBASE_AUTH_EMULATOR_HOST:=localhost:9555}"
: "${FIRESTORE_EMULATOR_HOST:=localhost:58080}"
: "${FIREBASE_STORAGE_EMULATOR_HOST:=localhost:59199}"

log_note() {
  printf '🔓 %s\n' "$1"
}

attempt_request() {
  local target="$1"

  # shellcheck disable=SC2086
  if command -v curl >/dev/null 2>&1; then
    curl --silent --show-error --max-time 2 "http://${target}/" >/dev/null 2>&1
  elif command -v python3 >/dev/null 2>&1; then
    python3 - <<PYTHON || true
import socket
host, port = "${target}".split(":")
sock = socket.socket()
sock.settimeout(2)
try:
    sock.connect((host, int(port)))
except OSError:
    pass
finally:
    sock.close()
PYTHON
  else
    # netcat/netcat-openbsd try
    nc -z "${target%:*}" "${target#*:}" >/dev/null 2>&1 || true
  fi
}

log_note "Requesting Codex network access (Firebase emulators)…"

# Try each emulator host; ignore failures but ensure we attempt a network call.
attempt_request "${FIREBASE_AUTH_EMULATOR_HOST}"
attempt_request "${FIRESTORE_EMULATOR_HOST}"
attempt_request "${FIREBASE_STORAGE_EMULATOR_HOST}"

# Fallback to a public endpoint in case emulators are disabled.
attempt_request "www.googleapis.com:443"

log_note "Network prompt (if required) should now be visible in the CLI."
