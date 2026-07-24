# Shared contracts

Khu vực dự kiến chứa các hợp đồng ổn định giữa engine và adapter nền tảng:

- `PHTVCore` C ABI có version;
- `KeyEvent`, `InputContext` và `EditPlan` dạng POD;
- schema cấu hình/macro/từ điển có migration;
- quy tắc UTF-8/UTF-16, ownership và error code.

Không để type Swift, C++ exception, COM object, GObject hoặc con trỏ framework đi
qua biên contract. Bên cấp phát bộ nhớ phải cung cấp hàm giải phóng tương ứng.

C ABI version 1 đang được triển khai cùng Swift package để SwiftPM có thể build,
link và smoke-test trực tiếp:
[`PHTVCoreContracts.h`](../PHTVCore/Sources/PHTVCoreContracts/include/PHTVCoreContracts.h).
Thư mục này sẽ tiếp tục chứa các schema độc lập package như cấu hình, import và
migration.
