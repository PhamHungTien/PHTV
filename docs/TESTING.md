# Kiểm thử PHTV

## Mục tiêu

PHTV xử lý sự kiện bàn phím ở cấp hệ thống, vì vậy chất lượng không thể được
chứng minh chỉ bằng một nhóm test engine. Quy trình gồm unit/regression test,
build/analyze và kiểm tra thủ công trên các ứng dụng đích.

## Chuẩn bị

- macOS 14 trở lên.
- Xcode đầy đủ. `scripts/dev.swift` tự tìm Xcode stable hoặc Xcode Beta; có thể
  đặt `DEVELOPER_DIR` để chọn rõ phiên bản.
- Bản chạy tương tác cần quyền Trợ năng (macOS 26 trở xuống) hoặc Device Control
  and Data Access (macOS 27+). XCTest thuần không tự cấp hoặc sửa quyền TCC của máy.

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
target có hơn 500 test bao phủ engine, hotkey, runtime policy, settings migration,
permission flow, Clipboard History, Sparkle và các profile tương thích.

TestAction dùng cấu hình `Testing` (cùng tùy chọn compiler Debug), bundle ID
test host riêng và Foundation home trong DerivedData. Chỉ domain test host được
reset; không xóa domain Debug/Release, không dừng `cfprefsd`, không đóng PHTV thật.
`CFFIXED_USER_HOME` không đủ để cô lập `UserDefaults` qua cfprefsd, nên không thay
`Testing` bằng `Debug` trong các lệnh test. XCTest không ghi global text preferences
của macOS. Test mới dùng named pasteboard, defaults suite và storage fixture riêng.

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
  -project Apps/macOS/PHTV.xcodeproj \
  -scheme PHTV \
  -configuration Testing \
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
- mất/khôi phục quyền Accessibility và event tap;
- Control+V/PHTV Picker khi mở đóng nhanh;
- cập nhật Sparkle từ bản public trước đó.

## Khôi phục từ và nhập/xuất dữ liệu

`EngineRegressionTests` kiểm tra từng tiền tố khi gõ `dudowjc`, `truowfng` và
các thứ tự đặt dấu trên Telex/Simple Telex, ranh giới từ, tên riêng viết hoa và
chuỗi nhiều từ. `AutoRestoreSettingsPersistenceTests` kiểm tra lưu/nạp lựa chọn,
đóng cửa sổ, migration và tắt/bật tính năng.

`SettingsBackupValueTests` kiểm tra codec giá trị và danh sách loại trừ macro.
`SettingsBackupServiceTests` kiểm tra round-trip sang kho trống cho registry
cài đặt, macro động/metadata, Clipboard/ảnh/file cache/nhóm/hotkey; file cũ,
thiếu/rỗng, đầu vào lỗi, lỗi ghi từng giai đoạn, journal phục hồi, symlink và
CSV nhiều dòng. Các test dùng UserDefaults suite và thư mục tạm riêng.
Phạm vi và giới hạn bảo vệ nằm trong [BACKUP.md](BACKUP.md).

Khi sửa nhập/xuất, cần kiểm tra file mới/cũ, trường thiếu và mảng rỗng, loại
snippet động, shortcut trùng, cấu hình không hợp lệ và lỗi ghi giữa chừng. Dùng
defaults suite/thư mục tạm độc lập, so sánh dữ liệu trước xuất và sau nhập;
không chạy thử nhập lên preferences của người dùng. UI cần kiểm tra hủy hộp
thoại, lỗi đọc/ghi và nội dung thông báo thành công.

## Definition of Done

Một thay đổi chỉ hoàn tất khi có test hồi quy phù hợp, full test xanh, Debug và
Release build thành công, Analyze không có lỗi mới, tài liệu/changelog được cập
nhật nếu hành vi người dùng thay đổi và không còn dữ liệu nhạy cảm trong diff.
