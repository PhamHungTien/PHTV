#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$ROOT_DIR/.."
GENERATOR="${GENERATOR:-Ninja}"
TARGET_RUNTIMES="${TARGET_RUNTIMES:-win-x64}"
PUBLISH_CONFIG="${PUBLISH_CONFIG:-Release}"
SELF_CONTAINED="${SELF_CONTAINED:-true}"

GENERATOR_SAFE="$(echo "$GENERATOR" | tr ' ' '-' | tr -cd '[:alnum:]-')"
BUILD_DIR="$REPO_ROOT/build/windows-$GENERATOR_SAFE"
CMAKE_ARGS=()

if [[ "$GENERATOR" == "Ninja" ]] && ! command -v ninja >/dev/null 2>&1; then
  GENERATOR="Unix Makefiles"
  GENERATOR_SAFE="$(echo "$GENERATOR" | tr ' ' '-' | tr -cd '[:alnum:]-')"
  BUILD_DIR="$REPO_ROOT/build/windows-$GENERATOR_SAFE"
fi

if [[ "${OS:-}" != "Windows_NT" ]]; then
  if command -v x86_64-w64-mingw32-g++ >/dev/null 2>&1 && command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then
    BUILD_DIR="$REPO_ROOT/build/mingw-win-$GENERATOR_SAFE"
    CMAKE_ARGS=(
      -DCMAKE_SYSTEM_NAME=Windows
      -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc
      -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++
    )
  fi
fi

# Build native Windows foundation (shared engine + console + hook daemon)
cmake -S "$REPO_ROOT" -B "$BUILD_DIR" -G "$GENERATOR" "${CMAKE_ARGS[@]}"
cmake --build "$BUILD_DIR" --target phtv_engine_shared --config Release
cmake --build "$BUILD_DIR" --target phtv_windows_console --config Release
cmake --build "$BUILD_DIR" --target phtv_windows_hook_daemon --config Release
cmake --build "$BUILD_DIR" --target phtv_windows_tsf --config Release
cmake --build "$BUILD_DIR" --target phtv_windows_tsf_register --config Release

DAEMON_EXE="$(find "$BUILD_DIR" -type f -name phtv_windows_hook_daemon.exe | head -n 1 || true)"
TSF_DLL="$(find "$BUILD_DIR" -type f -name 'phtv_windows_tsf.dll' | head -n 1 || true)"
if [[ -z "$TSF_DLL" ]]; then
  TSF_DLL="$(find "$BUILD_DIR" -type f -name 'libphtv_windows_tsf.dll' | head -n 1 || true)"
fi
TSF_REG_EXE="$(find "$BUILD_DIR" -type f -name phtv_windows_tsf_register.exe | head -n 1 || true)"

if [[ -z "$DAEMON_EXE" || -z "$TSF_DLL" || -z "$TSF_REG_EXE" ]]; then
  echo "Missing native artifacts. Expected daemon/TSF DLL/TSF register tool." >&2
  exit 1
fi

collect_mingw_runtime_dlls() {
  local binary="$1"
  if ! command -v x86_64-w64-mingw32-objdump >/dev/null 2>&1; then
    return 0
  fi

  x86_64-w64-mingw32-objdump -p "$binary" 2>/dev/null \
    | awk '/DLL Name:/ { print $3 }' \
    | tr -d '\r' \
    | grep -E '^lib.*\.dll$' || true
}

resolve_mingw_runtime_dll_path() {
  local dll_name="$1"
  local resolved_path

  if ! command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then
    return 1
  fi

  resolved_path="$(x86_64-w64-mingw32-gcc -print-file-name="$dll_name" 2>/dev/null || true)"
  if [[ -n "$resolved_path" && "$resolved_path" != "$dll_name" && -f "$resolved_path" ]]; then
    printf '%s\n' "$resolved_path"
    return 0
  fi

  local search_line
  search_line="$(x86_64-w64-mingw32-gcc -print-search-dirs 2>/dev/null | sed -n 's/^libraries: =//p')"
  local old_ifs="$IFS"
  IFS=':'
  for search_dir in $search_line; do
    if [[ -f "$search_dir/$dll_name" ]]; then
      printf '%s\n' "$search_dir/$dll_name"
      IFS="$old_ifs"
      return 0
    fi
  done
  IFS="$old_ifs"

  local libgcc_file toolchain_bin
  libgcc_file="$(x86_64-w64-mingw32-gcc -print-libgcc-file-name 2>/dev/null || true)"
  if [[ -n "$libgcc_file" && -f "$libgcc_file" ]]; then
    toolchain_bin="$(cd "$(dirname "$libgcc_file")/../../../../x86_64-w64-mingw32/bin" 2>/dev/null && pwd || true)"
    if [[ -n "$toolchain_bin" && -f "$toolchain_bin/$dll_name" ]]; then
      printf '%s\n' "$toolchain_bin/$dll_name"
      return 0
    fi
  fi

  return 1
}

resolve_dictionary_source_path() {
  local dictionary_name="$1"
  local candidate_paths=(
    "$REPO_ROOT/Shared/Resources/Dictionaries/$dictionary_name"
    "$REPO_ROOT/macOS/PHTV/Resources/Dictionaries/$dictionary_name"
    "$ROOT_DIR/Resources/Dictionaries/$dictionary_name"
  )

  local path
  for path in "${candidate_paths[@]}"; do
    if [[ -f "$path" ]]; then
      printf '%s\n' "$path"
      return 0
    fi
  done

  return 1
}

