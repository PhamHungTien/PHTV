# PHTV 1.8.4 - Sửa lỗi Safari Address Bar

Bản cập nhật này tập trung khắc phục triệt để lỗi nhân đôi ký tự khi gõ tiếng Việt trên thanh địa chỉ (Address Bar/Omnibox) của trình duyệt Safari.

### 🍎 Safari Improvements
*   **Vấn đề:** Khi gõ tiếng Việt trên thanh địa chỉ Safari, cơ chế autocomplete của trình duyệt đôi khi xung đột với bộ gõ, dẫn đến hiện tượng nhân đôi ký tự (ví dụ: gõ "đ" thành "dđ", "â" thành "aâ").
*   **Giải pháp:** PHTV 1.8.4 giờ đây tự động kích hoạt chiến lược **"Shift + Left Arrow" (Chọn + Xóa)** dành riêng cho Safari.
*   **Kết quả:**
    *   ✅ Loại bỏ hoàn toàn lỗi nhân đôi ký tự trên thanh địa chỉ.
    *   ✅ Hoạt động mượt mà ngay cả khi Safari gợi ý lịch sử duyệt web.
    *   ✅ Áp dụng tự động cho Safari, người dùng không cần phải bật thủ công tùy chọn "Fix Chromium Browser" trong cài đặt.

### 🛠 Technical Changes
*   Cập nhật `PHTVAppDetectionManager` để nhận diện chính xác `com.apple.Safari` và `com.apple.SafariTechnologyPreview`.
*   Cập nhật logic `SendBackspace` trong `PHTV.mm` để ép buộc sử dụng strategy `Shift+Left` cho Safari process, tách biệt logic này khỏi settings của Chromium.
