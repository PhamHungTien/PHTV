# PHTV 1.8.6 - Sửa lỗi Safari Google Docs/Sheets

Bản cập nhật này sửa lỗi gõ tiếng Việt trên Safari, đặc biệt trong Google Docs và Sheets.

### Sửa lỗi

- **Safari address bar**: Sửa lỗi nhân đôi ký tự đầu tiên (ví dụ: "nhaấn", "dđ")
- **Safari Google Docs/Sheets**: Sửa lỗi mất ký tự với các từ có nhiều dấu (ví dụ: "đến" → "đế", "với" → "ớ", "Việt" → "it")

### Cải tiến kỹ thuật

- Sử dụng Accessibility API để phân biệt Safari address bar và web content
- Safari address bar: Áp dụng chiến lược Shift+Left (fix nhân đôi ký tự)
- Safari web content: Áp dụng chiến lược SendEmptyCharacter (fix mất ký tự)
- Chromium browsers: Giữ nguyên chiến lược Shift+Left

### Kết quả

- Gõ tiếng Việt hoàn hảo trên Safari address bar
- Gõ tiếng Việt chính xác trên Google Docs/Sheets trong Safari
- Không ảnh hưởng đến các trình duyệt Chromium (Chrome, Edge, Brave, Arc...)
