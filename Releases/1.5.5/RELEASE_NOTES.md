# PHTV 1.5.5

Phiên bản 1.5.5 tập trung vào việc khắc phục các vấn đề về độ ổn định nền tảng, tương thích trình duyệt và tối ưu hóa hiệu năng nghiêm trọng.

## 🛠 Những thay đổi chính

### ⚡️ Độ ổn định & Hiệu năng
- **Fix Background Agent**: Khắc phục triệt để lỗi bộ gõ "lúc hoạt động lúc không". Đã cấu hình lại ứng dụng để chạy dưới dạng Agent (`LSUIElement`), ngăn macOS tự động tắt bộ gõ khi đóng cửa sổ cài đặt hoặc khi hệ thống dọn dẹp bộ nhớ.
- **Fix Memory Spike**: Khắc phục lỗi ngốn RAM đột biến (tăng từ 50MB lên 500MB) khi mở giao diện Cài đặt do tài nguyên ảnh thừa.
- **Cleanup**: Dọn dẹp tài nguyên dư thừa, giảm kích thước App Bundle.

### 🌐 Tương thích Trình duyệt
- **Fix Address Bar Duplication**: Sửa lỗi lặp ký tự đầu tiên (ví dụ: gõ "chào" -> "chaào", "đ" -> "dđ") trên thanh địa chỉ của **Safari**, **Firefox**, **Orion** và **DuckDuckGo**.
- **Fix Shortcut Deletion**: Sửa lỗi trình duyệt (đặc biệt là **Cốc Cốc** và Chromium) tự động xóa các shortcut tìm kiếm (như `/p`, `/g`) khi bắt đầu gõ tiếng Việt.

### 💬 Tương thích Ứng dụng
- **Fix WhatsApp**: Khắc phục lỗi mất tính năng gõ tiếng Việt (hoặc gõ lỗi) trên **WhatsApp** sau khi máy tính Sleep hoặc sử dụng lâu. Đã cải thiện cơ chế quản lý Cache PID để tự động nhận diện lại ứng dụng nhanh chóng.

## 📦 Cài đặt & Cập nhật

Người dùng hiện tại có thể cập nhật thông qua:
1.  **Tự động:** Mở PHTV Settings -> Hệ thống -> Kiểm tra cập nhật.
2.  **Homebrew:** `brew upgrade --cask phtv`
3.  **Thủ công:** Tải file `.dmg` mới nhất từ GitHub Releases.
