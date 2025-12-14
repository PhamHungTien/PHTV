# Hướng dẫn Đóng góp (Contributing Guidelines)

Cảm ơn bạn đã quan tâm đến PHTV! Chúng tôi rất vui được nhận đóng góp từ cộng đồng. Hướng dẫn này sẽ giúp bạn bắt đầu.

## 📋 Mục lục

1. [Quy tắc ứng xử](#quy-tắc-ứng-xử)
2. [Cách bắt đầu](#cách-bắt-đầu)
3. [Báo cáo lỗi](#báo-cáo-lỗi)
4. [Đề xuất tính năng](#đề-xuất-tính-năng)
5. [Gửi Pull Request](#gửi-pull-request)
6. [Hướng dẫn phát triển](#hướng-dẫn-phát-triển)
7. [Quy tắc Code](#quy-tắc-code)

## 🤝 Quy tắc ứng xử

Dự án này áp dụng [Contributor Covenant Code of Conduct](./CODE_OF_CONDUCT.md). Bằng cách tham gia, bạn đồng ý tuân thủ các quy tắc này.

**Hành vi mà chúng tôi không chấp nhận:**

- Cách đối xử kỳ thị hoặc quấy rối dựa trên các đặc tính cá nhân
- Lời luyạ bình nhận xét về người khác
- Tấn công cá nhân hoặc chính trị
- Spam hoặc quảng cáo không liên quan

## 🚀 Cách bắt đầu

### Thiết lập môi trường phát triển

1. **Fork repository:**

   ```bash
   # Đi đến https://github.com/PhamHungTien/PHTV
   # Nhấn nút "Fork" ở góc trên cùng bên phải
   ```

2. **Clone repository của bạn:**

   ```bash
   git clone https://github.com/YOUR_USERNAME/PHTV.git
   cd PHTV
   ```

3. **Thêm upstream remote:**

   ```bash
   git remote add upstream https://github.com/PhamHungTien/PHTV.git
   ```

4. **Cài đặt dependencies và build:**

   ```bash
   # Mở PHTV.xcodeproj trong Xcode
   open PHTV.xcodeproj

   # Hoặc build bằng dòng lệnh
   xcodebuild -project PHTV.xcodeproj -scheme PHTV
   ```

5. **Tạo branch mới cho tính năng/lỗi của bạn:**
   ```bash
   git checkout -b feature/your-feature-name
   # hoặc
   git checkout -b fix/your-bug-fix
   ```

## 🐛 Báo cáo lỗi

Nếu bạn phát hiện lỗi, vui lòng [tạo issue mới](../../issues/new).

### Thông tin cần cung cấp

Khi báo cáo lỗi, vui lòng bao gồm:

- **Tiêu đề rõ ràng và mô tả**: Mô tả vấn đề một cách ngắn gọn
- **Cách tái hiện lỗi**: Các bước chi tiết để tái hiện vấn đề
  ```
  1. Bước đầu tiên
  2. Bước thứ hai
  3. ...
  ```
- **Hành vi mong đợi**: Cái gì bạn dự kiến sẽ xảy ra
- **Hành vi thực tế**: Cái gì thực sự xảy ra
- **Ảnh chụp màn hình hoặc video** (nếu có liên quan)
- **Thông tin hệ thống:**
  - macOS version (ví dụ: macOS 14.2)
  - PHTV version
  - Xcode version (nếu build từ source)
- **Logs hoặc stack trace** (nếu có)

### Ví dụ báo cáo lỗi tốt

```markdown
**Tiêu đề:** Telex input không hoạt động trong Google Docs

**Cách tái hiện:**

1. Mở Google Docs
2. Chọn Telex input method từ menu PHTV
3. Gõ "vieetj"
4. Kết quả không hiển thị

**Hành vi mong đợi:**
Hiển thị "việt"

**Hành vi thực tế:**
Không có gì hiển thị

**Thông tin hệ thống:**

- macOS: 14.2
- PHTV: 1.0
- Chrome: Phiên bản mới nhất
```

## 💡 Đề xuất tính năng

Chúng tôi luôn chào đón các ý tưởng mới! Để đề xuất tính năng:

1. **Kiểm tra xem tính năng đã tồn tại chưa** bằng cách tìm kiếm trong [issues](../../issues)
2. **Tạo issue mới** với nhãn `enhancement`
3. **Mô tả chi tiết:**
   - **Vấn đề mà bạn cố gắng giải quyết**
   - **Giải pháp bạn đề xuất**
   - **Các giải pháp thay thế** bạn đã xem xét
   - **Ngữ cảnh bổ sung**

### Ví dụ đề xuất tính năng tốt

```markdown
**Tiêu đề:** Thêm hỗ trợ Theme tùy chỉnh

**Vấn đề:**
Hiện tại, tôi không thể tùy chỉnh màu sắc của menu bar icon và giao diện settings.

**Giải pháp đề xuất:**
Thêm tùy chọn "Theme" trong Settings cho phép người dùng chọn:

- Light theme
- Dark theme
- Auto (theo system)
- Custom colors (RGB picker)

**Giải pháp thay thế:**
Không có

**Ngữ cảnh:**
Tôi muốn PHTV khớp với theme tùy chỉnh của tôi.
```

## ✅ Gửi Pull Request

### Quy trình

1. **Cập nhật branch của bạn từ upstream:**

   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Commit các thay đổi của bạn:**

   ```bash
   git add .
   git commit -m "feat: Mô tả tính năng"
   # hoặc
   git commit -m "fix: Sửa lỗi cụ thể"
   ```

   Xem [Commit Message Guidelines](#commit-message-guidelines) phía dưới.

3. **Push branch của bạn:**

   ```bash
   git push origin feature/your-feature-name
   ```

4. **Tạo Pull Request:**
   - Đi đến repository gốc
   - Nhấn nút "Compare & pull request"
   - Điền thông tin chi tiết

### Pull Request Template

Khi tạo PR, vui lòng sử dụng template sau:

```markdown
## Mô tả

Mô tả ngắn gọn về thay đổi của bạn.

## Loại thay đổi

- [ ] Bug fix (sửa lỗi không ảnh hưởng đến API)
- [ ] New feature (tính năng mới)
- [ ] Breaking change (thay đổi có ảnh hưởng)
- [ ] Documentation update

## Cách tái hiện (nếu là bug fix)
```

## 🔨 Hướng dẫn phát triển

### Cấu trúc dự án

```
PHTV/
├── PHTV/
│   ├── Application/           # AppDelegate, main entry point
│   ├── Core/
│   │   ├── Engine/            # Core input method engine (C++)
│   │   │   ├── Engine.cpp/.h  # Logic chính
│   │   │   ├── Vietnamese.cpp/.h # Bảng mã tiếng Việt
│   │   │   ├── Macro.cpp/.h   # Quản lý macro
│   │   │   └── ...
│   │   └── Platforms/         # macOS-specific integration
│   ├── Managers/              # Business logic
│   ├── SwiftUI/               # Giao diện người dùng
│   │   ├── Views/             # SwiftUI views
│   │   ├── Controllers/       # Window/Status bar controllers
│   │   └── Utilities/         # Helper functions
│   └── Utils/                 # Utility functions
├── PHTV.xcodeproj/            # Xcode project
└── README.md
```

### Build và Test

```bash
# Build project
xcodebuild -project PHTV.xcodeproj -scheme PHTV

# Run tests (nếu có)
xcodebuild -project PHTV.xcodeproj -scheme PHTV test

# Clean build
xcodebuild -project PHTV.xcodeproj clean
```

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
- camelCase cho biến và hàm
- Thêm comment cho các logic phức tạp

### Commit Message Guidelines

Chúng tôi sử dụng [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**

- `feat`: Tính năng mới
- `fix`: Sửa lỗi
- `docs`: Thay đổi documentation
- `style`: Thay đổi format code (không ảnh hưởng đến logic)
- `refactor`: Refactor code
- `test`: Thêm hoặc sửa tests
- `chore`: Build, dependencies, v.v.

**Ví dụ:**

```
feat(telex): thêm hỗ trợ Quick Telex

Thêm tính năng Quick Telex cho phép gõ các cách phối hợp
như cc->ch, gg->gi, kk->kh một cách nhanh hơn.

Fixes #123
```

## 🧪 Testing

Trước khi gửi PR:

1. **Test tính năng của bạn thoroughly**
2. **Kiểm tra xem không break feature nào khác**
3. **Test trên các ứng dụng khác nhau** (Chrome, Safari, Word, v.v.)
4. **Kiểm tra trong Dark mode**
5. **Chạy trên macOS versions khác nhau** (nếu có)

## 📚 Tài liệu

Khi thêm tính năng mới, vui lòng cập nhật documentation:

- Cập nhật README.md nếu cần
- Thêm comments trong code
- Cập nhật CHANGELOG.md

## ❓ Câu hỏi?

- Tạo issue với nhãn `question`
- Tham gia discussion nếu có
- Contact maintainer

## 📄 Giấy phép

Bằng cách đóng góp, bạn đồng ý rằng đóng góp của bạn sẽ được cấp phép dưới cùng giấy phép GPL-3.0 với dự án.

---

**Cảm ơn đã đóng góp! 🎉**

Made with ❤️ by the PHTV community
