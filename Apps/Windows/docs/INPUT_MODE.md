# Trạng thái Việt/Anh trên Windows

## Mục tiêu

PHTV dùng cơ chế trạng thái của Text Services Framework thay vì bắt phím toàn
hệ thống. Trạng thái “mở” tương ứng với chế độ tiếng Việt; trạng thái “đóng”
tương ứng với tiếng Anh và toàn bộ phím được trả trực tiếp cho ứng dụng.

## Nguồn trạng thái

Khi TSF service được kích hoạt:

1. runtime snapshot v1 cung cấp giá trị Việt/Anh ban đầu;
2. IME ghi giá trị đó vào thread compartment
   `GUID_COMPARTMENT_KEYBOARD_OPENCLOSE`;
3. `InputModeState` giữ bản sao hiệu lực cho hot path;
4. `ITfCompartmentEventSink::OnChange` nhận thay đổi từ TSF và cập nhật bản sao.

IME đăng ký capability `GUID_TFCAT_TIPCAP_INPUTMODECOMPARTMENT` để khai báo rõ
việc sử dụng input-mode compartment. Callback `OnChange` chỉ đọc compartment;
không gọi `SetValue` ngược lại từ callback vì TSF không cho phép re-entrant
write theo cách đó.

## Chuyển đổi bằng phím tắt

Lát cắt PoC đăng ký `Ctrl+Space` bằng `ITfKeystrokeMgr::PreserveKey`. Đây là
preserved key thuộc TSF, không phải global keyboard hook và không dùng
`SendInput`. Phím chỉ được ăn khi đúng GUID đã đăng ký và cập nhật compartment
thành công; lỗi cập nhật trả phím về ứng dụng.

`Ctrl+Space` là mặc định tạm thời của PoC. Trước MVP cần:

- cho phép cấu hình hoặc tắt phím tắt trong WinUI;
- phát hiện/xử lý xung đột với IME hoặc shortcut khác;
- đồng bộ trạng thái với tray và accessibility label;
- kiểm chứng hành vi khi chuyển layout bằng Windows.

## Composition và session

Khi trạng thái thay đổi, PHTV:

- yêu cầu kết thúc composition hiện tại bằng read/write edit session;
- cho phép TSF chọn chạy đồng bộ hoặc bất đồng bộ khi callback không ở luồng
  xử lý phím;
- xóa kết quả input-scope tạm và reset Core session;
- không ghi nội dung composition hay phím vào log.

Việc reset chỉ xảy ra khi trạng thái hiệu lực thực sự đổi. Giá trị `VT_I4` bằng
`0` là tiếng Anh; mọi giá trị khác `0` là tiếng Việt.

## Lifecycle và lỗi

- Preserved key và compartment sink được gỡ trong `Deactivate`.
- Compartment không bị xóa khỏi hệ thống khi deactivate; chỉ COM subscription
  thuộc instance hiện tại được giải phóng.
- Không có compartment hoặc đăng ký preserved key thất bại làm activation thất
  bại rõ ràng, thay vì âm thầm cài một global hook.
- Source hiện đã có unit test cho state machine; registration, callback,
  composition và shortcut vẫn phải kiểm chứng trên Windows thật.

## API tham chiếu

- [ITfKeystrokeMgr::PreserveKey](https://learn.microsoft.com/windows/win32/api/msctf/nf-msctf-itfkeystrokemgr-preservekey)
- [ITfCompartmentMgr](https://learn.microsoft.com/windows/win32/api/msctf/nn-msctf-itfcompartmentmgr)
- [ITfCompartment::SetValue](https://learn.microsoft.com/windows/win32/api/msctf/nf-msctf-itfcompartment-setvalue)
- [ITfCompartmentEventSink::OnChange](https://learn.microsoft.com/windows/win32/api/msctf/nf-msctf-itfcompartmenteventsink-onchange)
- [TSF edit-session flags](https://learn.microsoft.com/windows/win32/tsf/tf-es--constants)
- [Predefined TSF categories](https://learn.microsoft.com/windows/win32/tsf/predefined-category-values)
