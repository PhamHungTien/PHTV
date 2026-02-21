# PHTV — Hướng dẫn cho AI coding assistant

## Giới thiệu

PHTV là bộ gõ tiếng Việt cho macOS. Viết bằng Swift (UI + bridge) và C++ (engine xử lý ngôn ngữ). Project chỉ hỗ trợ macOS — không có Windows/Linux.

## Cấu trúc source

```
macOS/PHTV/
├── App/           AppDelegate + extensions
├── Bridge/        Lớp tích hợp engine ↔ macOS (10 sub-folder)
│   ├── Engine/    C++ interop, globals, session service
│   ├── EventTap/  CGEventTap callback + lifecycle
│   ├── Input/     Character output, key sender, timing
│   ├── Context/   AX context, app detection, Spotlight
│   ├── Accessibility/
│   ├── Hotkey/
│   ├── CLI/
│   ├── Manager/   PHTVManager (ObjC entry point)
│   ├── SmartSwitch/
│   └── System/    Permission, TCC, safe mode, binary integrity
├── Core/Engine/   C++ engine source
├── Data/          Persistence, API clients
├── Models/        Value types
├── Resources/     Dictionaries, localization
├── Services/      Business logic
├── State/         SwiftUI observable state
├── UI/            SwiftUI views
└── Utilities/     Logger, constants, shared helpers
```

Xem chi tiết: `docs/ARCHITECTURE.md`

## Quy tắc quan trọng

### C++ ↔ Swift interop
- Tất cả C++ wrapper nằm trong `Bridge/Engine/PHTVEngineCxxInterop.hpp`
- C++ free function import vào Swift **không có argument label** (positional only)
- Build flag: `-cxx-interoperability-mode=default`

### Thread safety
- `CGEventTapCallBack` chạy trên **main run loop** (tap được add vào `CFRunLoopGetMain()`)
- Dùng `MainActor.assumeIsolated { }` khi cần gọi `@MainActor`-isolated method từ callback
- Static vars không có actor isolation dùng `nonisolated(unsafe)`

### Xcode project
- Project dùng `PBXFileSystemSynchronizedRootGroup` → Xcode tự phát hiện file mới/đổi chỗ
- Chỉ cần move file trên filesystem, không cần sửa `.xcodeproj`
- Ngoại lệ: `Info.plist` được quản lý thủ công trong project

### Bridging header
```objc
// macOS/PHTV/PHTVBridgingHeader.h
#import "Bridge/Engine/PHTVEngineCxxInterop.hpp"
```
Nếu move `PHTVEngineCxxInterop.hpp`, phải cập nhật đường dẫn này.

### Commit
- Tác giả commit chỉ là Phạm Hùng Tiến — không dùng `Co-Authored-By`
- Không dùng `--no-verify`

## Các service chính

| File | Vai trò |
|------|---------|
| `Bridge/EventTap/PHTVEventCallbackService.swift` | Main event tap callback (thay PHTVCallback C++) |
| `Bridge/Engine/PHTVEngineSessionService.swift` | Khởi động engine, quản lý session |
| `Bridge/Engine/PHTVEngineCxxInterop.hpp` | Tất cả wrapper C++ → Swift |
| `Bridge/Engine/PHTVEngineGlobals.cpp` | Định nghĩa `pData` global |
| `Bridge/EventTap/PHTVEventTapService.swift` | Tạo/bật/tắt CGEventTap |
| `Bridge/Input/PHTVCharacterOutputService.swift` | Commit kết quả ra ứng dụng đích |
| `Bridge/Manager/PHTVManager.swift` | ObjC entry point cho AppDelegate |
| `Bridge/System/PHTVPermissionService.swift` | Kiểm tra quyền Accessibility |

## Lịch sử migration

Project đã được migrate hoàn toàn từ ObjC/ObjC++ sang Swift:
- `PHTVCallback` (main event callback, ~600 dòng C++) → `PHTVEventCallbackService.swift`
- `PHTVInit` → `PHTVEngineSessionService.boot()`
- `RequestNewSession` → `PHTVEngineSessionService.requestNewSession()`
- `SendNewCharString`, `handleMacro` → `PHTVCharacterOutputService.swift`
- `PHTV.mm` đã bị xóa hoàn toàn

## Build & test

```bash
# Build
xcodebuild -project macOS/PHTV.xcodeproj -scheme PHTV build

# Mở trong Xcode
open macOS/PHTV.xcodeproj
```
