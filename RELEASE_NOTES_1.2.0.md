# PHTV v1.2.0 Release Notes

**PHTV — Precision Hybrid Typing Vietnamese**

## Tính năng mới

### Tự động khôi phục từ tiếng Anh
- **Nhận diện từ tiếng Anh thông minh**: Khi đang bật chế độ tiếng Việt mà gõ từ tiếng Anh (VD: "tẻminal"), PHTV sẽ tự động nhận diện và khôi phục lại từ gốc ("terminal")
- **Ưu tiên tiếng Việt**: Kiểm tra từ điển tiếng Việt trước - nếu là từ tiếng Việt hợp lệ thì giữ nguyên, chỉ khôi phục khi chắc chắn là từ tiếng Anh
- **Từ điển nhị phân tối ưu**: Sử dụng binary trie với mmap để tra cứu cực nhanh (O(k) với k = độ dài từ)
- **Hỗ trợ mọi kiểu gõ tone**: Nhận diện cả kiểu gõ tone giữa ("còn" → "cofn") và tone cuối ("còn" → "conf")

### Giao diện
- **Thêm subtitle "Precision Hybrid Typing Vietnamese"**: Hiển thị trong màn hình About và tooltip menu bar

## Cải tiến

### Hiệu năng Spotlight
- Giảm độ trễ polling AX API từ 30ms xuống 8ms
- Giảm SpotlightTinyDelay từ 10ms xuống 3ms
- Cache isSpotlightActive() với TTL 50ms để giảm overhead
- Loại bỏ AX retry loop không cần thiết

### Từ điển
- Nâng cấp format từ PHT2 (uint16) lên PHT3 (uint32) để hỗ trợ từ điển lớn hơn
- Từ điển tiếng Anh: 10,000+ từ phổ biến
- Từ điển tiếng Việt: 15,000+ pattern bao gồm tất cả biến thể Telex

## Yêu cầu hệ thống
- macOS 14.0+ (Sonoma trở lên)
- Apple Silicon (M1, M2, M3, M4)
- Xcode 26.0+ (nếu build từ source)

---

**Full Changelog**: [v1.1.9...v1.2.0](https://github.com/PhamHungTien/PHTV/compare/v1.1.9...v1.2.0)
