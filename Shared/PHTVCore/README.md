# PHTVCore

Swift package portable chứa hợp đồng session/C ABI dùng chung giữa macOS,
Windows và Linux. Package hiện build được và có C smoke test; engine tiếng Việt
vẫn đang ở macOS và chỉ được di chuyển sau khi có đủ golden vectors bảo vệ hành
vi.

## Trạng thái năng lực

`phtv_core_capabilities()` hiện chỉ công bố
`PHTV_CORE_CAPABILITY_SESSION_ABI`. Mọi sự kiện được trả về dưới dạng
`PHTV_CORE_EDIT_PASS_THROUGH`. Cờ
`PHTV_CORE_CAPABILITY_VIETNAMESE_ENGINE` chỉ được bật sau khi engine thật và test
parity đã được chuyển sang đây.

Đây là chủ đích: adapter TSF có thể phát hiện chính xác năng lực DLL thay vì
coi một scaffold là bộ gõ hoàn chỉnh.

## Hợp đồng ổn định

- Input: key event và input context đã chuẩn hóa.
- Output: `EditPlan` xác định, không tự phát sự kiện hệ điều hành.
- Không UI, filesystem path toàn cục, network hoặc API hệ điều hành.
- C ABI version 1 cho `PHTV.Windows.IME`.
- Struct có `struct_size`; type C dùng integer kích thước cố định.
- Caller sở hữu buffer UTF-16; DLL chỉ sở hữu opaque session do chính nó tạo.
- Một session dành cho một TSF document/context và không dùng đồng thời từ
  nhiều thread.
- Dictionary và test vector phải cho cùng kết quả trên hai nền tảng.

Header public nằm tại
[`PHTVCoreContracts.h`](Sources/PHTVCoreContracts/include/PHTVCoreContracts.h).

## Build và kiểm thử

```text
swift build --package-path Shared/PHTVCore
swift test --package-path Shared/PHTVCore
swift run --package-path Shared/PHTVCore PHTVCoreABISmoke
```

Trên macOS, dùng Xcode toolchain đầy đủ nếu Command Line Tools cục bộ không chứa
XCTest. Windows CI khóa Swift 6.3.3 và chạy cả ba lệnh trên.

Nguồn engine sẽ được tách dần từ `macOS/PHTV/Engine`, không copy rồi duy trì hai
engine theo nền tảng.
