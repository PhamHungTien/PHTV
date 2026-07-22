# PHTV macOS Architecture

## Tổng quan

PHTV là bộ gõ tiếng Việt cho macOS, được xây dựng bằng Swift. Ứng dụng chạy như một menu bar app native, dùng CGEvent tap để nhận phím, engine Swift để xử lý tiếng Việt và Accessibility/TCC để commit chữ ổn định vào ứng dụng đích.

Đây là kiến trúc của sản phẩm macOS trong `macOS/`. Nền móng Windows được tách
riêng tại [Windows/README.md](../Windows/README.md) để không trộn TSF/WinUI với
CGEvent/SwiftUI.

Project hiện chỉ còn:

- `PHTV` — app chính.
- `PHEngineTests` — test target cho engine, runtime policy và các regression quan trọng.

Target InputMethodKit thử nghiệm đã được gỡ bỏ; PHTV không cài thêm input source riêng vào `~/Library/Input Methods`.

## Cấu trúc thư mục

```text
macOS/PHTV/
├── App/                      # AppDelegate và vòng đời ứng dụng
├── Engine/                   # Engine xử lý tiếng Việt và Swift bridge exports
├── Input/                    # EventTap, Hotkey, xử lý phím đầu vào
├── Context/                  # App context, Spotlight detection, Smart Switch
├── System/                   # Permission, TCC, Safe Mode, binary integrity
├── Manager/                  # PHTVManager (public API + extensions)
├── Data/                     # Persistence, API clients, database
├── Models/                   # Value types và domain models
├── Resources/                # Từ điển, localization, assets
├── Services/                 # Business logic độc lập với UI (ClipboardMonitor, ClipboardHotkeyManager, ...)
├── State/                    # Observable state objects (SwiftUI)
├── UI/                       # SwiftUI views và components
└── Utilities/                # Tiện ích dùng chung (logger, cache, constants)

macOS/Tests/                    # XCTest regression tests
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
Engine xử lý tiếng Việt viết bằng Swift. Nhận keycode và trả về chuỗi kết quả. Runtime state được quản lý bởi `PHTVEngineRuntimeFacade`; các entry point ổn định cho tầng runtime được khai báo trong `PHTVEngineBridgeExports.swift` và các service bridge chuyên trách.

- `PHTVEngineCore.swift` — Logic xử lý key event, tone/mark/session
- `PHTVEngineSessionService.swift` — Khởi động engine (`boot()`), quản lý session
- `PHTVEngineDataBridge.swift` — Đọc kết quả xử lý từ engine
- `PHTVEngineRuntimeFacade.swift` — Facade cho runtime state
- `PHTVEngineStartupDataService.swift` — Load startup data từ UserDefaults
- `PHTVDictionaryTrieBridge.swift` — Dictionary trie (English/Vietnamese)
- `PHTVAutoEnglishRestoreBridge.swift` — Auto-English restore detector
- `PHTVEngineBridgeExports.swift` — Entry points dùng chung giữa engine và runtime

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
- `PHTVPermissionService.swift` — Kiểm tra readiness của Accessibility, Input Monitoring và event tap
- `PHTVTCCMaintenanceService.swift` — Query/reset TCC entry, restart `tccd` khi cần
- `PHTVTCCNotificationService.swift` — Lắng nghe thay đổi TCC và kích hoạt recovery
- `PHTVSafeModeStartupService.swift` — Khởi động Safe Mode
- `PHTVBinaryIntegrityService.swift` — Kiểm tra tính toàn vẹn binary
- `PHTVCacheStateService.swift` — Cache state
- `PHTVConvertToolTextConversionService.swift` — Convert bảng mã
- `PHTVAccessibilityService.swift` — AX API, mở System Settings và guided permission repair
- `PHTVCliProfileService.swift` — CLI profile (ổn định Terminal/IDE/Claude Code)

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
- `AppDelegate+Accessibility` — Runtime permission monitoring, event tap recovery, relaunch policy
- `AppDelegate+PermissionFlow` — Điều hướng onboarding/System Settings theo quyền còn thiếu
- `AppDelegate+InputSourceMonitoring` — Theo dõi input source
- `AppDelegate+AppMonitoring` — NSWorkspace notifications
- v.v.

### UI/
SwiftUI views. Không chứa business logic. Nhận state từ `State/` và gọi action qua `Services/`.

## Runtime Permission Flow

PHTV cần đủ 2 quyền macOS trước khi tạo event tap ổn định:

1. **Accessibility** — kiểm tra bằng `AXIsProcessTrusted()` và prompt bằng `AXIsProcessTrustedWithOptions`.
2. **Input Monitoring** — kiểm tra bằng `CGPreflightListenEventAccess()` và prompt bằng `CGRequestListenEventAccess()`.

`PHTVTypingRuntimeHealthSnapshot` gom trạng thái runtime thành các phase:

- `accessibilityRequired`
- `inputMonitoringRequired`
- `waitingForEventTap`
- `relaunchPending`
- `ready`

Các phase này là nguồn sự thật cho onboarding, Settings status card, menu bar và bug report.

Khi người dùng chủ động mở quyền còn thiếu, `AppDelegate+PermissionFlow` gọi guided repair:

- `tccutil reset Accessibility <bundleID>` nếu thiếu Accessibility.
- `tccutil reset ListenEvent <bundleID>` nếu thiếu Input Monitoring.
- Invalidate permission cache và restart `tccd` khi reset thành công.
- Mở đúng pane trong System Settings.

Luồng này xử lý các case TCC bị kẹt sau khi app được cập nhật, ký lại hoặc người dùng đã bật quyền nhưng macOS vẫn trả về trạng thái Denied.

## Quy tắc thiết kế

1. **Phân lớp theo trách nhiệm** — Engine, Input, Context, System, UI và Manager được tách rõ để giới hạn phạm vi thay đổi.
2. **Bridge ổn định** — Engine giao tiếp qua các API bridge (`phtvEngine*`, `phtvRuntime*`, `phtvDictionary*`) để giữ ranh giới rõ ràng giữa các lớp.
3. **Actor ownership rõ ràng** — UI/AppDelegate dùng `@MainActor`; EventTap và background I/O chỉ hop về main actor tại ranh giới cần thiết.
4. **Locked state box** — Mọi type `@unchecked Sendable` chứa mutable state phải có cùng một `NSLock` hoặc executor bảo vệ toàn bộ lần đọc/ghi. Không thêm `@unchecked Sendable` chỉ để tắt cảnh báo Swift 6.
5. **Không có global state không bảo vệ** — repository policy không cho thêm
   `nonisolated(unsafe)`; state dùng qua actor hoặc state box có lock.
6. **Xcode tự phát hiện file** qua `PBXFileSystemSynchronizedRootGroup` cho app và test target hiện có. Khi thêm hoặc xoá target, vẫn cần cập nhật `.xcodeproj` rõ ràng.

## Dữ liệu và mạng

Đường xử lý phím, macro và dictionary chạy local. Sparkle cùng Klipy là hai ranh giới mạng chính; mọi thay đổi endpoint hoặc dữ liệu gửi đi phải cập nhật `PrivacyInfo.xcprivacy` và [PRIVACY.md](PRIVACY.md). Không log nội dung phím gõ, clipboard, macro expansion hoặc từ khóa tìm kiếm online.

## Build

```bash
# Mở project
open macOS/PHTV.xcodeproj

# Kiểm tra môi trường local
scripts/dev.swift env-check

# Build từ command line
scripts/dev.swift build

# Chạy regression tests
scripts/dev.swift engine-test

# Chạy toàn bộ test target
scripts/dev.swift test

# Release build và static analysis
scripts/dev.swift release-build
scripts/dev.swift analyze
```
