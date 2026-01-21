# PHTV 1.9.8 - Sửa lỗi nhân đôi ký tự trên Safari

Bản cập nhật này sửa lỗi nhân đôi ký tự đầu khi gõ tiếng Việt trên thanh địa chỉ Safari.

### Sửa lỗi

*   **Sửa lỗi nhân đôi ký tự trên Safari address bar:** Khắc phục lỗi khi gõ các ký tự như `dd`, `aa`, `ee`... trên thanh địa chỉ Safari bị nhân đôi thành `dđ`, `aâ`, `eê`... thay vì ra đúng `đ`, `â`, `ê`.
    *   Nguyên nhân: Các phiên bản trước đã áp dụng chiến lược Shift+Left cho Safari, nhưng cách này không phù hợp với thanh địa chỉ Safari
    *   Giải pháp: Safari giờ sử dụng phương pháp `SendEmptyCharacter` tiêu chuẩn (như phiên bản 1.7.6)
    *   Chỉ các trình duyệt Chromium (Chrome, Edge, Brave...) mới sử dụng chiến lược Shift+Left

---

### Cách cập nhật
1.  Mở **PHTV Settings**.
2.  Chọn tab **Hệ thống** -> **Kiểm tra cập nhật**.
3.  Hoặc tải bản mới nhất tại: [GitHub Releases](https://github.com/PhamHungTien/PHTV/releases/latest)

---
*Cảm ơn bạn đã tin tưởng sử dụng PHTV! Nếu thấy hữu ích, hãy tặng cho dự án 1 ⭐ trên GitHub nhé.*
