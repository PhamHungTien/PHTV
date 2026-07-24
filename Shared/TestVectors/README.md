# Shared test vectors

Golden vectors sẽ mô tả chuỗi sự kiện bàn phím và `EditPlan` mong đợi bằng định
dạng trung lập nền tảng. Chúng được chạy giống nhau trên macOS, Windows và Linux
để ngăn engine lệch hành vi.

Fixture chỉ dùng dữ liệu tổng hợp, không chứa nội dung gõ, Clipboard, macro hoặc
từ điển cá nhân của người dùng.

`vietnamese-core-v1.json` là baseline Unicode đầu tiên cho Telex/VNI. Mỗi case
có `id`, `method`, chuỗi phím ASCII `keys` và chuỗi Unicode NFC `expected`.
Test của `PHTVCore` đọc trực tiếp file này; adapter macOS, Windows và Linux phải
dùng cùng fixture thay vì sao chép thành bộ test riêng.
