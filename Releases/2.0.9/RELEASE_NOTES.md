# PHTV 2.0.9 - Nâng cấp Báo lỗi & Sửa lỗi Apple Intelligence

### 🐞 Cải tiến hệ thống Báo lỗi (Bug Report)
Giao diện báo lỗi được thiết kế lại hoàn toàn để giúp người dùng cung cấp thông tin chi tiết hơn, hỗ trợ đội ngũ phát triển khắc phục lỗi nhanh nhất có thể:
- **Thông tin chi tiết:** Thêm các trường nhập liệu cụ thể cho *Bước tái hiện lỗi*, *Kết quả mong muốn* và *Kết quả thực tế*.
- **Phân loại thông minh:** Cho phép chọn *Mức độ nghiêm trọng* (từ Nhẹ đến Khẩn cấp) và *Khu vực xảy ra lỗi* (Gõ phím, Hotkey, Menu bar...).
- **Quản lý Log mạnh mẽ:** 
    - Tùy chọn đính kèm **Crash logs** của PHTV trong 7 ngày gần nhất.
    - Làm mới và xem trước log hệ thống trực tiếp trong cửa sổ báo lỗi.
- **Tiện ích mới:** 
    - Nút **Lưu báo cáo...** để xuất nội dung ra file `.md` khi bạn muốn gửi qua kênh khác.
    - Nút **Tạo mẫu** giúp tự động điền các khung sườn báo lỗi chuyên nghiệp.
    - Nút **Xoá nội dung** để làm sạch form nhanh chóng.

### 🧠 Sửa lỗi Apple Intelligence (Type to Siri)
- **Fix triệt để lỗi gõ:** Khắc phục vấn đề không thể gõ tiếng Việt hoặc gõ sai trong khung nhập liệu Apple Intelligence (gọi bằng 2 lần phím `Cmd`) sau khi đóng cửa sổ Cài đặt của PHTV.
- **Cơ chế tối ưu:** Vô hiệu hóa cache Spotlight ngay khi phím `Cmd` được nhấn để đảm bảo PHTV luôn nhận diện chính xác các cửa sổ overlay hệ thống mới nhất.

### 🛠️ Cải tiến hệ thống
- **Ổn định hơn:** Tinh chỉnh cơ chế khôi phục trạng thái gõ sau khi đóng cửa sổ Cài đặt để tránh kẹt ngữ cảnh nhập liệu.
- **Menu bar:** Tối ưu hiệu năng hiển thị và làm mới icon menu bar khi có thay đổi thiết lập nhanh.
