# PHTV Architecture

## Tổng quan

PHTV là bộ gõ tiếng Việt cho macOS, xây dựng **100% bằng Swift**. Engine xử lý tiếng Việt đã được port hoàn toàn sang Swift, không còn phụ thuộc C/C++.

## Cấu trúc thư mục

```text
App/PHTV/
├── App/                      # AppDelegate và vòng đời ứng dụng
├── Engine/                   # Engine xử lý tiếng Việt (Swift) + C bridge header
├── Input/                    # EventTap, Hotkey, xử lý phím đầu vào
├── Context/                  # App context, Spotlight detection, Smart Switch
├── System/                   # Permission, TCC, Safe Mode, binary integrity
├── Manager/                  # PHTVManager (public API + extensions)
├── Data/                     # Persistence, API clients, database
├── Models/                   # Value types và domain models
├── Resources/                # Từ điển, localization, assets
├── Services/                 # Business logic độc lập với UI
├── State/                    # Observable state objects (SwiftUI)
├── UI/                       # SwiftUI views và components
└── Utilities/                # Tiện ích dùng chung (logger, cache, constants)

App/Tests/                    # Engine regression tests (XCTest)
scripts/tools/                # Build-time tools (generate_dict_binary.swift, etc.)
```

## Luồng xử lý sự kiện

```
CGEventTap (main run loop)
    └─► Input/PHTVEventCallbackService
            ├─► Context/PHTVEventContextBridgeService  (AX context)
            ├─► Input/PHTVHotkeyService                (hotkey check)
            ├─► Engine/PHTVEngineCore (vKeyHandleEvent) (xử lý tiếng Việt)
            └─► Input/PHTVCharacterOutputService        (commit kết quả)
```

## Các lớp kiến trúc

### Engine/
Engine xử lý tiếng Việt viết bằng Swift. Nhận keycode và trả về chuỗi kết quả. Runtime state được quản lý bởi `PHTVEngineRuntimeFacade`. Giao tiếp với C bridge qua `PHTVEngineCBridge.inc`.

- `PHTVEngineCore.swift` — Logic xử lý key event, tone/mark/session
- `PHTVEngineSessionService.swift` — Khởi động engine (`boot()`), quản lý session
- `PHTVEngineDataBridge.swift` — Đọc kết quả xử lý từ engine
- `PHTVEngineRuntimeFacade.swift` — Facade cho runtime state
- `PHTVEngineStartupDataService.swift` — Load startup data từ UserDefaults
- `PHTVDictionaryTrieBridge.swift` — Dictionary trie (English/Vietnamese)
- `PHTVAutoEnglishRestoreBridge.swift` — Auto-English restore detector
- `PHTVEngineCBridge.inc` — C bridge header (Swift bridging header)

### Input/
- `PHTVEventTapService.swift` — Tạo, bật, tắt CGEventTap
- `PHTVEventCallbackService.swift` — Callback chính xử lý key event
- `PHTVEventTapHealthService.swift` — Giám sát và tái tạo tap khi cần
- `PHTVCharacterOutputService.swift` — Commit chuỗi ra ứng dụng đích
- `PHTVKeyEventSenderService.swift` — Gửi CGEvent key
- `PHTVSendSequenceService.swift` — Gửi từng ký tự theo thứ tự
- `PHTVInputStrategyService.swift` — Chọn chiến lược output (AX vs CGEvent)
- `PHTVTimingService.swift` — Điều chỉnh timing delay
- `PHTVHotkeyService.swift` — Xử lý hotkey chuyển ngôn ngữ
- `PHTVInputSourceLanguageService.swift` — Phát hiện ngôn ngữ input source
- `PHTVLayoutCompatibilityService.swift` — Hỗ trợ Dvorak, Colemak, v.v.

### Context/
- `PHTVEventContextBridgeService.swift` — Lấy AX context của cửa sổ đang focus
- `PHTVAppContextService.swift` — Bundle ID, smart switch context
- `PHTVAppDetectionService.swift` — Nhận dạng loại ứng dụng
- `PHTVSpotlightDetectionService.swift` — Phát hiện Spotlight đang mở
- `PHTVSmartSwitchRuntimeService.swift` — Smart Switch state transitions
- `PHTVSmartSwitchPersistenceService.swift` — Lưu trữ Smart Switch state
- `PHTVSmartSwitchBridgeService.swift` — Bridge cho Smart Switch

### System/
- `PHTVPermissionService.swift` — Quản lý Accessibility permission
- `PHTVTCCMaintenanceService.swift` / `PHTVTCCNotificationService.swift` — TCC
- `PHTVSafeModeStartupService.swift` — Khởi động Safe Mode
- `PHTVBinaryIntegrityService.swift` — Kiểm tra tính toàn vẹn binary
- `PHTVCacheStateService.swift` — Cache state
- `PHTVConvertToolTextConversionService.swift` — Convert bảng mã
- `PHTVAccessibilityService.swift` — CGAccessibility / AX API
- `PHTVCliProfileService.swift` — CLI profile (Claude Code patch)

### Manager/
`PHTVManager` là public API cho AppDelegate và Settings. Chia thành các extension:
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

1. **100% Swift** — Không còn C/C++ source trong app target. C bridge header (`PHTVEngineCBridge.inc`) chỉ khai báo API, implementation là Swift.
2. **Engine không phụ thuộc platform.** Swift gọi qua C bridge (`phtvEngine*`, `phtvRuntime*`, `phtvDictionary*`) để giữ ABI ổn định.
3. **`@MainActor`** trên `AppDelegate` và các service chạy trên main thread.
4. **`MainActor.assumeIsolated`** dùng trong EventTap callback (tap chạy trên main run loop).
5. **`nonisolated(unsafe)`** cho static vars trong các service không có actor isolation.
6. **Xcode tự phát hiện file** qua `PBXFileSystemSynchronizedRootGroup` — di chuyển file trong filesystem là đủ, không cần sửa `.xcodeproj`.

## Swift Bridge Config

```text
SWIFT_OBJC_BRIDGING_HEADER = PHTV/Engine/PHTVEngineCBridge.inc
HEADER_SEARCH_PATHS = $(SRCROOT)/PHTV/Engine
```

## Build

```bash
# Mở project
open App/PHTV.xcodeproj

# Build từ command line
xcodebuild -project App/PHTV.xcodeproj -scheme PHTV -destination 'platform=macOS' build

# Chạy regression tests
xcodebuild -project App/PHTV.xcodeproj -scheme PHTV -configuration Debug -destination 'platform=macOS' test -only-testing:PHEngineTests/EngineRegressionTests
```

## Migration Status

Engine đã được port **hoàn toàn sang Swift**. Không còn file `.cpp`/`.cc`/`.h`/`.hpp` trong app target. Xem lịch sử migration chi tiết tại [ENGINE_SWIFT_MIGRATION.md](ENGINE_SWIFT_MIGRATION.md).
