# PHTV 1.3.2 Release Notes

**Release Date:** December 29, 2024

## Tính năng mới

### Text Snippets (Gõ tắt động)
Mở rộng tính năng Macro với khả năng chèn nội dung động:
- **Ngày hiện tại**: Chèn ngày với format tùy chỉnh (dd/MM/yyyy, yyyy-MM-dd, ...)
- **Giờ hiện tại**: Chèn giờ (HH:mm, HH:mm:ss)
- **Ngày và giờ**: Kết hợp cả ngày và giờ
- **Clipboard**: Chèn nội dung từ clipboard
- **Random**: Chọn ngẫu nhiên từ danh sách (a,b,c)
- **Counter**: Số tự động tăng (1, 2, 3, ...)

### Từ điển tùy chỉnh
Thêm từ tiếng Anh hoặc tiếng Việt vào từ điển để:
- Cải thiện độ chính xác nhận diện từ tiếng Anh
- Thêm từ chuyên ngành, thương hiệu
- Import/Export từ điển

### Import/Export cài đặt
Sao lưu và khôi phục toàn bộ cài đặt:
- Xuất ra file `.phtv-backup`
- Bao gồm: Settings, Macros, Categories, Dictionary, Excluded Apps
- Tùy chọn bao gồm thống kê gõ phím

### Thống kê gõ phím
Theo dõi hoạt động gõ phím:
- Tổng số ký tự và từ đã gõ
- Thời gian gõ tích lũy
- Biểu đồ 7 ngày gần đây
- Phân bố ngôn ngữ (Việt/Anh)
- Toggle bật/tắt tính năng

## Cải tiến giao diện

### Tổ chức Settings mới
- Giảm từ 12 xuống 11 tabs
- Gộp "Nâng cao" vào "Bộ gõ" thành section "Phụ âm nâng cao"
- Sắp xếp theo mức độ sử dụng

### Giao diện Phím tắt
- Thiết kế mới cho nút modifier keys với gradient fill
- Hiệu ứng hover cho tương tác tốt hơn
- Radio button style cho phím tạm dừng
- Card hiển thị tổ hợp phím hiện tại

### Tìm kiếm cài đặt
- Mở rộng từ 40 lên 61 mục tìm kiếm
- Bao gồm tất cả chức năng mới

## Cải tiến từ điển tiếng Anh
- Thêm thuật ngữ công nghệ (API, SDK, npm, git, ...)
- Thêm thương hiệu phổ biến (Apple, Google, Microsoft, ...)
- Cải thiện nhận diện từ viết tắt

## Sửa lỗi
- Sửa lỗi phím Backspace không reset trạng thái khi gõ tiếng Việt
- Sửa lỗi Sendable conformance trong Swift concurrency

## Yêu cầu hệ thống
- macOS 13.0 (Ventura) trở lên
- Apple Silicon hoặc Intel Mac

## Cài đặt
1. Tải file `PHTV-1.3.2.dmg`
2. Mở DMG và kéo PHTV vào Applications
3. Mở PHTV và cấp quyền Accessibility

## Nâng cấp từ phiên bản cũ
- Cài đè lên phiên bản cũ, settings được giữ nguyên
- Hoặc dùng tính năng Import/Export để backup trước
