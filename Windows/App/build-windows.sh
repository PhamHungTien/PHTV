#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$ROOT_DIR/PHTV.Windows.csproj"
OUT_BASE="$ROOT_DIR/publish"

RUNTIME="${1:-win-x64}"
CONFIG="${2:-Release}"
SELF_CONTAINED="${3:-true}"

mkdir -p "$OUT_BASE"
rm -rf "$OUT_BASE/$RUNTIME"
mkdir -p "$OUT_BASE/$RUNTIME"

dotnet restore "$PROJECT" -r "$RUNTIME"

dotnet publish "$PROJECT" \
  -c "$CONFIG" \
  -r "$RUNTIME" \
  --no-restore \
  --self-contained "$SELF_CONTAINED" \
  -p:PublishSingleFile=true \
  -p:EnableCompressionInSingleFile=true \
  -p:IncludeNativeLibrariesForSelfExtract=true \
  -p:DebugSymbols=false \
  -p:DebugType=None \
  -o "$OUT_BASE/$RUNTIME"

SOURCE_EXE="$OUT_BASE/$RUNTIME/PHTV.Windows.exe"
TARGET_EXE="$OUT_BASE/$RUNTIME/PHTV.exe"
if [[ -f "$SOURCE_EXE" ]]; then
  mv -f "$SOURCE_EXE" "$TARGET_EXE"
fi

if [[ ! -f "$TARGET_EXE" ]]; then
  echo "Publish failed: PHTV.exe not found."
  exit 1
fi

EXE_SIZE_BYTES="$(wc -c < "$TARGET_EXE" | tr -d ' ')"
if [[ "${EXE_SIZE_BYTES:-0}" -lt 10000000 ]]; then
  echo "Publish failed: PHTV.exe is unexpectedly small (${EXE_SIZE_BYTES} bytes)."
  exit 1
fi

echo "Published to $OUT_BASE/$RUNTIME"
