# PHTV.Windows.IME

Text Services Framework Text Input Processor viết bằng C++/WinRT.

## Lát cắt hiện có

- COM DLL/class factory và `ITfTextInputProcessorEx`;
- `ITfKeyEventSink` với chuyển đổi layout Windows sang Unicode scalar;
- C++ Core bridge gọi Swift C ABI v1;
- synchronous TSF read/write edit session và composition replacement;
- COM/TSF profile/category registration entrypoints;
- rollback COM/profile/category và integration test gỡ sạch trên runner cô lập;
- runtime settings snapshot v1 cho trạng thái Việt/Anh và Telex/VNI;
- thread input-mode compartment, event sink và preserved key `Ctrl+Space`;
- guard `GUID_PROP_INPUTSCOPE` cho password, private data và PIN;
- fail-open: lỗi Core/edit session trả phím về ứng dụng thay vì nuốt phím.

PoC nạp snapshot lúc activation và fallback an toàn về Việt + Telex nếu file
thiếu/hỏng/tương lai. Chưa có notification cập nhật tức thời, chưa phát hành
installer và chưa được chứng nhận trên Notepad/Office/Chromium.

COM activation hiện được ghi dưới `HKCU\Software\Classes`; profile và category
được quản lý qua API TSF chính thức. CI xác nhận transaction đăng ký/gỡ trong
môi trường cô lập, không khẳng định cài đặt không quyền admin hoặc activation
trên Windows client thật.

Snapshot khởi tạo `GUID_COMPARTMENT_KEYBOARD_OPENCLOSE`; sau đó compartment là
trạng thái Việt/Anh hiệu lực của session. `OnChange` chỉ đọc trạng thái và reset
composition/Core. Kết thúc composition ngoài key handler dùng edit session cho
phép TSF chọn đồng bộ hoặc bất đồng bộ. `Ctrl+Space` hiện là mặc định PoC và còn
phải kiểm chứng xung đột trên Windows thật.

Input scope được đọc trong synchronous read edit session cho từng candidate key;
kết quả `OnTestKeyDown` chỉ được tái sử dụng cho `OnKeyDown` khớp tương ứng. Lỗi
đọc scope không làm PHTV đoán field là an toàn.

## Trách nhiệm

- COM/TSF registration và language profile;
- key event sink, document/context và composition lifecycle;
- adapter Virtual Key/layout sang sự kiện Core;
- áp dụng `EditPlan` bằng TSF edit session;
- trạng thái Việt–Anh tối thiểu và cleanup an toàn.

## Không thuộc thành phần này

- Settings/WinUI, updater hoặc network;
- Clipboard history/GIF;
- business rule ngôn ngữ;
- log nội dung nhập;
- global keyboard hook làm fallback im lặng.

Mọi fallback ngoài TSF phải được người dùng biết, có telemetry cục bộ không chứa
payload và có ADR riêng.
