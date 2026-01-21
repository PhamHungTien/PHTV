# PHTV 1.5.3 Release Notes

## 🐛 Sửa lỗi

### Sửa lỗi gõ tiếng Việt bị chuyển thành tiếng Anh
- **Gõ "ắ" → "aws"**: Sửa lỗi khi bật "Tự động khôi phục tiếng Anh", các nguyên âm có dấu thanh bị nhận diện sai là từ tiếng Anh
- Thêm kiểm tra nguyên âm tiếng Việt (a, e, i, o, u, y) - nếu có dấu thanh thì không khôi phục tiếng Anh

### Sửa lỗi phím "ê" mở bảng Emoji hệ thống
- **Gõ "ê" hoặc "eee"**: Sửa lỗi phím tắt synthetic có cờ Fn/Globe khiến macOS mở Character Viewer
- Xóa cờ `kCGEventFlagMaskSecondaryFn` trong tất cả synthetic keyboard events

### Sửa lỗi phím Tạm dừng ảnh hưởng đến phím tắt hệ thống
- **Phím tắt Option+Cmd+V** (hoặc các tổ hợp phím khác có Option): Sửa lỗi khi dùng Option làm phím tạm dừng, các phím tắt hệ thống bị hỏng
- Chỉ loại bỏ modifier của phím tạm dừng khi không có modifier khác được nhấn

### Sửa lỗi cửa sổ Cài đặt bị ẩn khi mất focus
- Cửa sổ cài đặt không còn tự động ẩn khi click ra ngoài
- Tạm thời hiển thị dock icon khi cửa sổ cài đặt đang mở
- Khôi phục dock icon về tùy chọn của người dùng khi đóng cửa sổ

---

## ✨ Tính năng mới

### PHTV Picker nhớ vị trí emoji sub-category
- Khi mở lại PHTV Picker, emoji tab sẽ nhớ sub-category đã chọn (Smileys, Animals, Food, v.v.)
- Tự động scroll đến tab đã lưu

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

## 📝 Chi tiết kỹ thuật

### Sửa lỗi "ắ" → "aws"
- Vị trí: `EnglishWordDetector.cpp`, function `shouldRestoreEnglish()`
- Thêm hàm `isVietnameseVowel()` kiểm tra nguyên âm a, e, i, o, u, y
- Logic: Nếu ký tự cuối là nguyên âm tiếng Việt CÓ dấu thanh → không restore tiếng Anh

### Sửa lỗi phím "ê" mở Emoji
- Vị trí: `PHTV.mm`, các function `SendKeyCode()`, `ApplyKeyboardTypeAndFlags()`, `SendBackspace()`, `SendNewCharString()`
- Xóa cờ `kCGEventFlagMaskSecondaryFn` khỏi `_privateFlag` trước khi gửi synthetic events

### Sửa lỗi phím tạm dừng
- Vị trí: `PHTV.mm`, function `StripPauseModifier()`
- Chỉ strip modifier khi `(flags & OTHER_MODIFIERS) == 0`

### Sửa lỗi cửa sổ cài đặt
- Sử dụng NotificationCenter để giao tiếp giữa Swift và Objective-C
- Thêm `settingsWindowOpen` flag để track trạng thái cửa sổ
- Sử dụng `orderFrontRegardless()` để đảm bảo cửa sổ ở trên cùng

---

> *Phiên bản này sửa nhiều lỗi quan trọng về gõ tiếng Việt và cải thiện trải nghiệm người dùng với cửa sổ cài đặt.*
