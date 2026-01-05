# PHTV 1.5.2 Release Notes

## 🐛 Sửa lỗi

### Khôi phục pattern tiếng Việt ngắn
- Sửa lỗi các từ tiếng Việt ngắn (2-3 ký tự) bị nhận diện sai là tiếng Anh
- **`ơn`** (`own`) giờ được nhận diện đúng là tiếng Việt
- Chỉ loại bỏ pattern >= 4 ký tự trùng với từ tiếng Anh
- Các âm tiết đơn như `ơn`, `ăn`, `ân`, `ên`, `ôn` hoạt động chính xác

**Ví dụ đã sửa:**
| Gõ | Trước (1.5.1) | Sau (1.5.2) |
| --- | --- | --- |
| `o` `w` `n` + space | own ❌ | ơn ✅ |

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

> *Phiên bản này sửa lỗi quan trọng về nhận diện từ tiếng Việt ngắn.*
