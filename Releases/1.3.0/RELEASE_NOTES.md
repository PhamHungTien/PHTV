# PHTV v1.3.0 - Safe Mode & macOS Ventura Support

## Tính năng mới

### 🛡️ Safe Mode cho Accessibility API
- **Tự động phát hiện crash**: Phát hiện khi Accessibility API gặp vấn đề và ghi nhận
- **Chế độ an toàn**: Tự động chuyển sang chế độ ổn định hơn nếu phát hiện lỗi liên tục
- **Hỗ trợ OCLP Macs**: Tương thích tốt hơn với máy Mac chạy OpenCore Legacy Patcher
- **Crash recovery**: Khôi phục tự động sau khi gặp sự cố Accessibility

### 🍎 Hỗ trợ macOS Ventura (13.0)
- **Mở rộng phạm vi hỗ trợ**: Hạ yêu cầu từ macOS 14.0 (Sonoma) xuống 13.0 (Ventura)
- **Nhiều máy Mac hơn**: Hỗ trợ các máy Mac cũ hơn chạy Ventura
- **Backward compatibility**: Đảm bảo tương thích với các API cũ hơn

## Cải tiến

### 🖼️ Cửa sổ Settings được thiết kế lại
- **Sửa lỗi mở settings**: Fix vòng lặp vô hạn khi mở settings từ menu bar
- **Kích thước tối ưu**: Kích thước mặc định 950x680, tối thiểu 600x450
- **Blur background**: Nền sidebar mờ đẹp mắt đồng bộ với theme color
- **Thread-safe**: Xử lý window management an toàn với Swift 6 concurrency

### 💫 Hỗ trợ macOS 26 Liquid Glass
- **Glass effect**: Tự động áp dụng hiệu ứng Liquid Glass trên macOS 26
- **Background extension**: Nội dung có thể mở rộng dưới sidebar
- **Adaptive button styles**: Nút bấm tự động chuyển đổi style phù hợp

## Sửa lỗi

- 🐛 Fix vòng lặp vô hạn khi mở cài đặt từ menu bar
- 🐛 Fix background trong suốt không đẹp mắt
- 🐛 Fix kích thước cửa sổ quá nhỏ khi mở lần đầu
- 🐛 Fix Swift 6 concurrency warnings trong SettingsWindowHelper

## Thông tin kỹ thuật

- **Phiên bản**: 1.3.0 (Build 5)
- **Yêu cầu tối thiểu**: macOS 13.0 (Ventura)
- **Kiến trúc**: Universal Binary (Intel x86_64 + Apple Silicon arm64)
- **Kích thước DMG**: ~12 MB
- **Code signing**: Developer ID + EdDSA cho Sparkle

## Cài đặt

### Homebrew (Khuyến nghị)
```bash
brew install phamhungtien/tap/phtv
```

### Cập nhật qua Homebrew
```bash
brew upgrade phtv
```

### Cài đặt thủ công
1. Tải file `PHTV-1.3.0.dmg`
2. Mở file DMG
3. Kéo PHTV vào thư mục Applications
4. Mở PHTV và cấp quyền Accessibility trong System Settings

## Nâng cấp từ phiên bản cũ

Nếu bạn đang dùng PHTV 1.2.x:
- **Auto-update**: Ứng dụng sẽ tự động thông báo có bản cập nhật mới
- **Homebrew**: Chạy `brew upgrade phtv`
- **Thủ công**: Tải DMG mới và cài đặt đè lên

## Ghi chú

Đây là bản cập nhật quan trọng dành cho:
- Người dùng máy Mac chạy OpenCore Legacy Patcher (OCLP)
- Người dùng macOS Ventura (13.0)
- Người gặp lỗi không mở được cửa sổ cài đặt

---

**Full Changelog**: https://github.com/PhamHungTien/PHTV/compare/v1.2.9...v1.3.0
