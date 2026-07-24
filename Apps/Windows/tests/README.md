# Windows tests

## Đang chạy trên CI

- `PHTV.Windows.CoreBridge.Tests`: gọi Core qua wrapper C++ giống TSF, kiểm tra
  Telex, VNI, rule khóa tiếng Anh và ownership session.
- `PHTV.Windows.Contracts.Tests`: kiểm tra config round-trip, normalization,
  duplicate rule và từ chối schema tương lai.

## Chưa triển khai

- TSF integration test host;
- WinUI UI automation;
- install/upgrade/uninstall smoke tests;
- application compatibility matrix automation.

Không đưa dữ liệu nhập, Clipboard hoặc tài liệu thật của người dùng vào fixture.
Quy tắc và ma trận đầy đủ nằm trong [../docs/TESTING.md](../docs/TESTING.md).
