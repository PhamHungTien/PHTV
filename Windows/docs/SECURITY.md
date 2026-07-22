# Bảo mật PHTV for Windows

Tài liệu này bổ sung cho [chính sách bảo mật chung](../../SECURITY.md). Báo cáo
bảo mật dùng kênh riêng được nêu trong tài liệu đó, không mở public issue.

## Ranh giới tin cậy

TSF tải IME DLL vào tiến trình ứng dụng đích. Vì vậy lỗi memory safety, deadlock,
dependency hijacking hoặc exception thoát khỏi callback có thể ảnh hưởng trực
tiếp đến ứng dụng người dùng.

Các ranh giới cần threat model riêng:

- TSF/COM registration và DLL search path;
- C ABI giữa C++ và Swift;
- file cấu hình và IPC giữa App với IME;
- updater/installer và code-signing key;
- import macro, từ điển và cấu hình;
- Clipboard/GIF nếu các tính năng này được triển khai.

## Yêu cầu bắt buộc

- IME chạy với quyền của tiến trình đích, không yêu cầu elevation thường xuyên.
- Không tải DLL theo current working directory hoặc đường dẫn có thể ghi tùy ý.
- Validate version, length, enum và encoding tại mọi biên ABI/IPC.
- Không ném exception qua COM/C ABI; trả mã lỗi xác định.
- Ký Authenticode mọi EXE/DLL/installer phát hành.
- Không chứa updater, HTTP client hoặc secret trong TSF DLL.
- Dependency được khóa phiên bản, kiểm tra license và tạo SBOM khi phát hành.
- Import dữ liệu có giới hạn kích thước, parse an toàn và ghi atomically.

## Logging và crash report

Mặc định chỉ log lifecycle và mã lỗi không chứa payload. Crash dump có thể chứa
bộ nhớ ứng dụng đích nên không tự động tải lên. Người dùng phải chủ động đồng ý,
được cảnh báo và có khả năng xem/xóa dữ liệu trước khi gửi.

## Kiểm thử bảo mật

- fuzz Core, parser cấu hình và C ABI;
- Application Verifier/sanitizer phù hợp cho native component;
- kiểm tra DLL search order và package tampering;
- cài/upgrade/uninstall bằng tài khoản không phải Administrator;
- kiểm tra AppContainer, ứng dụng elevated và integrity-level boundary;
- quét secret, dependency và binary trước release.

