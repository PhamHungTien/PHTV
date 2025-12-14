# Changelog

Tất cả các thay đổi đáng chú ý của dự án này sẽ được tài liệu hóa trong file này.

Format này dựa trên [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
và dự án tuân theo [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Giao diện SwiftUI mới với Liquid Glass design cho macOS 14+
- Status bar controller cho quick access đến tính năng chính
- Settings panel mới với tổ chức tốt hơn
- Hỗ trợ Smart Switch Key cho tự động chuyển đổi theo ứng dụng
- Macro (gõ tắt) support
- Spell checking với từ điển tiếng Việt
- Quick Telex - gõ nhanh với phối hợp phím

### Changed

- Refactor engine từ OpenKey để tích hợp tốt hơn với SwiftUI
- Cải thiện hiệu năng với optimized event handling
- Cập nhật user defaults storage

### Fixed

- Các vấn đề compatibility với các trình duyệt web
- Memory leak trong engine
- Crash khi chuyển ứng dụng nhanh

## [1.0.0] - 2025-12-15

### Added

- Phiên bản đầu tiên của PHTV
- Hỗ trợ 4 phương pháp gõ:
  - Telex
  - VNI
  - Simple Telex 1
  - Simple Telex 2
- Hỗ trợ 5 bảng mã:
  - Unicode (mặc định)
  - TCVN3 (ABC)
  - VNI Windows
  - Unicode Composite
  - Vietnamese Locale (CP1258)
- Giao diện Menu Bar với nhanh các tùy chọn chính
- Kiểm tra chính tả (spell checking)
- Quản lý macro (gõ tắt)
- Excluded apps - tự động tắt tiếng Việt cho ứng dụng chỉ định
- Hỗ trợ Dark Mode
- Tùy chỉnh phím tắt chuyển ngôn ngữ
- Thống kê sử dụng
- Khởi động cùng hệ thống (auto-launch)

---

## Hướng dẫn cho maintainers

### Khi release phiên bản mới

1. **Cập nhật version:**

   - Xcode: Product > Scheme > Edit Scheme, hoặc
   - Build Settings > Marketing Version

2. **Cập nhật CHANGELOG:**

   ```markdown
   ## [X.Y.Z] - YYYY-MM-DD

   ### Added

   - Mô tả tính năng mới

   ### Changed

   - Các thay đổi

   ### Fixed

   - Các lỗi được sửa

   ### Deprecated

   - Các tính năng sắp bỏ

   ### Removed

   - Các tính năng bị xóa

   ### Security

   - Các bản vá bảo mật
   ```

3. **Tạo git tag:**

   ```bash
   git tag -a v1.0.0 -m "Release version 1.0.0"
   git push origin v1.0.0
   ```

4. **Tạo release trên GitHub:**
   - Đi tới Releases
   - Nhấn "Create a new release"
   - Chọn tag
   - Thêm release notes từ CHANGELOG

### Version numbering

PHTV sử dụng Semantic Versioning: `MAJOR.MINOR.PATCH`

- **MAJOR**: Breaking changes
- **MINOR**: Tính năng mới (backward compatible)
- **PATCH**: Bug fixes

### Categories

Khi cập nhật changelog, sử dụng các category sau:

- **Added** - Tính năng mới
- **Changed** - Thay đổi tính năng hiện có
- **Deprecated** - Tính năng sắp bỏ
- **Removed** - Tính năng bị xóa
- **Fixed** - Bug fixes
- **Security** - Bản vá bảo mật

---

## Lịch sử phát triển

### Giai đoạn 1: Rebranding (2025)

- Từ OpenKey sang PHTV
- Xây dựng lại giao diện với SwiftUI
- Nâng cấp compatibility với macOS 14+

### Giai đoạn 2: Stability (Sắp tới)

- Bug fixes
- Performance optimization
- Tăng test coverage

### Giai đoạn 3: Features (Sắp tới)

- Input method plugin API
- Themes tùy chỉnh
- Đồng bộ settings qua iCloud

---

**Last updated**: 2025-12-15
