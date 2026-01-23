# PHTV 2.0.5 Release Notes

### 🎯 Khắc phục triệt để lỗi gõ trên Thanh địa chỉ (Address Bar)

Phiên bản 2.0.5 tập trung giải quyết vấn đề **nhân đôi ký tự đầu tiên** khi gõ Tiếng Việt trên thanh địa chỉ của các trình duyệt (Chrome, Edge, Safari, Arc...), đồng thời đảm bảo không ảnh hưởng đến trải nghiệm trên Google Docs và Sheets.

#### ✨ Cải tiến nổi bật

*   **Sửa lỗi Nhân đôi ký tự (Duplication Fix):**
    *   Khôi phục cơ chế xử lý ổn định (Send Empty Character) cho thanh địa chỉ.
    *   Loại bỏ hoàn toàn hiện tượng gõ "d" thành "dđ", "t" thành "tt" khi trình duyệt gợi ý từ khóa (Autocomplete).

*   **Nhận diện thông minh (Smart Detection):**
    *   Nâng cấp thuật toán nhận diện: Phân biệt chính xác giữa **Thanh địa chỉ** và **Nội dung trang web** (như Google Docs, Sheets).
    *   Tăng độ sâu quét cấu trúc giao diện (lên 12 cấp) để tránh nhận diện nhầm trong các ứng dụng web phức tạp.
    *   Hỗ trợ nhận diện các từ khóa đặc trưng (Address, Omnibox, Tìm kiếm...) để kích hoạt fix ngay lập tức.

*   **Tăng tốc độ phản hồi:**
    *   Giảm thời gian cache trạng thái nhận diện xuống **0.5s**.
    *   Bộ gõ nhận biết ngay lập tức khi bạn chuyển tiêu điểm vào thanh địa chỉ (ví dụ: nhấn `Cmd + L`), giúp áp dụng fix kịp thời mà không bị trễ.

---

### 🇬🇧 English Summary

**Fixed:**
- **Address Bar Duplication:** Resolved the issue where the first character would be duplicated (e.g., "d" -> "dđ") in browser address bars due to autocomplete conflicts.
- **Smart Detection:** Improved heuristics to accurately distinguish between Address Bars (using `SendEmptyCharacter` fix) and Web Content like Google Docs (using standard Backspace).
- **Responsiveness:** Reduced state cache duration to 500ms for faster context switching (e.g. using `Cmd+L`).

### 📝 Commit Log
- `94c2ba4` fix: resolve duplicate first character in browser address bar via improved detection and empty character strategy
