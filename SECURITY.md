# Chính sách bảo mật (Security Policy)

## Báo cáo lỗi bảo mật

Nếu bạn phát hiện lỗi bảo mật trong PHTV, **vui lòng không** mở public issue.

Thay vào đó, vui lòng gửi báo cáo cho người duy trì bằng cách:

### Email

Gửi email đến: [Contact the maintainer on GitHub](https://github.com/PhamHungTien/PHTV/issues) hoặc liên hệ trực tiếp thông qua GitHub Issues (với "SECURITY" prefix)

**Bao gồm trong báo cáo của bạn:**

- Mô tả chi tiết về lỗ hổng
- Các bước để tái hiện vấn đề
- Tác động tiềm ẩn của lỗ hổng
- Phiên bản PHTV bị ảnh hưởng
- Phiên bản macOS và Xcode (nếu liên quan)

### Timeline

1. **Ngay khi nhận được:** Chúng tôi sẽ xác nhận nhận được báo cáo
2. **Trong 48 giờ:** Chúng tôi sẽ đánh giá mức độ nghiêm trọng
3. **Trong 7 ngày:** Chúng tôi sẽ bắt đầu làm việc trên bản vá
4. **Trước khi release bản vá:** Chúng tôi sẽ liên hệ với bạn
5. **Khi release:** Chúng tôi sẽ công khai công bố lỗ hổng và bản vá

### Chính sách tiết lộ có trách nhiệm

Chúng tôi tin vào tiết lộ có trách nhiệm. Điều này có nghĩa:

- **Cho người báo cáo:** Vui lòng cung cấp cho chúng tôi thời gian hợp lý để bản vá trước khi tiết lộ công khai
- **Cho chúng tôi:** Chúng tôi sẽ làm việc nhanh chóng để bản vá và thông báo cho người dùng

## Hỗ trợ phiên bản

PHTV cam kết cung cấp bản vá bảo mật cho:

| Phiên bản | Hỗ trợ                   |
| --------- | ------------------------ |
| 1.x.x     | ✅ Hoạt động             |
| 0.x.x     | ⚠️ Bản vá quan trọng chỉ |

## Các loại lỗ hổng bảo mật

### Lỗ hổng quan trọng

- Truy cập trái phép vào dữ liệu người dùng
- Tính năng bảo mật bị vô hiệu hóa
- Remote code execution
- Tấn công elevation of privilege

**Ví dụ:** Một cách để đọc các tệp người dùng khác trên macOS

### Lỗ hổng cao

- Hành vi không mong muốn có thể ảnh hưởng đến bảo mật
- Tính năng bảo mật yếu

**Ví dụ:** Macro không được xác thực một cách đúng đắn

### Lỗ hổng trung bình

- Tính năng không hoạt động như mong đợi
- Tiềm năng bị lạm dụng

### Lỗ hổng thấp

- Các vấn đề nhỏ không có tác động bảo mật rõ ràng

## Các thực hành bảo mật tốt

### Để người dùng

- **Cập nhật thường xuyên:** Cài đặt các bản cập nhật của PHTV ngay khi có sẵn
- **Cấp quyền cẩn thận:** Chỉ cấp quyền Accessibility cho PHTV (đó là cách nó hoạt động)
- **Exclude sensitive apps:** Thêm các ứng dụng nhạy cảm vào danh sách Excluded Apps
- **Theo dõi macro:** Kiểm tra macro được thêm nếu bạn có nghi ngờ

### Để nhà phát triển

- Chúng tôi tuân theo các thực hành bảo mật tốt:
  - Code review trước merge
  - Kiểm tra dependency
  - Tránh đọc/ghi file không cần thiết
  - Sử dụng HTTPS cho tất cả các yêu cầu mạng (nếu có)

## Công khai lỗ hổng

Khi chúng tôi công bố lỗ hổng bảo mật, chúng tôi sẽ:

1. Phát hành phiên bản mới với bản vá
2. Cập nhật trang GitHub Releases
3. Gửi thông báo qua email cho người dùng (nếu có)
4. Đăng chi tiết trong CHANGELOG

**Format công bố:**

```
SECURITY: [X.X.X] Bảng vá cho lỗ hổng [tên lỗ hổng]

Mô tả: [Mô tả chi tiết]
Ảnh hưởng: [Ai bị ảnh hưởng]
Giải pháp: [Cập nhật lên phiên bản mới]
CVE: [Nếu có]
```

## Liên hệ

Nếu bạn có bất kỳ câu hỏi bảo mật nào, vui lòng liên hệ với người duy trì dự án.

---

**Cảm ơn đã giúp giữ PHTV an toàn!** 🔒
