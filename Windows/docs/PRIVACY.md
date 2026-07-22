# Quyền riêng tư PHTV for Windows

## Cam kết mặc định

Luồng nhập liệu, từ điển, chính tả, Auto English và macro được xử lý tại máy.
PHTV không thu thập, lưu hoặc truyền nội dung người dùng gõ trong ứng dụng khác.

## Dữ liệu cục bộ dự kiến

| Dữ liệu | Mục đích | Mặc định |
| --- | --- | --- |
| Cài đặt bộ gõ | duy trì lựa chọn người dùng | lưu cục bộ |
| Quy tắc theo ứng dụng | khóa/tự chuyển ngôn ngữ | lưu cục bộ |
| Từ điển và macro cá nhân | tính năng do người dùng tạo | lưu cục bộ |
| Clipboard history | truy cập lại nội dung sao chép | tắt |
| Log chẩn đoán | điều tra lỗi kỹ thuật | không chứa nội dung nhập |

Mỗi store phải có schema version, retention và thao tác xóa/export rõ ràng.
Không đồng bộ cloud nếu chưa có consent riêng và cập nhật tài liệu này.

## Trường nhạy cảm

IME phải tôn trọng input scope/password field và không áp dụng tính năng cần lưu
ngữ cảnh ở trường nhạy cảm. Companion app không được nhận bản sao của
composition hoặc phím gõ từ DLL TSF.

## Tính năng mạng

Updater chỉ kiểm tra metadata/binary phát hành. GIF/Sticker, telemetry hoặc crash
upload là ranh giới mạng riêng và phải trải qua privacy review trước khi bật.
Không dùng nội dung gõ làm analytics, kể cả ở dạng hash.

## Báo lỗi

Báo lỗi chỉ gồm version, Windows build, kiến trúc, component, mã lỗi, thời lượng
và danh tính ứng dụng tối thiểu khi người dùng chủ động gửi. Ảnh, video và crash
dump do người dùng tự chọn và cần hướng dẫn xóa dữ liệu nhạy cảm.

