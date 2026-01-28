# PHTV for Windows (Beta)

Bộ gõ PHTV phiên bản dành cho Windows với giao diện hiện đại (WPF) và lõi xử lý C++ tối ưu.

## Tính năng
- [x] Giao diện cài đặt hiện đại (Modern WPF UI).
- [x] Tray Icon với menu ngữ cảnh và chuyển đổi nhanh.
- [x] Single-File EXE (chạy ngay không cần cài đặt).
- [x] Tự động phát hiện và sửa lỗi gõ tiếng Anh (Auto English Restore).
- [ ] Tự động cập nhật.

## Yêu cầu hệ thống
- Windows 10/11 (x64)
- .NET 6.0 Runtime (đã được nhúng sẵn trong bản EXE nhưng khuyến khích cài đặt nếu muốn nhẹ hơn).

## Hướng dẫn Build (Dành cho Developer)

### Yêu cầu:
1.  **Visual Studio 2022** (với C++ Desktop Development).
2.  **.NET 6.0 SDK**.
3.  **CMake** (thường đi kèm Visual Studio).

### Cách build:
Chạy file script `Windows/build.bat`.

```cmd
cd Windows
build.bat
```

Script sẽ tự động:
1.  Build core C++ (`PHTVCore.dll`).
2.  Build giao diện C# (`PHTV.UI.exe`).
3.  Đóng gói tất cả thành 1 file duy nhất tại `Windows/build/Release/PHTV.exe`.