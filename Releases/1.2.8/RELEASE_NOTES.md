# PHTV 1.2.8 - Spotlight Detection & DMG Installer Enhancement

## 🎯 Cải tiến chính

### 🔍 Tối ưu hóa phát hiện Spotlight
**Vấn đề cũ:** PHTV đôi khi không kịp chuyển sang tiếng Anh khi mở Spotlight, gây ra lỗi gõ tiếng Việt trong tìm kiếm.

**Giải pháp mới:**
- **Phát hiện Cmd+Space ngay lập tức**: Invalidate cache ngay khi nhấn Cmd+Space để phát hiện Spotlight nhanh nhất
- **Aggressive cache invalidation**: Tự động làm mới cache khi modifier keys thay đổi (Cmd, Alt, Ctrl)
- **Element heuristic check**: Phân tích role/subrole của AXUIElement để nhận diện chính xác Spotlight search field
- **Retry mechanism**: Thử lại tối đa 3 lần với delays (0ms, 3ms, 8ms) khi AX API fails
- **Giảm latency**: Cache time giảm từ 50ms → 15ms để responsive hơn

**Kết quả:**
- ✅ Phát hiện Spotlight mở/đóng nhanh gấp 3 lần
- ✅ Tự động chuyển sang tiếng Anh khi mở Spotlight
- ✅ Không còn gõ nhầm tiếng Việt trong Spotlight search

### 📦 DMG Installer đẹp mắt
- **Applications shortcut**: Kéo thả PHTV.app vào Applications dễ dàng
- **Custom background image**: Giao diện cài đặt chuyên nghiệp và đẹp mắt
- **Icon layout tối ưu**: Sắp xếp icon PHTV.app và Applications folder hợp lý

### 🐛 Sửa lỗi
- Khắc phục lỗi Spotlight detection không hoạt động với custom hotkeys
- Cải thiện độ ổn định khi switch giữa nhiều ứng dụng nhanh
- Fix memory leak trong AXUIElement operations

### ⚡ Hiệu năng
- Giảm CPU usage khi kiểm tra Spotlight
- Tối ưu AX API calls với retry logic thông minh
- Cải thiện response time tổng thể

---

## 📥 Cài đặt

### Homebrew (khuyên dùng)
```bash
# Cài mới
brew install --cask phamhungtien/tap/phtv

# Hoặc cập nhật
brew upgrade --cask phtv
```

### Tải trực tiếp
1. Tải file **PHTV-1.2.8.dmg** bên dưới
2. Mở DMG và kéo PHTV.app vào Applications
3. Mở PHTV và cấp quyền Accessibility

---

## 🔧 Yêu cầu hệ thống
- **macOS**: 14.0+ (Sonoma)
- **Kiến trúc**: Universal Binary (Intel + Apple Silicon)
- **Quyền**: Accessibility permission

---

## 📝 Chi tiết kỹ thuật

### Spotlight Detection Architecture
```
Event Loop
  └─> Detect Cmd+Space keypress
      └─> Invalidate cache immediately
          └─> Check focused UI element (3 retries)
              ├─> Heuristic: Check role/subrole
              └─> Fallback: Check bundle ID
                  └─> Switch to English if Spotlight
```

### File Changes
- `PHTV/Managers/PHTV.mm`: Improved Spotlight detection logic (+131 lines)
- `docs/appcast.xml`: Updated with new release
- `PHTV/Info.plist`: Version bump to 1.2.8
- DMG installer: New background image and layout

---

## 🙏 Ghi nhận
Cảm ơn cộng đồng đã báo lỗi về Spotlight detection. Bản cập nhật này khắc phục hoàn toàn vấn đề này!

## 🔗 Liên kết
- **Website**: [phamhungtien.com/PHTV](https://phamhungtien.com/PHTV/)
- **GitHub**: [github.com/PhamHungTien/PHTV](https://github.com/PhamHungTien/PHTV)
- **Báo lỗi**: [Issues](https://github.com/PhamHungTien/PHTV/issues)
- **Ủng hộ**: [Donate](https://phamhungtien.com/PHTV/donate.html)

---

**Full Changelog**: [v1.2.7...v1.2.8](https://github.com/PhamHungTien/PHTV/compare/v1.2.7...v1.2.8)
