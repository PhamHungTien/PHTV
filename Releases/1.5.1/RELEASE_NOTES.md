# PHTV 1.5.1 Release Notes

## ✨ Tính năng mới

### PHTV Picker ghi nhớ tab gần nhất
PHTV Picker (Emoji, GIF, Sticker) giờ đây sẽ **ghi nhớ tab** bạn đã sử dụng lần trước và tự động mở đúng tab đó khi bạn mở lại.

**Các tab được ghi nhớ:**
- 🌟 Tất cả
- 😀 Emoji  
- 🎬 GIF
- ✨ Sticker

---

## 🔧 Cải tiến

### Từ điển tiếng Anh tối ưu hóa
- **Giảm 48%** số từ trong từ điển (10,537 → 5,493 từ)
- **Giảm 35%** dung lượng file (2.7MB → 1.75MB)
- Chỉ giữ lại những từ có **xung đột Telex** (chứa `aa`, `ee`, `oo`, `aw`, `ow`, `uw`, `dd`, hoặc nguyên âm + `s/f/r/x/j`)
- Các từ không có xung đột như `hello`, `popup`, `signin` được loại bỏ vì không cần nhận diện

### Từ điển tiếng Việt thông minh hơn
- Loại bỏ **424 pattern** trùng với từ tiếng Anh
- Từ như `telex`, `access`, `tex` giờ được nhận diện chính xác là tiếng Anh
- Ưu tiên tiếng Việt vẫn được giữ nguyên cho các từ thuần Việt

### Chuyển hướng website
- Trang `phamhungtien.github.io/PHTV` giờ chuyển tiếp tức thì đến `phamhungtien.com/PHTV`

---

## 🐛 Sửa lỗi

### Tương thích macOS 13
- Sửa lỗi `onChange(of:initial:_:)` chỉ khả dụng trên macOS 14+
- PHTV Picker giờ hoạt động đúng trên macOS 13 Ventura

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

> *Phiên bản này tập trung vào việc tối ưu hóa từ điển và cải thiện trải nghiệm PHTV Picker.*
