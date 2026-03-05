#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 5 || $# -gt 6 ]]; then
  echo "Usage: $0 <artifact-path> <label> <api-key-path> <api-key-id> <issuer-id> [staple-target]" >&2
  exit 64
fi

ARTIFACT_PATH="$1"
LABEL="$2"
API_KEY_PATH="$3"
API_KEY_ID="$4"
ISSUER_ID="$5"
STAPLE_TARGET="${6:-}"

if [[ ! -e "$ARTIFACT_PATH" ]]; then
  echo "ERROR [$LABEL] Artifact not found: $ARTIFACT_PATH" >&2
  exit 1
fi

if [[ ! -f "$API_KEY_PATH" ]]; then
  echo "ERROR [$LABEL] Notary API key file not found: $API_KEY_PATH" >&2
  exit 1
fi

echo "INFO  [$LABEL] Submitting artifact for notarization: $ARTIFACT_PATH"
SUBMISSION_OUTPUT="$(
  xcrun notarytool submit "$ARTIFACT_PATH" \
    --key "$API_KEY_PATH" \
    --key-id "$API_KEY_ID" \
    --issuer "$ISSUER_ID" \
    --wait \
    --output-format json
)"

STATUS="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("status",""))' <<< "$SUBMISSION_OUTPUT")"
SUBMISSION_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("id",""))' <<< "$SUBMISSION_OUTPUT")"

if [[ "$STATUS" != "Accepted" ]]; then
  echo "ERROR [$LABEL] Notarization failed (status: ${STATUS:-unknown})" >&2
  if [[ -n "$SUBMISSION_ID" ]]; then
    echo "INFO  [$LABEL] Fetching notarization log for submission: $SUBMISSION_ID"
    xcrun notarytool log "$SUBMISSION_ID" \
      --key "$API_KEY_PATH" \
      --key-id "$API_KEY_ID" \
      --issuer "$ISSUER_ID" || true
  fi
  exit 1
fi

echo "OK    [$LABEL] Notarization accepted (submission id: $SUBMISSION_ID)"

if [[ -z "$STAPLE_TARGET" ]]; then
  exit 0
fi

if [[ ! -e "$STAPLE_TARGET" ]]; then
  echo "ERROR [$LABEL] Staple target not found: $STAPLE_TARGET" >&2
  exit 1
fi

echo "INFO  [$LABEL] Stapling notarization ticket to: $STAPLE_TARGET"
xcrun stapler staple -v "$STAPLE_TARGET"

echo "INFO  [$LABEL] Validating stapled ticket..."
xcrun stapler validate -v "$STAPLE_TARGET"

if command -v spctl >/dev/null 2>&1; then
  if [[ -d "$STAPLE_TARGET" && "$STAPLE_TARGET" == *.app ]]; then
    echo "INFO  [$LABEL] Assessing stapled app with Gatekeeper..."
    spctl --assess --type execute --verbose=4 "$STAPLE_TARGET"
  elif [[ -f "$STAPLE_TARGET" && "$STAPLE_TARGET" == *.dmg ]]; then
    echo "INFO  [$LABEL] Assessing stapled DMG with Gatekeeper..."
    spctl --assess --type open --verbose=4 "$STAPLE_TARGET"
  fi
fi

echo "OK    [$LABEL] Notarization and stapling completed"
