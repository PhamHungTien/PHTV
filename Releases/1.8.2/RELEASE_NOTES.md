# PHTV 1.8.2 - Sửa lỗi Safari trên Google Docs/Sheets

Bản cập nhật này khắc phục lỗi gõ tiếng Việt trên Safari khi sử dụng Google Docs và Google Sheets.

### 🍎 Sửa lỗi Safari (Critical Fix)
*   **Vấn đề:** Khi gõ tiếng Việt trên Safari với Google Docs/Sheets, các ký tự bị mất hoặc hiển thị sai vị trí. Ví dụ: gõ "Chào mừng các bạn đã đến với Việt Nam" nhưng hiển thị "chào mừng các bạn đã đế ớ it Nam".
*   **Nguyên nhân:** Safari (WebKit) xử lý ký tự khác với Chromium (Blink). Việc gửi nhiều ký tự cùng lúc (batch posting) gây ra race condition trong rendering engine của Safari.
*   **Khắc phục:** Safari giờ đây sử dụng phương pháp gửi từng ký tự một (step-by-step sending) thay vì gửi cả chuỗi, đảm bảo WebKit xử lý đúng thứ tự các ký tự tiếng Việt.

### 🔧 Cải tiến kỹ thuật
*   Thêm Safari vào danh sách `stepByStepAppSet` để xử lý riêng biệt
*   Thêm Safari vào `unicodeCompoundAppSet` để xử lý backspace chính xác
*   Cập nhật UI Settings để phản ánh hỗ trợ Safari trong tính năng "Sửa lỗi Browser"
*   Thêm flag `isSafari` vào `AppCharacteristics` cho tối ưu hóa tương lai

### 📝 Lưu ý
*   Chromium-based browsers (Chrome, Edge, Brave...) vẫn sử dụng batch posting (nhanh hơn)
*   Safari sử dụng step-by-step sending (ổn định hơn cho Google Docs/Sheets)
*   Không ảnh hưởng đến hiệu năng gõ trên các ứng dụng khác
