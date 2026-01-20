# PHTV 1.8.8 - Sửa lỗi Safari & Cải tiến Claude Code Patcher

Bản cập nhật này sửa lỗi nhân đôi ký tự trên Safari và cải tiến phương pháp patch Claude Code CLI.

### Sửa lỗi

- **Safari address bar duplicate character**: Sửa lỗi nhân đôi ký tự đầu tiên khi gõ tiếng Việt trên thanh địa chỉ Safari
  - Áp dụng chiến lược Shift+Left cho TẤT CẢ trang web trên Safari
  - Ngoại trừ Google Docs/Sheets/Slides/Forms (giữ SendEmptyCharacter để tránh mất ký tự)

### Cải tiến

- **Claude Code Patcher**: Cải tiến phương pháp patch Claude Code CLI
  - Sử dụng phương pháp trích xuất biến động từ mã nguồn minified
  - Hoạt động ổn định trên Claude Code 2.1.x và các phiên bản mới hơn
  - Dựa trên công trình của [Đinh Văn Mạnh](https://github.com/manhit96/claude-code-vietnamese-fix)

### Chi tiết kỹ thuật

- Thêm method `isSafariGoogleDocsOrSheets` để phát hiện Google Docs/Sheets qua Accessibility API
  - Kiểm tra URL chứa `docs.google.com/document`, `docs.google.com/spreadsheets`, v.v.
  - Fallback kiểm tra tiêu đề cửa sổ ("- Google Docs", "- Google Sheets", v.v.)
- Cải thiện `isSafariAddressBar` với kiểm tra AXTextField/AXComboBox role trước
- Cập nhật regex pattern cho Claude Code 2.1.12+ với `\S+` thay vì `\w+`

### Kết quả

- Gõ tiếng Việt hoàn hảo trên Safari (address bar và web content)
- Google Docs/Sheets trong Safari hoạt động ổn định
- Claude Code CLI được patch tự động và hoạt động tốt với Vietnamese IME
