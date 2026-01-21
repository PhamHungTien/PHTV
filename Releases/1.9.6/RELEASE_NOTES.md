# PHTV 1.9.6 - Cải thiện bỏ dấu cho chữ kéo dài

Bản cập nhật này cải thiện việc đặt dấu cho các nguyên âm lặp lại liên tiếp (extended vowels).

### Cải tiến

*   **Bỏ dấu đúng vị trí cho chữ kéo dài:** Khi gõ các nguyên âm lặp lại sau khi đã bỏ dấu, dấu sẽ được giữ nguyên ở nguyên âm đầu tiên.
    *   Trước đây: "nhe" + "s" + "ee" => "nheée" (dấu bị dịch chuyển sai)
    *   Bây giờ: "nhe" + "s" + "ee" => "nhéee" (dấu giữ đúng vị trí)
    *   Ví dụ khác:
        *   "a" + "s" + "aa" => "áaa" (trước đây là "aáa")
        *   "nhe" + "r" + "ee" => "nhẻee"
        *   "a" + "x" + "aaa" => "ãaaa"

---

### Cách cập nhật
1.  Mở **PHTV Settings**.
2.  Chọn tab **Hệ thống** -> **Kiểm tra cập nhật**.
3.  Hoặc tải bản mới nhất tại: [GitHub Releases](https://github.com/PhamHungTien/PHTV/releases/latest)

---
*Cảm ơn bạn đã tin tưởng sử dụng PHTV! Nếu thấy hữu ích, hãy tặng cho dự án 1 trên GitHub nhé.*
