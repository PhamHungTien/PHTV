## PHTV 2.1.4

Phiên bản này tập trung vào sửa lỗi và tối ưu hóa giao diện người dùng.

### 🐛 Sửa lỗi

*   **Fix #121 - Lệnh Terminal không hoạt động:** Khắc phục lỗi lệnh `clear`, `grep`, `printf` và các lệnh khác không hoạt động đúng trong Terminal khi bật chế độ tiếng Việt.
    *   Nguyên nhân: Engine nhận nhầm phụ âm cuối của từ tiếng Anh (như `r` trong `clear`) là dấu thanh Telex.
    *   Giải pháp: Thêm logic nhận diện sớm các tổ hợp phụ âm không có trong tiếng Việt (bl, br, cl, cr, dr, fl, fr, gl, gr, pl, pr, sc, sk, sl, sm, sn, sp, st, sw, tw, wr).

### ✨ Tính năng mới

*   **Ứng dụng không viết hoa:** Thêm tùy chọn loại trừ ứng dụng khỏi tính năng viết hoa đầu câu. Hữu ích cho Terminal, IDE, và các ứng dụng cần gõ lệnh.

### 🎨 Cải tiến giao diện

*   **Onboarding đồng bộ:** Thiết kế lại các thẻ công tắc trong bước "Tính năng cơ bản" để có chiều cao đồng nhất và căn chỉnh đẹp hơn.
*   **Thêm tính năng vào Onboarding:** Bổ sung công tắc "Giữ nguyên từ tiếng Anh" vào bước Tính năng cơ bản (6 công tắc = 3 hàng đều).
*   **Sắp xếp lại Cài đặt:** Gộp phần "Cơ bản" vào "Tối ưu gõ" để giao diện gọn gàng và logic hơn.
*   **Empty state gọn hơn:** Thiết kế lại các mục "Chưa có ứng dụng" với layout ngang, tiết kiệm diện tích.
*   **Âm lượng beep có điều kiện:** Thanh trượt âm lượng chỉ hiển thị khi bật tính năng phát âm thanh.

### 🧹 Đơn giản hóa

*   **Xóa tùy chọn không cần thiết:** Loại bỏ giao diện của các tính năng luôn được bật:
    *   Kiểm tra chính tả (luôn bật)
    *   Cho phép phụ âm Z/F/W/J (luôn bật)
    *   Khôi phục khi từ sai (đã loại bỏ hoàn toàn)
*   **Cập nhật tìm kiếm:** Loại bỏ các mục tìm kiếm liên quan đến tính năng đã xóa.
*   **Cập nhật báo lỗi:** Loại bỏ thông tin của các tính năng đã xóa khỏi báo cáo debug.
