# Sensitive Input Scope Policy

TSF phải trả phím trực tiếp cho ứng dụng ở trường mật khẩu, PIN hoặc private
data. Đây là lớp phòng vệ bổ sung; ứng dụng Windows vẫn phải tắt text services
cho password field đúng theo hướng dẫn của Microsoft.

## Scope bị chặn

| InputScope | Giá trị |
| --- | ---: |
| `IS_PASSWORD` | 31 |
| `IS_PRIVATE` | 61 |
| `IS_NUMERIC_PASSWORD` | 63 |
| `IS_NUMERIC_PIN` | 64 |
| `IS_ALPHANUMERIC_PIN` | 65 |
| `IS_ALPHANUMERIC_PIN_SET` | 66 |

Chỉ cần một giá trị nhạy cảm trong mảng scope là toàn bộ key event được
pass-through. Username/login name không bị xem là password; quy tắc ưu tiên
tiếng Anh cho username sẽ thuộc application/context policy riêng.

## Cách đọc

1. `OnTestKeyDown` yêu cầu synchronous read edit session.
2. Lấy selection hiện tại.
3. Gọi `ITfContext::GetAppProperty(GUID_PROP_INPUTSCOPE)`.
4. Gọi `ITfReadOnlyProperty::GetValue` trên selection.
5. Query `ITfInputScope` và gọi `GetInputScopes`.
6. Giải phóng `VARIANT` và mảng scope bằng API COM tương ứng.

Kết quả chỉ được giữ từ `OnTestKeyDown` tới `OnKeyDown` của đúng virtual key và
key data. Không cache theo document vì một TSF context có thể chứa nhiều vùng có
scope khác nhau.

`S_FALSE` hoặc `E_NOTIMPL` từ `GetAppProperty` nghĩa là context không cung cấp
property và được xử lý như field thường. Lỗi lock, COM, variant, allocation,
scope array hoặc edit session được xem là “không xác định”: PHTV không ăn phím,
kết thúc composition nếu có thể và reset Core session.

## Tài liệu API

- [ITfInputScope](https://learn.microsoft.com/windows/win32/api/inputscope/nn-inputscope-itfinputscope)
- [InputScope enumeration](https://learn.microsoft.com/windows/win32/api/inputscope/ne-inputscope-inputscope)
- [ITfContext::GetAppProperty](https://learn.microsoft.com/windows/win32/api/msctf/nf-msctf-itfcontext-getappproperty)
- [TF_ES flags](https://learn.microsoft.com/windows/win32/tsf/tf-es--constants)

## Cổng kiểm chứng

Native policy tests khóa danh sách scope và nguyên tắc “bất kỳ scope nhạy cảm
nào cũng thắng”. Windows runtime matrix vẫn phải kiểm tra PasswordBox WinUI,
HTML password/PIN, Office protected input và field không khai báo scope; không
được suy rộng tương thích chỉ từ unit test.
