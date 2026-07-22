# Phát triển PHTV for Linux

## Trạng thái hiện tại

Chưa có binary hoặc build project. Không chạy lệnh build giả trước khi SwiftPM
package/CMake target đầu tiên được tạo và CI Linux kiểm chứng.

## Toolchain dự kiến

- Swift toolchain chính thức và SwiftPM;
- Clang hoặc GCC hỗ trợ C++20;
- CMake, Ninja và `pkg-config`;
- development packages cho GTK 4, libadwaita, IBus và Fcitx 5;
- D-Bus/session desktop thực để chạy integration tests.

Tên package khác nhau theo distro; tài liệu lệnh cài cụ thể chỉ được thêm sau
khi ma trận distro được khóa. Tham khảo [Swift Linux](https://www.swift.org/install/)
và tài liệu backend trong [README](../README.md#tài-liệu-nền-tảng-chính-thức).

## Cấu trúc build dự kiến

```text
Shared/PHTVCore/Package.swift       # Swift core
Linux/CMakeLists.txt                # native adapters/settings
Linux/src/PHTV.Linux.IBus/          # executable IBus engine
Linux/src/PHTV.Linux.Fcitx5/        # shared-library addon
Linux/src/PHTV.Linux.Settings/      # GTK/libadwaita app
Linux/tests/                        # native/integration/package tests
```

CMake import Core qua C header + library artifact. Không để CMake tự tải
dependency không khóa phiên bản trong release build.

## Quy trình thay đổi

1. Thêm golden vector hoặc test tái hiện ở `Shared/TestVectors`.
2. Thay đổi Core và chạy cùng vector trên macOS/Linux.
3. Kiểm tra C ABI, UTF encoding và ownership.
4. Thay đổi đúng adapter IBus/Fcitx; không copy workaround giữa backend nếu API
   framework khác nhau.
5. Chạy ma trận trong [TESTING.md](TESTING.md).
6. Cập nhật ADR khi đổi backend, IPC, package layout hoặc privacy boundary.

## Quy tắc code

- Swift 6 strict concurrency; không import framework hệ điều hành trong Core.
- C++20, RAII, smart pointer và exception không thoát qua C callback/ABI.
- GObject/IBus reference ownership phải thể hiện rõ trong wrapper.
- Fcitx addon callback không blocking và không để crash thoát ra host.
- UI không chứa logic engine; cấu hình có schema và migration.
- Không log key, preedit, surrounding text, Clipboard, macro hoặc document title.

## Công cụ repository

Khi có target thật, entrypoint `scripts/dev.swift` sẽ thêm `linux-doctor`,
`linux-build`, `linux-test` và `linux-package`. Local tooling tiếp tục bằng Swift;
không thêm script `.sh`/`.py` vào repository.

