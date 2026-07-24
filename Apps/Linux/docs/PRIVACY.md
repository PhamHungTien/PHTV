# Quyền riêng tư PHTV for Linux

## Cam kết

Engine, từ điển, chính tả, Auto English và macro chạy tại máy. PHTV không thu
thập, lưu hoặc truyền nội dung người dùng gõ trong ứng dụng khác.

IBus/Fcitx adapter chỉ giữ context tối thiểu cần cho composition hiện tại. Khi
focus mất, field nhạy cảm hoặc framework yêu cầu reset, session tương ứng phải
được xóa.

## Dữ liệu cục bộ

| Dữ liệu | Vị trí XDG | Mặc định |
| --- | --- | --- |
| Cài đặt/quy tắc app | config | lưu cục bộ |
| Macro/từ điển cá nhân | data | lưu cục bộ |
| Cache không nhạy cảm | cache | giới hạn/xóa được |
| Clipboard history | data | tắt |
| Log chẩn đoán | state/journal | không chứa nội dung nhập |

Không dùng nội dung gõ làm analytics kể cả hash. Không đồng bộ cloud nếu chưa có
consent riêng, threat model và cập nhật tài liệu.

## Network boundary

IME backend không có network client. Package manager xử lý update. GIF/Sticker,
telemetry hoặc crash upload chỉ được thêm sau privacy review riêng và phải tắt
theo mặc định nếu có thể chứa nội dung người dùng.

