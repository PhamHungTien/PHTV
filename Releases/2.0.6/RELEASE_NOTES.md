# PHTV 2.0.6 - Sửa lỗi Spotlight & Trình duyệt

### 🛠 Sửa lỗi (Bug Fixes)
- **Spotlight Detection:** Khắc phục lỗi Spotlight không được nhận diện khi gọi (Cmd+Space) đè lên cửa sổ trình duyệt (Chrome, Safari, Edge...).
  - Trước đây, để tối ưu hiệu suất, bộ gõ bỏ qua việc kiểm tra Spotlight nếu ứng dụng phía dưới là trình duyệt. Điều này dẫn đến việc các fix input cho Spotlight không được áp dụng.
  - Fix: Luôn kiểm tra trạng thái Spotlight bất kể ứng dụng nền, đảm bảo trải nghiệm gõ tiếng Việt nhất quán.

### 📝 Ghi chú kỹ thuật
- `PHTV.mm`: Removed `!isTargetBrowser` optimization in `spotlightActive` check.
