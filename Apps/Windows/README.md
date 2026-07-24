# PHTV for Windows

> Trạng thái: **đang triển khai TSF proof of concept**. Repository đã có Unicode
> Telex/VNI portable, C ABI, C++ Core bridge, TSF DLL và WinUI Settings project.
> Chưa có installer phát hành; việc đăng ký/kích hoạt và tương thích ứng dụng
> vẫn phải được xác nhận trên máy Windows thật.

PHTV for Windows là nhánh sản phẩm Windows của PHTV. Mục tiêu là dùng lại engine
Swift và dữ liệu ngôn ngữ hiện có, đồng thời tích hợp đúng chuẩn Windows bằng
Text Services Framework (TSF) và cung cấp giao diện quản lý native bằng WinUI 3.

## Nguyên tắc

- Bộ gõ chạy offline; không ghi hoặc truyền nội dung người dùng nhập.
- TSF là đường nhập liệu chính. Không dùng global keyboard hook + `SendInput`
  làm kiến trúc mặc định.
- Engine không phụ thuộc giao diện hoặc API riêng của macOS hay Windows.
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
Apps/Windows/
├── README.md
├── PHTV.Windows.slnx
├── Directory.Build.props
├── Directory.Packages.props
├── global.json
├── docs/
│   ├── ARCHITECTURE.md
│   ├── DEVELOPMENT.md
│   ├── DISTRIBUTION.md
│   ├── PRIVACY.md
│   ├── ROADMAP.md
│   ├── SETTINGS_SNAPSHOT.md
│   ├── SECURITY.md
│   ├── TESTING.md
│   └── adr/
│       └── 0001-native-windows-stack.md
├── src/
│   ├── PHTV.Windows.Contracts/  # config schema/version
│   ├── PHTV.Windows.CoreBridge/ # C++ wrapper quanh Swift C ABI
│   ├── PHTV.Windows.IME/        # TSF Text Input Processor
│   └── PHTV.Windows.App/        # WinUI companion app
└── tests/
    ├── PHTV.Windows.Contracts.Tests/
    ├── PHTV.Windows.CoreBridge.Tests/
    └── PHTV.Windows.SettingsSnapshot.Tests/
```

Engine và test vector dùng chung nằm tại
[Shared/README.md](../../Shared/README.md),
không được copy vào từng nền tảng.

Swift package dùng chung nằm tại
[`Shared/PHTVCore`](../../Shared/PHTVCore/README.md). TSF hiện đã nhận phím qua
`ITfKeyEventSink`, gọi Core bằng C ABI và áp dụng replacement bằng TSF edit
session/composition. Settings app giữ JSON làm nguồn cấu hình và ghi thêm runtime
snapshot nhị phân atomically; TSF nạp snapshot khi activation để dùng đúng trạng
thái Việt/Anh và Telex/VNI mà không parse JSON trong DLL nhập liệu. Xem
[contract snapshot v1](docs/SETTINGS_SNAPSHOT.md).

## Nền tảng mục tiêu ban đầu

- Windows 10 version 1809 trở lên và Windows 11.
- Kiến trúc x64 trước; arm64 sau khi x64 đạt tiêu chí ổn định.
- Swift 6.3.3 chính thức cho Windows.
- .NET SDK 10.0.100 LTS, cho phép roll forward trong patch 10.0.
- Windows App SDK 2.3.1 stable.
- Windows SDK 10.0.26100.0 và MSVC v143 cho native component.
- Visual Studio 2026 cho trải nghiệm solution đầy đủ; CI dùng MSBuild v143 và
  .NET CLI độc lập để build tái lập.

## Tài liệu

- [Kiến trúc](docs/ARCHITECTURE.md)
- [Thiết lập môi trường phát triển](docs/DEVELOPMENT.md)
- [Roadmap và tiêu chí hoàn thành](docs/ROADMAP.md)
- [Chiến lược kiểm thử](docs/TESTING.md)
- [Runtime Settings Snapshot v1](docs/SETTINGS_SNAPSHOT.md)
- [Bảo mật](docs/SECURITY.md)
- [Quyền riêng tư](docs/PRIVACY.md)
- [Đóng gói và phát hành](docs/DISTRIBUTION.md)
- [ADR 0001: Native Windows stack](docs/adr/0001-native-windows-stack.md)

## Tài liệu nền tảng chính thức

- [Swift trên Windows](https://www.swift.org/install/windows/)
- [Text Services Framework](https://learn.microsoft.com/windows/win32/tsf/what-is-text-services-framework)
- [Yêu cầu đối với IME](https://learn.microsoft.com/windows/apps/develop/input/input-method-editor-requirements)
- [Windows App SDK](https://learn.microsoft.com/windows/apps/windows-app-sdk/)
