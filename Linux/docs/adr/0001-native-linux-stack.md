# ADR 0001: Native Linux input stack

- Trạng thái: Accepted
- Ngày: 2026-07-22
- Phạm vi: nền móng PHTV for Linux

## Bối cảnh

Linux desktop dùng nhiều input framework và compositor. Port mô hình CGEvent
của macOS bằng raw keyboard hook sẽ xung đột bảo mật Wayland, selection,
composition và sandbox.

## Quyết định

1. IBus engine là backend đầu tiên cho GNOME.
2. Fcitx 5 C++ addon là backend cho KDE và hệ thống dùng Fcitx.
3. GTK 4/libadwaita là toolkit Settings; desktop IM indicator hiển thị trạng
   thái thay vì custom tray mặc định.
4. `Shared/PHTVCore` tiếp tục bằng Swift, giao tiếp qua C ABI có version.
5. Native adapters/settings dùng C++20; CMake/Ninja là build system native.
6. Package manager của distro sở hữu install/update/uninstall.

## Phương án không chọn

### Raw evdev/uinput/X11 hook

Không chọn vì cần quyền rộng, không phù hợp Wayland/App sandbox và dễ tạo race
condition khi mô phỏng Backspace/Unicode.

### Chỉ IBus hoặc chỉ Fcitx

Không chọn vì làm trải nghiệm kém tự nhiên trên một nhóm desktop lớn. Hai adapter
mỏng dùng chung Core ít rủi ro hơn ép người dùng đổi framework.

### Electron/Tauri/Flutter cho Settings

Không chọn ở giai đoạn đầu vì tăng runtime/bundle và không tích hợp GNOME bằng
GTK/libadwaita tốt bằng UI native. Settings không cần một web runtime.

### Flatpak/AppImage làm gói IME chính

Không chọn vì input engine/addon cần tích hợp host framework và lifecycle package
hệ thống; sandboxed UI có thể được đánh giá riêng về sau.

## Hệ quả

- Linux có hai adapter và ma trận test riêng, nhưng chỉ một engine.
- Fcitx addon có blast radius lớn hơn IBus process nên boundary C++ phải chặt.
- Packaging theo distro tốn công hơn một binary tự cập nhật nhưng đúng kỳ vọng
  vận hành và bảo mật của Linux.
- Swift runtime/ABI/package footprint là PoC gate bắt buộc trước khi xây UI đầy
  đủ.

