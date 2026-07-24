# Tương thích Linux

## Phạm vi mục tiêu

PHTV hỗ trợ ứng dụng thông qua IBus/Fcitx frontend và input-method module của
toolkit. “Chạy trên Wayland” không tự động có nghĩa mọi ứng dụng đều tương thích;
protocol/capability thực tế phải được kiểm thử.

## Chiến lược backend

| Môi trường | Backend ưu tiên | Ghi chú |
| --- | --- | --- |
| GNOME | IBus | tích hợp indicator/input source của GNOME |
| KDE Plasma | Fcitx 5 | dùng UI/config/indicator sẵn có của Fcitx |
| Desktop khác | theo IM framework người dùng chọn | không chạy đồng thời hai backend |

## Quy tắc fallback

- Không có surrounding text: dùng preedit/composition trong phạm vi framework;
  không phát Backspace toàn cục.
- Password/sensitive input purpose: pass-through và xóa Core session.
- Không nhận diện chắc ứng dụng: dùng rule mặc định, không tự khóa tiếng Anh.
- Terminal/raw mode: ưu tiên pass-through; profile riêng chỉ thêm khi có case tái
  hiện và regression test.
- Sandboxed app: không yêu cầu người dùng cấp quyền filesystem/device rộng chỉ
  để khắc phục một ứng dụng.

Mỗi workaround phải ghi backend, desktop, display server, toolkit và ứng dụng cụ
thể; không áp dụng theo tên tiến trình quá rộng.

