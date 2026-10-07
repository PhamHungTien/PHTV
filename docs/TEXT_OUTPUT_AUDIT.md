# Rà soát gửi ký tự và lỗi “Từ chối”

Ngày: 2026-10-06.

## Lỗi đã xác nhận từ mã nguồn

Luồng gửi chuỗi ghi `syncKeyLengths` từ dữ liệu Unicode tổ hợp trước khi
chuyển chuỗi sang Unicode dựng sẵn cho các ứng dụng cần tương thích.
Ví dụ `a + dấu sắc` có độ dài 2 trong dữ liệu nguồn nhưng chuỗi gửi đi là
`á`, dài 1. Ở editor xóa từng mã UTF-16, lần Backspace hoặc sửa dấu tiếp theo
có thể xóa luôn ký tự đứng trước.

Bản sửa gộp từng ký tự tiếng Việt trước khi chia chunk và ghi độ dài đồng bộ.
Phạm vi chỉ là đường xuất Unicode tổ hợp đang được yêu cầu chuyển sang dựng
sẵn; bảng mã cũ và đường gửi Unicode tổ hợp thông thường giữ quy tắc hiện có.
Kiểm thử mô phỏng thay `chá` thành `chà`, toàn bộ nguyên âm tiếng Việt hoa/thường
với năm dấu thanh, ranh giới chunk, cùng dữ liệu VNI không bị chuyển mã.

## Báo cáo Telegram

Các chuỗi `Tuwf choois`, `Tuwf choosi`, `Tuwf chosoi` cho `Từ chối` trong
kiểm thử engine; `Tuwf chois` cho `Từ chói`, đúng vì thiếu lần nhấn `o` thứ hai.
Chưa tái hiện được `Từ choói`.

Đã thử ô nháp Saved Messages trên Telegram 12.10 đang cài. Thao tác bàn phím
qua công cụ tự động cho nguyên chuỗi `Tuwf choois`; vì chưa đi qua chuyển đổi
của bộ gõ nên phép thử này không chứng minh việc tương tác PHTV–Telegram hoạt
động đúng hay sai. Đã xóa bản nháp kiểm thử, không gửi tin nhắn. Bản PHTV người
dùng đang chạy là 3.6.2; các build kiểm thử không thay thế bản này.

Không thêm độ trễ hay profile Telegram khi chưa có bằng chứng tái hiện.
Lỗi độ dài Unicode nêu trên là phát hiện độc lập, chưa được coi là nguyên nhân
của báo cáo Telegram. Cần chuỗi phím chính xác, bảng mã, phiên bản ứng dụng và
thử gõ vật lý trên cấu hình người báo lỗi để xác nhận bước sửa tiếp theo.

## Kiểm chứng bản sửa ngày 2026-10-07

- Full XCTest: 603 ca, 601 đạt, 2 microbenchmark bỏ qua theo cấu hình, không lỗi.
- Debug build, Release build, static analysis và metadata check đều đạt.
- Có kiểm thử bảo toàn Unicode tổ hợp khi không bật chuyển sang dựng sẵn,
  ký tự ngoài BMP, các ranh giới chunk và độ dài xóa ở bảng mã cũ.
