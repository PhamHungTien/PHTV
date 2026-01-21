# PHTV 1.3.6 - Liquid Glass UI & UX Improvements

**Ngày phát hành:** 2 tháng 1, 2026

## ✨ Cải tiến giao diện

### Liquid Glass Design
- **PHTV Picker với Liquid Glass**: Áp dụng thiết kế Liquid Glass hiện đại từ Apple cho PHTV Picker trên macOS 26 (Tahoe) trở lên
- **Settings đồng bộ**: Tất cả tab cài đặt có thiết kế nhất quán với Liquid Glass principles
- **Modern UI**: Sử dụng `.glassEffect()` API mới nhất từ Apple

### Window Management
- **Cố định kích thước cửa sổ**: Sử dụng SwiftUI `.windowResizability(.contentSize)` chuẩn từ Apple (WWDC 2024)
- **Perfect sizing**: Cửa sổ Settings có kích thước tối ưu 800-1000px chiều rộng, 600-900px chiều cao
- **Card alignment**: Căn chỉnh SettingsCard (maxWidth: 700px) đồng nhất trên tất cả các tab

### UI Cleanup
- **Xóa card trùng lặp**: Loại bỏ card "Phím tắt hiện tại" không cần thiết trong tab Phím tắt
- **Improved visibility**: Giảm độ trong suốt của PHTV Picker để dễ nhìn hơn (Glass.clear → Glass.regular)

## 🔧 Sửa lỗi quan trọng

### Text Handling
- **Selected text replacement**: Xử lý đúng việc thay thế văn bản đã được highlight/select
  - Đọc đúng cả `location` và `length` từ CFRange
  - Khi có text được select (selectedLength > 0), thay thế đúng range thay vì dùng backspaceCount

### UX Improvements
- **Auto-focus tìm kiếm**: Con trỏ tự động vào ô tìm kiếm trong tab Emoji (đồng bộ với GIF/Sticker)
- **Consistent behavior**: Tất cả 3 tab (Emoji, GIF, Sticker) đều auto-focus search bar khi mở

## ⚙️ Cài đặt nâng cao

### Always on Top
- **Cửa sổ Settings luôn ở trên**: Thêm cài đặt giữ cửa sổ Settings luôn hiển thị phía trên các app khác
- **Flexible**: Có thể bật/tắt tùy theo nhu cầu sử dụng

### Run on Startup
- **Áp dụng ngay lập tức**: Cài đặt "Khởi động cùng hệ thống" được áp dụng ngay khi bật/tắt
- **No restart needed**: Không cần restart app để thay đổi có hiệu lực

## 🎨 Branding Updates

### PHTV Picker
- **Đổi tên thống nhất**: Đổi "Emoji Picker" thành "PHTV Picker" cho nhất quán branding
- **Search integration**: PHTV Picker xuất hiện trong kết quả tìm kiếm Settings
- **Unified experience**: Tên gọi thống nhất trên UI, settings, và documentation

## 📋 Chi tiết kỹ thuật

### SwiftUI APIs (macOS 26+)
```swift
// Window sizing (WWDC 2024)
.frame(minWidth: 800, maxWidth: 1000, minHeight: 600, maxHeight: 900)
.windowResizability(.contentSize)

// Liquid Glass effect
.glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
```

### Bug Fixes
- **PHTV.mm:775-853**: Fixed selected text range handling in `ReplaceFocusedTextViaAX()`
- **PHTPApp.swift:2407**: Added `.onAppear { isSearchFocused = true }` to EmojiCategoriesView
- **Multiple views**: Added `.frame(maxWidth: .infinity)` for consistent card alignment

## 🔄 Compatibility

### Backward Compatibility
- ✅ Tất cả phiên bản từ 1.2.5+ có thể tự động cập nhật lên 1.3.6
- ✅ Sparkle auto-updater đã được cấu hình đúng với EdDSA signature
- ✅ AppCast feed (appcast.xml) đã được cập nhật

### System Requirements
- **macOS**: 13.0 (Ventura) trở lên
- **Architecture**: Universal Binary (Intel + Apple Silicon)
- **Liquid Glass**: Yêu cầu macOS 26 (Tahoe) để có hiệu ứng Liquid Glass

## 📦 Installation

1. Tải file `PHTV-1.3.6.dmg` từ [GitHub Releases](https://github.com/PhamHungTien/PHTV/releases/tag/v1.3.6)
2. Mở DMG và kéo PHTV vào thư mục Applications
3. Mở PHTV và cấp quyền Accessibility khi được yêu cầu

## 🔗 Links

- [GitHub Release](https://github.com/PhamHungTien/PHTV/releases/tag/v1.3.6)
- [Full Changelog](../../CHANGELOG.md)
- [Documentation](../../README.md)

---

**Lưu ý**: Bản cập nhật này mang đến giao diện hiện đại hơn với Liquid Glass design và sửa nhiều lỗi quan trọng về trải nghiệm người dùng.
