<div align="center">

# ❓ FAQ - Câu hỏi thường gặp

**Giải đáp thắc mắc về PHTV**

[🏠 Trang chủ](README.md) • [📦 Cài đặt](INSTALL.md) • [🤝 Đóng góp](CONTRIBUTING.md)

</div>

---

## 📥 Cài đặt & Cấu hình

### Q1: PHTV có tương thích với phiên bản macOS nào?

**A:** PHTV hỗ trợ macOS 14.0+ (Sonoma trở lên). Hoạt động tốt trên Apple Silicon (M1/M2/M3) và Intel Macs.

### Q2: Làm sao để chuyển đổi giữa tiếng Anh và tiếng Việt?

**A:** Nhấn phím tắt được cấu hình (mặc định `Ctrl + Shift`). Hoặc click vào Status Bar icon để chọn ngôn ngữ.

### Q3: Phương pháp gõ nào phù hợp nhất?

**A:**

- **Telex**: Phổ biến, dễ học (ơ=o, ư=u, ư=uw, v.v.)
- **VNI**: Gõ bằng số (1-9 cho các dấu)
- **Simple Telex 1/2**: Biến thể đơn giản của Telex

Hãy thử từng cái để tìm phù hợp nhất!

### Q4: Sử dụng font nào để xem tiếng Việt đúng nhất?

**A:** PHTV hỗ trợ mọi font tiêu chuẩn:

- **Unicode**: Mọi font hiện đại (khuyến khích)
- **TCVN3**: Các font cũ hơn
- **VNI Windows**: Nếu dùng các app cũ

---

## Sử dụng

### Q5: Phím khôi phục là gì và cách sử dụng?

**A:** Phím khôi phục giúp chuyển văn bản tiếng Việt về ASCII gốc (VD: "úẻ" → "user").

1. Mở Settings → Typing → Restore Key Settings
2. Chọn phím: **ESC**, **Option**, hoặc **Control**
3. Nhấn phím đã chọn để khôi phục văn bản vừa gõ

**Lưu ý**: Nếu chọn Option/Control làm phím khôi phục mà cũng dùng làm phím tắt chuyển chế độ, hệ thống sẽ cảnh báo xung đột.

### Q6: Làm sao để tắt PHTV cho một ứng dụng cụ thể?

**A:**

1. Mở Settings → Excluded Apps
2. Nhấn "+" và chọn ứng dụng
3. Khi sử dụng app đó, PHTV sẽ tự động tắt

### Q7: Macro (gõ tắt) hoạt động như thế nào?

**A:**

1. Settings → Macros → "+"
2. Nhập từ viết tắt (VD: "tks") và nội dung (VD: "cảm ơn")
3. Khi gõ "tks" + Space, tự động thay thế bằng "cảm ơn"

### Q8: Cảnh báo xung đột phím là gì?

**A:** Khi phím khôi phục trùng với phím tắt chuyển chế độ, PHTV sẽ hiển thị cảnh báo màu cam:

- **VD**: Chọn Option làm phím khôi phục + bật Option trong phím tắt chuyển chế độ
- **Giải pháp**: Đổi phím khôi phục hoặc đổi phím tắt để tránh xung đột

### Q9: Có thể bỏ dấu khi gõ không?

**A:** Có! Gõ bình thường mà không cần phím dấu. Ví dụ:

- `ao` → `ào`, `áo`, `ảo`, v.v. (gõ thêm phím để thêm dấu)

### Q10: Làm sao để điều chỉnh kích cỡ icon trên thanh menu?

**A:**

1. Settings → System → Menu Bar Icon Size
2. Kéo thanh trượt để điều chỉnh từ 12-20 px
3. Thay đổi áp dụng ngay lập tức

### Q11: Làm sao để reset cài đặt về mặc định?

**A:**

```bash
defaults delete com.phtv.app
```

Hoặc trong Settings → System → Reset Settings.

---

## Tính năng & Hiệu năng

### Q12: PHTV tiêu thụ bao nhiêu tài nguyên?

**A:** Rất nhẹ!

- **CPU**: < 1% khi không dùng
- **Memory**: ~30-50 MB
- **Disk**: ~50 MB

### Q13: Có thể tùy chỉnh phím tắt được không?

**A:** Có! Settings → Hotkey

- Thay đổi phím chuyển ngôn ngữ (Ctrl/Shift/Option/Command)
- Hệ thống tự động cảnh báo nếu xung đột với phím khôi phục

### Q14: Ngoài tiếng Việt, có hỗ trợ ngôn ngữ khác không?

**A:** Hiện tại chỉ hỗ trợ tiếng Việt. Tiếng Anh là ngôn ngữ mặc định của hệ thống.

### Q15: Spell checking hoạt động như thế nào?

**A:** PHTV có từ điển tiếng Việt tích hợp:

- Tự động kiểm tra chính tả
- Gợi ý từ sai (khi bật tính năng này)
- Hỗ trợ cả từ địa phương

---

## Bảo mật & Quyền riêng tư

### Q16: PHTV có gửi dữ liệu lên Internet không?

**A:** Không! Hoàn toàn offline, không kết nối mạng, không thu thập dữ liệu.

### Q17: Dữ liệu được lưu ở đâu?

**A:** Chỉ nằm trên máy của bạn:

- Settings: `~/Library/Preferences/com.phtv.app.plist`
- Macros: `~/Library/Application Support/PHTV/`

### Q18: Tại sao PHTV cần quyền Accessibility?

**A:** Để giám sát phím gõ, chuyển ngôn ngữ, hoạt động trên mọi ứng dụng. Yêu cầu chuẩn của macOS.

---

## Khắc phục sự cố

### Q19: PHTV không hoạt động?

**A:**

1. Kiểm tra quyền Accessibility
2. Tắt/bật lại PHTV
3. Restart ứng dụng gặp lỗi
4. Tạo issue trên GitHub

### Q20: Phím tắt không hoạt động?

**A:**

1. Kiểm tra Settings → Hotkey
2. Kiểm tra System Preferences → Keyboard → Shortcuts
3. Xem cảnh báo xung đột (nếu có)
4. Thử đổi tổ hợp phím khác

### Q21: Tiếng Việt gõ ra sai?

**A:** Kiểm tra Input Method (Telex/VNI) và Character Set (Unicode/TCVN3).

---

## Phát triển

### Q22: Làm sao để đóng góp?

**A:** Xem [CONTRIBUTING.md](CONTRIBUTING.md) - Fork, tạo branch, commit, PR.

### Q23: Engine gõ là gì?

**A:** Dựa trên [OpenKey](https://github.com/tuyenvm/OpenKey) - dự án mã nguồn mở tiếng Việt.

---

<div align="center">

## 💬 Vẫn có câu hỏi?

[![GitHub Discussions](https://img.shields.io/badge/GitHub-Discussions-green?logo=github)](../../discussions)
[![Email](https://img.shields.io/badge/Email-hungtien10a7@gmail.com-blue?logo=gmail)](mailto:hungtien10a7@gmail.com)

[🏠 Trang chủ](README.md) • [📦 Cài đặt](INSTALL.md) • [🐛 Báo lỗi](../../issues)

</div>
