# Kiến trúc PHTV for Windows

## Mục tiêu

Kiến trúc Windows phải cho phép dùng chung engine tiếng Việt mà không mang các
chi tiết CGEvent, Accessibility, AppKit hoặc SwiftUI sang Windows. Tích hợp hệ
thống được đặt sau một adapter TSF nhỏ, có thể kiểm thử và ký độc lập.

## Thành phần

### `Shared/PHTVCore`

Thư viện Swift không giao diện, chịu trách nhiệm:

- Telex, VNI, Simple Telex và các bảng mã được hỗ trợ;
- đặt dấu, chính tả, Auto English, macro và session;
- tra cứu từ điển tiếng Việt/Anh;
- nhận sự kiện phím đã chuẩn hóa và trả về một `EditPlan` xác định.

Core không được import AppKit, SwiftUI, Carbon, ApplicationServices, WinSDK hoặc
WinUI. Đồng hồ, lưu trữ và log đi qua protocol/adapter được truyền vào. API liên
ngôn ngữ dùng C ABI có version, không để type Swift đi qua biên DLL.

### `PHTV.Windows.IME`

TSF Text Input Processor viết bằng C++/WinRT, chịu trách nhiệm:

- đăng ký language profile và thực thi các COM interface TSF;
- nhận `ITfKeyEventSink`, quản lý composition/edit session;
- chuyển virtual key, modifier và layout thành sự kiện trung lập cho Core;
- áp dụng `EditPlan` bằng TSF range/composition;
- bật/tắt Việt–Anh và đồng bộ trạng thái tối thiểu;
- giải phóng mọi tài nguyên khi DLL bị unload.

IME không gọi mạng, không hiển thị Settings và không ghi nội dung phím vào log.
Mọi callback COM phải có giới hạn thời gian và không chờ I/O đồng bộ.

### `PHTV.Windows.App`

Companion app viết bằng C# và WinUI 3, chịu trách nhiệm:

- onboarding, Settings, tray menu và trạng thái Việt–Anh;
- macro, từ điển cá nhân, quy tắc theo ứng dụng và import/export;
- chẩn đoán đã loại dữ liệu nhạy cảm;
- cập nhật, thông tin phiên bản và quy trình gỡ cài đặt.

Ứng dụng không cài global keyboard hook. Việc thay đổi cấu hình phải được ghi
atomically và phát notification có version; IME chỉ đọc snapshot hợp lệ.

## Luồng nhập liệu

```text
OnTestKeyDown
    └─► chuẩn hóa VirtualKey + modifier + layout
          └─► PHTVCore.handle(event)
                └─► EditPlan
                      ├─ passThrough
                      ├─ replace(rangeLength, text)
                      ├─ commit(text)
                      └─ resetSession
                            └─► TSF edit session/composition
```

`EditPlan` phải chứa toàn bộ ý định sửa trong một giao dịch logic. Không mô
phỏng chuỗi Backspace rồi gửi Unicode như đường chính vì cách đó dễ tạo race
condition trong Chromium/Electron, terminal và ứng dụng tải cao.

## Cấu hình và IPC

Định dạng cấu hình phải có `schemaVersion`, được ghi atomically và giữ mặc định
an toàn khi đọc lỗi. Kênh thông báo giữa App và IME sẽ được chọn sau PoC trong
thứ tự ưu tiên:

1. TSF compartments cho trạng thái nhỏ như Việt–Anh;
2. cấu hình per-user chỉ đọc, có version và notification;
3. broker/IPC chỉ khi hai lựa chọn trên không đáp ứng AppContainer.

Không đưa HTTP client, updater hoặc database lịch sử Clipboard vào DLL TSF.

## Quy tắc theo ứng dụng

Context Windows dùng executable identity, package family name và input scope.
Không dùng tiêu đề cửa sổ làm định danh chính. Quy tắc phải phân biệt:

- tự chuyển sang tiếng Anh;
- khóa tiếng Anh;
- cho phép người dùng chuyển thủ công;
- Terminal/console;
- trường mật khẩu hoặc input scope nhạy cảm.

Core chỉ nhận `InputContext`; việc thu thập context thuộc adapter Windows.

## Threading và hiệu năng

- Callback TSF không chạy tác vụ mạng hoặc đọc file chậm.
- Core có một session độc lập cho từng document/context TSF.
- State chia sẻ phải có ownership rõ ràng; không dùng singleton mutable không
  đồng bộ.
- Mục tiêu ban đầu: xử lý Core p95 dưới 1 ms trên máy tham chiếu, không tính thời
  gian commit của ứng dụng đích.
- Cache phải có giới hạn và được xóa khi document/context kết thúc.

## Khả năng quan sát

Log chỉ chứa version, component, mã trạng thái, thời lượng và định danh ứng dụng
đã chuẩn hóa khi người dùng chủ động tạo báo cáo. Không log:

- phím hoặc chuỗi đã nhập;
- nội dung composition, Clipboard hay macro;
- đường dẫn tài liệu, tiêu đề cửa sổ hoặc tên tài khoản;
- secret, token hoặc dữ liệu crash dump chưa kiểm duyệt.

## Cổng khả thi bắt buộc

Trước khi tạo toàn bộ UI, PoC phải chứng minh:

1. TSF DLL x64 đăng ký/kích hoạt/gỡ đăng ký sạch.
2. Core Swift được gọi ổn định qua C ABI trong Notepad, Office và Chromium.
3. Composition hoạt động với app Win32, WinUI, Electron và AppContainer.
4. Không cần quyền Administrator trong lúc chạy bình thường.
5. Đóng gói được Swift runtime và ký toàn bộ binary theo cách có thể phát hành.

Nếu mục 2 hoặc 5 thất bại, phải lập ADR mới trước khi thay đổi ngôn ngữ Core.
