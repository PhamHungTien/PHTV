# Shared contracts

Khu vực dự kiến chứa các hợp đồng ổn định giữa engine và adapter nền tảng:

- `PHTVCore` C ABI có version;
- `KeyEvent`, `InputContext` và `EditPlan` dạng POD;
- schema cấu hình/macro/từ điển có migration;
- quy tắc UTF-8/UTF-16, ownership và error code.

Không để type Swift, C++ exception, COM object, GObject hoặc con trỏ framework đi
qua biên contract. Bên cấp phát bộ nhớ phải cung cấp hàm giải phóng tương ứng.

