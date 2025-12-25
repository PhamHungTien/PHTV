<div align="center">

# FAQ - Câu hỏi thường gặp

**Giải đáp thắc mắc về PHTV — Precision Hybrid Typing Vietnamese**

[Trang chủ](README.md) • [Cài đặt](INSTALL.md) • [Đóng góp](CONTRIBUTING.md)

</div>

---

## Cài đặt & Cấu hình

### Q1: PHTV có tương thích với phiên bản macOS nào?

**A:** PHTV hỗ trợ macOS 14.0+ (Sonoma trở lên). Universal Binary - hoạt động trên cả Intel và Apple Silicon (M1/M2/M3/M4). Tương thích với mọi Mac chạy macOS 14.0+.

### Q2: Cách nào dễ nhất để cài đặt PHTV?

**A:** Dùng Homebrew (khuyến khích):

```bash
brew install --cask phamhungtien/phtv/phtv
```

**Ưu điểm:**
- Cài đặt tự động chỉ với 1 lệnh
- Cập nhật dễ dàng: `brew upgrade --cask phtv`
- Gỡ cài đặt sạch sẽ: `brew uninstall --cask phtv`

Hoặc tải trực tiếp từ [phamhungtien.com/PHTV](https://phamhungtien.com/PHTV/) hoặc [GitHub Releases](https://github.com/PhamHungTien/PHTV/releases).

### Q3: Làm sao để chuyển đổi giữa tiếng Anh và tiếng Việt?

**A:** Nhấn phím tắt được cấu hình (mặc định `Ctrl + Shift`). Hoặc click vào Status Bar icon để chọn ngôn ngữ.

### Q4: Phương pháp gõ nào phù hợp nhất?

**A:**

- **Telex**: Phổ biến, dễ học (ơ=ow, ư=uw, â=aa, v.v.)
- **VNI**: Gõ bằng số (1-9 cho các dấu)
- **Simple Telex 1/2**: Biến thể đơn giản của Telex

Hãy thử từng cái để tìm phù hợp nhất!

### Q5: Sử dụng font nào để xem tiếng Việt đúng nhất?

**A:** PHTV hỗ trợ mọi font tiêu chuẩn:

- **Unicode**: Mọi font hiện đại (khuyến khích)
- **TCVN3**: Các font cũ hơn
- **VNI Windows**: Nếu dùng các app cũ

---

## Sử dụng

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

### Q8: Có thể bỏ dấu khi gõ không?

**A:** Có! Gõ bình thường mà không cần phím dấu. Ví dụ:

- `ao` → `ào`, `áo`, `ảo`, v.v. (gõ thêm phím để thêm dấu)

### Q9: Làm sao để reset cài đặt về mặc định?

**A:**

```bash
defaults delete com.phtv.app
```

Hoặc trong Settings → Reset All (nếu có button này).

---

## Tính năng & Hiệu năng

### Q10: PHTV tiêu thụ bao nhiêu tài nguyên?

**A:** Rất nhẹ!

- **CPU**: < 1% khi không dùng
- **Memory**: ~30-50 MB
- **Disk**: ~50 MB

### Q11: Có thể tùy chỉnh phím tắt được không?

**A:** Có! Settings → Keyboard Shortcuts

- Thay đổi phím chuyển ngôn ngữ
- Thay đổi phím gõ dấu (nếu cần)

### Q12: Ngoài tiếng Việt, có hỗ trợ ngôn ngữ khác không?

**A:** Hiện tại chỉ hỗ trợ tiếng Việt. Tiếng Anh là ngôn ngữ mặc định của hệ thống.

### Q13: Spell checking hoạt động như thế nào?

**A:** PHTV có từ điển tiếng Việt tích hợp:

- Tự động kiểm tra chính tả
- Gợi ý từ sai (khi bật tính năng này)
- Hỗ trợ cả từ địa phương

---

## Bảo mật & Quyền riêng tư

### Q14: PHTV có gửi dữ liệu lên Internet không?

**A:** Không! Hoàn toàn offline, không kết nối mạng, không thu thập dữ liệu.

### Q15: Dữ liệu được lưu ở đâu?

**A:** Chỉ nằm trên máy của bạn:

- Settings: `~/Library/Preferences/com.phtv.app.plist`
- Macros: `~/Library/Application Support/PHTV/`

### Q16: Tại sao PHTV cần quyền Accessibility?

**A:** Để giám sát phím gõ, chuyển ngôn ngữ, hoạt động trên mọi ứng dụng. Yêu cầu chuẩn của macOS.

## Khắc phục sự cố

### Q17: PHTV không hoạt động?

**A:**

1. Kiểm tra quyền Accessibility
2. Tắt/bật lại PHTV
3. Restart ứng dụng gặp lỗi
4. Tạo issue trên GitHub

### Q18: Phím tắt không hoạt động?

**A:**

1. Kiểm tra Settings → Keyboard Shortcuts
2. Kiểm tra System Preferences → Keyboard → Shortcuts
3. Tìm xung đột với ứng dụng khác

### Q19: Tiếng Việt gõ ra sai?

**A:** Kiểm tra Input Method (Telex/VNI) và Character Set (Unicode/TCVN3).

## Phát triển

### Q20: Làm sao để đóng góp?

**A:** Xem [CONTRIBUTING.md](CONTRIBUTING.md) - Fork, tạo branch, commit, PR.

### Q21: Engine gõ là gì?

**A:** Dựa trên [OpenKey](https://github.com/tuyenvm/OpenKey) - dự án mã nguồn mở tiếng Việt.

---

<div align="center">

## Vẫn có câu hỏi?

[![GitHub Discussions](https://img.shields.io/badge/GitHub-Discussions-green?logo=github)](../../discussions)
[![Email](https://img.shields.io/badge/Email-hungtien10a7@gmail.com-blue?logo=gmail)](mailto:hungtien10a7@gmail.com)

[Trang chủ](README.md) • [Cài đặt](INSTALL.md) • [Báo lỗi](../../issues)

</div>
