<div align="center">

# Hướng dẫn cài đặt PHTV

**PHTV — Precision Hybrid Typing Vietnamese | Cài đặt bộ gõ tiếng Việt cho macOS trong 3 phút**

[Trang chủ](README.md) • [FAQ](FAQ.md) • [Báo lỗi](../../issues)

</div>

---

## 📋 Mục lục

- [Yêu cầu hệ thống](#yêu-cầu-hệ-thống)
- [Các phương pháp cài đặt](#các-phương-pháp-cài-đặt)
- [Hướng dẫn từng bước có ảnh](#hướng-dẫn-có-ảnh)
- [Cấu hình sau khi cài đặt](#các-bước-sau-khi-cài)
- [Xử lý sự cố](#xử-lý-sự-cố)

---

## ⚙️ Yêu cầu hệ thống

| Yêu cầu | Chi tiết |
|---------|----------|
| **macOS** | 13.0 (Ventura) trở lên |
| **CPU** | Universal Binary - Intel & Apple Silicon (M1/M2/M3/M4) |
| **RAM** | Tối thiểu 256 MB |
| **Dung lượng** | ~50 MB |
| **Quyền** | Accessibility Access (sẽ được yêu cầu khi cài đặt) |

> ✅ **Lưu ý**: PHTV là Universal Binary, chạy native trên cả chip Intel và Apple Silicon, đảm bảo hiệu suất tối ưu.

---

## 📥 Tải xuống

**[⬇️ Tải PHTV từ phamhungtien.com/PHTV](https://phamhungtien.com/PHTV/)**

---

## 💻 Các phương pháp cài đặt

Chọn một trong các phương pháp dưới đây phù hợp với bạn:

### 🍺 Option 1: Homebrew (Khuyến nghị)

**Phương pháp nhanh nhất và dễ nhất** - chỉ cần một lệnh:

```bash
brew install --cask phamhungtien/tap/phtv
```

**Ưu điểm:**
- ✅ Cài đặt tự động, chỉ cần 1 lệnh
- ✅ Tự động xử lý dependencies
- ✅ Dễ dàng cập nhật: `brew upgrade --cask phtv`
- ✅ Gỡ cài đặt sạch sẽ: `brew uninstall --cask phtv`

**Lưu ý:** Nếu chưa có Homebrew, cài đặt tại [brew.sh](https://brew.sh)

---

### 🌐 Option 2: Từ Website (Người dùng thông thường)

**Dành cho người dùng muốn giao diện đồ họa:**

1. 🔗 Truy cập [phamhungtien.com/PHTV](https://phamhungtien.com/PHTV/)
2. 📦 Tải file `.dmg` mới nhất
3. 📂 Mở file `.dmg` vừa tải về
4. 🖱️ Kéo `PHTV.app` vào thư mục `Applications`
5. 🚀 Khởi động từ Launchpad hoặc Spotlight (⌘+Space → gõ "PHTV")

---

### 🐙 Option 3: Từ GitHub Releases

**Dành cho developers hoặc muốn version cụ thể:**

1. Vào [GitHub Releases](https://github.com/PhamHungTien/PHTV/releases)
2. Chọn version cần tải (hoặc [latest](https://github.com/PhamHungTien/PHTV/releases/latest))
3. Download file `.dmg` (VD: `PHTV-1.7.0.dmg`)
4. Double-click để mở DMG
5. Drag `PHTV.app` vào thư mục `Applications`

---

### 🛠️ Option 4: Build từ Source Code

**Dành cho developers muốn tự build hoặc đóng góp:**

```bash
# Clone repository
git clone https://github.com/PhamHungTien/PHTV.git
cd PHTV

# Build với Xcode
# Universal Binary - hỗ trợ cả Intel và Apple Silicon
xcodebuild -scheme PHTV -configuration Release

# App sẽ được build tại: build/Release/PHTV.app
```

**Yêu cầu:**
- Xcode 14.0 trở lên
- macOS 13.0+ SDK
- Swift 5.7+

---

## 📸 Hướng dẫn có ảnh

<div align="center">

**Bước 1: Tải về**
<img src="docs/images/setup/step1-download.png" alt="Tải PHTV" width="70%">

**Bước 2: Mở ứng dụng**
<img src="docs/images/setup/step2-open.png" alt="Mở PHTV" width="70%">

**Bước 3: Yêu cầu quyền**
<img src="docs/images/setup/step3-permissions.png" alt="Yêu cầu Accessibility" width="70%">

**Bước 4: Cấp quyền Accessibility**
<img src="docs/images/setup/step4-grant-access.png" alt="Cấp quyền" width="70%">

**Bước 5: Hoàn tất**
<img src="docs/images/setup/step5-complete.png" alt="Hoàn tất cài đặt" width="70%">

</div>

---

## ⚡ Các bước sau khi cài

### 1. 🔐 Cấp quyền Accessibility (Bắt buộc)

Lần đầu tiên chạy PHTV, bạn sẽ được yêu cầu cấp quyền Accessibility:

1. Click **"Open System Settings"** khi được yêu cầu
2. Hoặc vào **System Settings** → **Privacy & Security** → **Accessibility**
3. Bật PHTV trong danh sách
4. Khởi động lại PHTV

> ⚠️ **Quan trọng**: Không có quyền Accessibility, PHTV sẽ không thể gõ tiếng Việt được.

---

### 2. 🎯 Cấu hình cơ bản

Sau khi cài đặt, click vào icon PHTV trên menu bar để cấu hình:

| Bước | Hành động | Mô tả |
|------|-----------|-------|
| **Ngôn ngữ** | Chọn "Tiếng Việt" | Bật/tắt gõ tiếng Việt (mặc định: bật) |
| **Bộ gõ** | Settings → Method | Chọn **Telex** hoặc **VNI** |
| **Phím tắt** | Settings → Shortcuts | Tùy chỉnh phím chuyển VN/EN (mặc định: `⌘⇧V`) |
| **Gõ tắt** | Settings → Macros | Thêm từ viết tắt (optional) |
| **Picker** | Nhấn `⌘E` | Thử emoji/GIF picker |

---

### 3. 💡 Tips sử dụng hiệu quả

<details>
<summary><b>🎨 Tùy chỉnh phím tắt chuyển ngôn ngữ</b></summary>

Mặc định: `⌘⇧V` (Command + Shift + V)

Bạn có thể đổi sang:
- `⌃⇧V` (Control + Shift + V)
- `⌥⇧V` (Option + Shift + V)
- Hoặc bất kỳ tổ hợp nào phù hợp

**Cách đổi:** Menu bar → Settings → Shortcuts

</details>

<details>
<summary><b>⚡ Sử dụng Macros để gõ nhanh</b></summary>

Ví dụ macros hữu ích:
- `@@` → email của bạn
- `sdt` → số điện thoại
- `dc` → địa chỉ nhà
- `hs` → chữ ký hoặc hashtag

**Cách thêm:** Menu bar → Settings → Macros → Add New

</details>

<details>
<summary><b>🎭 PHTV Picker - Emoji & GIF</b></summary>

Nhấn `⌘E` (Command + E) bất kỳ đâu để mở:
- 😀 Emoji picker
- 🎬 GIF search
- 📋 Clipboard history
- ⚡ Quick actions

</details>

---

## 📚 Tài liệu thêm

- 📖 [Hướng dẫn chi tiết](https://phamhungtien.com/PHTV/#setup) - Video & Screenshots đầy đủ
- ⭐ [Các tính năng](README.md#tính-năng) - Danh sách đầy đủ các tính năng
- ❓ [FAQ](FAQ.md) - Câu hỏi thường gặp và giải đáp
- 🤝 [Đóng góp](CONTRIBUTING.md) - Hướng dẫn contribute cho developers

---

## 🔧 Xử lý sự cố

### ⚠️ Lỗi "PHTV is damaged" hoặc "can't be opened"

**Nguyên nhân:** macOS Gatekeeper chặn ứng dụng tải từ Internet (do chưa được notarized hoặc đã được quarantine).

**Giải pháp nhanh:**

```bash
# Mở Terminal (⌘+Space → gõ "Terminal")
# Copy và paste lệnh sau, sau đó nhấn Enter:
xattr -cr /Applications/PHTV.app
```

**Giải thích:** Lệnh này xóa extended attributes (quarantine flag) khỏi app.

**Alternative:**
- Right-click PHTV.app → chọn "Open" → click "Open" trong dialog cảnh báo
- Hoặc: System Settings → Privacy & Security → Allow "PHTV"

---

### 🚫 PHTV không gõ được tiếng Việt

<details>
<summary><b>Checklist khắc phục</b></summary>

✅ **Bước 1: Kiểm tra quyền Accessibility**
```
System Settings → Privacy & Security → Accessibility → Đảm bảo PHTV được bật
```

✅ **Bước 2: Kiểm tra ngôn ngữ đang chọn**
- Click icon PHTV trên menu bar
- Đảm bảo chọn **"Tiếng Việt"** (không phải "English")
- Icon sẽ hiển thị "VI" khi đang ở chế độ tiếng Việt

✅ **Bước 3: Kiểm tra phương pháp gõ**
- Menu bar → Settings → Method
- Chọn Telex hoặc VNI (tùy thói quen)

✅ **Bước 4: Restart ứng dụng**
- Menu bar → Quit PHTV
- Mở lại PHTV từ Applications

✅ **Bước 5: Test trong ứng dụng khác**
- Thử gõ trong Notes, TextEdit, hoặc trình duyệt
- Một số app có thể chặn input methods (vd: terminal, IDE)

</details>

---

### ⌨️ Phím tắt không hoạt động

<details>
<summary><b>Giải pháp</b></summary>

**Nguyên nhân thường gặp:**
1. Phím tắt bị trùng với shortcut khác trong macOS
2. Ứng dụng hiện tại chặn global shortcuts
3. Chưa cấp quyền Accessibility

**Cách khắc phục:**

1. **Kiểm tra conflict:**
   - System Settings → Keyboard → Keyboard Shortcuts
   - Tìm xem có shortcut nào trùng với PHTV không

2. **Đổi sang tổ hợp khác:**
   - PHTV → Settings → Shortcuts
   - Thử các tổ hợp: `⌃⇧V`, `⌥⇧V`, `⌘⇧Space`, etc.

3. **Test shortcut:**
   - Mở Notes hoặc TextEdit
   - Nhấn phím tắt để kiểm tra

</details>

---

### 🐛 PHTV bị crash hoặc không phản hồi

<details>
<summary><b>Các bước debug</b></summary>

**1. Kiểm tra Console logs:**
```bash
# Mở Console.app → tìm "PHTV" để xem error logs
```

**2. Reset settings về mặc định:**
```bash
# Xóa preferences (sẽ reset tất cả settings)
rm ~/Library/Preferences/com.phamhungtien.PHTV.plist
```

**3. Reinstall clean:**
```bash
# Nếu dùng Homebrew:
brew uninstall --cask phtv
brew install --cask phtv

# Nếu dùng manual:
# 1. Xóa /Applications/PHTV.app
# 2. Xóa ~/Library/Preferences/com.phamhungtien.PHTV.plist
# 3. Cài lại từ đầu
```

**4. Báo lỗi:**
- [Tạo issue trên GitHub](../../issues/new) với thông tin:
  - macOS version
  - PHTV version
  - Console logs
  - Các bước tái hiện lỗi

</details>

---

### 💬 Các vấn đề khác

<details>
<summary><b>PHTV không hiển thị icon trên menu bar</b></summary>

**Giải pháp:**
1. Quit và mở lại PHTV
2. Kiểm tra menu bar có bị ẩn không (macOS Sonoma+)
3. System Settings → Control Center → Menu Bar Only → Tìm PHTV

</details>

<details>
<summary><b>Một số ký tự đặc biệt không gõ được</b></summary>

**Lưu ý:**
- PHTV hỗ trợ đầy đủ Unicode Vietnamese (Unicode NFC)
- Nếu app đích không hỗ trợ Unicode, chữ có thể hiển thị sai
- Thử copy-paste để kiểm tra xem có phải do font chữ không

</details>

<details>
<summary><b>PHTV tốn RAM hoặc CPU</b></summary>

**Bình thường:**
- RAM: 30-50 MB khi idle
- CPU: < 1% khi không gõ

**Nếu cao hơn:**
1. Restart PHTV
2. Kiểm tra có loop hoặc memory leak không
3. [Báo bug](../../issues/new) kèm Activity Monitor screenshot

</details>

---

<div align="center">

**Vẫn gặp vấn đề?** [Tạo issue trên GitHub](../../issues/new) hoặc [Liên hệ qua email](mailto:phamhungtien.contact@gmail.com)

[Về trang chủ](README.md) • [Email](mailto:phamhungtien.contact@gmail.com) • [Discussions](../../discussions)

</div>
