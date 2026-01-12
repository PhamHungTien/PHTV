# PHTV 1.7.1

## 🔴 Sửa Lỗi Nghiêm Trọng

### Crash khi chuyển ứng dụng
- **Nguyên nhân:** `getFocusedAppBundleId()` trả về `nil` trong quá trình chuyển app, gây crash khi gọi `.UTF8String`
- **Triệu chứng:** Segmentation fault (SIGSEGV) khi switch giữa các ứng dụng
- **Sửa chữa:** Thêm nil-check trong 3 functions:
  - `OnActiveAppChanged()` - Smart switch khi đổi app
  - `OnTableCodeChange()` - Remember code table
  - `OnInputMethodChanged()` - Smart switch input method
- **Ảnh hưởng:** Người dùng bật Smart Switch Key hoặc Remember Code Table
- **Kết quả:** ✅ Không còn crash khi chuyển app

### Crash ProgressView trong Settings
- **Nguyên nhân:** SwiftUI ProgressView không có frame rõ ràng gây constraint solver crash
- **Triệu chứng:** `NSISEngine: max length doesn't satisfy min <= max` khi mở Settings
- **Sửa chữa:** Thêm `frame(width: 16, height: 16)` vào tất cả ProgressView
- **Vị trí:** SystemSettingsView, AppsSettingsView, CompatibilitySettingsView
- **Kết quả:** ✅ Settings window ổn định

## ⚡ Cải Tiến

### 100% Thread-Safe
- **Sửa warning cuối cùng** về Swift 6 concurrency trong EmojiHotkeyManager
- Wrapped notification handler trong `Task { @MainActor }`
- **Kết quả:** 0 concurrency warnings, hoàn toàn thread-safe

### Dọn Dẹp Code
- **Xóa 65+ dòng debug NSLog** không cần thiết trong 8 files:
  - EmojiHotkeyManager.swift (47 dòng)
  - SettingsNotificationObserver.swift (3 dòng)
  - SettingsWindowHelper.swift (4 dòng)
  - EmojiDatabase.swift (1 dòng)
  - GIFOnlyView.swift & UnifiedContentView.swift (2 dòng)
  - SettingsWindowContent.swift (7 dòng)
  - EmojiHotkeyBridge.swift (5 dòng)
- **Giữ lại:** Tất cả error logs để debug production
- **Kết quả:** Code sạch hơn, console ít spam hơn

### Cập Nhật Tài Liệu

#### Bug Report Accuracy
- **BugReportView:** Thông tin chính xác về browser detection
  - Detection method: Bundle ID matching (không dùng delays)
  - Event posting: CGEventTapPostEvent (standard)
  - Backspace method: Standard SendBackspace (không có delays)
  - Xóa tham chiếu đến "adaptive delays" đã lỗi thời

#### README Cleanup
- **Xóa phần Warning** về:
  - Gatekeeper workaround (lỗi thời)
  - Browser input fixes với adaptive delays (đã không dùng nữa)
- **Kết quả:** Tài liệu gọn gàng, chính xác hơn

## 📦 Cài Đặt

```bash
# Từ Homebrew (khuyến nghị)
brew upgrade phtv

# Build từ source
git clone https://github.com/PhamHungTien/PHTV.git
cd PHTV
xcodebuild -scheme PHTV -configuration Release build
```

## 🎯 Tương Thích

- ✅ **Tương thích 100%** với v1.7.0
- ✅ Settings được giữ nguyên
- ✅ Macros được giữ nguyên
- ✅ Không cần cấp quyền lại

## 📊 Thống Kê

### Bugs Fixed
- 2 critical crashes (app switching, ProgressView)
- 1 concurrency warning
- 65+ debug noise lines removed

### Code Changes
- 3 files modified (PHTV.mm, BugReportView.swift, README.md)
- +18 lines (nil-checks và comments)
- -65 lines (debug logs)
- Net: -47 lines

### Commits
```
bff7a1b fix: prevent crash when frontmost app bundleIdentifier is nil
64dc907 docs: remove outdated Warning section from README
ccc09d1 refactor: remove debug NSLog from settings and picker views
fb1ddc0 refactor: remove debug NSLog statements from hotkey and settings code
29a6fd1 fix: resolve concurrency warning in EmojiHotkeyManager
```

## 🙏 Lời Cảm Ơn

Cảm ơn người dùng đã báo cáo crash với crash logs chi tiết! Nhờ đó chúng tôi fix được bug nghiêm trọng này.

---

**Ngày phát hành:** 12 Tháng 1, 2026
**Version:** 1.7.1 (Build 64)
**Phiên bản trước:** 1.7.0 (Build 63)
**macOS tối thiểu:** 13.0 (Ventura)

**Chi tiết thay đổi:** https://github.com/PhamHungTien/PHTV/compare/v1.7.0...v1.7.1

---

**© 2026 Phạm Hùng Tiến. All rights reserved.**
