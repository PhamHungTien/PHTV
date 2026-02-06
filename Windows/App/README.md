# PHTV Windows App (UI)

Ứng dụng desktop Windows được port từ cấu trúc SwiftUI Settings của macOS.

## Mục tiêu

- Giữ nguyên layout chính: sidebar + search + 7 tab.
- Giữ shape card/section/spacing tương tự SwiftUI.
- Làm lớp Settings điều khiển cho Windows, dùng chung engine ở `Shared/Engine`.

## Chức năng đã hoàn thành

- `Auto-save` toàn bộ settings vào `%LOCALAPPDATA%/PHTV/settings.json`.
- `Tray icon` giống menubar flow:
  - icon đổi theo ngôn ngữ:
    - bật tiếng Việt: `tray_vi` (hoặc `menubar_icon` nếu tắt tùy chọn "Hiển thị biểu tượng chữ V").
    - tắt tiếng Việt (English mode): luôn dùng `tray_en`.
  - click trái để chuyển Việt/Anh.
  - click phải mở menu nhanh (bộ gõ, bảng mã, gõ tắt, chính tả, cập nhật, mở cài đặt, thoát).
  - đóng cửa sổ sẽ ẩn xuống tray thay vì thoát app.
- Tab `Gõ tắt`:
  - Thêm/sửa/xóa macro.
  - Thêm/sửa danh mục.
  - Nhập/xuất macro (`.json`) và parse thêm format text đơn giản.
- Tab `Ứng dụng`:
  - Thêm/xóa app loại trừ.
  - Thêm/xóa app gửi từng phím.
- Tab `Hệ thống`:
  - Bật/tắt startup cùng Windows (HKCU Run registry).
  - Điều khiển native hook daemon (start/stop/restart, runtime status).
  - Xuất/nhập cấu hình đầy đủ.
  - Khôi phục mặc định.
  - Mở trang cập nhật và trang hướng dẫn.
- Tab `Báo lỗi`:
  - Tạo report markdown theo state hiện tại.
  - Copy clipboard, lưu file, mở GitHub issue, mở email draft.
- Tab `Thông tin`:
  - Mở website / GitHub / donate.

## Map tab SwiftUI -> Windows

- `TypingSettingsView` -> `Views/Tabs/TypingTabView.axaml`
- `HotkeySettingsView` -> `Views/Tabs/HotkeysTabView.axaml`
- `MacroSettingsView` -> `Views/Tabs/MacroTabView.axaml`
- `AppsSettingsView` -> `Views/Tabs/AppsTabView.axaml`
- `SystemSettingsView` -> `Views/Tabs/SystemTabView.axaml`
- `BugReportView` -> `Views/Tabs/BugReportTabView.axaml`
- `AboutView` -> `Views/Tabs/AboutTabView.axaml`

## Build

```bash
dotnet build Windows/App/PHTV.Windows.csproj
```

## Build icon (.ico)

```bash
python3 Windows/App/Tools/build_ico.py
```

Script sẽ tạo:
- `Windows/App/Assets/PHTV.ico` (icon chính cho `PHTV.exe`)
- `Windows/App/Assets/tray_vi.ico` (tray icon chế độ tiếng Việt)
- `Windows/App/Assets/tray_en.ico` (tray icon chế độ tiếng Anh)
- `Windows/App/Assets/menubar_icon.ico` (tray icon khi tắt tiếng Việt)

## Run (development)

```bash
dotnet run --project Windows/App/PHTV.Windows.csproj
```

## Publish Windows

```bash
# win-x64
./Windows/App/build-windows.sh win-x64 Release true
```

Output sản phẩm: `Windows/App/publish/win-x64/PHTV.exe` (single-file).

## Kiến trúc code

- `ViewModels/MainWindowViewModel.cs`: điều phối command, autosave, import/export, bug report, startup integration.
- `ViewModels/SettingsState.cs`: state tập trung cho toàn bộ settings + selected items.
- `Models/SettingsSnapshot.cs`: snapshot DTO + mapping state.
- `Services/SettingsPersistenceService.cs`: đọc/ghi cấu hình.
- `Services/WindowsStartupService.cs`: startup registry cho Windows.
- `Services/BugReportService.cs`: tạo report markdown và URL action.
- `Services/RuntimeBridgeService.cs`: đồng bộ runtime config/macro cho shared engine, quản lý hook daemon.
- `Dialogs/TextPromptWindow.cs`: dialog nhập liệu dùng lại cho CRUD.

## Phạm vi hiện tại

- Ứng dụng này là lớp Settings/Control app cho Windows và đã đầy đủ luồng cấu hình.
- Runtime gõ tiếng Việt theo mô hình OpenKey win32 đã có daemon native tại `Windows/Hook`.
- App tự ghi runtime files tại `%LOCALAPPDATA%/PHTV/runtime-config.ini` và `%LOCALAPPDATA%/PHTV/runtime-macros.tsv` để daemon hot-reload.
- Có thể chỉ định đường dẫn daemon thủ công bằng biến môi trường `PHTV_HOOK_DAEMON_PATH`.
