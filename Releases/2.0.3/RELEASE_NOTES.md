# PHTV 2.0.3 - Release Notes

Bản cập nhật này tập trung giải quyết triệt để vấn đề tương thích với thanh địa chỉ trình duyệt và tối ưu hóa hiệu năng xử lý sự kiện bàn phím.

## 🚀 Điểm nổi bật

- **Sửa lỗi nhân đôi kí tự:** Khắc phục hoàn toàn lỗi khó chịu khiến kí tự đầu tiên bị nhân đôi (ví dụ: gõ "d" thành "dd") khi nhập liệu trên thanh địa chỉ của Chrome, Safari, Edge, v.v.
- **Tăng tốc độ phản hồi:** Loại bỏ độ trễ khi chuyển đổi giữa các ứng dụng và Spotlight.

## 🛠 Chi tiết thay đổi

### Core Engine & Hiệu năng
- **Tối ưu hóa thuật toán nhận diện Spotlight:** Loại bỏ cơ chế thử lại (retry loop) và các lệnh chờ (sleep) gây chặn luồng xử lý phím. Điều này giúp ngăn chặn việc macOS vô hiệu hóa bộ gõ (Event Tap timeout) khi hệ thống đang tải nặng.
- **Cải tiến Address Bar Detection:**
  - Tăng thời gian lưu bộ nhớ đệm (cache) cho trạng thái thanh địa chỉ từ 500ms lên **3000ms**. Giúp giảm thiểu việc gọi API hệ thống liên tục khi người dùng đang suy nghĩ hoặc gõ ngắt quãng.
  - Thêm cơ chế **Smart Invalidation**: Tự động làm mới trạng thái ngay lập tức khi phát hiện click chuột hoặc thay đổi tiêu điểm (focus), đảm bảo bộ gõ luôn nhận diện chính xác ngữ cảnh nhập liệu.
- **Đồng bộ hóa Cache:** Chuẩn hóa thời gian cache giữa các module quản lý để đảm bảo sự nhất quán và ổn định.

## 📦 Cập nhật

Khuyên dùng cho tất cả người dùng, đặc biệt là những người thường xuyên gặp lỗi gõ tiếng Việt trên trình duyệt web.
