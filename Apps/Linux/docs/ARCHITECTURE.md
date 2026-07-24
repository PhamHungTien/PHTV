# Kiến trúc PHTV for Linux

## Mục tiêu

Linux không có một input framework duy nhất cho mọi desktop. PHTV cung cấp hai
adapter mỏng cho IBus và Fcitx 5, cùng gọi một engine và một tập test vector.
Không có adapter nào được tự triển khai lại quy tắc Telex/VNI.

## Thành phần

### `Shared/PHTVCore`

Swift library portable nhận `KeyEvent` + `InputContext` và trả `EditPlan` xác
định. Core quản lý session theo input context nhưng không gọi D-Bus, GLib, IBus,
Fcitx, Wayland hoặc X11.

### `PHTV.Linux.IBus`

IBus engine process viết bằng C++20 trên `libibus-1.0`, chịu trách nhiệm:

- đăng ký engine/component và lifecycle trên session bus;
- nhận key event, focus, reset, enable/disable;
- đọc surrounding text/cursor khi framework cho phép;
- cập nhật preedit, commit text và delete surrounding text;
- ánh xạ capability/input purpose sang `InputContext`.

Process này không gọi mạng hoặc mở Settings trong đường xử lý phím.

### `PHTV.Linux.Fcitx5`

Fcitx 5 shared-library addon C++20 triển khai input method engine, chịu trách
nhiệm tương đương adapter IBus qua `InputMethodEngineV2` và `InputContext`.

Addon chạy trong tiến trình Fcitx nên phải đặc biệt nghiêm ngặt về exception,
ownership và thời gian callback: lỗi adapter không được làm treo toàn bộ Fcitx.

### `PHTV.Linux.Settings`

Ứng dụng C++20 dùng GTK 4/libadwaita:

- onboarding cho IBus/Fcitx và chẩn đoán backend đang hoạt động;
- Settings, macro, từ điển, quy tắc theo ứng dụng, import/export;
- ghi cấu hình XDG atomically và phát notification qua session D-Bus;
- báo lỗi đã loại nội dung nhạy cảm.

Settings không bắt phím và không chạy thường trú chỉ để tạo tray icon. Desktop
IME indicator tiếp tục là nguồn trạng thái chính.

## Luồng nhập liệu

```text
framework key event
    └─► Linux adapter chuẩn hóa key/layout/capability
          └─► PHTVCore.handle(event, context)
                └─► EditPlan
                      ├─ passThrough
                      ├─ setPreedit(text, cursor)
                      ├─ commit(text)
                      ├─ deleteSurrounding(offset, length)
                      └─ resetSession
                            └─► IBus hoặc Fcitx API
```

`EditPlan` mô tả một giao dịch logic. Adapter không mô phỏng Backspace bằng
XTest/uinput khi framework đã cung cấp preedit, commit và surrounding text.

## Wayland và X11

PHTV không kết nối trực tiếp compositor để đọc phím. IBus/Fcitx cùng frontend IM
module/protocol của GTK, Qt và desktop sở hữu khác biệt Wayland/X11. Adapter chỉ
dùng capability được framework công bố và phải fallback an toàn khi ứng dụng
không cung cấp surrounding text.

## Session và concurrency

- Một Core session cho mỗi IBus engine context/Fcitx input context.
- Reset session khi focus-out, surrounding text mất đồng bộ hoặc framework yêu
  cầu reset.
- Callback phím không chờ file I/O, D-Bus round-trip hoặc network.
- Config được đọc từ immutable snapshot; reload diễn ra ngoài callback nóng.
- Không có singleton session dùng chung giữa các cửa sổ.

## Cấu hình XDG

- Config: `${XDG_CONFIG_HOME:-~/.config}/phtv/`.
- Data người dùng: `${XDG_DATA_HOME:-~/.local/share}/phtv/`.
- Cache: `${XDG_CACHE_HOME:-~/.cache}/phtv/`.
- Runtime notification/socket nếu cần: `$XDG_RUNTIME_DIR/phtv/`.

File có `schemaVersion`, permission tối thiểu, ghi tạm + fsync + atomic rename.
Không ghi dữ liệu người dùng vào `/usr` hoặc package-owned directory.

## Quy tắc theo ứng dụng

Client identity trên Linux không luôn đầy đủ. Adapter dùng tên chương trình,
desktop ID, sandbox ID và input purpose khi framework cung cấp; không dựa duy
nhất vào window title. Quy tắc không xác định phải fallback về hành vi mặc định,
không tự khóa ngôn ngữ.

## Cổng khả thi bắt buộc

1. Swift Core build/load ổn định trên glibc x86_64 qua C ABI.
2. IBus PoC hoạt động trên GNOME Wayland/X11 với GTK, Qt và Chromium.
3. Fcitx 5 PoC hoạt động trên KDE Wayland/X11 với cùng golden vectors.
4. Package cài/gỡ engine metadata và shared library sạch.
5. Không cần root khi chạy và không đọc raw input device.
6. Đóng gói Swift runtime phù hợp chính sách distro mục tiêu.

