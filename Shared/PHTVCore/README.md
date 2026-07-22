# PHTVCore

Thành phần Swift portable dự kiến chứa engine ngôn ngữ dùng chung giữa macOS,
Windows và Linux. Chưa di chuyển mã nguồn vào đây trước khi có baseline test và
kế hoạch tách phụ thuộc được phê duyệt.

## Hợp đồng

- Input: key event và input context đã chuẩn hóa.
- Output: `EditPlan` xác định, không tự phát sự kiện hệ điều hành.
- Không UI, filesystem path toàn cục, network hoặc API hệ điều hành.
- C ABI có version cho `PHTV.Windows.IME`.
- Dictionary và test vector phải cho cùng kết quả trên hai nền tảng.

Nguồn dự kiến tách dần từ `macOS/PHTV/Engine`, không copy rồi duy trì nhiều
engine theo nền tảng.
