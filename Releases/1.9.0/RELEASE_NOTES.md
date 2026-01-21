# PHTV 1.9.0 - Ổn định Safari & Hoàn thiện Claude Code Fix

Bản cập nhật này mang đến những cải tiến quan trọng về độ ổn định cho trình duyệt Safari và khắc phục triệt để các vấn đề liên quan đến tính năng hỗ trợ gõ tiếng Việt trong Claude Code CLI.

### 🍎 Cải tiến Safari (Triệt để)
*   **Sửa lỗi nhân đôi ký tự đầu:** Khắc phục hoàn toàn lỗi khi gõ chữ có dấu đầu tiên trên thanh địa chỉ hoặc các ô nhập liệu (ví dụ: gõ "đ" ra "dđ", "â" ra "aâ").
*   **Đồng bộ Engine:** Đồng nhất danh sách nhận diện ứng dụng giữa lõi xử lý C++ và bộ quản lý AppDetection, đảm bảo chiến lược "Shift + Left" (Chọn + Xóa) luôn được áp dụng chính xác cho Safari.

### 💻 Claude Code CLI Support (Vượt trội)
*   **Lưu cache đường dẫn:** PHTV giờ đây sẽ ghi nhớ đường dẫn đến file `cli.js` sau khi tìm thấy. Điều này giúp trạng thái "Đã bật" luôn được giữ nguyên ổn định khi bạn khởi động lại ứng dụng.
*   **Nhận diện thông minh hơn:** Cải tiến thuật toán tìm kiếm file trong thư mục `~/.npm/_npx/...`. Hệ thống ưu tiên kiểm tra bản cài đặt npm trước để tránh nhận diện nhầm các bản cài đặt qua Homebrew node thành bản binary không thể patch.
*   **Fix lỗi mất công tắc:** Đảm bảo công tắc bật/tắt patch luôn hiển thị đúng trạng thái "Đã bật ✓" thay vì quay lại yêu cầu "Chuyển đổi sang npm" một cách vô lý.

### 📝 Tài liệu & Hệ thống
*   **Tinh gọn Repository:** Xóa file tài liệu rời `CLAUDE_CODE_FIX.md` và tích hợp trực tiếp thông tin vào `README.md` để người dùng dễ dàng theo dõi.
*   **Cập nhật README:** Làm mới phần hướng dẫn và cảm ơn các đóng góp từ cộng đồng (OpenKey, Đinh Văn Mạnh).

---

### 🚀 Cách cập nhật
1.  Mở **PHTV Settings**.
2.  Chọn tab **Hệ thống** -> **Kiểm tra cập nhật**.
3.  Hoặc tải bản mới nhất tại: [GitHub Releases](https://github.com/PhamHungTien/PHTV/releases/latest)

---
*Cảm ơn bạn đã tin tưởng sử dụng PHTV! Nếu thấy hữu ích, hãy tặng cho dự án 1 ⭐ trên GitHub nhé.*
