# PHTV Architecture

## Tổng quan

PHTV là bộ gõ tiếng Việt cho macOS, xây dựng hoàn toàn bằng Swift với lõi xử lý ngôn ngữ viết bằng C++. Kiến trúc tách biệt rõ ràng giữa engine xử lý (C++) và lớp tích hợp hệ thống (Swift).

## Cấu trúc thư mục

```text
macOS/PHTV/
├── App/                      # AppDelegate và vòng đời ứng dụng
├── Bridge/                   # Lớp tích hợp giữa engine C++ và hệ thống macOS
│   ├── Accessibility/        # CGAccessibility / AX API bridge
│   ├── CLI/                  # CLI profile service
│   ├── Context/              # App context, Spotlight detection
│   ├── Engine/               # C++ interop, engine session, startup data
│   ├── EventTap/             # CGEventTap callback, tap lifecycle, health
│   ├── Hotkey/               # Hotkey, input source, layout compatibility
│   ├── Input/                # Character output, key sender, send sequence, timing
│   ├── Manager/              # PHTVManager (public API + extensions)
│   ├── SmartSwitch/          # Smart switch logic, persistence, runtime
│   └── System/               # Permission, TCC, safe mode, binary integrity, etc.
├── Core/
│   └── Engine/               # C++ engine source (xử lý tiếng Việt)
├── Data/                     # Persistence, API clients, database
├── Models/                   # Value types và domain models
├── Resources/                # Từ điển, localization, assets
├── Services/                 # Business logic độc lập với UI
├── State/                    # Observable state objects (SwiftUI)
├── Tools/                    # Build-time tools và data generators
├── UI/                       # SwiftUI views và components
└── Utilities/                # Tiện ích dùng chung (logger, cache, constants)
```

## Luồng xử lý sự kiện

```
CGEventTap (main run loop)
    └─► Bridge/EventTap/PHTVEventCallbackService
            ├─► Bridge/Context/PHTVEventContextBridgeService  (AX context)
            ├─► Bridge/Hotkey/PHTVHotkeyService               (hotkey check)
            ├─► Core/Engine (C++ vKeyHandleEvent)             (xử lý tiếng Việt)
            └─► Bridge/Input/PHTVCharacterOutputService       (commit kết quả)
```

## Các lớp kiến trúc

### Core/Engine (C++)
Engine xử lý tiếng Việt thuần C++. Không phụ thuộc vào platform. Nhận keycode và trả về chuỗi kết quả. Runtime pointer state (`vKeyHookState*`) hiện được quản lý phía Swift facade.

### Bridge/Engine
- `PHTVEngineCxxInterop.hpp` — Wrapper inline C++ → Swift (không argument label)
- `PHTVEngineSessionService.swift` — Khởi động engine (`boot()`), quản lý session
- `PHTVEngineDataBridge.swift` — Đọc kết quả xử lý từ engine
- `PHTVEngineStartupDataService.swift` — Load startup data từ UserDefaults

### Bridge/EventTap
- `PHTVEventTapService.swift` — Tạo, bật, tắt CGEventTap
- `PHTVEventCallbackService.swift` — Callback chính (~700 dòng Swift), thay thế `PHTVCallback` cũ trong ObjC++
- `PHTVEventTapHealthService.swift` — Giám sát và tái tạo tap khi cần

### Bridge/Input
- `PHTVCharacterOutputService.swift` — Commit chuỗi ra ứng dụng đích
- `PHTVKeyEventSenderService.swift` — Gửi CGEvent key
- `PHTVSendSequenceService.swift` — Gửi từng ký tự theo thứ tự
- `PHTVInputStrategyService.swift` — Chọn chiến lược output (AX vs CGEvent)
- `PHTVTimingService.swift` — Điều chỉnh timing delay

### Bridge/Context
- `PHTVEventContextBridgeService.swift` — Lấy AX context của cửa sổ đang focus
- `PHTVAppContextService.swift` — Bundle ID, smart switch context
- `PHTVAppDetectionService.swift` — Nhận dạng loại ứng dụng
- `PHTVSpotlightDetectionService.swift` — Phát hiện Spotlight đang mở

### Bridge/Manager
`PHTVManager` là entry point ObjC cho phần còn lại của app (AppDelegate, settings). Chia thành các extension theo chức năng:
- `PHTVManager+PublicAPI` — API công khai
- `PHTVManager+RuntimeState` — Runtime state bridge
- `PHTVManager+SettingsLoading` — Load settings
- `PHTVManager+SettingsToggles` — Toggle settings
- `PHTVManager+SystemUtilities` — Tiện ích hệ thống

### App/
AppDelegate được chia thành nhiều extension:
- `AppDelegate+Lifecycle` — applicationDidFinishLaunching, terminate
- `AppDelegate+Accessibility` — AX permission flow
- `AppDelegate+InputSourceMonitoring` — Theo dõi input source
- `AppDelegate+AppMonitoring` — NSWorkspace notifications
- v.v.

### UI/
SwiftUI views. Không chứa business logic. Nhận state từ `State/` và gọi action qua `Services/`.

## Quy tắc thiết kế

1. **Engine C++ không phụ thuộc Swift/ObjC.** Mọi giao tiếp qua wrapper inline trong `PHTVEngineCxxInterop.hpp`.
2. **Không argument label cho C++ free function trong Swift.** Swift import C++ free functions dưới dạng positional.
3. **`@MainActor.assumeIsolated`** dùng trong EventTap callback (tap chạy trên main run loop).
4. **`nonisolated(unsafe)`** cho static vars trong các service không có actor isolation.
5. **Xcode tự phát hiện file** qua `PBXFileSystemSynchronizedRootGroup` — di chuyển file trong filesystem là đủ, không cần sửa `.xcodeproj`.

## Interop C++ ↔ Swift

File `Bridge/Engine/PHTVEngineCxxInterop.hpp` được import qua bridging header:

```objc
// PHTVBridgingHeader.h
#import "Bridge/Engine/PHTVEngineCxxInterop.hpp"
```

Build flag: `-cxx-interoperability-mode=default` (Swift 5.9+).

Tất cả wrapper đều là `inline` `noexcept` function, không phải class method, để Swift có thể gọi mà không cần argument label.

## Build

```bash
# Mở project
open macOS/PHTV.xcodeproj

# Build từ command line
xcodebuild -project macOS/PHTV.xcodeproj -scheme PHTV -destination 'platform=macOS,arch=arm64' build
```

## Swift Migration Status

- Smart Switch runtime đã chạy hoàn toàn bằng Swift (`Bridge/SmartSwitch/*`).
- C++ `SmartSwitchKey` đã được loại bỏ khỏi `Core/Engine`.
- Kế hoạch migrate engine còn lại sang Swift: xem `docs/ENGINE_SWIFT_MIGRATION.md`.
