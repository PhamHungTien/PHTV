# Đóng gói và phát hành PHTV for Windows

## Mục tiêu

Phát hành phải cài, nâng cấp và gỡ cả companion app lẫn TSF profile một cách
atomic, có chữ ký và có thể phục hồi khi một bước thất bại.

## Thành phần phát hành dự kiến

- `PHTV.Windows.App` packaged app (WinUI 3);
- TSF DLL cho từng kiến trúc hỗ trợ;
- Swift runtime/Core binary cần thiết;
- resource từ điển và localization;
- manifest, license, privacy, SBOM và checksum.

Không quyết định MSIX/Store/bootstrapper cuối cùng trước khi PoC chứng minh cách
đăng ký TSF, cập nhật và rollback đáp ứng yêu cầu Windows. Quyết định đó phải có
ADR riêng.

## Phiên bản

- Dùng cùng semantic version sản phẩm với macOS khi tính năng tương ứng được
  phát hành, nhưng build number và artifact theo nền tảng độc lập.
- C ABI, config schema và IPC protocol có version riêng.
- Không cho App/IME/Core có major ABI không tương thích chạy cùng nhau.

## Pipeline dự kiến

1. Restore dependency từ lockfile.
2. Build Core, IME và App cho từng kiến trúc.
3. Chạy unit, ABI, integration và UI smoke tests.
4. Tạo SBOM, quét dependency và secret.
5. Ký binary và package bằng identity bảo vệ ngoài repository.
6. Cài/upgrade/uninstall trên Windows runner hoặc máy kiểm thử sạch.
7. Xuất checksum, release notes và provenance.
8. Promote cùng artifact đã kiểm thử từ Beta sang Stable.

## Kênh cập nhật

Sparkle chỉ dùng cho macOS và không được port sang Windows. Các lựa chọn Windows
gồm Microsoft Store, App Installer/MSIX hoặc updater đã ký; lựa chọn cuối cùng
phụ thuộc kết quả PoC TSF và nhu cầu rollback.

## Tiêu chí rollback

- Có thể ngừng phân phối update mà không đổi binary đã ký.
- Bản cũ đọc được cấu hình mới hoặc từ chối an toàn theo schema version.
- Uninstall xóa TSF registration và file chương trình nhưng không tự xóa dữ liệu
  người dùng nếu chưa hỏi rõ.
- Tài liệu phục hồi language profile hỏng phải có trước Beta công khai.

