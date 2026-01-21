# PHTV 1.8.9 - Nâng cấp Claude Code Patcher & Vietnamese IME Fix

Bản cập nhật này tập trung vào việc nâng cấp toàn diện khả năng tương thích của Claude Code CLI với bộ gõ tiếng Việt, hỗ trợ các phiên bản Claude Code mới nhất.

### 🚀 Tính năng & Cải tiến mới
- **Claude Code Patcher v2**: 
    - Cải tiến vượt bậc cơ chế vá lỗi (patch) động, tự động phân tích và trích xuất biến từ mã nguồn đã được minified của Claude Code.
    - Hỗ trợ tốt các phiên bản Claude Code từ **v2.1.6 đến v2.1.12+**.
    - Cơ chế vá lỗi thông minh hơn, hỗ trợ cả các biến thể sử dụng nháy đơn, nháy kép hoặc mã hóa ký tự đặc biệt.
- **Quản lý Backup thông minh**:
    - Hệ thống khôi phục hiện đã có thể nhận diện và sử dụng các file sao lưu được tạo bởi cả ứng dụng PHTV và các script sửa lỗi phổ biến khác (như bản fix của manhit96).
    - Đảm bảo tính năng bật/tắt sửa lỗi trên giao diện hoạt động mượt mà và an toàn.

### 📚 Tài liệu & Hướng dẫn
- **Hướng dẫn mới**: Thêm tài liệu chi tiết tại `docs/CLAUDE_CODE_FIX.md` hướng dẫn cách sửa lỗi gõ tiếng Việt trong Claude Code CLI cho cả người dùng **macOS** và **Windows**.
- **Chẩn đoán**: Cập nhật các lệnh chẩn đoán (diagnostic) giúp người dùng tự kiểm tra trạng thái patch trong Terminal.

### 🛠 Sửa lỗi & Tối ưu
- **Regex Optimization**: Sử dụng Swift raw string literals để xử lý các biểu thức chính quy (regex) phức tạp, tránh lỗi "Invalid escape sequence" trên các phiên bản macOS mới.
- **Code Cleanup**: Loại bỏ các biến thừa và tối ưu hóa hiệu suất khi quét file hệ thống để tìm đường dẫn cài đặt Claude Code.
