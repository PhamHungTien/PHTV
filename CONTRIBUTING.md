<div align="center">

# 🤝 Hướng dẫn Đóng góp

**Cảm ơn bạn muốn đóng góp cho PHTV!**

[🏠 Trang chủ](README.md) • [📋 Code of Conduct](CODE_OF_CONDUCT.md) • [🐛 Issues](../../issues)

</div>

---

## 📜 Quy tắc ứng xử

Xem [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md). Bằng cách tham gia, bạn đồng ý tuân thủ các quy tắc.

## 🚀 Bắt đầu nhanh

1. **Fork & Clone:**

   ```bash
   git clone https://github.com/YOUR_USERNAME/PHTV.git
   cd PHTV
   git remote add upstream https://github.com/PhamHungTien/PHTV.git
   ```

2. **Tạo branch mới:**

   ```bash
   git checkout -b feature/your-name
   ```

3. **Build & test:**

   ```bash
   open PHTV.xcodeproj
   ```

4. **Commit & push:**

   ```bash
   git add .
   git commit -m "feat: Mô tả tính năng"
   git push origin feature/your-name
   ```

5. **Tạo Pull Request** trên GitHub

## 🐛 Báo cáo lỗi

Tạo [issue mới](../../issues/new) với thông tin:

- Tiêu đề rõ ràng
- Cách tái hiện (bước chi tiết)
- Hành vi mong đợi vs thực tế
- macOS version & PHTV version
- Screenshot/video (nếu có)

## 💡 Đề xuất tính năng

Tạo issue với nhãn `enhancement` bao gồm:

- Vấn đề bạn cố gắng giải quyết
- Giải pháp đề xuất
- Giải pháp thay thế

## ✅ Pull Request

- Rebase từ `upstream/main` trước khi push
- Commit message: `feat:` hoặc `fix:` + mô tả
- Liên kết issue nếu có
- Thêm test nếu cần

## 📝 Commit Message

Format: `<type>: <mô tả>`

- `feat:` - Tính năng mới
- `fix:` - Sửa lỗi
- `docs:` - Cập nhật tài liệu
- `style:` - Format code
- `refactor:` - Tái cấu trúc
- `test:` - Thêm test
- `chore:` - Công việc khác

## 🔨 Hướng dẫn phát triển

### Cấu trúc dự án

```

PHTV/
├── PHTV/
│ ├── Application/ # AppDelegate, main entry point
│ ├── Core/
│ │ ├── Engine/ # Core input method engine (C++)
│ │ │ ├── Engine.cpp/.h # Logic chính
│ │ │ ├── Vietnamese.cpp/.h # Bảng mã tiếng Việt
│ │ │ ├── Macro.cpp/.h # Quản lý macro
│ │ │ └── ...
│ │ └── Platforms/ # macOS-specific integration
│ ├── Managers/ # Business logic
│ ├── SwiftUI/ # Giao diện người dùng
│ │ ├── Views/ # SwiftUI views
│ │ ├── Controllers/ # Window/Status bar controllers
│ │ └── Utilities/ # Helper functions
│ └── Utils/ # Utility functions
├── PHTV.xcodeproj/ # Xcode project
└── README.md

````

### Build và Test

```bash
# Build project
xcodebuild -project PHTV.xcodeproj -scheme PHTV

# Run tests (nếu có)
xcodebuild -project PHTV.xcodeproj -scheme PHTV test

# Clean build
xcodebuild -project PHTV.xcodeproj clean
````

### Debugging

1. **Trong Xcode:**

   - Nhấn Cmd+R để run
   - Sử dụng breakpoints (Cmd+\)
   - View console output (Cmd+Shift+C)

2. **Console logging:**
   ```swift
   print("Debug message: \(value)")
   ```

## 📝 Quy tắc Code

### Swift Code Style

- Sử dụng 4 spaces cho indentation
- Tên biến và hàm: `camelCase`
- Tên class và struct: `PascalCase`
- Tên hằng số: `camelCase` hoặc `UPPER_CASE`
- Viết comment cho các hàm public

**Ví dụ:**

```swift
/// Chuyển đổi giữa tiếng Việt và Anh
/// - Parameter enabled: Bật/tắt tiếng Việt
func toggleVietnameseMode(enabled: Bool) {
    // Logic ở đây
}
```

### Objective-C/C++ Code Style

- Sử dụng 4 spaces cho indentation
- PascalCase cho tên class/struct

---

<div align="center">

## ✨ Cảm ơn đã đóng góp!

Mọi đóng góp, dù lớn hay nhỏ, đều được trân trọng và ghi nhận.

[![Contributors](https://img.shields.io/github/contributors/PhamHungTien/PHTV)](../../graphs/contributors)

**[⬆️ Về đầu trang](#-hướng-dẫn-đóng-góp)**

[🏠 Trang chủ](README.md) • [📦 Cài đặt](INSTALL.md) • [💬 FAQ](FAQ.md)

</div>
