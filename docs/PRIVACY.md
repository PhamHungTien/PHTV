# Quyền riêng tư trong PHTV

Cập nhật lần cuối: 22/07/2026

PHTV xử lý phím gõ và chuyển đổi tiếng Việt trực tiếp trên máy. Nội dung bạn gõ
trong các ứng dụng khác không được gửi tới máy chủ của PHTV. Một số tính năng
tùy chọn cần mạng và được mô tả rõ bên dưới.

## Dữ liệu đi qua mạng

| Tính năng | Khi nào kết nối | Dữ liệu được gửi | Bên nhận |
| --- | --- | --- | --- |
| Cập nhật ứng dụng | Khi Sparkle kiểm tra hoặc tải bản mới | Metadata HTTP cần thiết để lấy appcast và DMG | GitHub Pages, GitHub Releases |
| GIF/Sticker thịnh hành | Khi mở khu GIF hoặc Sticker | Mã cài đặt ngẫu nhiên, domain tích hợp và metadata mạng như địa chỉ IP | Klipy |
| Tìm GIF/Sticker | Khi nhập tìm kiếm trong khu GIF hoặc Sticker | Từ khóa tìm kiếm, mã cài đặt ngẫu nhiên và metadata mạng | Klipy |
| Quảng cáo trong kết quả Klipy | Khi quảng cáo được hiển thị hoặc bấm | ID nội dung/quảng cáo và sự kiện hiển thị hoặc bấm | Klipy hoặc URL đo lường do Klipy trả về |
| Báo lỗi | Chỉ khi người dùng chủ động mở GitHub hoặc email | Nội dung báo cáo mà người dùng xem lại và quyết định gửi | GitHub hoặc nhà cung cấp email |

PHTV không dùng từ khóa tìm GIF/Sticker để cải thiện engine và không ghi từ khóa
đó vào file log chẩn đoán. Klipy có thể xử lý IP, dữ liệu sử dụng và quảng cáo
theo [chính sách riêng tư của Klipy](https://klipy.com/support/privacy-policy).

Mã cài đặt Klipy là UUID ngẫu nhiên được lưu trong `UserDefaults`. Nó không chứa
tên, email hoặc Apple ID, nhưng có thể liên kết các yêu cầu GIF/Sticker từ cùng
một bản cài đặt. PHTV khai báo dữ liệu này cùng tìm kiếm và tương tác quảng cáo
trong `PrivacyInfo.xcprivacy`.

## Dữ liệu lưu trên máy

| Dữ liệu | Vị trí/phạm vi | Thời gian lưu |
| --- | --- | --- |
| Cài đặt, macro, quy tắc ứng dụng | `UserDefaults` của PHTV | Đến khi reset hoặc gỡ sạch ứng dụng |
| Lịch sử Clipboard | Application Support của PHTV | Theo giới hạn số lượng/thời gian người dùng chọn |
| Mục Clipboard đã ghim | Application Support của PHTV | Đến khi người dùng bỏ ghim hoặc xóa |
| Bản sao file Clipboard | `ClipboardHistoryFiles` trong Application Support | Đi cùng mục lịch sử; file trên 25 MB không được sao chép vào cache |
| Log chẩn đoán | `PHTV/Logs/phtv_debug.log` trong Application Support | Tối đa khoảng 2 MB và được dọn theo chu kỳ 24 giờ |
| GIF/Sticker tạm dùng để dán | Thư mục tạm `PHTPMedia` | Thường xóa sau khi dán; cơ chế dự phòng dọn file cũ hơn 7 ngày và giới hạn cache |
| ID GIF/Sticker gần đây | `UserDefaults` | Tối đa 20 ID mỗi loại, đến khi reset dữ liệu |

Lịch sử Clipboard mặc định tắt. PHTV chỉ theo dõi pasteboard khi người dùng bật
tính năng này. Clipboard và macro không được tải lên máy chủ của PHTV.

## Quyền macOS

- **Accessibility**: tương tác với ô nhập liệu và commit chuỗi đã xử lý.
- **Input Monitoring**: nhận sự kiện bàn phím để engine Telex/VNI hoạt động.
- **Automation/Apple Events**: chỉ dùng trong luồng phục hồi TCC có xác nhận của
  người dùng; PHTV không tự động điều khiển ứng dụng khác trong quá trình gõ.

PHTV không chạy trong App Sandbox vì CGEvent tap và khả năng tương thích trên
toàn hệ thống cần quyền ở cấp tiến trình. Hardened Runtime, Developer ID signing
và notarization vẫn được bật cho bản phát hành.

## Xóa dữ liệu

- Xóa lịch sử trong **Cài đặt > Lịch sử Clipboard**.
- Reset cấu hình trong **Cài đặt > Hệ thống**.
- Gỡ sạch bằng `brew uninstall --zap --cask phtv` hoặc công cụ gỡ trong ứng dụng.
- File log được đính kèm báo lỗi chỉ khi người dùng chủ động chọn gửi.

## Tracking

PHTV không kết hợp dữ liệu với dữ liệu của ứng dụng khác để lập hồ sơ người dùng
và khai báo `NSPrivacyTracking = false`. Klipy là dịch vụ bên thứ ba có nội dung
quảng cáo; nếu cách tích hợp hoặc chính sách của Klipy thay đổi, privacy manifest
và tài liệu này phải được rà soát trước bản phát hành tiếp theo.

Mọi câu hỏi về quyền riêng tư có thể gửi tới
[phamhungtien.contact@gmail.com](mailto:phamhungtien.contact@gmail.com).
