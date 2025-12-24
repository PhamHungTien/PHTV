# PHTV v1.2.2 Release Notes

## Hỗ trợ đầy đủ bàn phím quốc tế (International Keyboard Support)

Phiên bản này tập trung vào việc hỗ trợ hoàn toàn các bàn phím quốc tế, đặc biệt là các layout không phải US QWERTY.

### Các tính năng mới

#### 🌍 Hỗ trợ bàn phím quốc tế
- **QWERTZ (German, Swiss, Austrian)**: Gõ tiếng Việt hoạt động bình thường với các phím đặc biệt như ß, ü, ö, ä
- **AZERTY (French, Belgian)**: Hỗ trợ đầy đủ các phím é, è, ç, à, ù và layout số khác biệt
- **Nordic (Swedish, Norwegian, Danish, Finnish)**: Hỗ trợ å, ä, ö, æ, ø
- **Dvorak & Colemak**: Hoạt động tốt với tính năng tương thích layout tự động
- **Và nhiều layout khác**: Spanish, Italian, Portuguese, Polish, Czech, Hungarian, Turkish...

#### 🔧 Tự động phát hiện bàn phím
- Ứng dụng tự động bật "Tương thích bố cục bàn phím" khi phát hiện bàn phím không phải US
- Không cần cấu hình thủ công cho hầu hết người dùng quốc tế

#### ⌨️ Hiển thị phím tắt chính xác
- Phím tắt hiện hiển thị đúng tên phím theo layout bàn phím hiện tại
- Ví dụ: Trên QWERTZ, phím Z hiển thị là "Z" (không còn hiển thị sai là "Y")

### Sửa lỗi

- **Sửa lỗi không gõ được tiếng Việt trên bàn phím German/French**: Logic kiểm tra ngôn ngữ giờ cho phép tất cả các bàn phím Latin-based
- **Sửa lỗi phím số nhảy ký tự khác trên QWERTZ**: Thêm mapping đầy đủ cho các ký tự đặc biệt
- **Sửa lỗi VNI trên AZERTY**: Xử lý đặc biệt cho number row trên AZERTY (Shift + key = number)
- **Cải thiện ConvertKeyStringToKeyCode**: Thêm nhiều chiến lược fallback để xử lý tốt hơn các trường hợp đặc biệt

### Cải tiến kỹ thuật

- Mở rộng danh sách ngôn ngữ Latin-based được hỗ trợ (50+ ngôn ngữ)
- Thêm mapping cho 100+ ký tự đặc biệt từ các layout quốc tế
- Sử dụng UCKeyTranslate API để lấy tên phím chính xác theo layout hiện tại
- Tối ưu performance với dispatch_once cho static data

### Danh sách ngôn ngữ bàn phím được hỗ trợ

| Khu vực | Ngôn ngữ |
|---------|----------|
| Western European | English, German, French, Spanish, Italian, Portuguese, Dutch, Catalan |
| Nordic | Danish, Swedish, Norwegian, Finnish, Icelandic, Faroese |
| Eastern European | Polish, Czech, Slovak, Hungarian, Romanian, Croatian, Slovenian |
| Baltic | Estonian, Latvian, Lithuanian |
| Turkic | Turkish, Azerbaijani, Uzbek, Turkmen |
| Southeast Asian | Indonesian, Malay, Vietnamese, Tagalog |
| Celtic | Irish, Scottish Gaelic, Welsh, Breton |

---

**Full Changelog**: [v1.2.1...v1.2.2](https://github.com/phamhungtien/PHTV/compare/v1.2.1...v1.2.2)
