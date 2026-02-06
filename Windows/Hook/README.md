# PHTV Windows Hook Daemon

`phtv_windows_hook_daemon` là tiến trình native bắt bàn phím/mouse bằng low-level hook và gọi shared engine để xử lý tiếng Việt.

## Nguồn tham chiếu

Luồng xử lý được thiết kế theo mô hình OpenKey win32:

- Hook `WH_KEYBOARD_LL` / `WH_MOUSE_LL`
- Gọi engine trên mỗi `KeyDown`
- Synthesize output bằng `SendInput`
- Đồng bộ backspace cho bảng mã double-code (VNI/Unicode Compound)

## Build

```bash
cmake -S . -B build -G Ninja
cmake --build build --target phtv_windows_hook_daemon --config Release
```

## Run

```bash
./build/windows/Release/phtv_windows_hook_daemon.exe
```

Nếu cần gõ trong ứng dụng chạy quyền cao (admin), daemon cũng cần chạy cùng mức quyền.

## Runtime Config

Daemon tự reload config từ:

- `%LOCALAPPDATA%/PHTV/runtime-config.ini`
- `%LOCALAPPDATA%/PHTV/runtime-macros.tsv`

Các file này được Windows settings app ghi tự động mỗi lần thay đổi cấu hình.

Có thể override runtime directory bằng biến môi trường:

- `PHTV_RUNTIME_DIR=D:\PHTV\Runtime`
