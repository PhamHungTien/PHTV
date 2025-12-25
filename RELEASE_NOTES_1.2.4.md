# PHTV v1.2.4 Release Notes

## Hỗ trợ gõ tiếng Việt trong Claude Code

Phiên bản này bổ sung tính năng quan trọng: **sửa lỗi gõ tiếng Việt trong Claude Code CLI** - công cụ AI của Anthropic chạy trong Terminal.

### Tính năng mới

#### 🤖 Hỗ trợ Claude Code CLI
- **Sửa lỗi không nhận dấu tiếng Việt**: Claude Code có bug xử lý ký tự DEL (backspace) nhưng không insert text thay thế, khiến dấu tiếng Việt bị mất
- **Tự động phát hiện cài đặt**: Nhận diện Claude Code được cài qua npm hay Homebrew
- **Patch thông minh**: Tự động vá file `cli.js` của Claude Code để sửa lỗi
- **Toggle đơn giản**: Bật/tắt trong Settings > Tùy chọn nâng cao
- **Hỗ trợ Claude Code 2.0.76+**: Tương thích với các phiên bản mới nhất

#### 🔧 Chuyển đổi cài đặt tự động
- **Phát hiện Homebrew**: Nếu Claude Code cài qua Homebrew (binary), không thể patch
- **Chuyển sang npm**: Tự động gỡ bản Homebrew và cài lại qua npm để có thể patch
- **Tiến trình chi tiết**: Hiển thị từng bước khi chuyển đổi

### Cách sử dụng

1. Mở **PHTV Settings** > **Tùy chọn nâng cao**
2. Bật toggle **"Hỗ trợ gõ tiếng Việt trong Claude Code"**
3. Nếu Claude Code cài qua Homebrew, PHTV sẽ tự động chuyển sang npm
4. Khởi động lại Claude Code để áp dụng

### Chi tiết kỹ thuật

- **ClaudeCodePatcher**: Utility class mới xử lý việc patch/unpatch Claude Code
- **Tự động backup**: Tạo backup file gốc trước khi patch, có thể khôi phục
- **Hỗ trợ nvm**: Tự động tìm npm trong các thư mục nvm
- **Pattern matching**: Sử dụng regex để tìm và thay thế đoạn code lỗi trong file minified

### Lưu ý

- Cần cài đặt Node.js/npm để sử dụng tính năng này
- Nếu Claude Code cập nhật, có thể cần bật lại toggle để patch phiên bản mới
- Có thể tắt toggle để khôi phục Claude Code về bản gốc

---

**Full Changelog**: [v1.2.3...v1.2.4](https://github.com/phamhungtien/PHTV/compare/v1.2.3...v1.2.4)
