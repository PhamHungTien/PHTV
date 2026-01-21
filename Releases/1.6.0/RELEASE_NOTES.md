# PHTV 1.6.0

Phiên bản 1.6.0 tập trung vào cải thiện độ ổn định gõ tiếng Việt trên các trình duyệt web và ứng dụng Electron, cùng nhiều sửa lỗi quan trọng khác.

## ✨ Những thay đổi chính

### 🌐 Cải thiện độ ổn định trên trình duyệt
- **Hỗ trợ thêm Zen Browser**: Sửa lỗi duplicate characters khi gõ VNI trong address bar (#82)
- **Browser delays tối ưu**: Tăng delays cho Chromium, Safari, Firefox để đảm bảo gõ tiếng Việt ổn định 100%
- **Auto English restore**: Cải thiện việc khôi phục từ tiếng Anh (VD: "tẻminal" → "terminal") trên browsers

### 🔧 Hỗ trợ ứng dụng mới
- **Notion**: Thêm xử lý đặc biệt cho Notion (Electron app) để tránh lỗi duplicate text khi gõ
- **Step-by-step input**: Notion được thêm vào danh sách apps cần gửi phím từng bước

### 🎯 PHTV Picker
- **Mặc định bật cho người dùng mới**: PHTV Picker (Emoji, GIF, Sticker) giờ được bật sẵn khi cài đặt lần đầu
- **Hotkey mặc định**: ⌘E để mở nhanh bảng chọn

### 🛠 Sửa lỗi
- **Settings window không tự tắt**: Khắc phục lỗi cửa sổ cài đặt tự động đóng khi không bật "always on top" trong accessory mode
- **Hiển thị phím Space**: Sửa lỗi phím Space không hiển thị tên trong giao diện cài đặt phím tắt
- **Loại bỏ Edit-in-place**: Tính năng này đã được gỡ bỏ do chưa ổn định

### 📁 Cải tiến kỹ thuật
- **Tái cấu trúc project**: Sắp xếp lại thư mục và file cho dễ bảo trì
  - `SwiftUI/` → `UI/`
  - Thêm `Development/` cho dev tools
  - Thêm `Core/Config/` và `Core/Legacy/`
  - Tổ chức `Resources/` với `Dictionaries/`, `Images/`, `Localization/`
- **Xcode references**: Đảm bảo tất cả file được reference đúng trong project

## 🐛 Các lỗi đã sửa

| Issue | Mô tả |
|-------|-------|
| #82 | Lỗi gõ VNI trên Zen Browser |
| - | Settings window tự động tắt trong accessory mode |
| - | Phím Space không hiển thị tên trong hotkey settings |
| - | Duplicate text khi gõ tiếng Việt trong Notion |
| - | Vietnamese input không ổn định trên browsers |

## 📦 Cài đặt & Cập nhật

### Homebrew (khuyên dùng)
```bash
brew upgrade --cask phtv
```

### Tự động cập nhật
Mở PHTV → Settings → Hệ thống → Kiểm tra cập nhật

### Thủ công
Tải file `.dmg` từ [GitHub Releases](https://github.com/PhamHungTien/PHTV/releases/latest)

## 🙏 Cảm ơn

Cảm ơn cộng đồng đã báo lỗi và đóng góp ý kiến, đặc biệt:
- @meichengg - Báo lỗi Zen Browser (#82)
- Các bạn đã góp ý về độ ổn định trên browsers và Notion

---

**Full Changelog**: [v1.5.6...v1.6.0](https://github.com/PhamHungTien/PHTV/compare/v1.5.6...v1.6.0)
