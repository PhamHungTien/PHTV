# Roadmap PHTV for Linux

## Giai đoạn 0 — Nền móng

- [x] Chọn IBus + Fcitx 5 thay cho raw keyboard hook.
- [x] Chọn GTK 4/libadwaita cho Settings.
- [x] Đưa hợp đồng Core dùng chung ra `Shared/`.
- [x] Tạo tài liệu kiến trúc, test, bảo mật, privacy và distribution.
- [ ] Khóa distro/toolchain/dependency matrix cho PoC.

## Giai đoạn 1 — Portable Core

- [ ] Tách engine Swift khỏi Carbon/ApplicationServices/Darwin.
- [ ] Tạo `EditPlan`, C ABI có version và schema test vector.
- [ ] Build/test Core trên macOS và glibc Linux x86_64.
- [ ] Kiểm tra sanitizer/fuzz tại C ABI.

**Cổng:** golden vectors giống nhau 100% và không có lỗi ownership/concurrency.

## Giai đoạn 2 — IBus proof of concept

- [ ] Component/engine metadata và session D-Bus lifecycle.
- [ ] Preedit/commit/delete-surrounding trong GTK, Qt và Chromium.
- [ ] GNOME Wayland và X11; password/input-purpose fallback.
- [ ] Cài/gỡ engine sạch bằng package thử nghiệm.

**Cổng:** không mất/lặp/đảo ký tự trong stress corpus và không cần raw input.

## Giai đoạn 3 — Fcitx 5 proof of concept

- [ ] Addon/input-method metadata và `InputMethodEngineV2`.
- [ ] KDE Plasma Wayland/X11 cùng application matrix.
- [ ] Reload config, context lifecycle và crash isolation.
- [ ] Kết quả Core giống backend IBus.

**Cổng:** lỗi adapter không làm treo Fcitx; install/uninstall không để metadata
hỏng.

## Giai đoạn 4 — MVP

- [ ] Telex, VNI, Unicode và chuyển Việt–Anh.
- [ ] GTK/libadwaita Settings và onboarding backend.
- [ ] Auto English, chính tả, từ điển cá nhân.
- [ ] Quy tắc khóa/tự chuyển theo ứng dụng khi identity khả dụng.
- [ ] Import/export có schema version và báo lỗi đã lọc dữ liệu.
- [ ] `.deb` và `.rpm` reproducible packages.

## Giai đoạn 5 — Mở rộng và phát hành ổn định

- [ ] Macro/snippets, nhiều bảng mã và layout.
- [ ] Clipboard/Picker chỉ sau privacy review riêng.
- [ ] arm64, Arch package và downstream distro collaboration.
- [ ] SBOM, package signing, repository metadata và rollback.
- [ ] Accessibility/localization review trên GNOME và KDE.

