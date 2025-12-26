<div align="center">

<img src="PHTV/Resources/icon.png" alt="PHTV Icon" width="128" height="128">

# PHTV — Precision Hybrid Typing Vietnamese

### Bộ gõ tiếng Việt hiện đại cho macOS

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![macOS 14+](https://img.shields.io/badge/macOS-14+-blue.svg)](https://www.apple.com/macos/)
[![Universal Binary](https://img.shields.io/badge/Universal-Intel%20%2B%20Apple%20Silicon-red.svg)](https://support.apple.com/en-us/HT211814)
[![Swift 6.0+](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![GitHub release](https://img.shields.io/github/v/release/PhamHungTien/PHTV)](../../releases/latest)
[![GitHub downloads](https://img.shields.io/github/downloads/PhamHungTien/PHTV/total?label=Downloads)](../../releases)
[![GitHub stars](https://img.shields.io/github/stars/PhamHungTien/PHTV)](../../stargazers)
[![Sponsor](https://img.shields.io/badge/❤️_Sponsor-PHTV-ea4aaa?style=flat&logo=github-sponsors)](https://phamhungtien.github.io/PHTV/donate.html)

[**Tải về**](https://phamhungtien.com/PHTV/) | [**Tài liệu**](INSTALL.md) | [**Báo lỗi**](../../issues) | [**FAQ**](FAQ.md) | [**☕ Ủng hộ**](https://phamhungtien.github.io/PHTV/donate.html)

</div>

---

## Giới thiệu

**PHTV (Precision Hybrid Typing Vietnamese)** là bộ gõ tiếng Việt **offline, nhanh, và riêng tư** cho macOS 14+. Được phát triển bằng Swift/SwiftUI với engine C++ từ OpenKey, mang đến trải nghiệm gõ tiếng Việt mượt mà và tích hợp sâu vào hệ thống.

## Tính năng

### Cốt lõi
- **Hoàn toàn offline** - Không cần Internet, bảo mật tuyệt đối
- **Telex, VNI, Simple Telex** - Đầy đủ các phương pháp gõ phổ biến
- **Nhiều bảng mã** - Unicode, TCVN3 (ABC), VNI Windows, Unicode Compound
- **Native macOS** - Giao diện SwiftUI hiện đại, hỗ trợ Dark Mode

### Gõ thông minh
- **Kiểm tra chính tả** - Tự động phát hiện từ sai chính tả
- **Chính tả hiện đại** - Hỗ trợ quy tắc "oà, uý" thay vì "òa, úy"
- **Gõ tắt nhanh (Quick Telex)** - cc→ch, gg→gi, kk→kh, nn→ng, qq→qu, pp→ph, tt→th
- **Phụ âm đầu/cuối nhanh** - f→ph, j→gi, w→qu (đầu) và g→ng, h→nh, k→ch (cuối)
- **Tự động viết hoa** - Viết hoa chữ cái đầu câu sau dấu chấm
- **Tự động khôi phục từ tiếng Anh** - Nhận diện và khôi phục từ tiếng Anh khi gõ nhầm (VD: "tẻminal" → "terminal")

### Macro (Gõ tắt)
- **Gõ tắt thông minh** - Định nghĩa từ viết tắt tùy ý (VD: "btw" → "by the way")
- **Tự động viết hoa macro** - "Btw" → "By the way", "BTW" → "BY THE WAY"
- **Hoạt động ở cả 2 chế độ** - Macro hoạt động cả khi gõ tiếng Việt và tiếng Anh
- **Import/Export** - Nhập xuất danh sách macro từ file

### Tương thích ứng dụng
- **Spotlight Fix** - Gõ tiếng Việt trong Spotlight không bị lỗi
- **WhatsApp Fix** - Hỗ trợ gõ tiếng Việt mượt mà trong WhatsApp
- **Chromium Fix** - Tối ưu cho Chrome, Edge, Brave và các trình duyệt Chromium
- **Claude Code Fix** - Sửa lỗi gõ tiếng Việt trong Claude Code CLI (Terminal)
- **Excluded Apps** - Danh sách ứng dụng tự động chuyển sang tiếng Anh
- **Nhớ bảng mã theo ứng dụng** - Tự động chuyển bảng mã phù hợp cho từng app

### Phím tắt & Điều khiển
- **Phím chuyển ngôn ngữ tùy chỉnh** - Control, Option, Command, Shift hoặc tổ hợp
- **Tạm tắt tiếng Việt** - Giữ phím để tạm thời gõ tiếng Anh
- **Khôi phục ký tự gốc** - Nhấn ESC để hoàn tác dấu (VD: "việt" → "viet")
- **Smart Switch** - Tự động nhớ ngôn ngữ cho từng ứng dụng

### Hệ thống
- **Khởi động cùng macOS** - Tùy chọn chạy khi đăng nhập
- **Hot Reload** - Thay đổi cài đặt không cần khởi động lại
- **Tự động cập nhật** - Kiểm tra phiên bản mới từ GitHub
- **Menu bar icon** - Hiển thị trạng thái Vi/En trên thanh menu
- **Báo lỗi thông minh** - Tự động thu thập log debug, thống kê lỗi, gửi qua GitHub/Email

## Screenshots

<div align="center">

### Menu Bar

<table>
<tr>
<td width="50%">
<img src="PHTV/Resources/UI/menu-input-methods.png" alt="Các kiểu gõ trên menu bar" width="100%">
<p align="center"><em>Các kiểu gõ trên menu bar</em></p>
</td>
<td width="50%">
<img src="PHTV/Resources/UI/menu-charset.png" alt="Các bảng mã trên menu bar" width="100%">
<p align="center"><em>Các bảng mã trên menu bar</em></p>
</td>
</tr>
</table>

### Settings

<table>
<tr>
<td width="33%">
<img src="PHTV/Resources/UI/settings-typing.png" alt="Settings - Typing" width="100%">
<p align="center"><em>Typing Settings</em></p>
</td>
<td width="33%">
<img src="PHTV/Resources/UI/settings-macros.png" alt="Settings - Macros" width="100%">
<p align="center"><em>Macros Settings</em></p>
</td>
<td width="33%">
<img src="PHTV/Resources/UI/settings-system.png" alt="Settings - System" width="100%">
<p align="center"><em>System Settings</em></p>
</td>
</tr>
</table>

</div>

## Cài đặt

### Homebrew (khuyên dùng)

```bash
brew install --cask phamhungtien/tap/phtv
```

**Cập nhật phiên bản mới:**
```bash
brew upgrade --cask phtv
```

**Gỡ cài đặt:**
```bash
# Gỡ ứng dụng
brew uninstall --cask phtv

# Gỡ sạch (bao gồm cả settings)
brew uninstall --zap --cask phtv
```

### Tải trực tiếp

```bash
# Tải từ website
open https://phamhungtien.com/PHTV/

# Hoặc từ GitHub Releases
open https://github.com/PhamHungTien/PHTV/releases/latest
```

### Build từ source

```bash
git clone https://github.com/PhamHungTien/PHTV.git
cd PHTV
open PHTV.xcodeproj
# Build với Cmd+B, chạy với Cmd+R
```

> **Lưu ý**: Ứng dụng cần quyền **Accessibility** để hoạt động. Vào **System Settings > Privacy & Security > Accessibility** và thêm PHTV.

## Sử dụng

### Phím tắt mặc định

| Phím tắt | Chức năng |
| --- | --- |
| **Control + Shift** | Chuyển Việt/Anh (tùy chỉnh được) |
| **ESC** | Khôi phục ký tự gốc (hoàn tác dấu) |
| **Giữ Option** | Tạm tắt tiếng Việt (tùy chỉnh được) |

### Menu Bar

Click biểu tượng **Vi** (Việt) / **En** (Anh) trên menu bar:

- Chuyển đổi phương pháp gõ (Telex/VNI/Simple Telex)
- Thay đổi bảng mã (Unicode/TCVN3/VNI Windows/Unicode Compound)
- Bật/tắt kiểm tra chính tả, gõ tắt
- Mở Settings để cấu hình chi tiết

### Cài đặt chi tiết

| Tab | Nội dung |
| --- | --- |
| **Typing** | Phương pháp gõ, bảng mã, chính tả, Quick Telex, phụ âm nhanh |
| **Macros** | Quản lý gõ tắt, import/export, tự động viết hoa |
| **Excluded Apps** | Danh sách app tự động chuyển sang tiếng Anh |
| **System** | Khởi động cùng macOS, hotkey, Smart Switch, cập nhật |
| **About** | Thông tin phiên bản, ủng hộ phát triển |

## Yêu cầu hệ thống

| Thành phần | Yêu cầu |
| --- | --- |
| **macOS** | 14.0+ (Sonoma trở lên) |
| **Kiến trúc** | Universal Binary (Intel + Apple Silicon) |
| **Xcode** | 26.0+ (nếu build từ source) |
| **Quyền** | Accessibility |

> **Lưu ý**: PHTV hỗ trợ cả Intel và Apple Silicon (M1/M2/M3/M4). Universal Binary cho mọi Mac chạy macOS 14.0+.

## Công nghệ

- **Swift 6.0** + **SwiftUI** - Giao diện native hiện đại
- **C++** - Engine xử lý input (từ OpenKey)
- **CGEvent API** - Event interception và xử lý bàn phím
- **Accessibility API** - Hỗ trợ Spotlight và các app đặc biệt
- **NSUserDefaults** - Lưu trữ cấu hình local

## Tài liệu

### Người dùng
- **[Cài đặt](INSTALL.md)** - Hướng dẫn cài đặt chi tiết
- **[FAQ](FAQ.md)** - Các câu hỏi thường gặp
- **[Homebrew](docs/homebrew/)** - Cài đặt qua Homebrew

### Nhà phát triển
- **[Documentation](docs/)** - Tài liệu đầy đủ
- **[Automation](docs/automation/)** - Hệ thống automation Homebrew
- **[Scripts](scripts/)** - Scripts tự động hóa
- **[Contributing](CONTRIBUTING.md)** - Hướng dẫn đóng góp
- **[Security](SECURITY.md)** - Chính sách bảo mật

## Đóng góp

Mọi đóng góp đều được chào đón! Xem [CONTRIBUTING.md](CONTRIBUTING.md) để biết cách thức.

**Các cách đóng góp:**

- [Báo lỗi](../../issues/new?template=bug_report.md)
- [Đề xuất tính năng](../../issues/new?template=feature_request.md)
- Gửi Pull Request
- Cải thiện tài liệu

## Hỗ trợ & Liên hệ

- Email: hungtien10a7@gmail.com
- GitHub: [Issues](../../issues) | [Discussions](../../discussions)
- Website: [phamhungtien.com/PHTV](https://phamhungtien.com/PHTV/)
- Facebook: [phamhungtien1404](https://www.facebook.com/phamhungtien1404)
- LinkedIn: [Phạm Hùng Tiến](https://www.linkedin.com/in/ph%E1%BA%A1m-h%C3%B9ng-ti%E1%BA%BFn-a1b405327/)

## License & Credits

PHTV được phát hành dưới giấy phép **[GPL v3.0](LICENSE)**.

Dự án kế thừa và mở rộng engine từ **[OpenKey](https://github.com/tuyenvm/OpenKey)** của Tuyến Võ Minh. Chân thành cảm ơn cộng đồng OpenKey đã tạo nền tảng tuyệt vời này.

---

<div align="center">

### Nếu PHTV hữu ích, hãy cho dự án một star!

[![GitHub stars](https://img.shields.io/github/stars/PhamHungTien/PHTV?style=social)](../../stargazers)

**[Về đầu trang](#phtv)**

Made with love for Vietnamese macOS users

</div>
