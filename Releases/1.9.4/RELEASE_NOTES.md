# PHTV 1.9.4 - Sửa lỗi gõ nguyên âm kéo dài

Bản cập nhật này khắc phục lỗi quan trọng khi gõ các nguyên âm kéo dài sau từ đã có dấu.

### 🐛 Sửa lỗi

*   **Giữ đúng dấu khi gõ nguyên âm kéo dài:** Khắc phục lỗi mất dấu hoặc dấu nhảy sai vị trí khi gõ thêm nguyên âm giống nhau sau từ đã có dấu.
    *   `nữa` + `aa` → `nữaaa` (trước đây bị thành `nũaa`)
    *   `nhé` + `ee` → `nhéeee` (trước đây bị thành `nheée`)
    *   `á` + `aa` → `áaaa` (trước đây bị thành `aáa`)
    *   Tương tự với các từ khác như `hảaa`, `hõoo`...

*   **Cải thiện nhận diện từ tiếng Anh:** Tối ưu auto-restore cho các từ như `case`, `term`, `follower` không bị chuyển thành tiếng Việt.

---

### 🚀 Cách cập nhật
1.  Mở **PHTV Settings**.
2.  Chọn tab **Hệ thống** -> **Kiểm tra cập nhật**.
3.  Hoặc tải bản mới nhất tại: [GitHub Releases](https://github.com/PhamHungTien/PHTV/releases/latest)

---
*Cảm ơn bạn đã tin tưởng sử dụng PHTV! Nếu thấy hữu ích, hãy tặng cho dự án 1 ⭐ trên GitHub nhé.*
