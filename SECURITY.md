<div align="center">

# 🔒 Chính sách bảo mật

**Security Policy - Báo cáo lỗ hổng bảo mật**

[🏠 Trang chủ](README.md) • [📧 Email](mailto:hungtien10a7@gmail.com)

</div>

---

## 🚨 Báo cáo lỗi bảo mật

**Không mở public issue** cho lỗ hổng bảo mật.

### Liên hệ

Gửi email chi tiết lỗ hổng đến: **hungtien10a7@gmail.com**

Bao gồm:

- Mô tả lỗ hổng
- Cách tái hiện
- Tác động tiềm ẩn
- PHTV & macOS version

### Timeline

- **Ngay khi nhận:** Xác nhận báo cáo
- **Trong 48 giờ:** Đánh giá mức độ nghiêm trọng
- **Trong 7 ngày:** Bắt đầu làm việc trên bản vá
- **Trước release vá:** Liên hệ với bạn
- **Sau release:** Công bố lỗ hổng và bản vá

### Tiết lộ có trách nhiệm

- **Cho bạn:** Vui lòng cho chúng tôi thời gian bản vá trước khi công bố
- **Cho chúng tôi:** Chúng tôi sẽ bản vá và thông báo người dùng nhanh chóng

## Hỗ trợ phiên bản

| Phiên bản | Hỗ trợ            |
| --------- | ----------------- |
| 1.x       | ✅ Đầy đủ         |
| 0.x       | ⚠️ Quan trọng chỉ |

## Mức độ nghiêm trọng

### Lỗ hổng nghiêm trọng

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

## 📞 Liên hệ

Nếu bạn có bất kỳ câu hỏi bảo mật nào, vui lòng liên hệ với người duy trì dự án.

---

<div align="center">

### 🔒 Bảo mật là ưu tiên hàng đầu

Chúng tôi cam kết bảo vệ người dùng và xử lý mọi báo cáo bảo mật một cách nghiêm túc.

[![Security Policy](https://img.shields.io/badge/Security-Policy-red?logo=security)](SECURITY.md)

**Cảm ơn đã giúp PHTV an toàn hơn!**

[🏠 Trang chủ](README.md) • [📧 Email bảo mật](mailto:hungtien10a7@gmail.com)

</div>

**Cảm ơn đã giúp giữ PHTV an toàn!** 🔒
