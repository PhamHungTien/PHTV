# FAQ - Câu hỏi thường gặp

## Cài đặt & Cấu hình

### Q1: PHTV có tương thích với phiên bản macOS nào?
**A:** PHTV hỗ trợ macOS 12.0+ (Monterey trở lên). Hoạt động tốt trên Apple Silicon (M1/M2/M3) và Intel Macs.

### Q2: Làm sao để chuyển đổi giữa tiếng Anh và tiếng Việt?
**A:** Nhấn phím tắt được cấu hình (mặc định `Cmd + Space` hoặc `Cmd + Option + Space`). Hoặc click vào Status Bar icon để chọn ngôn ngữ.

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

### Q5: Làm sao để tắt PHTV cho một ứng dụng cụ thể?
**A:** 
1. Mở Settings → Excluded Apps
2. Nhấn "+" và chọn ứng dụng
3. Khi sử dụng app đó, PHTV sẽ tự động tắt

### Q6: Macro (gõ tắt) hoạt động như thế nào?
**A:** 
1. Settings → Macros → "+"
2. Nhập từ viết tắt (VD: "tks") và nội dung (VD: "cảm ơn")
3. Khi gõ "tks" + Space, tự động thay thế bằng "cảm ơn"

### Q7: Có thể bỏ dấu khi gõ không?
**A:** Có! Gõ bình thường mà không cần phím dấu. Ví dụ:
- `ao` → `ào`, `áo`, `ảo`, v.v. (gõ thêm phím để thêm dấu)

### Q8: Làm sao để reset cài đặt về mặc định?
**A:** 
```bash
defaults delete com.phtv.app
```
Hoặc trong Settings → Reset All (nếu có button này).

---

## Tính năng & Hiệu năng

### Q9: PHTV tiêu thụ bao nhiêu tài nguyên?
**A:** Rất nhẹ!
- **CPU**: < 1% khi không dùng
- **Memory**: ~30-50 MB
- **Disk**: ~50 MB

### Q10: Có thể tùy chỉnh phím tắt được không?
**A:** Có! Settings → Keyboard Shortcuts
- Thay đổi phím chuyển ngôn ngữ
- Thay đổi phím gõ dấu (nếu cần)

### Q11: Ngoài tiếng Việt, có hỗ trợ ngôn ngữ khác không?
**A:** Hiện tại chỉ hỗ trợ tiếng Việt. Tiếng Anh là ngôn ngữ mặc định của hệ thống.

### Q12: Spell checking hoạt động như thế nào?
**A:** PHTV có từ điển tiếng Việt tích hợp:
- Tự động kiểm tra chính tả
- Gợi ý từ sai (khi bật tính năng này)
- Hỗ trợ cả từ địa phương

---

## Bảo mật & Quyền riêng tư

### Q13: PHTV có gửi dữ liệu gì lên internet không?
**A:** Không! PHTV hoàn toàn **offline**:
- Không có kết nối mạng
- Không thu thập dữ liệu người dùng
- Mã nguồn công khai trên GitHub

### Q14: Dữ liệu cài đặt được lưu ở đâu?
**A:** 
- **Local**: `~/Library/Preferences/com.phtv.app.plist`
- **Macros**: `~/Library/Application Support/PHTV/`
- Chỉ nằm trên máy của bạn

### Q15: Tại sao PHTV cần quyền "Accessibility"?
**A:** Cần quyền này để:
- Giám sát các phím bạn gõ
- Chuyển ngôn ngữ tự động
- Hoạt động trên mọi ứng dụng

Đây là yêu cầu chuẩn của macOS cho Input Methods.

---

## Vấn đề & Khắc phục

### Q16: PHTV bị crash/không phản hồi?
**A:** 
1. Restart ứng dụng bị lỗi
2. Tắt PHTV và bật lại: `Cmd + Space`
3. Nếu vẫn lỗi, gửi issue tới GitHub

### Q17: Phím tắt chuyển ngôn ngữ không hoạt động?
**A:**
1. Kiểm tra Settings → Keyboard Shortcuts
2. Kiểm tra System Preferences → Keyboard → Shortcuts
3. Tìm xung đột phím tắt với ứng dụng khác

### Q18: PHTV không xuất hiện trong Status Bar?
**A:**
1. Kiểm tra System Preferences → Security & Privacy → Accessibility
2. Thêm PHTV vào danh sách
3. Restart PHTV

### Q19: Tiếng Việt gõ ra không đúng?
**A:** 
- Kiểm tra Input Method được chọn (Telex/VNI/v.v.)
- Kiểm tra Character Set (Unicode/TCVN3/v.v.)
- Nếu dùng ứng dụng cũ, thử đổi Character Set

---

## Phát triển

### Q20: Làm sao để đóng góp vào dự án?
**A:** Xem [CONTRIBUTING.md](CONTRIBUTING.md)
1. Fork repository
2. Tạo branch cho feature/fix
3. Commit changes với message rõ ràng
4. Tạo Pull Request

### Q21: PHTV sử dụng động cơ gõ nào?
**A:** PHTV dựa trên engine từ [OpenKey](https://github.com/tuyenvm/OpenKey) - một dự án mã nguồn mở tiếng Việt lâu năm.

### Q22: Có thể sử dụng PHTV trên iOS/iPad không?
**A:** Hiện tại chỉ dành cho macOS. iOS Input Methods có hạn chế từ Apple, cần khảo sát kỹ.

---

## Liên hệ & Hỗ trợ

- **GitHub Issues**: [Report bugs](https://github.com/PhamHungTien/PHTV/issues)
- **Discussions**: [Thảo luận](https://github.com/PhamHungTien/PHTV/discussions)
- **Email**: Có thể thêm sau

---

**Cập nhật lần cuối**: 2025-12-15
