# PHTV 1.2.5 - Auto-Update Framework

## Tính năng mới

### Hệ thống cập nhật tự động

- **Sparkle Framework**: Tích hợp Sparkle 2.8.1 - framework cập nhật chuyên nghiệp cho macOS
- **Kiểm tra tự động**: Tự động kiểm tra phiên bản mới theo lịch (hàng ngày/hàng tuần/hàng tháng)
- **Kênh Beta**: Hỗ trợ opt-in vào kênh beta để nhận phiên bản thử nghiệm
- **UI hiện đại**: Banner thông báo cập nhật với glassmorphism effect
- **Release notes viewer**: Xem chi tiết changelog trước khi cập nhật
- **EdDSA signing**: Bảo mật cao với chữ ký EdDSA cho mọi bản cập nhật

## Cải tiến

### Giao diện cài đặt

- **Đơn giản hóa**: Loại bỏ phần "Thông tin ứng dụng" trùng lặp trong cài đặt hệ thống
- **Tối ưu UI**: Chỉ giữ lại một nút "Kiểm tra cập nhật" trong card "Cập nhật"
- **Settings card mới**: Card "Cập nhật" với đầy đủ tùy chọn:
  - Chọn tần suất kiểm tra (Không bao giờ/Hàng ngày/Hàng tuần/Hàng tháng)
  - Bật/tắt kênh Beta
  - Kiểm tra cập nhật thủ công

### Backend

- **Loại bỏ code cũ**: Xóa hoàn toàn logic kiểm tra cập nhật qua GitHub API thủ công
- **Notification flow**: Cải thiện luồng thông báo giữa SwiftUI và Objective-C
- **Sparkle delegates**: Sử dụng SPUUpdaterDelegate và SPUStandardUserDriverDelegate

## Sửa lỗi

- **Timeout error**: Sửa lỗi timeout 30 giây khi kiểm tra cập nhật
- **Stuck alert**: Sửa lỗi alert "Đang kiểm tra cập nhật..." không biến mất
- **No response**: Sửa lỗi nhấn nút "Kiểm tra cập nhật" không có phản hồi
- **Notification mismatch**: Sửa lỗi tên notification không khớp ("CheckForUpdates" vs "SparkleManualCheck")
- **Missing feedback**: Sửa lỗi Sparkle check im lặng (silent) khi người dùng click thủ công

## Kỹ thuật

- **Hardened Runtime**: Bật hardened runtime theo yêu cầu của Sparkle
- **Code signing**: Ký code với Apple Development certificate
- **SwiftUI integration**: Tích hợp Sparkle với SwiftUI qua Objective-C++ bridge
- **AppState management**: Quản lý trạng thái update check frequency và beta channel

---

Phiên bản này là bước quan trọng giúp PHTV có hệ thống cập nhật chuyên nghiệp, tự động và an toàn như các ứng dụng macOS khác.
