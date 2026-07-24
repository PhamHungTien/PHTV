# Quy tắc ngôn ngữ theo ứng dụng

PHTV for Windows tách rõ hai hành vi để người dùng không nhầm với trạng thái
Việt/Anh chung:

- **Mở bằng tiếng Anh**: ứng dụng bắt đầu ở tiếng Anh, nhưng người dùng vẫn có
  thể nhấn `Ctrl+Space` để chuyển sang tiếng Việt.
- **Luôn dùng tiếng Anh**: ứng dụng bị khóa ở tiếng Anh; PHTV không xử lý phím
  tiếng Việt và `Ctrl+Space` không mở lại tiếng Việt trong ứng dụng đó.

Ứng dụng không có quy tắc riêng kế thừa trạng thái Việt/Anh chung. Quy tắc theo
package family cụ thể được ưu tiên hơn quy tắc theo executable.

## Định danh và quyền riêng tư

WinUI chỉ lưu tên executable đã chuẩn hóa, ví dụ `code.exe`, và package family
name khi có. PHTV không lưu đường dẫn cài đặt, tiêu đề cửa sổ, tài liệu đang mở
hoặc nội dung người dùng nhập. TSF tự lấy định danh của process đang chứa nó khi
activation; không dùng global hook hay quét process khác.

Giới hạn runtime:

- tối đa 256 quy tắc;
- tên executable tối đa 260 ký tự và phải kết thúc bằng `.exe`;
- package family tối đa 255 ký tự;
- snapshot nhị phân tối đa 64 KiB.

## Snapshot runtime v1

`settings.json` vẫn là nguồn dữ liệu. App tạo thêm
`%LocalAppData%\PHTV\application-rules.snapshot` để DLL TSF không phải parse JSON
trong callback nhập liệu.

Mọi số nguyên dùng little-endian:

| Offset | Size | Trường |
| ---: | ---: | --- |
| 0 | 8 | Magic `PHTVRUL\0` |
| 8 | 2 | Format version `1` |
| 10 | 2 | Header length `32` |
| 12 | 4 | Settings schema |
| 16 | 8 | Revision |
| 24 | 4 | Số record |
| 28 | 4 | Tổng kích thước payload |
| 32 | thay đổi | Các record |
| cuối | 4 | FNV-1a 32-bit của toàn bộ byte trước checksum |

Mỗi record có header 8 byte: rule (1), flags (1), độ dài executable (2), độ dài
package family (2), reserved (2), sau đó là hai chuỗi UTF-8 không có NUL. Rule
`1` là mở bằng tiếng Anh, rule `2` là luôn dùng tiếng Anh. Trạng thái kế thừa
không được ghi vào snapshot.

Golden vector cho schema 1, revision `0x0102030405060708`, một rule
`code.exe` mở bằng tiếng Anh:

```text
5048545652554c000100200001000000
08070605040302010100000010000000
0100080000000000636f64652e657865
1159a51e
```

## Tính nhất quán và fail-safe

App ghi `settings.snapshot` và `application-rules.snapshot` bằng temporary file,
flush-to-disk rồi replace. Hai file dùng cùng revision. TSF chỉ áp dụng danh
sách khi cả parser và revision đều hợp lệ; lúc một file đã đổi mà file còn lại
chưa đổi, TSF bỏ qua toàn bộ quy tắc ứng dụng thay vì dùng cấu hình trộn.

Snapshot được nạp lúc profile TSF activation, không đọc file trên hot path. Sau
khi lưu, người dùng cần kích hoạt lại profile PHTV. File thiếu, quá lớn, hỏng
checksum, UTF-8 lỗi, identity không chuẩn hóa, record trùng hoặc enum chưa biết
đều bị từ chối. FNV-1a dùng để phát hiện file hỏng/ghi dở, không phải chữ ký bảo
mật.

Source và contract tests xác nhận parser C# với C++ dùng cùng golden vector.
Runtime activation, package identity và hành vi đổi focus vẫn phải được smoke
test trên Windows thật trước khi đánh dấu tính năng hoàn tất.
