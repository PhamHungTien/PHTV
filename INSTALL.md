<div align="center">

# Hướng dẫn cài đặt PHTV

**PHTV — Precision Hybrid Typing Vietnamese | Cài đặt bộ gõ tiếng Việt cho macOS trong 3 phút**

[Trang chủ](README.md) • [FAQ](FAQ.md) • [Báo lỗi](../../issues)

</div>

---

## Tải xuống

**[Tải PHTV từ phamhungtien.com/PHTV](https://phamhungtien.com/PHTV/)**

## Cách cài đặt

### Hướng dẫn có ảnh

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

### Option 1: Homebrew (Khuyến khích - Dễ nhất)

```bash
brew install --cask phamhungtien/tap/phtv
```

**Ưu điểm:**
- Cài đặt tự động, chỉ cần 1 lệnh
- Dễ dàng cập nhật: `brew upgrade --cask phtv`
- Gỡ cài đặt sạch sẽ: `brew uninstall --cask phtv`

### Option 2: Từ Website

1. Tải từ [phamhungtien.com/PHTV](https://phamhungtien.com/PHTV/)
2. Mở file `.dmg`
3. Drag `PHTV.app` vào `Applications`
4. Khởi động từ Launchpad hoặc Spotlight

### Option 3: Từ GitHub Releases

1. Vào [GitHub Releases](https://github.com/PhamHungTien/PHTV/releases)
2. Download `PHTV-1.2.6.dmg`
3. Double-click để mở DMG
4. Drag `PHTV.app` vào `Applications`

### Option 4: Từ Source Code

```bash
# Clone repository
git clone https://github.com/PhamHungTien/PHTV.git
cd PHTV

# Build với Xcode (yêu cầu Xcode 26.0+)
# Universal Binary - hỗ trợ cả Intel và Apple Silicon
xcodebuild -scheme PHTV -configuration Release

# App sẽ được build tại: build/Release/PHTV.app
```

## Yêu cầu hệ thống

- **macOS**: 14.0 hoặc cao hơn (Sonoma+)
- **Bộ xử lý**: Universal Binary - Intel và Apple Silicon (M1/M2/M3/M4)
- **Xcode**: 26.0+ (nếu build từ source)
- **Dung lượng**: ~50 MB

> **Lưu ý**: PHTV là Universal Binary, hỗ trợ cả Intel và Apple Silicon. Hoạt động tốt trên mọi Mac chạy macOS 14.0+.

## Các bước sau khi cài

1. **Cấp quyền Accessibility** - App sẽ yêu cầu lần đầu
2. **Chọn phương pháp gõ** - Settings → Telex hoặc VNI
3. **Tùy chỉnh phím chuyển** - Settings → Keyboard Shortcuts (optional)
4. **Thêm Macros** - Settings → Macros (optional)

## Tài liệu thêm

- [Hướng dẫn chi tiết](https://phamhungtien.com/PHTV/#setup) - Video & Screenshots
- [Các tính năng](README.md#tính-năng)
- [FAQ](FAQ.md) - Câu hỏi thường gặp
- [Đóng góp](CONTRIBUTING.md)

---

## Xử lý sự cố

<details>
<summary><b>PHTV không hoạt động</b></summary>

**Kiểm tra:**

1. Đảm bảo đã cấp quyền **Accessibility**
2. Restart PHTV từ menu bar (Quit → Reopen)
3. Kiểm tra **System Settings > Privacy & Security > Accessibility**

</details>

<details>
<summary><b>Không gõ được tiếng Việt</b></summary>

**Giải pháp:**

1. Click icon PHTV trên menu bar
2. Đảm bảo chọn "**Tiếng Việt**" (không phải English)
3. Kiểm tra phương pháp gõ (Telex/VNI)

</details>

<details>
<summary><b>Phím tắt không hoạt động</b></summary>

**Kiểm tra:**

1. Settings → System → Hotkey Configuration
2. Đảm bảo không trùng với phím tắt khác trong macOS
3. Thử đổi sang tổ hợp phím khác

</details>

---

<div align="center">

**Vẫn gặp vấn đề?** [Tạo issue trên GitHub](../../issues/new) hoặc [Liên hệ qua email](mailto:hungtien10a7@gmail.com)

[Về trang chủ](README.md) • [Email](mailto:hungtien10a7@gmail.com) • [Discussions](../../discussions)

</div>
