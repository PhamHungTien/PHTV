# PHTV Installation Guide

## 🚀 Cách cài đặt PHTV

### Option 1: Download DMG trực tiếp (Khuyến khích)

1. Vào [GitHub Releases](https://github.com/PhamHungTien/PHTV/releases)
2. Download file `PHTV_1.0.0.dmg`
3. Double-click để mở DMG
4. Drag `PHTV.app` vào folder `Applications`
5. Khởi động từ Launchpad hoặc Spotlight (Cmd + Space)

### Option 2: Homebrew Cask (Coming soon)

```bash
brew tap phamhungtien/phtv https://github.com/PhamHungTien/PHTV.git
brew install --cask phtv
```

Hoặc khi được thêm vào chính thức Homebrew Casks:
```bash
brew install --cask phtv
```

### Option 3: Từ Source Code

```bash
# Clone repository
git clone https://github.com/PhamHungTien/PHTV.git
cd PHTV

# Build với Xcode
xcodebuild -scheme PHTV -configuration Release -arch arm64 -arch x86_64

# App sẽ được build tại: build/Release/PHTV.app
```

---

## ⚙️ Yêu cầu hệ thống

- **macOS**: 12.0 hoặc cao hơn
- **Bộ xử lý**: Apple Silicon (M1/M2/M3) hoặc Intel
- **Dung lượng**: ~50 MB

---

## 🔧 Cách sử dụng

### Bật/Tắt tiếng Việt
- Nhấn phím tắt mặc định: `Cmd + Space` (hoặc tùy chỉnh)
- Hoặc click vào Status Bar icon → chọn ngôn ngữ

### Thay đổi phương pháp gõ
1. Click Status Bar icon → Settings
2. Chọn Input Method: Telex, VNI, Simple Telex 1/2
3. Chọn Character Set: Unicode, TCVN3, VNI Windows, v.v.

### Quản lý Macros (Gõ tắt)
1. Mở Settings → Macros
2. Nhấn "+" để thêm macro mới
3. Nhập từ viết tắt và nội dung

### Loại trừ ứng dụng
1. Settings → Excluded Apps
2. Nhấn "+" và chọn ứng dụng muốn tắt tiếng Việt

---

## 🆘 Xử lý sự cố

### PHTV không hoạt động

**Kiểm tra**:
1. Đảm bảo đã bật PHTV trong Language Settings
2. Restart app gặp vấn đề
3. Kiểm tra System Preferences → Security & Privacy → Accessibility

**Bật quyền truy cập**:
```bash
# Yêu cầu password admin
sudo defaults write com.apple.universalaccess enabled -bool true
```

### Ứng dụng không mở

Nếu macOS cảnh báo app chưa được xác thực:
1. Mở Finder → Applications
2. Right-click PHTV.app → Open
3. Nhấn "Open" khi được hỏi

---

## 📝 License

GNU General Public License v3.0 - xem [LICENSE](../LICENSE)

## 🔗 Liên kết

- GitHub: https://github.com/PhamHungTien/PHTV
- Issues: https://github.com/PhamHungTien/PHTV/issues
- Discussions: https://github.com/PhamHungTien/PHTV/discussions

