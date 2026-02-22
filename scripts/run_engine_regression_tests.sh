#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT_DIR/macOS/PHTV.xcodeproj"

xcodebuild \
  -project "$PROJECT" \
  -scheme PHTV \
  -destination 'platform=macOS' \
  test \
  2>&1 | grep -E "Test Suite|Test Case|passed|failed|\*\* TEST"
