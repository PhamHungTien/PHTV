# Phụ âm tùy chỉnh

Trong **Cài đặt → Bộ gõ → Phụ âm nhanh**, bật **Phụ âm tùy chỉnh**.
Nhập một hoặc hai chữ cái phụ âm không dấu, rồi nhấn Enter hoặc **Thêm**.
Ví dụ: `Z`, `DZ`, `BL`. Các mục trùng nhau không được thêm; chữ thường
được chuyển thành chữ hoa. Nhấn dấu × để xoá từng mục.

Mặc định là `Z, F, W, J, DZ`, giữ tương thích với cài đặt trước đây.
**Khôi phục mặc định** chỉ thay danh sách này. Tắt tính năng vẫn giữ danh sách
để dùng lại; danh sách trống không bổ sung phụ âm nào. Tối đa 64 mục.
Phụ âm tiếng Việt chuẩn luôn được giữ nguyên.

Danh sách bổ sung **phụ âm đầu** cho kiểm tra chính tả, không phải bảng thay thế
văn bản hoặc phụ âm cuối. Ví dụ thêm `BL` cho phép đặt dấu trong `blấ`.
Các phím Telex vẫn có chức năng đặt dấu; dùng mục Gõ tắt nếu cần thay một chuỗi
bất kỳ bằng văn bản khác. Chế độ tự phục hồi từ tiếng Anh vẫn ưu tiên từ tiếng
Anh đã nhận diện; chế độ phục hồi từ không phải tiếng Việt tôn trọng các phụ âm
đã bổ sung.

Danh sách được lưu ngay, nạp lại khi mở ứng dụng và đi cùng sao lưu cài đặt.
Bản sao lưu cũ thiếu mục này không xoá danh sách đang có.

## Viết tắt có Đ

Các viết tắt chỉ gồm phụ âm in hoa có chữ Đ như `ĐKKD`, `ĐN`, `ĐL`, `HĐ`, `GĐ`
được giữ khi tự phục hồi từ không phải tiếng Việt đang bật, với Shift hoặc Caps
Lock. Từ tiếng Anh có nguyên âm vẫn dùng quy tắc phục hồi bình thường.

## Kiểm chứng

601 XCTest: 599 đạt, 2 microbenchmark bỏ qua theo cấu hình, không lỗi.
Bao gồm danh sách hai chữ cái, danh sách trống, tắt tính năng, phụ âm chuẩn,
gõ nhanh, lưu/nạp, thay mục nhưng giữ nguyên độ dài danh sách, kiểm tra dữ liệu
sao lưu và các viết tắt có Đ. Giao diện được dựng bằng NSHostingView để kiểm tra
bố cục. Các ca engine “Từ chối” theo nhiều thứ tự đặt dấu đã đạt; kết quả này
chưa xác nhận hành vi phát phím trong Telegram.

Debug build, Release build, static analysis và metadata check đều đạt.
