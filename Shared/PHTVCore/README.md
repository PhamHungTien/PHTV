# PHTVCore

Swift package portable chứa hợp đồng session/C ABI dùng chung giữa macOS,
Windows và Linux. Package hiện có bộ biến đổi Unicode Telex/VNI độc lập nền
tảng, session composition, contract tests và C smoke test. Các tính năng engine
nâng cao vẫn đang được tách dần khỏi app macOS.

## Trạng thái năng lực

`phtv_core_capabilities()` công bố session ABI, Telex và VNI. Core xử lý Unicode
scalar trung lập, theo dõi raw keys cho từng session và chỉ trả `.replace` khi
kết quả hiển thị khác thao tác gõ thẳng; phím thường tiếp tục
`.passThrough`.

Baseline hiện tại chưa gồm Simple Telex, Auto English, kiểm tra chính tả, macro,
từ điển và các bảng mã legacy. Adapter phải kiểm tra capability/version và không
được suy diễn các tính năng này từ cờ Telex/VNI.

## Hợp đồng ổn định

- Input: key event và input context đã chuẩn hóa.
- Output: `EditPlan` xác định, không tự phát sự kiện hệ điều hành.
- Không UI, filesystem path toàn cục, network hoặc API hệ điều hành.
- C ABI version 1 cho `PHTV.Windows.IME`.
- Struct có `struct_size`; type C dùng integer kích thước cố định.
- Caller sở hữu buffer UTF-16; DLL chỉ sở hữu opaque session do chính nó tạo.
- Nếu buffer thiếu, Core trả `PHTV_CORE_STATUS_BUFFER_TOO_SMALL`, ghi độ dài cần
  thiết vào `EditPlan` và rollback session để caller có thể gọi lại an toàn.
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
XCTest. Windows CI khóa Swift 6.3.3 và chạy cả ba lệnh trên. Golden vectors
trung lập nằm tại
[`Shared/TestVectors`](../TestVectors/README.md).

Các lát cắt còn lại của engine sẽ được tách dần từ
`Apps/macOS/PHTV/Engine`; không copy rồi duy trì hai engine hoàn chỉnh theo nền
tảng.
