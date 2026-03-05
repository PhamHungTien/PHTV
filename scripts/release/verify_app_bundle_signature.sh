#!/usr/bin/env bash
set -euo pipefail

REQUIRE_NOTARIZED_TICKET="${REQUIRE_NOTARIZED_TICKET:-0}"

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <path-to-app-bundle> [label]" >&2
  exit 64
fi

APP_PATH="$1"
LABEL="${2:-$(basename "$APP_PATH")}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "ERROR [$LABEL] App bundle not found: $APP_PATH" >&2
  exit 1
fi

INFO_PLIST="$APP_PATH/Contents/Info.plist"
if [[ ! -f "$INFO_PLIST" ]]; then
  echo "ERROR [$LABEL] Missing Info.plist at $INFO_PLIST (MissingPlist)" >&2
  exit 1
fi

CF_BUNDLE_IDENTIFIER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$INFO_PLIST" 2>/dev/null || true)
CF_BUNDLE_EXECUTABLE=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$INFO_PLIST" 2>/dev/null || true)

if [[ -z "$CF_BUNDLE_IDENTIFIER" ]]; then
  echo "ERROR [$LABEL] CFBundleIdentifier is missing from Info.plist" >&2
  exit 1
fi

if [[ -z "$CF_BUNDLE_EXECUTABLE" ]]; then
  echo "ERROR [$LABEL] CFBundleExecutable is missing from Info.plist" >&2
  exit 1
fi

EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/$CF_BUNDLE_EXECUTABLE"
if [[ ! -f "$EXECUTABLE_PATH" ]]; then
  echo "ERROR [$LABEL] Executable not found at $EXECUTABLE_PATH" >&2
  exit 1
fi

echo "INFO  [$LABEL] Validating Info.plist..."
plutil -lint "$INFO_PLIST"
echo "OK    [$LABEL] Bundle identifier: $CF_BUNDLE_IDENTIFIER"
echo "OK    [$LABEL] Executable: $CF_BUNDLE_EXECUTABLE"

echo "INFO  [$LABEL] Dumping bundle signature metadata..."
codesign -dv --verbose=4 "$APP_PATH" 2>&1 | sed 's/^/    /'

echo "INFO  [$LABEL] Verifying bundle code signature..."
codesign --verify --deep --strict --verbose=4 "$APP_PATH"

echo "INFO  [$LABEL] Verifying main executable signature..."
codesign --verify --strict --verbose=4 "$EXECUTABLE_PATH"

if command -v spctl >/dev/null 2>&1; then
  echo "INFO  [$LABEL] Assessing Gatekeeper status..."
  if ! spctl --assess --type execute --verbose=4 "$APP_PATH"; then
    echo "WARN  [$LABEL] Gatekeeper assessment failed in CI environment"
  fi
fi

if command -v xcrun >/dev/null 2>&1; then
  echo "INFO  [$LABEL] Validating stapled notarization ticket..."
  if xcrun stapler validate -v "$APP_PATH"; then
    echo "OK    [$LABEL] Stapled notarization ticket is valid"
  elif [[ "$REQUIRE_NOTARIZED_TICKET" == "1" ]]; then
    echo "ERROR [$LABEL] Missing or invalid stapled notarization ticket" >&2
    exit 1
  else
    echo "WARN  [$LABEL] Stapled notarization ticket not found (allowed in this stage)"
  fi
fi

echo "OK    [$LABEL] Signature validation completed successfully"
