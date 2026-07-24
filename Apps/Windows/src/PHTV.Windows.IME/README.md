# PHTV.Windows.IME

Text Services Framework Text Input Processor viết bằng C++/WinRT.

## Lát cắt hiện có

- COM DLL/class factory và `ITfTextInputProcessorEx`;
- `ITfKeyEventSink` với chuyển đổi layout Windows sang Unicode scalar;
- C++ Core bridge gọi Swift C ABI v1;
- synchronous TSF read/write edit session và composition replacement;
- COM/TSF profile/category registration entrypoints;
- fail-open: lỗi Core/edit session trả phím về ứng dụng thay vì nuốt phím.

PoC hiện dùng tiếng Việt + Telex mặc định. Chưa đọc snapshot Settings, chưa phát
hành installer và chưa được chứng nhận trên Notepad/Office/Chromium.

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
