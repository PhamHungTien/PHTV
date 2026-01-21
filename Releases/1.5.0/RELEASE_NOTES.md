# PHTV 1.5.0 Release Notes

## ✨ Tính năng mới

### Phát hiện bàn phím non-Latin nâng cao
PHTV giờ đây tự động phát hiện và xử lý **tất cả** các bàn phím non-Latin, không chỉ giới hạn ở Nhật/Trung/Hàn.

**Bàn phím được hỗ trợ:**

| Khu vực | Bàn phím |
| --- | --- |
| **Đông Á** | Japanese (Kotoeri, Google IME, ATOK), Chinese (SCIM, TCIM, Sogou, Baidu, QQ), Korean |
| **Trung Đông** | Arabic, Arabic PC, Hebrew, Hebrew QWERTY |
| **Nam Á** | Thai, Hindi, Devanagari, Tamil, Telugu, Kannada, Malayalam, Gujarati, Punjabi, Bengali, Oriya, Nepali, Sinhala |
| **Châu Âu (non-Latin)** | Greek, Greek Polytonic, Russian, Russian PC, Ukrainian, Bulgarian, Serbian, Macedonian |
| **Đông Nam Á** | Myanmar, Khmer, Lao |
| **Khác** | Georgian, Armenian, Tibetan, Emoji/Character Palette |

**Cách hoạt động:**
1. 🔄 Khi chuyển sang bàn phím non-Latin → PHTV tự động chuyển về **English**
2. ✅ Khi chuyển lại bàn phím Latin → PHTV tự động khôi phục **Vietnamese**
3. 📝 Log hiển thị tên bàn phím thực tế để dễ theo dõi

---

## 🗑️ Đã xóa

### Chromium Fix
Tính năng "Sửa lỗi Chromium" đã được xóa khỏi ứng dụng. Lý do:
- Gây ra nhiều lỗi hơn là giải quyết
- Cách tiếp cận Shift+Left thay vì Backspace không còn phù hợp với các phiên bản Chrome/Edge mới
- Người dùng không cần bật tính năng này để gõ tiếng Việt bình thường trong trình duyệt

### Thống kê gõ phím
Tính năng thống kê gõ phím (đếm từ, ký tự, biểu đồ 7 ngày) đã được xóa để đơn giản hóa ứng dụng và giảm memory usage.

---

## 🔧 Cải tiến

### Từ điển tiếng Anh
- Xóa từ "fpt" khỏi từ điển tiếng Anh để tránh nhận diện sai

### Code cleanup
- Xóa toàn bộ code liên quan đến Chromium Fix (UI, backend, settings)
- Xóa code thống kê gõ phím không sử dụng
- Cập nhật documentation

---

## 📋 Yêu cầu hệ thống

| Thành phần | Yêu cầu |
| --- | --- |
| **macOS** | 13.0+ (Ventura trở lên) |
| **Kiến trúc** | Universal Binary (Intel + Apple Silicon) |
| **Quyền** | Accessibility |

---

## 🔄 Nâng cấp

Nếu bạn đã cài đặt PHTV, ứng dụng sẽ tự động thông báo khi có bản cập nhật mới.

**Cài đặt mới qua Homebrew:**
```bash
brew install --cask phamhungtien/tap/phtv
```

**Cập nhật thủ công:**
```bash
brew upgrade --cask phtv
```

---

> *Phiên bản này tập trung vào việc mở rộng hỗ trợ đa ngôn ngữ và đơn giản hóa ứng dụng bằng cách xóa các tính năng ít sử dụng hoặc gây lỗi.*
