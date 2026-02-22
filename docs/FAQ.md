# PHTV — Các câu hỏi thường gặp (FAQ)

Chào mừng bạn đến với trang giải đáp thắc mắc của PHTV. Dưới đây là danh sách các câu hỏi thường gặp và cách xử lý.

---

## 🛠 Cài đặt & Cấp quyền

### 1. Tại sao PHTV yêu cầu quyền "Accessibility" (Trợ năng)?
PHTV là một ứng dụng gõ tiếng Việt chạy ở tầng hệ thống. Để có thể nhận diện phím bạn gõ và chuyển đổi chúng thành tiếng Việt một cách mượt mà trên tất cả các ứng dụng, PHTV cần quyền Trợ năng để tương tác với các sự kiện bàn phím. PHTV cam kết **không lưu trữ hoặc gửi bất kỳ nội dung nào bạn gõ** ra bên ngoài.

### 2. Tôi đã cấp quyền Accessibility nhưng PHTV vẫn báo thiếu hoặc không gõ được?
Hãy thử các bước sau:
1. Vào **System Settings > Privacy & Security > Accessibility**.
2. Xóa PHTV khỏi danh sách (nhấn dấu `-`).
3. Khởi động lại PHTV và cấp lại quyền khi được hỏi.
4. Đảm bảo icon PHTV trên menu bar đang ở trạng thái **Vi**.

---

## ⌨️ Lỗi khi gõ tiếng Việt

### 3. Tại sao tôi gõ bị lặp từ hoặc xuất hiện ký tự lạ?
Đây là lỗi phổ biến nhất do xung đột với tính năng tự động sửa lỗi của macOS.
**Cách khắc phục:**
1. Vào **System Settings > Keyboard > Input Sources > Edit**.
2. **Tắt hết** các tùy chọn:
   - *Correct spelling automatically*
   - *Capitalize words automatically*
   - *Add period with double-space*
   - *Show inline predictive text*
3. Xem chi tiết tại [Hướng dẫn cài đặt](INSTALL.md#️-chuẩn-bị-trước-khi-cài-đặt).

### 4. PHTV có hỗ trợ gõ trên các ứng dụng Terminal/IDE không?
Có. PHTV hỗ trợ tốt trên Terminal, iTerm2, VS Code, v.v. Nếu bạn gặp vấn đề gõ tiếng Việt trong **Claude Code CLI**, hãy vào **Settings > Apps** và bật tính năng **Patch Claude Code** để khắc phục lỗi không nhận dấu.

### 5. Làm sao để tạm thời tắt tiếng Việt khi gõ code?
Bạn có thể:
- Sử dụng phím tắt chuyển đổi (mặc định **Control + Shift**).
- Giữ phím **Option** (mặc định, có thể tùy chỉnh) để tạm thời gõ tiếng Anh mà không cần chuyển chế độ.
- Nhấn phím **ESC** để khôi phục ký tự gốc (hoàn tác dấu vừa gõ).

---

## ✨ Tính năng & Tùy chỉnh

### 6. PHTV Picker là gì và làm sao để mở?
PHTV Picker là bảng chọn nhanh Emoji và GIF theo phong cách Liquid Glass hiện đại.
- **Mở nhanh:** Nhấn phím tắt mặc định (tùy chỉnh trong Settings) hoặc click icon trên menu bar.
- **Tìm kiếm:** Bạn có thể tìm emoji/gif bằng cả tiếng Việt và tiếng Anh.
- **Tự động dán:** Chỉ cần click vào emoji/gif, PHTV sẽ tự động dán vào ứng dụng bạn đang dùng.

### 7. Macro (Gõ tắt) trong PHTV có gì đặc biệt?
PHTV hỗ trợ Macro cực mạnh:
- **Text Snippets:** Tự động chèn ngày giờ (`{date}`, `{time}`), nội dung clipboard, hoặc số thứ tự.
- **Thông minh:** Tự động viết hoa macro theo ngữ cảnh (VD: `btw` -> `by the way`, `Btw` -> `By the way`).
- **Chế độ Anh:** Bạn có thể bật macro ngay cả khi đang ở chế độ gõ tiếng Anh.

### 8. "Safe Mode" là gì?
Safe Mode (Chế độ an toàn) là tính năng giúp PHTV tự động phục hồi khi gặp lỗi với Accessibility API của macOS. Tính năng này đặc biệt hữu ích cho các dòng máy Mac cũ hoặc các máy chạy macOS qua OCLP (OpenCore Legacy Patcher).

---

## 🔄 Cập nhật & Gỡ cài đặt

### 9. Làm sao để cập nhật PHTV lên bản mới nhất?
PHTV tích hợp sẵn Sparkle framework. Ứng dụng sẽ tự động kiểm tra và thông báo khi có phiên bản mới. Bạn chỉ cần nhấn **Install Update** để hoàn tất.

### 10. Tôi muốn gỡ cài đặt sạch PHTV thì làm thế nào?
Nếu cài qua Homebrew, hãy dùng lệnh:
```bash
brew uninstall --zap --cask phtv
```
Lệnh này sẽ xóa cả ứng dụng và các file cấu hình liên quan.

---

## 📮 Hỗ trợ thêm

Nếu câu hỏi của bạn không nằm trong danh sách này, vui lòng:
- [Báo lỗi trên GitHub](../../issues)
- Gửi email về: phamhungtien.contact@gmail.com
- Tham gia thảo luận tại [Facebook PHTVInput](https://www.facebook.com/PHTVInput)

---
[🏠 Trang chủ](README.md) • [📦 Cài đặt](INSTALL.md)
