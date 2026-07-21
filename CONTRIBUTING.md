<div align="center">

# Hướng dẫn Đóng góp

**Cảm ơn bạn muốn đóng góp cho PHTV — Precision Hybrid Typing Vietnamese!**

[Trang chủ](README.md) • [Code of Conduct](CODE_OF_CONDUCT.md) • [Issues](https://github.com/PhamHungTien/PHTV/issues)

</div>

---

## 📜 Quy tắc ứng xử

Xem [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md). Bằng cách tham gia, bạn đồng ý tuân thủ các quy tắc.

## Bắt Đầu Nhanh

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
   scripts/dev.swift env-check
   scripts/dev.swift build
   scripts/dev.swift test
   ```

4. **Commit & push:**

   ```bash
   git add .
   git commit -m "feat: Mô tả tính năng"
   git push origin feature/your-name
   ```

5. **Tạo Pull Request** trên GitHub

## Báo Cáo Lỗi

Tạo [issue mới](https://github.com/PhamHungTien/PHTV/issues/new) với thông tin:

- Tiêu đề rõ ràng
- Cách tái hiện (bước chi tiết)
- Hành vi mong đợi vs thực tế
- macOS version & PHTV version
- Trạng thái Accessibility/Input Monitoring nếu lỗi liên quan đến gõ phím
- Screenshot/video (nếu có)

## Đề Xuất Tính Năng

Tạo issue với nhãn `enhancement` bao gồm:

- Vấn đề bạn cố gắng giải quyết
- Giải pháp đề xuất
- Giải pháp thay thế

## Pull Request

- Rebase từ `upstream/main` trước khi push
- Commit message: `feat:` hoặc `fix:` + mô tả
- Liên kết issue nếu có
- Thêm test nếu cần

## Commit Message

Format: `<type>: <mô tả>`

- `feat:` - Tính năng mới
- `fix:` - Sửa lỗi
- `docs:` - Cập nhật tài liệu
- `style:` - Format code
- `refactor:` - Tái cấu trúc
- `test:` - Thêm test
- `chore:` - Công việc khác

## Hướng Dẫn Phát Triển

### Cấu trúc dự án

```
PHTV/
├── App/                    # Mã nguồn chính cho macOS
│   ├── PHTV/
│   │   ├── App/            # AppDelegate và vòng đời ứng dụng
│   │   ├── Engine/         # Engine xử lý tiếng Việt (Swift)
│   │   ├── Input/          # EventTap, Hotkey, xử lý phím
│   │   ├── Context/        # App context, Smart Switch
│   │   ├── System/         # Permission, TCC, Safe Mode, binary integrity
│   │   ├── Manager/        # PHTVManager (public API)
│   │   ├── Models/         # Data models
│   │   ├── State/          # Observable state (SwiftUI)
│   │   ├── Data/           # Persistence, API clients
│   │   ├── Services/       # Business logic độc lập với UI
│   │   ├── UI/             # SwiftUI views và components
│   │   ├── Utilities/      # Tiện ích dùng chung
│   │   └── Resources/      # Từ điển, localization, assets
│   ├── Tests/              # Engine regression tests
│   └── PHTV.xcodeproj/     # Xcode project
├── docs/                   # Tài liệu, kiến trúc, hình ảnh
├── scripts/                # Local dev entrypoint và build tools
│   └── tools/              # Build tools (generate_dict_binary.swift, etc.)
└── README.md
```

### Build và Test

> **Yêu cầu**: macOS 14.0+ và Xcode phiên bản mới nhất. Bản chạy thật cần cấp đủ Accessibility và Input Monitoring cho bundle đang test.

```bash
# Clone project
git clone https://github.com/PhamHungTien/PHTV.git

# Kiểm tra môi trường local
scripts/dev.swift env-check

# Build Debug cho kiến trúc máy hiện tại
scripts/dev.swift build

# Run all XCTest tests
scripts/dev.swift test

# Run engine regression tests
scripts/dev.swift engine-test

# Run hotkey smoke tests
scripts/dev.swift hotkey-test

# Validate appcasts, privacy manifest và release metadata
scripts/dev.swift metadata-check

# Release build và static analysis
scripts/dev.swift release-build
scripts/dev.swift analyze

# Clean build
scripts/dev.swift clean
```

### Debugging

1. **Trong Xcode:**

   - Nhấn Cmd+R để run
   - Sử dụng breakpoints (Cmd+\)
   - View console output (Cmd+Shift+C)

2. **Logging:**
   ```swift
   PHTVLogger.shared.debug("Mô tả trạng thái không chứa nội dung người dùng")
   ```

   Không log phím gõ, nội dung clipboard/macro, từ khóa GIF/Sticker, API key hoặc URL có token. Dùng category và mức log phù hợp thay cho `print`/`NSLog` mới.

## Quy Tắc Code

### Swift Code Style

- Sử dụng 4 spaces cho indentation
- Dùng cấu hình `.editorconfig` và `.swift-format` cho file được sửa
- Tên biến và hàm: `camelCase`
- Tên class và struct: `PascalCase`
- Tên hằng số: `camelCase` hoặc `UPPER_CASE`
- Viết comment cho các hàm public
- Mọi `@unchecked Sendable` phải giải thích lock/executor bảo vệ mutable state
- Cập nhật `THIRD_PARTY_NOTICES.md` và privacy docs khi thêm dependency/dịch vụ mạng

**Ví dụ:**

```swift
/// Chuyển đổi giữa tiếng Việt và Anh
/// - Parameter enabled: Bật/tắt tiếng Việt
func toggleVietnameseMode(enabled: Bool) {
    // Logic ở đây
}
```

---

<div align="center">

## Cảm ơn đã đóng góp!

Mọi đóng góp, dù lớn hay nhỏ, đều được trân trọng và ghi nhận.

[![Contributors](https://img.shields.io/github/contributors/PhamHungTien/PHTV)](../../graphs/contributors)

**[⬆️ Về đầu trang](#-hướng-dẫn-đóng-góp)**

[Trang chủ](README.md) • [Cài đặt](docs/INSTALL.md) • [FAQ](docs/FAQ.md)

</div>
