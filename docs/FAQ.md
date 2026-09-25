# PHTV FAQ

Các câu hỏi thường gặp khi cài đặt, cấp quyền và sử dụng PHTV.

[Trang chủ](../README.md) • [Cài đặt](INSTALL.md) • [Quyền riêng tư](PRIVACY.md) • [Báo lỗi](https://github.com/PhamHungTien/PHTV/issues)

---

## Cài Đặt & Quyền macOS

### 1. Vì sao PHTV cần quyền nhập liệu?

PHTV là bộ gõ chạy ở tầng hệ thống. PHTV cần đúng một quyền: **Trợ năng** trên macOS 26 trở xuống hoặc **Device Control and Data Access** trên macOS 27+.

Quyền này cho phép PHTV dùng active event tap để nhận, xử lý và gửi lại phím. Engine xử lý dữ liệu gõ offline trên máy và không gửi nội dung bạn gõ trong ứng dụng khác ra máy chủ. Khu GIF/Sticker và cập nhật Sparkle có kết nối mạng riêng, được mô tả tại [Quyền riêng tư](PRIVACY.md).

### 2. Tôi đã cấp quyền nhưng PHTV vẫn không gõ được?

Quyền AX là điều kiện cần; PHTV còn phải tạo và enable event tap production thành công trước khi báo sẵn sàng:

1. Mở **PHTV > Settings** hoặc màn hình onboarding.
2. Nếu đang thiếu quyền, bấm nút mở **Trợ năng** hoặc **Device Control and Data Access**.
3. Nếu trạng thái là đang khởi tạo, bấm **Thử lại ngay** hoặc mở lại PHTV.
4. Rời khỏi ô mật khẩu/ứng dụng đang bật Secure Input rồi thử lại.

Nếu PHTV vẫn báo thiếu quyền dù đã bật, bấm lại nút mở quyền trong PHTV. Ứng dụng sẽ làm mới entry TCC Accessibility rồi mở đúng mục System Settings để bạn bật lại.

### 3. PHTV báo mất quyền Trợ năng sau khi cập nhật, phải làm gì?

Đây thường là trạng thái TCC cũ/hỏng của macOS, đặc biệt sau khi app được ký lại hoặc cập nhật lớn.

Khuyên dùng:

1. Mở PHTV.
2. Bấm **Mở quyền nhập liệu** trong onboarding/Settings.
3. PHTV sẽ reset entry `Accessibility` cho bundle hiện tại.
4. Bật lại PHTV trong **System Settings > Privacy & Security > Accessibility**.
5. Thoát hẳn PHTV và mở lại nếu macOS chưa áp dụng ngay.

Không cần tự chạy lệnh Terminal trong trường hợp thông thường.

### 4. PHTV có theo dõi nội dung tôi gõ không?

PHTV cần nhận phím gõ để chuyển đổi tiếng Việt, nhưng engine xử lý local trên máy và không upload nội dung bạn gõ trong ứng dụng khác. Macro và Clipboard History lưu cục bộ. Khi tìm GIF/Sticker, từ khóa được gửi tới Klipy; khi gửi bug report, bạn luôn có thể kiểm tra nội dung trước khi gửi.

---

## Lỗi Khi Gõ Tiếng Việt

### 5. Vì sao chữ bị lặp, bị sửa sai hoặc xuất hiện ký tự lạ?

Nguyên nhân phổ biến là macOS hoặc ứng dụng đích tự sửa chữ cùng lúc với PHTV.

Hãy tắt trong **System Settings > Keyboard > Edit Input Sources...**:

- **Correct spelling automatically**
- **Capitalize words automatically**
- **Show inline predictive text**
- **Add period with double-space**
- **Use smart quotes and dashes**

Xem thêm trong [Hướng dẫn cài đặt](INSTALL.md#chuẩn-bị-trước-khi-cài-đặt).

### 6. PHTV có hỗ trợ Terminal, IDE và Claude Code không?

Có. PHTV có profile tương thích cho Terminal, iTerm2, VS Code và các môi trường CLI. Với Claude Code CLI, PHTV tự nhận diện session và áp timing profile ổn định hơn. Nếu app đích vẫn xử lý text khác thường, bạn có thể bật **Send Key Step-by-Step** trong **Settings > Ứng dụng**.

### 7. Làm sao tạm tắt tiếng Việt khi gõ code?

Bạn có thể:

- Nhấn phím chuyển Việt/Anh, mặc định **Control + Shift**.
- Giữ phím tạm tắt, mặc định **Option** nếu đã bật trong Settings.
- Nhấn **ESC** để khôi phục ký tự gốc sau khi vừa gõ dấu.
- Thêm IDE/Terminal vào **Luôn dùng tiếng Anh** nếu muốn PHTV cố định chế độ gõ tiếng Anh trong ứng dụng đó.

---

## Tính Năng

### 8. PHTV Picker là gì?

PHTV Picker là bảng chọn nhanh Emoji, GIF và Sticker theo giao diện native. Emoji hoạt động offline; GIF/Sticker dùng Klipy và chỉ kết nối mạng khi mở hoặc tìm khu tương ứng. Bạn có thể mở Picker bằng hotkey trong Settings hoặc từ menu bar rồi click để dán vào ứng dụng hiện tại.

### 9. Clipboard History hoạt động thế nào?

Clipboard History lưu nội dung bạn sao chép trên máy để dán lại nhanh:

- Mặc định tắt, bật trong **Settings > Phím tắt**.
- Hỗ trợ văn bản, ảnh và đường dẫn file.
- Có giới hạn số mục lưu và tìm kiếm nhanh.
- Dữ liệu nằm local trên máy.

### 10. Macro/Gõ tắt có gì đặc biệt?

PHTV hỗ trợ macro văn bản và snippet động:

- `{date}`, `{time}`, clipboard, counter và random.
- Tự viết hoa macro theo ngữ cảnh.
- Có thể bật macro cả khi đang ở chế độ tiếng Anh.
- Import/export để sao lưu hoặc chuyển máy.

### 11. Safe Mode là gì?

Safe Mode giúp PHTV giảm phụ thuộc vào một số luồng Accessibility API khi phát hiện môi trường không ổn định. Tính năng này hữu ích trên máy cũ, máy chạy OCLP hoặc các app có hành vi text field không chuẩn.

---

## Cập Nhật & Gỡ Cài Đặt

### 12. Làm sao cập nhật PHTV?

PHTV dùng Sparkle để tự kiểm tra và thông báo khi có bản mới. Nếu cài bằng Homebrew, bạn cũng có thể chạy:

```bash
brew upgrade --cask phtv
```

### 13. Gỡ sạch PHTV như thế nào?

Nếu cài bằng Homebrew:

```bash
brew uninstall --zap --cask phtv
```

Nếu cài thủ công:

1. Thoát PHTV.
2. Xoá `/Applications/PHTV.app`.
3. Xoá các preferences nếu muốn reset hoàn toàn:

```bash
rm -f ~/Library/Preferences/com.phamhungtien.phtv.plist
rm -f ~/Library/Preferences/com.phamhungtien.phtv.debug.plist
killall cfprefsd
```

---

## Hỗ Trợ

Nếu câu hỏi của bạn chưa có ở đây:

- [Tạo issue trên GitHub](https://github.com/PhamHungTien/PHTV/issues)
- Email: contact@phamhungtien.com
- Facebook: [PHTVInput](https://www.facebook.com/PHTVInput)

---

[Trang chủ](../README.md) • [Cài đặt](INSTALL.md)
