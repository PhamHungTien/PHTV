# PHTV - Release Notes v1.9.2

### 🚀 Có gì mới?
Trong bản cập nhật này, PHTV tập trung tối ưu hóa thuật toán xử lý nguyên âm và vị trí đặt dấu, mang lại trải nghiệm gõ phím tự nhiên và chính xác hơn, đặc biệt là khi gõ các từ kéo dài hoặc biểu cảm.

### ✨ Cải tiến & Sửa lỗi (Engine)

*   **Hoàn thiện cơ chế gõ từ kéo dài (Prolonged Vowels):**
    *   Sửa lỗi dấu thanh bị nhảy sai vị trí khi gõ kéo dài nguyên âm (Ví dụ: `nhe` + `s` + `ee` giờ đây sẽ ra **"nhéee"** thay vì "nheée").
    *   Hỗ trợ gõ các từ biểu cảm như **"áaa"**, **"hảaa"**, **"chàoo"** một cách chính xác.

*   **Thông minh hóa việc nhân đôi nguyên âm (Double-tap Logic):**
    *   **Ngăn chặn biến đổi sai:** Tự động chặn việc chuyển đổi `aa` -> `â` hoặc `oo` -> `ô` nếu nó tạo ra các tổ hợp không có thực trong tiếng Việt khi đứng sau một nguyên âm khác.
    *   Sửa lỗi: **"chưa" + "a" -> "chưaa"** (không còn bị thành "chưâ").
    *   Sửa lỗi: **"cua" + "a" -> "cuaa"** (không còn bị thành "cuâ").

*   **Bảo vệ dấu thanh cho từ đã hoàn thành:**
    *   Khi một từ đã có dấu (như **"của"**, **"vừa"**, **"dứa"**), việc gõ thêm nguyên âm để kéo dài sẽ không làm thay đổi hoặc mất dấu của từ gốc.
    *   Ví dụ: `của` + `a` -> **"củaa"** (thay vì "cuẩ").

*   **Tối ưu hóa gõ dấu linh hoạt (Flexible Tone Placement):**
    *   Cải thiện thuật toán tìm kiếm nguyên âm mục tiêu, cho phép gõ dấu/mũ ở cuối từ một cách linh hoạt mà không gây xung đột với cơ chế gõ kéo dài.
    *   Ví dụ: `m u o n o` vẫn sẽ ra **"muôn"**, `t u a n a` vẫn ra **"tuân"** chính xác.

### 🛠 Kỹ thuật
- Cập nhật hàm `handleModernMark` và `handleOldMark` để nhận diện hậu tố kéo dài.
- Nâng cấp `handleMainKey` với khả năng quét toàn bộ cụm nguyên âm để kiểm tra điều kiện đặt dấu.
