# PHTV - Release Notes v1.9.3

### 🚀 Có gì mới?
Bản cập nhật 1.9.3 mang đến những cải tiến "triệt để" cho bộ máy xử lý (Engine), giúp giải quyết hoàn hảo sự cân bằng giữa gõ từ kéo dài (prolonged vowels) và gõ các từ có cấu trúc phức tạp (diphthongs/triphthongs).

### ✨ Cải tiến & Sửa lỗi (Engine)

*   **Sửa lỗi triệt để cho các từ có cấu trúc Vowel + Vowel + Consonant:**
    *   Hỗ trợ gõ chính xác các từ khó như **"xuất"**, **"suất"**, **"chuẩn"**, **"triệt"** ngay cả khi người dùng gõ theo phong cách lặp nguyên âm.
    *   Cơ chế **Retroactive Vowel Fix**: Tự động nhận diện và chuyển đổi thông minh các cụm nguyên âm kéo dài (như `uaa`, `iee`) thành nguyên âm có dấu mũ (`uâ`, `iê`) ngay khi bạn gõ thêm phụ âm kết thúc.
    *   Ví dụ: `xuaa` + `t` -> **"xuất"**, `trie` + `e` + `t` -> **"triệt"**, `chuaa` + `n` -> **"chuẩn"**.

*   **Tối ưu hóa phản hồi thị giác (Typing Feedback):**
    *   Theo yêu cầu người dùng, PHTV hiện hiển thị các tổ hợp như **"chuâ"** ngay khi bạn gõ `chuaa` để bạn biết chính xác mình đang gõ gì, thay vì giữ nguyên `chuaa` như ở phiên bản trước.
    *   Vẫn giữ nguyên khả năng chặn các tổ hợp sai logic như **"chưâ"** (vẫn sẽ là `chưaa`).

*   **Xử lý dấu thanh thông minh hơn:**
    *   Cải thiện khả năng bảo toàn và kết hợp dấu thanh khi chuyển đổi nguyên âm. Nếu bạn đã gõ dấu hỏi ở `chủaa`, khi hoàn thành từ `chuẩn`, dấu hỏi sẽ được di chuyển chính xác đến vị trí mới.

*   **Sửa lỗi lặp ký tự (Duplication Fix):**
    *   Loại bỏ hoàn toàn lỗi lặp ký tự đầu (như `xxuất`, `ssuất`) khi bộ máy thực hiện hiệu chỉnh ngữ pháp tự động.

### 🛠 Kỹ thuật
- Nâng cấp hàm `checkGrammar` với khả năng xử lý hồi tố (retroactive) cho toàn bộ các cặp nguyên âm `aa`, `ee`, `oo`.
- Hoàn thiện hàm `checkCorrectVowel` để hỗ trợ gõ kéo dài (Smart Skip) mà không vi phạm quy tắc chính tả của bộ gõ.
