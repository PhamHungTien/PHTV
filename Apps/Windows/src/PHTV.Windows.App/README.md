# PHTV.Windows.App

Companion app native viết bằng C# và WinUI 3.

## Trách nhiệm

- onboarding và kiểm tra trạng thái cài/kích hoạt IME;
- Settings, tray và chuyển Việt–Anh;
- quản lý macro, từ điển và quy tắc theo ứng dụng;
- import/export, migration và reset;
- update UI, version, privacy và báo lỗi đã lọc dữ liệu.

App không nhận luồng phím từ IME và không thay thế TSF bằng keyboard hook. UI chỉ
ghi cấu hình có schema/version; IME quyết định thời điểm nạp snapshot an toàn.

