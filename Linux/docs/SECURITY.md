# Bảo mật PHTV for Linux

Tài liệu này bổ sung [SECURITY.md](../../SECURITY.md).

## Ranh giới tin cậy

- IBus engine giao tiếp trên session D-Bus.
- Fcitx addon là shared library trong tiến trình Fcitx.
- Swift Core đi qua C ABI.
- Settings ghi config XDG và phát notification.
- Package installer sở hữu file hệ thống nhưng runtime không chạy bằng root.

## Yêu cầu bắt buộc

- Không đọc `/dev/input`, không tạo `uinput`, không dùng root/setuid/capability
  trong runtime thông thường.
- Không gọi mạng từ IBus engine hoặc Fcitx addon.
- Validate length/version/encoding tại C ABI, D-Bus và config parser.
- Fcitx addon bắt mọi exception tại boundary; IBus process fail closed và có
  giới hạn restart.
- Chỉ load library từ package-owned path; không dựa vào current directory hoặc
  biến môi trường không tin cậy trong launcher phát hành.
- Config/user dictionary có permission phù hợp, ghi atomically và chống symlink
  replacement trong thao tác nhạy cảm.
- Package/repository metadata được ký; release có checksum, SBOM và provenance.

## Logging và crash report

Không log key, preedit, committed text, surrounding text, Clipboard, macro,
window title hoặc document path. Core dump có thể chứa bộ nhớ ứng dụng/IME nên
không tự upload; báo lỗi phải do người dùng chủ động và có hướng dẫn kiểm duyệt.

## Kiểm thử bảo mật

- fuzz Core/ABI/config/D-Bus payload;
- ASan/UBSan/TSan phù hợp cho native adapters;
- symlink/path traversal và config race tests;
- package upgrade/downgrade/tamper tests;
- D-Bus spoofing, disconnect và malformed reply;
- dependency/license/secret scan trước release.

