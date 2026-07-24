# Windows tests

## Đang chạy trên CI

- `PHTV.Windows.CoreBridge.Tests`: gọi Core qua wrapper C++ giống TSF, kiểm tra
  Telex, VNI, rule khóa tiếng Anh và ownership session.
- `PHTV.Windows.Contracts.Tests`: kiểm tra config round-trip, normalization,
  duplicate rule, snapshot golden vector và từ chối schema tương lai.
- `PHTV.Windows.SettingsSnapshot.Tests`: kiểm tra native parser từ chối snapshot
  thiếu byte, hỏng checksum, format/schema tương lai, flag và enum không hợp lệ.

## Chưa triển khai

- TSF integration test host;
- WinUI UI automation;
- install/upgrade/uninstall smoke tests;
- application compatibility matrix automation.

Không đưa dữ liệu nhập, Clipboard hoặc tài liệu thật của người dùng vào fixture.
Quy tắc và ma trận đầy đủ nằm trong [../docs/TESTING.md](../docs/TESTING.md).
