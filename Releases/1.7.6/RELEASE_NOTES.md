# PHTV 1.7.6 Release Notes

### 🚀 Trải nghiệm gõ hoàn hảo trên Facebook & Messenger

Bản cập nhật 1.7.6 tập trung giải quyết triệt để vấn đề "nhân đôi ký tự" gây khó chịu trên các nền tảng web, mang lại trải nghiệm gõ mượt mà và chính xác tuyệt đối.

#### 🌟 Tính năng nổi bật

*   **Sửa lỗi nhân đôi ký tự (Duplicate Characters):** Khắc phục hoàn toàn lỗi gõ "d" thành "dđ", "chào" thành "Chaào" thường gặp trên thanh tìm kiếm Facebook, Messenger và các ô nhập liệu có tính năng gợi ý (Autocomplete).
*   **Chiến thuật nhập liệu mới (Select & Overwrite):**
    *   Thay đổi cơ chế sửa lỗi từ "Xóa rồi Gõ lại" (Delete-then-Type) sang **"Chọn rồi Ghi đè" (Select-then-Overwrite)**.
    *   **Nguyên lý:** Khi cần sửa dấu hoặc ký tự, PHTV sẽ bôi đen (Select) ký tự cũ và gửi ký tự mới đè lên ngay lập tức. Điều này ngăn chặn trình duyệt hiểu nhầm lệnh xóa (Backspace) là lệnh "hủy gợi ý", giúp loại bỏ hiện tượng sót chữ cũ.
    *   *Tính năng này hoạt động trên tất cả trình duyệt phổ biến:* Chrome, Safari, Edge, Brave, Arc, Cốc Cốc, Firefox, v.v.

#### 🛠 Cải thiện kỹ thuật

*   Tối ưu hóa `PHTV Engine` để nhận diện ngữ cảnh trình duyệt chính xác hơn.
*   Loại bỏ độ trễ (delay) không cần thiết khi xử lý phím Backspace trên trình duyệt, giúp tốc độ phản hồi nhanh hơn.
*   Refactor mã nguồn, dọn dẹp các logic xử lý cũ để engine nhẹ và ổn định hơn.

#### 🫶 Lời cảm ơn

Chân thành cảm ơn cộng đồng mã nguồn mở **OpenKey** đã tiên phong giải pháp xử lý input thông minh này. PHTV 1.7.6 kế thừa và tích hợp giải pháp này để mang lại trải nghiệm tốt nhất cho người dùng macOS.

---

### 🇬🇧 English Summary

**Fixed:**
- **Facebook/Messenger Duplication:** Resolved an issue where typing on Facebook/Messenger caused character duplication (e.g., "dđ", "Chaào") due to browser autocomplete conflicts.
- **New Input Strategy:** Implemented the **"Select then Overwrite"** strategy (inspired by OpenKey). Instead of backspacing, the engine now selects the text and overwrites it, preventing race conditions with browser autocomplete logic.
- **Supported Browsers:** Fix applies to Chrome, Safari, Edge, Brave, Arc, Cốc Cốc, and Electron-based apps.

---

### 📝 Commit Log
- `c2c14bc` fix: resolve duplicate characters on Facebook/Browser via Select-Overwrite strategy
- `d456cf1` fix: Implement TCC entry corruption detection and recovery (#96)
- `574e535` refactor: Remove #ifdef toggles and cleanup PHTV.mm
