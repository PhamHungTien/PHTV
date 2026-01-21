# PHTV 1.9.5 - Sửa lỗi mất cấu hình sau khởi động lại

Bản cập nhật này khắc phục lỗi quan trọng khiến các cấu hình bị reset về mặc định sau khi khởi động lại máy hoặc wake from sleep.

### 🐛 Sửa lỗi

*   **Giữ nguyên cấu hình sau restart/wake:** Khắc phục lỗi mất các thiết lập đã cài đặt khi khởi động lại máy hoặc quay trở lại sau khi sleep.
    *   Trước đây: Các cấu hình như kiểu gõ (Telex/VNI), bật/tắt tiếng Việt, bảng mã... bị reset về mặc định sau mỗi lần khởi động lại.
    *   Bây giờ: Tất cả cấu hình được lưu và khôi phục đúng, bao gồm:
        *   Bật/tắt tiếng Việt
        *   Kiểu gõ (Telex, VNI, Simple Telex)
        *   Bảng mã (Unicode, TCVN, VNI Windows)
        *   Kiểm tra chính tả
        *   Chính tả hiện đại
        *   Quick Telex
        *   Smart Switch Key
        *   Và tất cả các tùy chọn khác...

---

### 🚀 Cách cập nhật
1.  Mở **PHTV Settings**.
2.  Chọn tab **Hệ thống** -> **Kiểm tra cập nhật**.
3.  Hoặc tải bản mới nhất tại: [GitHub Releases](https://github.com/PhamHungTien/PHTV/releases/latest)

---
*Cảm ơn bạn đã tin tưởng sử dụng PHTV! Nếu thấy hữu ích, hãy tặng cho dự án 1 ⭐ trên GitHub nhé.*
