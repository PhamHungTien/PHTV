<div align="center">

# 📦 Hướng dẫn cài đặt PHTV

**Cài đặt bộ gõ tiếng Việt cho macOS trong 3 phút**

[🏠 Trang chủ](README.md) • [💬 FAQ](FAQ.md) • [🐛 Báo lỗi](../../issues)

</div>

---

## 🚀 Tải xuống

**[👉 Tải PHTV từ phamhungtien.com/PHTV](https://phamhungtien.com/PHTV/)**

## 📥 Cách cài đặt

### 🖼️ Hướng dẫn có ảnh

<div align="center">

**Bước 1: Tải về**
<img src="PHTV/Resources/Setup/step1-download.png" alt="Tải PHTV" width="70%">

**Bước 2: Mở ứng dụng**
<img src="PHTV/Resources/Setup/step2-open.png" alt="Mở PHTV" width="70%">

**Bước 3: Yêu cầu quyền**
<img src="PHTV/Resources/Setup/step3-permissions.png" alt="Yêu cầu Accessibility" width="70%">

**Bước 4: Cấp quyền Accessibility**
<img src="PHTV/Resources/Setup/step4-grant-access.png" alt="Cấp quyền" width="70%">

**Bước 5: Hoàn tất**
<img src="PHTV/Resources/Setup/step5-complete.png" alt="Hoàn tất cài đặt" width="70%">

</div>

---

### Option 1: Từ Website (Khuyến khích)

1. Tải từ [phamhungtien.com/PHTV](https://phamhungtien.com/PHTV/)
2. Drag `PHTV.app` vào `Applications`
3. Khởi động từ Launchpad hoặc Spotlight

### Option 2: Từ GitHub Releases

1. Vào [GitHub Releases](https://github.com/PhamHungTien/PHTV/releases)
2. Download `PHTV.dmg`
3. Double-click để mở DMG
4. Drag `PHTV.app` vào `Applications`

### Option 3: Từ Source Code

```bash
# Clone repository
git clone https://github.com/PhamHungTien/PHTV.git
cd PHTV

# Build với Xcode
xcodebuild -scheme PHTV -configuration Release -arch arm64 -arch x86_64

# App sẽ được build tại: build/Release/PHTV.app
```

## ⚙️ Yêu cầu hệ thống

- **macOS**: 14.0 hoặc cao hơn (Sonoma+)
- **Bộ xử lý**: Apple Silicon (M1/M2/M3) hoặc Intel
- **Dung lượng**: ~50 MB

## 🔧 Các bước sau khi cài

1. **Cấp quyền Accessibility** - App sẽ yêu cầu lần đầu
2. **Chọn phương pháp gõ** - Settings → Telex hoặc VNI
3. **Tùy chỉnh phím chuyển** - Settings → Keyboard Shortcuts (optional)
4. **Thêm Macros** - Settings → Macros (optional)

## 📖 Tài liệu

- [Hướng dẫn chi tiết](https://phamhungtien.com/PHTV/#setup) - Hình ảnh và video
- [Các tính năng](https://phamhungtien.com/PHTV/#features)
- [Liên hệ hỗ trợ](https://phamhungtien.com/PHTV/#feedback)

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
