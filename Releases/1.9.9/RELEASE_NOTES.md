# 📝 PHTV Release Notes - Phiên bản 1.9.9

Bản cập nhật này tập trung vào việc khắc phục triệt để lỗi mất văn bản trên các trình duyệt web, sửa lỗi bỏ dấu với phụ âm ngoài và mang đến màn hình hướng dẫn thiết lập mới.

### ✨ Tính năng mới & Cải tiến
*   **Màn hình hướng dẫn (Onboarding):** Thêm giao diện chào mừng và hướng dẫn thiết lập nhanh cho người dùng mới lần đầu sử dụng ứng dụng. Giúp bạn chọn bộ gõ, bật các tính năng cần thiết và cấp quyền Accessibility một cách dễ dàng.
*   **Hỗ trợ trình duyệt tối ưu:** Mở rộng danh sách hỗ trợ chế độ "Gõ từng ký tự" (Step-by-step) cho hàng loạt trình duyệt phổ biến: **Google Chrome, Microsoft Edge, Firefox, Arc, Brave, Opera và Vivaldi.**

### 🐛 Sửa lỗi quan trọng (Bug Fixes)
*   **Sửa lỗi nhập liệu trên Trình duyệt (Smart Browser Fix):**
    *   Sử dụng công nghệ nhận diện thông minh (Accessibility API) để phân biệt chính xác vị trí bạn đang gõ phím.
    *   **Thanh địa chỉ (Address Bar):** Tự động kích hoạt cơ chế chống nhân đôi ký tự ("dđ", "chaào") bằng cách chọn và thay thế ký tự cũ một cách chính xác.
    *   **Nội dung trang web (Google Sheets, Docs...):** Tự động chuyển sang chế độ an toàn, ngăn chặn tuyệt đối lỗi xóa nhầm văn bản ("iệt Nam") và lỗi chọn vùng không mong muốn.
    *   *Kết quả:* Giải quyết triệt để xung đột giữa bộ gõ và trình duyệt, mang lại trải nghiệm gõ mượt mà và ổn định nhất từ trước đến nay.
*   **Sửa lỗi bỏ dấu với phụ âm ngoài (Z, F, W, J):**
    *   Sửa lỗi Engine chỉ nhận diện bỏ dấu cho nguyên âm 'a' khi gõ phụ âm ngoài. Bây giờ bạn đã có thể gõ mượt mà các từ như: *Zuj -> Zụ, Zif -> Zì, Zaayj -> Zậ...*
    *   Sửa lỗi không thể bỏ dấu lên các nguyên âm đôi (â, ê, ô) khi đứng sau các phụ âm đặc biệt.
*   **Chốt chặn an toàn (Safety Limit):** Bổ sung giới hạn xóa ký tự tối đa (15 ký tự). Điều này giúp bảo vệ văn bản của bạn, ngăn chặn việc xóa nhầm đoạn văn dài trong trường hợp có lỗi logic hoặc phản hồi chậm từ ứng dụng đích.

### 🛠 Cải thiện hiệu năng
*   Dọn dẹp các đoạn mã gây trễ (delay) không cần thiết, giúp tốc độ phản hồi của bộ gõ đạt mức tối đa ngay cả trong chế độ tương thích cao.
*   Tối ưu hóa vòng lặp kiểm tra nguyên âm trong Engine C++, giảm tải cho CPU khi xử lý các từ phức tạp.

---
*Cảm ơn bạn đã tin tưởng và sử dụng PHTV. Nếu gặp bất kỳ vấn đề gì, hãy gửi báo cáo lỗi ngay trong phần Cài đặt nhé!*
