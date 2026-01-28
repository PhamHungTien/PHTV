# PHTV for Windows (In Development)

Bộ gõ PHTV phiên bản dành cho Windows đang trong quá trình phát triển.

## Trạng thái hiện tại
- [x] Core Engine C++ (OpenKey) tích hợp thành công.
- [x] Giao diện cài đặt (WPF/C#) đã được thiết kế hiện đại theo phong cách macOS.
- [ ] Tính năng gõ tiếng Việt cơ bản.
- [ ] Hệ thống Tray icon và Menu.
- [ ] Tự động cập nhật.

## Yêu cầu hệ thống
- Windows 10/11 (x64)
- .NET 6.0 Runtime

## Hướng dẫn Build (Dành cho Developer)
Yêu cầu cài đặt [.NET SDK 6.0](https://dotnet.microsoft.com/en-us/download/dotnet/6.0).

```powershell
# Build toàn bộ dự án UI
dotnet build Windows/UI/PHTV.UI.csproj -c Release
```

Sử dụng Visual Studio 2022 để mở giải pháp và phát triển.
