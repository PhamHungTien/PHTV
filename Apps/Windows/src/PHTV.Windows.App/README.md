# PHTV.Windows.App

Companion app native viết bằng C# và WinUI 3.

## Lát cắt hiện có

- shell WinUI native dùng NavigationView, Mica và accessibility labels;
- bật/tắt tiếng Việt, chọn Telex/VNI;
- config schema v1 dùng chung;
- đọc/ghi `%LocalAppData%\PHTV\settings.json` atomically;
- không nhận hoặc ghi nội dung phím.

TSF chưa đọc snapshot này nên UI đang là nền móng Settings thật, chưa phải control
plane hoàn chỉnh của IME.

## Trách nhiệm

- onboarding và kiểm tra trạng thái cài/kích hoạt IME;
- Settings, tray và chuyển Việt–Anh;
- quản lý macro, từ điển và quy tắc theo ứng dụng;
- import/export, migration và reset;
- update UI, version, privacy và báo lỗi đã lọc dữ liệu.

App không nhận luồng phím từ IME và không thay thế TSF bằng keyboard hook. UI chỉ
ghi cấu hình có schema/version; IME quyết định thời điểm nạp snapshot an toàn.
