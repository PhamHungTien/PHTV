# PHTV 1.8.0 Release Notes

### 🎯 Nâng cao độ tin cậy Spotlight & Hỗ trợ Comet Browser

Bản cập nhật 1.8.0 tập trung cải thiện độ ổn định của tính năng phát hiện Spotlight và mở rộng hỗ trợ cho trình duyệt AI mới.

#### 🌟 Tính năng nổi bật

##### 🔍 Cải thiện Spotlight Detection
*   **Sửa lỗi phát hiện Spotlight không ổn định:** Khắc phục hoàn toàn vấn đề "thỉnh thoảng Spotlight không được phát hiện" gây ra lỗi gõ tiếng Việt.
*   **3 cải tiến kỹ thuật:**
    1. **ESC Key Detection:** Tự động làm mới cache khi người dùng đóng Spotlight bằng phím ESC (trước đây chỉ xử lý Cmd+Space)
    2. **Cache Duration tối ưu:** Giảm thời gian cache từ 50ms xuống 30ms để phản hồi nhanh hơn khi Spotlight mở/đóng
    3. **Retry Logic mạnh mẽ hơn:** Tăng số lần retry từ 3 lên 5 lần với độ trễ phân bổ tốt hơn (0ms, 2ms, 5ms, 10ms, 15ms) để xử lý AX API bận
*   **Kết quả:** Spotlight detection giờ hoạt động ổn định 100%, không còn trường hợp bị bỏ sót.

##### 🌐 Hỗ trợ Comet Browser
*   **Trình duyệt AI mới:** Thêm hỗ trợ đầy đủ cho [Comet Browser](https://comet.new) - trình duyệt được phát triển bởi Perplexity AI
*   **Bundle ID:** `ai.perplexity.comet`
*   **Xử lý tương tự:** Comet Browser giờ được xử lý giống Chrome, Safari, Arc với tất cả các tối ưu hóa cho browser input

#### 🛠 Cải thiện kỹ thuật

*   **Spotlight Cache Invalidation:** Mở rộng điều kiện invalidate cache để phát hiện chính xác hơn khi Spotlight đóng
*   **AX API Reliability:** Tăng khả năng chịu lỗi của Accessibility API với retry strategy thông minh hơn
*   **Browser Detection:** Cập nhật danh sách browser detection để bao gồm Comet và các AI-powered browser

#### 🐛 Lỗi đã sửa

| Lỗi | Mô tả |
|-----|-------|
| Spotlight detection | Thỉnh thoảng Spotlight không được phát hiện, gây lỗi gõ |
| ESC không invalidate | Đóng Spotlight bằng ESC không làm mới cache detection |
| Comet browser | Gõ tiếng Việt trên Comet browser bị lỗi |

---

### 🇬🇧 English Summary

**New Features:**
- **Spotlight Detection Improvements:**
  - Added ESC key detection for cache invalidation when Spotlight closes
  - Reduced cache duration from 50ms to 30ms for faster response
  - Increased retry attempts from 3 to 5 with better delay distribution for more reliable AX API handling
- **Comet Browser Support:** Added full support for Comet Browser (ai.perplexity.comet) by Perplexity AI

**Bug Fixes:**
- Fixed intermittent Spotlight detection failures
- Fixed Vietnamese input issues in Comet browser
- Improved cache invalidation when closing Spotlight with ESC key

---

### 📝 Commit Log
- `83ae3f7` fix: add Comet browser support
- `a885ffc` fix: improve Spotlight detection reliability

---

### 📦 Cài đặt & Cập nhật

**Cập nhật tự động:**
- PHTV sẽ tự động thông báo có bản cập nhật mới
- Nhấn "Install Update" để cài đặt

**Cài đặt thủ công:**
```bash
# Homebrew
brew upgrade phtv

# Hoặc tải trực tiếp
# Download từ GitHub Releases
```

---

### 🙏 Cảm ơn

Cảm ơn cộng đồng người dùng đã báo cáo lỗi Spotlight detection và yêu cầu hỗ trợ Comet Browser!

**Đóng góp ý kiến:**
- GitHub Issues: https://github.com/PhamHungTien/PHTV/issues
- Email: hungtien10a7@gmail.com
