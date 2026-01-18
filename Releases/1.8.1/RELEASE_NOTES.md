# PHTV 1.8.1 - Cải thiện độ ổn định Spotlight

Bản cập nhật này là một bản vá lỗi quan trọng (hotfix) tập trung vào việc hoàn thiện trải nghiệm người dùng với Spotlight và khả năng nhận diện ngữ cảnh nhập liệu.

### 🔍 Sửa lỗi Spotlight & Trình duyệt (Critical Fix)
*   **Vấn đề:** Trước đây, khi gọi Spotlight (Cmd+Space) đè lên cửa sổ trình duyệt (Chrome, Safari, Edge...), bộ gõ đôi khi nhận diện nhầm là đang gõ vào trình duyệt thay vì Spotlight. Điều này dẫn đến việc áp dụng sai các kỹ thuật xử lý (như Shift+Left) gây lỗi gõ hoặc mất chữ.
*   **Khắc phục:** Đã tách biệt hoàn toàn cơ chế phát hiện Spotlight và Browser. PHTV giờ đây luôn ưu tiên nhận diện Spotlight chính xác bất kể bạn đang mở ứng dụng nào ở phía dưới.

### ⚡ Chuyển đổi ngữ cảnh nhanh (Rapid Switching)
*   **Vấn đề:** Khi người dùng đóng Spotlight thật nhanh (bằng phím ESC) và lập tức gõ vào ứng dụng khác (ví dụ: Terminal hoặc VS Code), bộ gõ vẫn "nghĩ" là đang ở trong Spotlight do cache chưa kịp xóa, dẫn đến hành vi gõ không mong muốn.
*   **Khắc phục:** Loại bỏ cơ chế "Sticky Cache" khi API hệ thống phản hồi chậm. Trạng thái nhập liệu giờ đây được làm mới ngay lập tức khi Spotlight đóng lại, đảm bảo gõ trơn tru khi chuyển đổi giữa các ứng dụng.

### 🛠 Cải tiến kỹ thuật
*   Tối ưu hóa `PHTVCacheManager` để đồng bộ hóa trạng thái focus giữa các luồng xử lý.
*   Giảm thiểu độ trễ (latency) khi phát hiện ô nhập liệu mới.
