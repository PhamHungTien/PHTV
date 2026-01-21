# PHTV 1.5.2 Release Notes

## 🐛 Sửa lỗi

### Khôi phục toàn bộ pattern tiếng Việt
- Sửa lỗi các từ tiếng Việt bị nhận diện sai là tiếng Anh
- **Giữ nguyên tất cả** pattern tiếng Việt trong từ điển, không loại bỏ bất kỳ pattern nào
- Logic runtime sẽ ưu tiên tiếng Việt khi gõ

**Các từ đã sửa:**
| Gõ Telex | Trước (1.5.1) | Sau (1.5.2) |
| --- | --- | --- |
| `o` `w` `n` | own ❌ | ơn ✅ |
| `b` `e` `e` `n` | been ❌ | bên ✅ |
| `b` `e` `e` `f` | beef ❌ | bề ✅ |
| `b` `e` `e` `r` | beer ❌ | bể ✅ |
| `s` `o` `o` `n` | soon ❌ | sôn ✅ |
| `t` `e` `e` `n` | teen ❌ | tên ✅ |
| `s` `e` `e` `n` | seen ❌ | sên ✅ |

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

> *Phiên bản này sửa lỗi quan trọng về nhận diện từ tiếng Việt trong chức năng tự động nhận diện tiếng Anh.*
