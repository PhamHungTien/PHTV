# PHTV 1.6.6 Release Notes

## 🎉 Phiên bản 1.6.6 - Tối ưu Trình duyệt và Hệ thống

Phiên bản 1.6.6 tập trung vào việc giải quyết triệt để lỗi nhập liệu trên các trình duyệt hiện đại và chuẩn hóa các tính năng hệ thống cho macOS mới nhất.

---

## 🔧 Cải tiến quan trọng

### ✅ Khắc phục triệt để lỗi nhân đôi ký tự trên Trình duyệt

Đây là bản cập nhật quan trọng cho người dùng thường xuyên gõ tiếng Việt trên thanh địa chỉ (Omnibox) của Chrome, Safari, Firefox, Arc...

**Vấn đề trước đây:**
- Khi gõ trên thanh địa chỉ, trình duyệt thường tự động gợi ý (autocomplete).
- Phím `Backspace` từ bộ gõ đôi khi chỉ làm mất gợi ý mà không xóa được ký tự thật, dẫn đến lỗi nhân đôi (ví dụ: gõ "đ" ra "dđ").

**Giải pháp mới (Tham khảo OpenKey):**
- ✅ **Chiến lược "Chọn rồi Xóa"**: Thay vì gửi phím Backspace đơn thuần, PHTV giờ đây sử dụng tổ hợp **Shift + Left Arrow** để bôi đen ký tự cần xóa, sau đó mới gửi lệnh xóa vật lý.
- ✅ **Áp dụng toàn diện**: Giải pháp này được áp dụng cho tất cả các trình duyệt nhân Chromium, WebKit (Safari) và Gecko (Firefox).
- ✅ **Auto English Restore**: Khôi phục từ tiếng Anh trên trình duyệt cũng được áp dụng cơ chế mới này để đảm bảo tính ổn định 100%.

**Kết quả:**
- 🚀 Gõ tiếng Việt trên thanh địa chỉ trình duyệt mượt mà, không còn lỗi lặp từ.
- 🚀 Hoạt động chính xác ngay cả khi trình duyệt đang hiển thị danh sách gợi ý dày đặc.

---

### 🚀 Chuẩn hóa tính năng "Khởi động cùng hệ thống"

PHTV hiện đã chính thức chuyển sang hỗ trợ tối thiểu macOS 13.0, cho phép tối ưu hóa các API hệ thống.

- ✅ **Sử dụng SMAppService**: Chuyển hoàn toàn sang API hiện đại của Apple để quản lý việc khởi động cùng máy.
- ✅ **Loại bỏ mã cũ (Legacy)**: Xóa bỏ các API lỗi thời (`LSSharedFileList`, `SMLoginItemSetEnabled`) giúp ứng dụng gọn nhẹ và tránh các cảnh báo bảo mật.
- ✅ **Đồng bộ trạng thái**: Fix lỗi nút gạt (toggle) trong cài đặt không khớp với trạng thái thực tế của hệ thống sau khi khởi động lại.

---

## 🔍 Chi tiết kỹ thuật

### Tối ưu hóa mã nguồn

1. **Robust Backspace Handling**
   - Implement `SendPhysicalBackspace` để gửi sự kiện xóa vật lý trực tiếp.
   - Cập nhật `SendBackspaceSequenceWithDelay` để chuyển đổi linh hoạt giữa các chiến lược xóa tùy theo ứng dụng mục tiêu.

2. **Code Cleanup**
   - Sửa lỗi thứ tự khai báo hàm (Function Declaration Order) trong `PHTV.mm`.
   - Loại bỏ toàn bộ các cảnh báo Deprecated liên quan đến Login Items.
   - Tối ưu hóa các kiểm tra phiên bản hệ thống (`@available`).

---

## 📊 Compatibility

### Hỗ trợ

- ✅ **Yêu cầu tối thiểu**: macOS 13.0 (Ventura) trở lên.
- ✅ **Kiến trúc**: Apple Silicon (M1/M2/M3/M4) & Intel Macs.
- ✅ **Trình duyệt**: Safari, Chrome, Firefox, Edge, Arc, Brave, Cốc Cốc, v.v.

---

## 🐛 Known Issues

Hiện tại chưa ghi nhận lỗi nghiêm trọng nào trên bản release này.

---

## 📝 Changelog

### Fixed
- **Lỗi nhân đôi ký tự trên thanh địa chỉ trình duyệt**: Thay đổi cơ chế xóa ký tự sang tổ hợp "Chọn + Xóa" (Shift+Left -> Delete).
- **Lỗi đồng bộ Launch at Login**: Đảm bảo cài đặt luôn khớp với trạng thái hệ thống qua `SMAppService`.

### Changed
- **Nâng cấp yêu cầu hệ thống**: Chỉ hỗ trợ macOS 13.0 trở lên để sử dụng các API tối ưu nhất.
- **Làm sạch mã nguồn**: Loại bỏ mã legacy và các cảnh báo biên dịch.

---

## 🙏 Credits

Cảm ơn cộng đồng người dùng đã báo cáo chi tiết lỗi trên trình duyệt và các bạn phát triển OpenKey đã chia sẻ giải pháp xử lý input hữu ích.

---

## 📥 Download

**Cài đặt qua Homebrew (Recommended):**
```bash
brew upgrade phtv
```

**Hoặc tải trực tiếp:**
- [GitHub Releases](https://github.com/PhamHungTien/PHTV/releases/tag/v1.6.6)

---

**Release Date**: January 11, 2026
**Version**: 1.6.6
**Minimum macOS**: 13.0

---

**© 2026 Phạm Hùng Tiến. All rights reserved.**
