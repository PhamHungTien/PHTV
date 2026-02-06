# PHTV Architecture (Cross-Platform)

## Mục tiêu

- Một codebase engine duy nhất cho tất cả nền tảng.
- Tách rõ `Engine Core` và `Platform Integration`.
- Giữ tương thích macOS hiện tại trong khi mở rộng Windows/Linux.

## Repository Layout

```text
PHTV/
├── Shared/
│   ├── Engine/        # Canonical shared engine (C/C++)
│   └── Platforms/     # Internal key-id definitions per platform
├── macOS/
│   └── PHTV/
│       ├── Core/Engine/  # Compatibility wrappers -> Shared/Engine
│       └── SystemBridge/ # macOS integration (CGEvent/AX/...) 
├── Windows/
│   ├── Runtime/       # Engine globals for Windows process
│   ├── Adapter/       # Win32 VK -> engine key-id mapping
│   ├── Host/          # Engine session facade + smoke host
│   ├── Hook/          # Low-level hook daemon (OpenKey-style runtime path)
│   ├── TSF/           # TSF COM TIP bridge + register tool
│   └── App/           # Windows desktop UI (SwiftUI-structure port)
└── Linux/
    ├── Runtime/       # Engine globals for Linux process
    ├── Adapter/       # keysym -> engine key-id mapping
    ├── Host/          # Engine session facade + smoke host
    └── IBus/          # IBus/Fcitx bridge foundation
```

## Design Rules

1. `Shared/Engine` là nguồn duy nhất của logic xử lý tiếng Việt.
2. Adapter từng nền tảng chỉ làm nhiệm vụ map key/event và commit output.
3. Runtime từng nền tảng sở hữu globals của engine (`vLanguage`, `vInputType`, ...).
4. Không fork logic engine theo từng OS.

## Build

### macOS app (current production app)

Dùng Xcode project hiện tại trong `macOS/`.

### Shared core (CMake)

macOS:

```bash
cmake -S . -B build -G Xcode
cmake --build build --target phtv_engine_shared
```

Windows/Linux (Ninja):

```bash
cmake -S . -B build -G Ninja
cmake --build build --target phtv_engine_shared
```

### Windows foundation target

```bash
cmake -S . -B build -G Ninja
cmake --build build --target phtv_windows_console
```

### Windows settings app (Avalonia)

```bash
dotnet build Windows/App/PHTV.Windows.csproj
./Windows/App/build-windows.sh win-x64 Release false
```

`Windows/App` hiện đã có đầy đủ luồng cấu hình (autosave, import/export, macro/app list management, bug-report workflow, startup integration).
`Windows/TSF` đã có COM TIP foundation (register/unregister, keystroke sink, edit-session commit). App Windows có thể điều khiển cả hook daemon lẫn TSF registration trong tab `Hệ thống`.

### Linux foundation target

```bash
cmake -S . -B build -G Ninja
cmake --build build --target phtv_linux_console
```

## Migration Note

`macOS/PHTV/Core/Engine/*` đã được chuyển thành wrappers để bảo toàn đường dẫn cũ trong Xcode và giảm rủi ro khi refactor.
