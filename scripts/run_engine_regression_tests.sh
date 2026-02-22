#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT_DIR/App/PHTV.xcodeproj"

xcodebuild \
  -project "$PROJECT" \
  -scheme PHTV \
  -destination 'platform=macOS,arch=arm64' \
  test \
  2>&1 | grep -E "Test Suite|Test Case|passed|failed|\*\* TEST"
