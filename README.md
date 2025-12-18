<div align="center">

<img src="PHTV/Resources/icon.png" alt="PHTV Icon" width="128" height="128">

# PHTV

### Bộ gõ tiếng Việt hiện đại cho macOS

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![macOS 14+](https://img.shields.io/badge/macOS-14+-blue.svg)](https://www.apple.com/macos/)
[![Swift 6.0+](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![GitHub release](https://img.shields.io/github/v/release/PhamHungTien/PHTV)](../../releases/latest)
[![GitHub stars](https://img.shields.io/github/stars/PhamHungTien/PHTV)](../../stargazers)

[**📥 Tải về**](https://phamhungtien.com/PHTV/) • [**📖 Tài liệu**](INSTALL.md) • [**🐛 Báo lỗi**](../../issues) • [**❓ FAQ**](FAQ.md)

</div>

---

## 🎯 Giới thiệu

PHTV là bộ gõ tiếng Việt **offline, nhanh, và riêng tư** cho macOS 14+. Được phát triển bằng Swift/SwiftUI với engine C++ từ OpenKey, mang đến trải nghiệm gõ tiếng Việt mượt mà và tích hợp sâu vào hệ thống.

### ✨ Tính năng nổi bật

- 🚀 **Hoàn toàn offline** - Không cần Internet, bảo mật tuyệt đối
- ⌨️ **Telex & VNI** - Đầy đủ các phương pháp gõ phổ biến
- 🎨 **Native macOS** - Giao diện SwiftUI, hỗ trợ Dark Mode
- 🔍 **Spotlight Fix** - Gõ tiếng Việt trong Spotlight không bị lỗi
- 📝 **Macro** - Gõ tắt thông minh, import từ file
- 🎛️ **Hot Reload** - Thay đổi cài đặt không cần khởi động lại

## 📸 Screenshots

<div align="center">

### 🎨 Menu Bar

<table>
<tr>
<td width="50%">
<img src="PHTV/Resources/UI/menu-input-methods.png" alt="Các kiểu gõ trên menu bar" style="border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);" width="100%">
<p align="center"><em>Các kiểu gõ trên menu bar</em></p>
</td>
<td width="50%">
<img src="PHTV/Resources/UI/menu-charset.png" alt="Các bảng mã trên menu bar" style="border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);" width="100%">
<p align="center"><em>Các bảng mã trên menu bar</em></p>
</td>
</tr>
</table>

### ⚙️ Settings

<table>
<tr>
<td width="33%">
<img src="PHTV/Resources/UI/settings-typing.png" alt="Settings - Typing" style="border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);" width="100%">
<p align="center"><em>Typing Settings</em></p>
</td>
<td width="33%">
<img src="PHTV/Resources/UI/settings-macros.png" alt="Settings - Macros" style="border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);" width="100%">
<p align="center"><em>Macros Settings</em></p>
</td>
<td width="33%">
<img src="PHTV/Resources/UI/settings-system.png" alt="Settings - System" style="border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);" width="100%">
<p align="center"><em>System Settings</em></p>
</td>
</tr>
</table>

</div>

## ⚡ Cài đặt nhanh

**Phương pháp 1: Tải trực tiếp** (khuyên dùng)

```bash
# Tải từ website
open https://phamhungtien.com/PHTV/

# Hoặc từ GitHub Releases
open https://github.com/PhamHungTien/PHTV/releases/latest
```

**Phương pháp 2: Build từ source**

```bash
git clone https://github.com/PhamHungTien/PHTV.git
cd PHTV
open PHTV.xcodeproj
# Build với Cmd+B, chạy với Cmd+R
```

> ⚠️ **Lưu ý**: Ứng dụng cần quyền **Accessibility** để hoạt động. Vào **System Settings > Privacy & Security > Accessibility** và thêm PHTV.

## 📚 Sử dụng

### Phím tắt

| Phím tắt            | Chức năng                        |
| ------------------- | -------------------------------- |
| **Control + Shift** | Chuyển Việt/Anh (tùy chỉnh được) |
| **Fn + Modifier**   | Phím tắt nâng cao (v1.1.2+)      |

### Menu Bar

Click biểu tượng **Vi** (Việt) / **En** (Anh) trên menu bar:

- Chuyển đổi phương pháp gõ (Telex/VNI/Simple Telex)
- Thay đổi bảng mã (Unicode/TCVN3/VNI Windows)
- Bật/tắt kiểm tra chính tả, gõ tắt
- Mở Settings để cấu hình chi tiết

### Settings

- **Typing**: Phương pháp gõ, bảng mã, chính tả hiện đại
- **Macros**: Quản lý gõ tắt, import/export từ file
- **Excluded Apps**: Danh sách app tự động chuyển sang Anh
- **System**: Khởi động cùng macOS, hotkey tùy chỉnh

## 🔧 Yêu cầu hệ thống

| Thành phần    | Yêu cầu                                   |
| ------------- | ----------------------------------------- |
| **macOS**     | 14.0+ (Sonoma trở lên)                    |
| **Kiến trúc** | Apple Silicon (arm64) hoặc Intel (x86_64) |
| **Xcode**     | 26.0+ (nếu build từ source)               |
| **Quyền**     | Accessibility                             |

## 🛠️ Công nghệ

- **Swift 6.0** + **SwiftUI** - Giao diện native hiện đại
- **C++** - Engine xử lý input (từ OpenKey)
- **CGEvent API** - Event interception và xử lý bàn phím
- **NSUserDefaults** - Lưu trữ cấu hình local

## 📋 Changelog

### v1.1.2 (2025-12-17)

- ⚙️ Thêm tính năng **Kiểm tra cập nhật** tự động lúc khởi động
- 🛠️ Khôi phục phím nếu từ sai (Restore if invalid word)
- ⌨️ Chế độ "Gửi từng phím" (Send key step by step)
- 🎯 Cải thiện tính ổn định

### v1.1.1 (2025-12-16)

- ⌨️ Hỗ trợ phím **Fn** trong hotkey
- 🔄 **Hot reload** - Không cần restart khi đổi chế độ
- 📥 **Import macro** từ file

### v1.1.0 (2025-12-16)

- ✅ Khắc phục lỗi gõ trong **Spotlight Search**
- 🔤 Sửa lỗi garbling text
- 🎯 Tích hợp Accessibility API

### v1.0.3

- Cấu hình cơ bản, Macro, Excluded Apps
- Smart Switch Key, macOS integration

<details>
<summary>📅 Xem lịch sử đầy đủ</summary>

Truy cập [GitHub Releases](../../releases) để xem chi tiết tất cả các phiên bản.

</details>

## 🤝 Đóng góp

Mọi đóng góp đều được chào đón! Xem [CONTRIBUTING.md](CONTRIBUTING.md) để biết cách thức.

**Các cách đóng góp:**

- 🐛 [Báo lỗi](../../issues/new?template=bug_report.md)
- 💡 [Đề xuất tính năng](../../issues/new?template=feature_request.md)
- 🔧 Gửi Pull Request
- 📝 Cải thiện tài liệu

## 📞 Hỗ trợ & Liên hệ

- 📧 Email: hungtien10a7@gmail.com
- 🐙 GitHub: [Issues](../../issues) • [Discussions](../../discussions)
- 🌐 Website: [phamhungtien.com/PHTV](https://phamhungtien.com/PHTV/)
- 👤 Facebook: [phamhungtien1404](https://www.facebook.com/phamhungtien1404)
- 💼 LinkedIn: [Phạm Hùng Tiến](https://www.linkedin.com/in/ph%E1%BA%A1m-h%C3%B9ng-ti%E1%BA%BFn-a1b405327/)

## 📄 License & Credits

PHTV được phát hành dưới giấy phép **[GPL v3.0](LICENSE)**.

Dự án kế thừa và mở rộng engine từ **[OpenKey](https://github.com/tuyenvm/OpenKey)** của Tuyến Võ Minh. Chân thành cảm ơn cộng đồng OpenKey đã tạo nền tảng tuyệt vời này.

---

<div align="center">

### ⭐ Nếu PHTV hữu ích, hãy cho dự án một star!

[![GitHub stars](https://img.shields.io/github/stars/PhamHungTien/PHTV?style=social)](../../stargazers)

**[⬆️ Về đầu trang](#phtv)**

Made with ❤️ for Vietnamese macOS users

</div>