copy_dictionary_bundle() {
  local target_dir="$1"
  local dictionary_name source_path

  for dictionary_name in en_dict.bin vi_dict.bin; do
    source_path="$(resolve_dictionary_source_path "$dictionary_name" || true)"
    if [[ -z "$source_path" || ! -f "$source_path" ]]; then
      echo "Missing dictionary file: $dictionary_name" >&2
      echo "Expected under Shared/Resources/Dictionaries or macOS/PHTV/Resources/Dictionaries." >&2
      exit 1
    fi

    cp "$source_path" "$target_dir/$dictionary_name"
  done
}

APP_NATIVE_ROOT="$ROOT_DIR/App/Native"
mkdir -p "$APP_NATIVE_ROOT/win-x64"
rm -f "$APP_NATIVE_ROOT/win-x64/phtv_windows_hook_daemon.exe" \
      "$APP_NATIVE_ROOT/win-x64/phtv_windows_tsf.dll" \
      "$APP_NATIVE_ROOT/win-x64/phtv_windows_tsf_register.exe" \
      "$APP_NATIVE_ROOT/win-x64/en_dict.bin" \
      "$APP_NATIVE_ROOT/win-x64/vi_dict.bin" \
      "$APP_NATIVE_ROOT/win-x64"/lib*.dll
cp "$DAEMON_EXE" "$APP_NATIVE_ROOT/win-x64/phtv_windows_hook_daemon.exe"
cp "$TSF_DLL" "$APP_NATIVE_ROOT/win-x64/phtv_windows_tsf.dll"
cp "$TSF_REG_EXE" "$APP_NATIVE_ROOT/win-x64/phtv_windows_tsf_register.exe"
copy_dictionary_bundle "$APP_NATIVE_ROOT/win-x64"

if command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then
  MINGW_RUNTIME_DLLS="$(
    {
      collect_mingw_runtime_dlls "$DAEMON_EXE"
      collect_mingw_runtime_dlls "$TSF_DLL"
      collect_mingw_runtime_dlls "$TSF_REG_EXE"
    } | sort -u
  )"

  while IFS= read -r runtime_dll; do
    [[ -z "$runtime_dll" ]] && continue
    runtime_dll_path="$(resolve_mingw_runtime_dll_path "$runtime_dll" || true)"
    if [[ -n "$runtime_dll_path" && -f "$runtime_dll_path" ]]; then
      cp "$runtime_dll_path" "$APP_NATIVE_ROOT/win-x64/$runtime_dll"
    fi
  done <<< "$MINGW_RUNTIME_DLLS"
fi

if [[ -n "${PHTV_ARM64_NATIVE_DIR:-}" ]]; then
  if [[ -f "${PHTV_ARM64_NATIVE_DIR}/phtv_windows_hook_daemon.exe" &&
        -f "${PHTV_ARM64_NATIVE_DIR}/phtv_windows_tsf.dll" &&
        -f "${PHTV_ARM64_NATIVE_DIR}/phtv_windows_tsf_register.exe" ]]; then
    mkdir -p "$APP_NATIVE_ROOT/win-arm64"
    rm -f "$APP_NATIVE_ROOT/win-arm64/"*
    cp "${PHTV_ARM64_NATIVE_DIR}/phtv_windows_hook_daemon.exe" "$APP_NATIVE_ROOT/win-arm64/phtv_windows_hook_daemon.exe"
    cp "${PHTV_ARM64_NATIVE_DIR}/phtv_windows_tsf.dll" "$APP_NATIVE_ROOT/win-arm64/phtv_windows_tsf.dll"
    cp "${PHTV_ARM64_NATIVE_DIR}/phtv_windows_tsf_register.exe" "$APP_NATIVE_ROOT/win-arm64/phtv_windows_tsf_register.exe"
    copy_dictionary_bundle "$APP_NATIVE_ROOT/win-arm64"
    if compgen -G "${PHTV_ARM64_NATIVE_DIR}/lib*.dll" > /dev/null; then
      cp "${PHTV_ARM64_NATIVE_DIR}"/lib*.dll "$APP_NATIVE_ROOT/win-arm64/"
    fi
  else
    echo "Ignoring PHTV_ARM64_NATIVE_DIR because required files are missing."
  fi
else
  rm -rf "$APP_NATIVE_ROOT/win-arm64"
fi

IFS=',' read -ra RUNTIMES <<< "$TARGET_RUNTIMES"
for runtime in "${RUNTIMES[@]}"; do
  runtime="${runtime//[[:space:]]/}"
  if [[ -z "$runtime" ]]; then
    continue
  fi

  if [[ "$runtime" == "win-arm64" && ! -f "$APP_NATIVE_ROOT/win-arm64/phtv_windows_hook_daemon.exe" ]]; then
    echo "Skipping win-arm64 publish: missing arm64 native artifacts (set PHTV_ARM64_NATIVE_DIR)." >&2
    continue
  fi

  "$ROOT_DIR/App/build-windows.sh" "$runtime" "$PUBLISH_CONFIG" "$SELF_CONTAINED"

  APP_EXE="$ROOT_DIR/App/publish/$runtime/PHTV.exe"
  if [[ ! -f "$APP_EXE" ]]; then
    echo "Expected output not found: $APP_EXE" >&2
    exit 1
  fi
done

echo "Done."
