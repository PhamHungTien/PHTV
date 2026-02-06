# Windows Foundation

This folder contains the first production-grade foundation for Windows IME integration while reusing the shared engine in `Shared/Engine`.

## Layout

- `Runtime/`: engine global setting ownership for Windows process space.
- `Adapter/`: Win32 key mapping (`VK_*` -> internal engine key id).
- `Host/`: engine session facade and smoke executable.
- `Hook/`: low-level keyboard/mouse hook daemon (ported from OpenKey win32 processing model).
- `TSF/`: Text Services Framework TIP module (`.dll`) + register tool.
- `App/`: desktop UI app (Avalonia) ported from SwiftUI Settings structure.

## Build (Windows)

```bash
cmake -S . -B build -G Ninja
cmake --build build --target phtv_windows_console

# Build Windows UI app
dotnet build Windows/App/PHTV.Windows.csproj

# Build/publish single-file Windows app (recommended)
./Windows/build-all.sh
# output: Windows/App/publish/win-x64/PHTV.exe

# Build native daemon + smoke host
cmake --build build --target phtv_windows_console --config Release
cmake --build build --target phtv_windows_hook_daemon --config Release

# Build TSF TIP + register tool
cmake --build build --target phtv_windows_tsf --config Release
cmake --build build --target phtv_windows_tsf_register --config Release
```

## Current Status

- `Windows/App`: functional settings app (state persistence, macro/app management, import/export, bug-report workflow, startup integration).
- `Windows/App`: functional settings app + runtime bridge (ghi `runtime-config.ini`, `runtime-macros.tsv`, điều khiển daemon start/stop/restart).
- `Windows/Host` + `Windows/Runtime` + `Windows/Adapter`: native engine foundation using shared core.
- `Windows/Hook`: runtime hook daemon that applies OpenKey-style output synthesis (`SendInput`, backspace sync for VNI/Unicode Compound, macro flow).
- `Windows/TSF`: COM TIP foundation completed (`ITfTextInputProcessor`, `ITfThreadMgrEventSink`, `ITfKeyEventSink`, edit-session commit, register/unregister exports).

## Run Hook Daemon

```bash
./build/windows/Release/phtv_windows_hook_daemon.exe
```

Daemon cần chạy cùng hoặc cao hơn quyền của ứng dụng đích nếu muốn gõ trong app chạy admin.

## Runtime Files

Windows app sẽ đồng bộ runtime config cho daemon tại:

- `%LOCALAPPDATA%/PHTV/runtime-config.ini`
- `%LOCALAPPDATA%/PHTV/runtime-macros.tsv`

Có thể override đường dẫn artifact bằng biến môi trường:

- `PHTV_HOOK_DAEMON_PATH`
- `PHTV_TSF_DLL_PATH`
- `PHTV_TSF_REGISTER_TOOL_PATH`

## Register TSF TIP

```bash
# Register TIP
./build/windows/Release/phtv_windows_tsf_register.exe

# Unregister TIP
./build/windows/Release/phtv_windows_tsf_register.exe /u
```

Sau khi register, mở `Windows Language settings` và bật input source PHTV để dùng như IME system-wide. Các thao tác register/unregister cũng có trong tab `Hệ thống` của `Windows/App`.
