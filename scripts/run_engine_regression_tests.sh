#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build"
BIN="$BUILD_DIR/engine_regression_tests"

mkdir -p "$BUILD_DIR"

clang++ \
  -std=c++17 \
  -O2 \
  -Wno-deprecated-declarations \
  -I"$ROOT_DIR/macOS/PHTV/Core/Engine" \
  -I"$ROOT_DIR/macOS/PHTV/Core" \
  "$ROOT_DIR/tests/engine/EnglishWordDetectorFallback.cpp" \
  "$ROOT_DIR/macOS/PHTV/Core/Engine/Engine.cpp" \
  "$ROOT_DIR/tests/engine/EngineRegressionTests.cpp" \
  -o "$BIN"

"$BIN" \
  "$ROOT_DIR/macOS/PHTV/Resources/Dictionaries/en_dict.bin" \
  "$ROOT_DIR/macOS/PHTV/Resources/Dictionaries/vi_dict.bin"
