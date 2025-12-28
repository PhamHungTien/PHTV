## PHTV 1.2.8 - Spotlight Detection & Beautiful DMG Installer

### 🔍 Cải tiến phát hiện Spotlight
**Vấn đề**: PHTV đôi khi không kịp chuyển sang tiếng Anh khi mở Spotlight, gây gõ lỗi.

**Giải pháp**:
- ⚡ Phát hiện Cmd+Space ngay lập tức → Invalidate cache trong 0ms
- 🎯 Element heuristic check: Phân tích role/subrole của UI element
- 🔄 Retry mechanism: Thử lại 3 lần (0ms, 3ms, 8ms) khi AX API fails
- ⏱️ Giảm latency: Cache time từ 50ms → 15ms

**Kết quả**: Phát hiện Spotlight **nhanh gấp 3 lần**, không còn gõ nhầm tiếng Việt trong tìm kiếm!

### 📦 DMG Installer đẹp mắt
- ✨ Custom background image với giao diện chuyên nghiệp
- 📂 Applications shortcut: Kéo thả PHTV.app vào Applications dễ dàng
- 🎨 Icon layout tối ưu và thẩm mỹ

### 🐛 Sửa lỗi & Tối ưu
- Fix Spotlight detection với custom hotkeys
- Cải thiện độ ổn định khi switch apps nhanh
- Giảm CPU usage và memory leak

---

## 📥 Cài đặt

**Homebrew** (khuyên dùng):
```bash
brew install --cask phamhungtien/tap/phtv
```

**Tải trực tiếp**: Download **PHTV-1.2.8.dmg** ⬇️

---

## 🔧 Yêu cầu
- macOS 14.0+ (Sonoma)
- Universal Binary (Intel + Apple Silicon)
- Accessibility permission

---

**Full Changelog**: https://github.com/PhamHungTien/PHTV/compare/v1.2.7...v1.2.8

Made with ❤️ for Vietnamese macOS users
