# PHTV 1.5.6

Phiên bản 1.5.6 giới thiệu tính năng "Sửa dấu tại chỗ" đột phá cùng nhiều cải tiến về độ ổn định cho trải nghiệm gõ tiếng Việt trên macOS.

## ✨ Những thay đổi chính

### 📝 Tính năng mới: Sửa dấu tại chỗ (Edit-in-place)
- **Khôi phục ngữ cảnh thông minh**: Cho phép bạn quay lại một từ đã gõ (bằng cách nhấp chuột hoặc dùng phím mũi tên) và tiếp tục thêm dấu hoặc sửa dấu trực tiếp. 
- **Tiết kiệm thời gian**: Không còn phải xóa toàn bộ từ để gõ lại khi phát hiện thiếu dấu. Bạn chỉ cần đặt con trỏ vào cuối hoặc giữa từ và gõ phím dấu tương ứng.
- **Hoạt động rộng rãi**: Tương thích tốt với các ứng dụng native và soạn thảo văn bản (Notes, Safari, Word, TextEdit...).

### 🛠 Độ ổn định & Sửa lỗi
- **Fix Memory Safety**: Khắc phục triệt để lỗi quản lý bộ nhớ khi đọc dữ liệu Unicode từ Accessibility API, giúp bộ gõ hoạt động ổn định trong thời gian dài mà không bị crash.
- **C++ Compatibility**: Tối ưu hóa mã nguồn Engine để tương thích tốt nhất với các chuẩn trình biên dịch mới nhất trên macOS.

## 📦 Cài đặt & Cập nhật

Người dùng hiện tại có thể cập nhật thông qua:
1. **Tự động**: Mở PHTV Settings -> Hệ thống -> Kiểm tra cập nhật.
2. **Homebrew**: `brew upgrade --cask phtv`
3. **Thủ công**: Tải file `.dmg` mới nhất từ GitHub Releases.
