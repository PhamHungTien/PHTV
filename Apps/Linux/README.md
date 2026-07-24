# PHTV for Linux

> Trạng thái: **khởi tạo kiến trúc**. Thư mục này chưa chứa package Linux có thể
> build hoặc cài đặt.

PHTV for Linux dùng engine Swift chung nhưng tích hợp qua framework bộ gõ chuẩn
của desktop Linux. IBus là backend đầu tiên cho GNOME; Fcitx 5 được hỗ trợ bằng
addon native cho KDE Plasma và các hệ thống chọn Fcitx.

## Nguyên tắc

- IBus/Fcitx 5 là đường nhập liệu chính; không đọc `/dev/input`, không dùng
  `uinput`, XRecord hay global hook làm kiến trúc mặc định.
- Hỗ trợ Wayland và X11 thông qua input-method framework của desktop.
- Engine chạy offline và không log hoặc truyền nội dung người dùng nhập.
- Settings dùng GTK 4/libadwaita; trạng thái IME ưu tiên indicator sẵn có của
  desktop thay vì tạo tray icon riêng không nhất quán.
- Cài đặt, cập nhật và gỡ bỏ qua package manager của distro, không tự sửa file hệ
  thống bằng script tải từ mạng.

## Kiến trúc dự kiến

```text
Ứng dụng GTK/Qt/Chromium/Electron
                ▲
                │ preedit / commit / surrounding text
        ┌───────┴────────┐
        │                │
PHTV.Linux.IBus    PHTV.Linux.Fcitx5
        │                │
        └────── C ABI ───┘
                │
                ▼
       Shared/PHTVCore (Swift)

PHTV.Linux.Settings (C++ + GTK 4/libadwaita)
       └── cấu hình XDG và notification qua session D-Bus
```

## Cấu trúc thư mục

```text
Linux/
├── README.md
├── docs/
│   ├── ARCHITECTURE.md
│   ├── COMPATIBILITY.md
│   ├── DEVELOPMENT.md
│   ├── DISTRIBUTION.md
│   ├── PRIVACY.md
│   ├── ROADMAP.md
│   ├── SECURITY.md
│   ├── TESTING.md
│   └── adr/0001-native-linux-stack.md
├── src/
│   ├── PHTV.Linux.IBus/
│   ├── PHTV.Linux.Fcitx5/
│   └── PHTV.Linux.Settings/
└── tests/
```

Engine, contracts và golden vectors dùng chung nằm tại
[Shared/README.md](../Shared/README.md).

## Nền tảng mục tiêu ban đầu

- glibc Linux x86_64; arm64 sau khi x86_64 đạt tiêu chí ổn định.
- GNOME/IBus và KDE Plasma/Fcitx 5 trên Wayland; X11 là ma trận tương thích.
- Swift toolchain chính thức cho Linux.
- C++20, CMake/Ninja, GTK 4, libadwaita, IBus 1.5 và Fcitx 5.

Phiên bản dependency tối thiểu sẽ được khóa sau PoC trên các distro mục tiêu,
không dùng “latest” trong pipeline phát hành tái lập.

## Tài liệu

- [Kiến trúc](docs/ARCHITECTURE.md)
- [Môi trường phát triển](docs/DEVELOPMENT.md)
- [Roadmap](docs/ROADMAP.md)
- [Kiểm thử](docs/TESTING.md)
- [Ma trận tương thích](docs/COMPATIBILITY.md)
- [Bảo mật](docs/SECURITY.md)
- [Quyền riêng tư](docs/PRIVACY.md)
- [Đóng gói và phát hành](docs/DISTRIBUTION.md)
- [ADR 0001: Native Linux stack](docs/adr/0001-native-linux-stack.md)

## Tài liệu nền tảng chính thức

- [Swift trên Linux](https://www.swift.org/install/)
- [IBus](https://github.com/ibus/ibus)
- [Fcitx 5 input method addon](https://fcitx-im.org/wiki/Develop_an_simple_input_method)
- [GTK 4](https://docs.gtk.org/gtk4/)
- [libadwaita](https://gnome.pages.gitlab.gnome.org/libadwaita/)

