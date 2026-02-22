#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT_DIR/App/PHTV.xcodeproj"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/.build/derived-data}"
DESTINATION="${PHTV_TEST_DESTINATION:-platform=macOS}"
DEFAULTS_DOMAIN="com.phamhungtien.phtv"

# Ensure smoke tests run from a clean persisted state.
pkill -x PHTV >/dev/null 2>&1 || true
defaults delete "$DEFAULTS_DOMAIN" >/dev/null 2>&1 || true

xcodebuild \
  -project "$PROJECT" \
  -scheme PHTV \
  -configuration Debug \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -skipPackagePluginValidation \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  DEVELOPMENT_TEAM="" \
  -parallel-testing-enabled NO \
  test \
  -only-testing:PHEngineTests/HotkeyReliabilityTests

# Keep CI runners deterministic for any follow-up test step.
pkill -x PHTV >/dev/null 2>&1 || true
defaults delete "$DEFAULTS_DOMAIN" >/dev/null 2>&1 || true
