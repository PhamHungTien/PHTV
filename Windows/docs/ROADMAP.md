# Roadmap PHTV for Windows

Roadmap dùng cổng chất lượng thay cho ngày phát hành cố định. Một giai đoạn chỉ
được đóng khi toàn bộ tiêu chí của nó đạt trên CI và máy Windows thật.

## Giai đoạn 0 — Nền móng

- [x] Chọn WinUI 3 cho companion app và TSF cho IME.
- [x] Xác định ranh giới Swift Core/C ABI/TSF.
- [x] Tạo tài liệu phát triển, kiểm thử, bảo mật và phát hành ban đầu.
- [ ] Ghi nhận baseline test của engine macOS trước khi tách Core.
- [ ] Chọn và khóa Windows SDK, Windows App SDK, .NET và Swift toolchain.

## Giai đoạn 1 — Portable Core

- [ ] Tách engine thành Swift package không phụ thuộc macOS.
- [ ] Thay Carbon/ApplicationServices/Darwin bằng adapter hoặc API portable.
- [ ] Đưa từ điển và test vector sang resource độc lập nền tảng.
- [ ] Thiết kế `EditPlan` và C ABI có version.
- [ ] Build/test Core trên macOS và Windows x64 cho kết quả giống nhau.

**Cổng:** toàn bộ golden vectors bằng nhau giữa hai nền tảng; sanitizer không
phát hiện lỗi ownership tại C ABI.

## Giai đoạn 2 — TSF proof of concept

- [ ] Đăng ký Text Input Processor per-user trên máy test.
- [ ] Bật/tắt Việt–Anh và commit composition trong Notepad.
- [ ] Kiểm chứng Office, Chromium/Electron, WinUI và AppContainer.
- [ ] Kiểm chứng đóng gói Swift runtime, unload DLL và ký binary.
- [ ] Chọn cơ chế cấu hình/notification dựa trên kết quả AppContainer.

**Cổng:** không mất/lặp/đảo ký tự trong bộ câu stress; cài và gỡ không để lại
language profile hoặc COM registration hỏng.

## Giai đoạn 3 — MVP

- [ ] Telex, VNI, Unicode và chuyển Việt–Anh.
- [ ] WinUI Settings, tray, onboarding và trạng thái IME.
- [ ] Tự khôi phục tiếng Anh, chính tả và từ điển cá nhân.
- [ ] Quy tắc khóa/tự chuyển tiếng Anh theo ứng dụng.
- [ ] Import/export cấu hình có schema version.
- [ ] Báo lỗi đã loại dữ liệu nhạy cảm.

**Cổng:** test matrix mức P0 đạt; không có crash/hang đã biết trong luồng nhập
cơ bản; installer và uninstaller chạy sạch trên máy mới.

## Giai đoạn 4 — Feature parity có chọn lọc

- [ ] Macro và text snippets.
- [ ] Clipboard history với consent và retention rõ ràng.
- [ ] Emoji/GIF Picker sau khi hoàn tất privacy review riêng.
- [ ] Nhiều bảng mã và layout bàn phím.
- [ ] Rule tương thích Terminal, IDE và ứng dụng đặc thù.
- [ ] Windows arm64.

Tính năng macOS chỉ được port khi có API Windows phù hợp và lợi ích rõ ràng;
không sao chép workaround CGEvent/Accessibility sang TSF.

## Giai đoạn 5 — Phát hành ổn định

- [ ] Code signing, SBOM, dependency/license review.
- [ ] CI release tái lập cho x64 và arm64.
- [ ] Kênh Stable/Beta, rollback và kiểm tra cập nhật.
- [ ] Accessibility, localization và UX review.
- [ ] Threat model và external security review cho DLL TSF/installer.

