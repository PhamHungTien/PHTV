#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/App"
PROJECT="$APP_DIR/PHTV.xcodeproj"
SCHEME="PHTV"
DESTINATION="platform=macOS"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/.build/derived-data}"
XCODE_DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

usage() {
  cat <<'USAGE'
Usage: scripts/dev.sh <command>

Commands:
  env-check     Print the local toolchain setup used by this project
  build         Build the macOS app in Debug
  test          Run all XCTest tests
  engine-test   Run EngineRegressionTests only
  hotkey-test   Run HotkeyReliabilityTests only
  dict-check    Validate checked-in dictionary sources
  clean         Remove local DerivedData used by this script

Environment:
  DEVELOPER_DIR       Override Xcode path, defaults to /Applications/Xcode.app/Contents/Developer
  DERIVED_DATA_PATH   Override build cache path, defaults to .build/derived-data
USAGE
}

require_xcode() {
  if [[ ! -d "$XCODE_DEVELOPER_DIR" ]]; then
    cat >&2 <<EOF
Xcode developer directory not found:
  $XCODE_DEVELOPER_DIR

Install Xcode or run with:
  DEVELOPER_DIR=/path/to/Xcode.app/Contents/Developer scripts/dev.sh $COMMAND
EOF
    exit 1
  fi
}

xcodebuild_project() {
  require_xcode
  DEVELOPER_DIR="$XCODE_DEVELOPER_DIR" xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    "$@"
}

COMMAND="${1:-}"

case "$COMMAND" in
  env-check)
    require_xcode
    echo "repo: $ROOT_DIR"
    echo "xcode-select: $(xcode-select -p 2>/dev/null || true)"
    echo "DEVELOPER_DIR: $XCODE_DEVELOPER_DIR"
    DEVELOPER_DIR="$XCODE_DEVELOPER_DIR" xcodebuild -version
    DEVELOPER_DIR="$XCODE_DEVELOPER_DIR" xcrun swift --version
    echo "derived data: $DERIVED_DATA_PATH"
    ;;
  build)
    xcodebuild_project build
    ;;
  test)
    xcodebuild_project test
    ;;
  engine-test)
    xcodebuild_project test -only-testing:PHEngineTests/EngineRegressionTests
    ;;
  hotkey-test)
    xcodebuild_project test -only-testing:PHEngineTests/HotkeyReliabilityTests
    ;;
  dict-check)
    DEVELOPER_DIR="$XCODE_DEVELOPER_DIR" xcrun swift "$ROOT_DIR/scripts/tools/generate_dict_binary.swift" --strict-check-sources
    ;;
  clean)
    rm -rf "$DERIVED_DATA_PATH"
    ;;
  ""|-h|--help|help)
    usage
    ;;
  *)
    echo "Unknown command: $COMMAND" >&2
    usage >&2
    exit 2
    ;;
esac
