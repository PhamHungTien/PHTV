# Kiểm thử PHTV for Linux

## Các lớp kiểm thử

### Core và ABI

- golden vectors Telex/VNI/Unicode/Auto English/macro/session;
- UTF-8/UTF-16, struct layout, null/buffer limit và memory ownership;
- fuzz event sequence, concurrent contexts và load/unload Swift runtime;
- cùng output với macOS/Windows cho input trung lập.

### IBus integration

- engine registration, enable/disable/focus/reset;
- preedit, commit, surrounding text và capability fallback;
- D-Bus disconnect/restart và session logout/login;
- GTK/Qt/Electron trên Wayland/X11.

### Fcitx 5 integration

- addon load/unload/config reload;
- input context lifecycle, key filtering và commit;
- Fcitx restart/crash recovery;
- không exception hoặc ownership lỗi thoát khỏi addon.

### Settings và packaging

- keyboard navigation, screen reader, scale factor, light/dark;
- config migration, atomic write, corrupted/unknown schema;
- install/upgrade/downgrade/uninstall trên image sạch;
- package file ownership và leftover user data.

## Ma trận desktop và ứng dụng

| Nhóm | Đại diện | Backend | Mức |
| --- | --- | --- | --- |
| GNOME Wayland | GTK 4, Firefox | IBus | P0 |
| GNOME X11 | GTK 3/4 | IBus | P1 |
| KDE Wayland | Qt 6, Chromium | Fcitx 5 | P0 |
| KDE X11 | Qt 5/6 | Fcitx 5 | P1 |
| Office | LibreOffice | cả hai | P0 |
| Electron/IDE | VS Code, JetBrains | cả hai | P0 |
| Terminal | GNOME Console, Konsole | cả hai | P1 |
| Sandboxed | Flatpak app test host | cả hai | P1 |

## Stress corpus

- câu tiếng Việt dài, gõ nhanh và nhiều lần đổi dấu;
- chuyển Việt/Anh như `tiếng Việt scenario tiếp tục`;
- Backspace, selection, focus switch, composition cancel;
- emoji, combining marks, ký tự ngoài BMP, dead key và layout non-Latin;
- restart IBus/Fcitx khi Settings đang mở hoặc config vừa thay đổi.

## Điều kiện release

- Không retry ẩn test lỗi; P0/P1 regression phải đóng.
- Core vectors giống giữa các nền tảng.
- Package cài/upgrade/uninstall đạt trên distro matrix.
- Không có raw-input permission hoặc network trong IM component.
- Log/artifact đã kiểm tra không chứa key, preedit hay surrounding text.

