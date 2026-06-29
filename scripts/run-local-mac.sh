#!/usr/bin/env bash
# Build, test, run, and tail logs for the local macOS app.
# This script is intentionally separate from release/CI flows.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA="$ROOT/.derivedData/local-mac"
SWIFTPM_SCRATCH="$DERIVED_DATA/swiftpm"
LOCAL_CACHE="$DERIVED_DATA/cache"
PROJECT="$ROOT/TimelogMac.xcodeproj"
SCHEME="TimelogMac"
CONFIGURATION="Debug"
APP_PATH="$DERIVED_DATA/Build/Products/$CONFIGURATION/Timelog.app"
EXECUTABLE="$APP_PATH/Contents/MacOS/Timelog"

RUN_TESTS=true
RUN_BUILD=true
STREAM_LOGS=true
RESTART_EXISTING=false
LAUNCH_APP=true

usage() {
  cat <<'EOF'
Usage: scripts/run-local-mac.sh [options]

Builds and runs the local macOS Timelog app from terminal.

Options:
  --skip-tests        Do not run TimelogCore swift tests first.
  --skip-build        Run the existing local build from .derivedData/local-mac.
  --build-only        Run tests/build, then stop before launching the app.
  --test-only         Run tests only.
  --no-logs           Do not stream macOS unified logs.
  --restart           Quit any running Timelog process before launching.
  -h, --help          Show this help.

Examples:
  scripts/run-local-mac.sh
  scripts/run-local-mac.sh --skip-tests
  scripts/run-local-mac.sh --restart
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-tests) RUN_TESTS=false ;;
    --skip-build) RUN_BUILD=false ;;
    --build-only) LAUNCH_APP=false ;;
    --test-only) RUN_BUILD=false; LAUNCH_APP=false; STREAM_LOGS=false ;;
    --no-logs) STREAM_LOGS=false ;;
    --restart) RESTART_EXISTING=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
  shift
done

cleanup() {
  if [[ -n "${LOG_PID:-}" ]]; then
    kill "$LOG_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

cd "$ROOT"
mkdir -p "$SWIFTPM_SCRATCH" "$LOCAL_CACHE/clang-module-cache"

export XDG_CACHE_HOME="$LOCAL_CACHE"
export CLANG_MODULE_CACHE_PATH="$LOCAL_CACHE/clang-module-cache"

if "$RUN_TESTS"; then
  echo "==> Running TimelogCore tests"
  (cd "$ROOT/TimelogCore" && swift test --scratch-path "$SWIFTPM_SCRATCH")
fi

if "$RUN_BUILD"; then
  echo "==> Building $SCHEME ($CONFIGURATION)"
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DATA" \
    build
fi

if [[ ! -x "$EXECUTABLE" ]]; then
  if ! "$LAUNCH_APP"; then
    exit 0
  fi
  echo "App executable not found: $EXECUTABLE" >&2
  echo "Run without --skip-build first." >&2
  exit 1
fi

if ! "$LAUNCH_APP"; then
  echo "==> Build available at $APP_PATH"
  exit 0
fi

if "$RESTART_EXISTING"; then
  echo "==> Stopping existing Timelog processes"
  pkill -x Timelog 2>/dev/null || true
fi

if "$STREAM_LOGS"; then
  echo "==> Streaming system logs for process Timelog"
  log stream --style compact --predicate 'process == "Timelog"' &
  LOG_PID=$!
fi

echo "==> Launching $APP_PATH"
echo "==> Press Ctrl-C to stop the terminal session. If the app keeps running, close it normally or rerun with --restart."
"$EXECUTABLE"
