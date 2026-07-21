#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="PHTV"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/.build/derived-data}"
APP_BUNDLE="$DERIVED_DATA_PATH/Build/Products/Debug/PHTV.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/PHTV"

cd "$ROOT_DIR"
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
DERIVED_DATA_PATH="$DERIVED_DATA_PATH" scripts/dev.swift build

if [[ ! -x "$APP_BINARY" ]]; then
  echo "Built app executable not found: $APP_BINARY" >&2
  exit 1
fi

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    /usr/bin/lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate 'process == "PHTV"'
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact \
      --predicate 'subsystem BEGINSWITH "com.phamhungtien.phtv"'
    ;;
  --verify|verify)
    open_app
    for _ in 1 2 3 4 5; do
      if pgrep -x "$APP_NAME" >/dev/null; then
        echo "PHTV launched successfully."
        exit 0
      fi
      sleep 1
    done
    echo "PHTV did not remain running after launch." >&2
    exit 1
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
