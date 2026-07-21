# Kiểm thử PHTV

## Mục tiêu

PHTV xử lý sự kiện bàn phím ở cấp hệ thống, vì vậy chất lượng không thể được
chứng minh chỉ bằng một nhóm test engine. Quy trình gồm unit/regression test,
build/analyze và kiểm tra thủ công trên các ứng dụng đích.

## Chuẩn bị

- macOS 14 trở lên.
- Xcode đầy đủ. `scripts/dev.swift` tự tìm Xcode stable hoặc Xcode Beta; có thể
  đặt `DEVELOPER_DIR` để chọn rõ phiên bản.
- Bản chạy tương tác cần Accessibility và Input Monitoring. XCTest thuần không
  tự cấp hoặc sửa quyền TCC của máy.

Kiểm tra môi trường:

```bash
scripts/dev.swift env-check
scripts/dev.swift dict-check
scripts/dev.swift metadata-check
```

## Lệnh chuẩn

```bash
# Toàn bộ XCTest — lệnh bắt buộc trước khi merge/release
scripts/dev.swift test

# Nhóm hẹp khi đang phát triển
scripts/dev.swift engine-test
scripts/dev.swift hotkey-test

# Build và static analysis
scripts/dev.swift build
scripts/dev.swift release-build
scripts/dev.swift analyze

# Build, mở app Debug và xác nhận tiến trình còn sống
scripts/build_and_run.swift verify
```

Không dùng kết quả của test hẹp để khẳng định toàn bộ ứng dụng đã ổn. Test
target có hơn 400 test bao phủ engine, hotkey, runtime policy, settings migration,
permission flow, Clipboard History, Sparkle và các profile tương thích.

## CI

Pull request và push vào `main` phải:

1. Kiểm tra dictionary, appcast, privacy manifest và release-note renderer.
2. Build Debug không ký phân phối.
3. Chạy toàn bộ test target một lần, không tự coi lần retry là thành công.
4. Lưu `.xcresult` trong 14 ngày và xuất báo cáo code coverage.

Workflow `Nightly diagnostics` chạy static analysis và nhóm regression chạm các
ranh giới concurrency với Thread Sanitizer mỗi tuần; cũng có thể kích hoạt thủ
công khi thay đổi concurrency. Full XCTest vẫn là gate riêng ở mọi PR/release.

Nếu test không ổn định, sửa nguyên nhân hoặc cô lập thành test được theo dõi rõ;
không thêm vòng retry im lặng.

## Concurrency và sanitizer

Các state box đánh dấu `@unchecked Sendable` phải có một lock hoặc executor duy
nhất bảo vệ toàn bộ mutable state. Khi sửa EventTap, Accessibility, cache hoặc
panel lifecycle, chạy thêm Thread Sanitizer:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test \
  -project App/PHTV.xcodeproj \
  -scheme PHTV \
  -destination 'platform=macOS' \
  -enableThreadSanitizer YES \
  -parallel-testing-enabled NO
```

Sanitizer không thay thế test hành vi và có thể làm timing hệ thống chậm hơn.

## Kiểm tra thủ công trước release

Dùng [COMPATIBILITY.md](COMPATIBILITY.md) và ghi lại:

- phiên bản macOS, chip và keyboard layout;
- Telex, VNI và Simple Telex;
- chữ thường, Shift, Caps Lock, Backspace, Space và dấu câu;
- Terminal/CLI, trình duyệt, IDE, ứng dụng chat và editor đặc biệt;
- mất/khôi phục Accessibility hoặc Input Monitoring;
- Control+V/PHTV Picker khi mở đóng nhanh;
- cập nhật Sparkle từ bản public trước đó.

## Definition of Done

Một thay đổi chỉ hoàn tất khi có test hồi quy phù hợp, full test xanh, Debug và
Release build thành công, Analyze không có lỗi mới, tài liệu/changelog được cập
nhật nếu hành vi người dùng thay đổi và không còn dữ liệu nhạy cảm trong diff.
