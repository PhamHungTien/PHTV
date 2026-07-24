# PHTV.Linux.Settings

Companion Settings app C++20 dùng GTK 4/libadwaita.

## Trách nhiệm

- onboarding và chẩn đoán IBus/Fcitx;
- cấu hình bộ gõ, macro, từ điển và quy tắc ứng dụng;
- import/export và schema migration;
- ghi XDG config atomically, phát session D-Bus notification;
- báo lỗi đã loại dữ liệu nhạy cảm.

App không bắt phím, không thay thế desktop IM indicator và không chạy nền nếu
không có tính năng đã được người dùng bật cần service riêng.

