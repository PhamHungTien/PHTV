# PHTV.Windows.IME

Text Services Framework Text Input Processor viết bằng C++/WinRT.

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

