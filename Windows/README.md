# PHTV for Windows

> Trạng thái: **khởi tạo kiến trúc**. Thư mục này chưa chứa bản Windows có thể
> build hoặc cài đặt.

PHTV for Windows là nhánh sản phẩm Windows của PHTV. Mục tiêu là dùng lại engine
Swift và dữ liệu ngôn ngữ hiện có, đồng thời tích hợp đúng chuẩn Windows bằng
Text Services Framework (TSF) và cung cấp giao diện quản lý native bằng WinUI 3.

## Nguyên tắc

- Bộ gõ chạy offline; không ghi hoặc truyền nội dung người dùng nhập.
- TSF là đường nhập liệu chính. Không dùng global keyboard hook + `SendInput`
  làm kiến trúc mặc định.
- Engine không phụ thuộc giao diện hoặc API riêng của macOS/Windows.
- Ứng dụng WinUI không bắt phím; TSF không thực hiện cập nhật hoặc truy cập mạng.
- Mọi tính năng tương thích ứng dụng phải có phạm vi rõ ràng và regression test.

## Kiến trúc dự kiến

```text
Ứng dụng đang nhập
       ▲
       │ TSF edit session
       │
PHTV.Windows.IME (C++/WinRT, COM DLL)
       │ C ABI
       ▼
Shared/PHTVCore (Swift)

PHTV.Windows.App (C# + WinUI 3)
       └── cài đặt, onboarding, tray, chẩn đoán và cập nhật
```

Chi tiết và các ranh giới an toàn nằm trong
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Cấu trúc thư mục

```text
Windows/
├── README.md
├── docs/
│   ├── ARCHITECTURE.md
│   ├── DEVELOPMENT.md
│   ├── DISTRIBUTION.md
│   ├── PRIVACY.md
│   ├── ROADMAP.md
│   ├── SECURITY.md
│   ├── TESTING.md
│   └── adr/
│       └── 0001-native-windows-stack.md
├── src/
│   ├── PHTV.Windows.IME/   # TSF Text Input Processor
│   └── PHTV.Windows.App/   # WinUI 3 companion app
└── tests/                  # Test vectors và integration tests Windows
```

Engine và test vector dùng chung nằm tại [Shared/README.md](../Shared/README.md),
không được copy vào từng nền tảng.

Các thư mục `src/` hiện chỉ có tài liệu hợp đồng thành phần. Project Visual
Studio/SwiftPM sẽ chỉ được tạo sau khi PoC TSF vượt qua các cổng trong
[ROADMAP.md](docs/ROADMAP.md).

## Nền tảng mục tiêu ban đầu

- Windows 10 version 1809 trở lên và Windows 11.
- Kiến trúc x64 trước; arm64 sau khi x64 đạt tiêu chí ổn định.
- Swift toolchain chính thức cho Windows.
- Visual Studio 2022, Windows SDK và Windows App SDK.

Phiên bản SDK cụ thể phải được khóa trong source control khi project đầu tiên
được tạo, không dùng mô tả “latest” trong build tái lập.

## Tài liệu

- [Kiến trúc](docs/ARCHITECTURE.md)
- [Thiết lập môi trường phát triển](docs/DEVELOPMENT.md)
- [Roadmap và tiêu chí hoàn thành](docs/ROADMAP.md)
- [Chiến lược kiểm thử](docs/TESTING.md)
- [Bảo mật](docs/SECURITY.md)
- [Quyền riêng tư](docs/PRIVACY.md)
- [Đóng gói và phát hành](docs/DISTRIBUTION.md)
- [ADR 0001: Native Windows stack](docs/adr/0001-native-windows-stack.md)

## Tài liệu nền tảng chính thức

- [Swift trên Windows](https://www.swift.org/install/windows/)
- [Text Services Framework](https://learn.microsoft.com/windows/win32/tsf/what-is-text-services-framework)
- [Yêu cầu đối với IME](https://learn.microsoft.com/windows/apps/develop/input/input-method-editor-requirements)
- [Windows App SDK](https://learn.microsoft.com/windows/apps/windows-app-sdk/)
