# Windows tests

## Đang chạy trên CI

- `PHTV.Windows.CoreBridge.Tests`: gọi Core qua wrapper C++ giống TSF, kiểm tra
  Telex, VNI, rule khóa tiếng Anh và ownership session.
- `PHTV.Windows.Contracts.Tests`: kiểm tra config round-trip, normalization,
  duplicate rule, hai snapshot golden vector và từ chối schema tương lai.
- `PHTV.Windows.ApplicationRulesSnapshot.Tests`: kiểm tra C++ parser, golden
  vector dùng chung, matching package/executable và input lỗi.
- `PHTV.Windows.InputModeState.Tests`: kiểm tra trạng thái khởi tạo, quy ước
  open/close `VT_I4`, idempotence, toggle và generation khi trạng thái đổi.
- `PHTV.Windows.SettingsSnapshot.Tests`: kiểm tra native parser từ chối snapshot
  thiếu byte, hỏng checksum, format/schema tương lai, flag và enum không hợp lệ.
- `PHTV.Windows.InputScopePolicy.Tests`: khóa danh sách password/private/PIN và
  bảo đảm một scope nhạy cảm luôn thắng trong mảng nhiều scope.

## Chưa triển khai

- TSF integration test host;
- WinUI UI automation;
- install/upgrade/uninstall smoke tests;
- application compatibility matrix automation.

Không đưa dữ liệu nhập, Clipboard hoặc tài liệu thật của người dùng vào fixture.
Quy tắc và ma trận đầy đủ nằm trong [../docs/TESTING.md](../docs/TESTING.md).
