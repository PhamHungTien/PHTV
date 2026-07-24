# GitHub Actions của PHTV

## macOS CI (`ci.yml`)

Chạy khi mã macOS, `Shared/`, tooling release hoặc metadata appcast/changelog
liên quan thay đổi trên `main` (các thư mục build của nền tảng khác không kích
hoạt job này) với quyền `contents: read`:

1. chạy bộ tự kiểm tra release notes viết bằng Swift, repository policy,
   appcast, plist và privacy manifest;
2. kiểm tra dictionary source và binary sinh ra;
3. build Debug;
4. chạy toàn bộ XCTest một lần, không retry và bật code coverage;
5. tải lên `.xcresult` và build log để điều tra khi lỗi.

Các action bên thứ ba được khóa bằng full commit SHA. Dependabot theo dõi phiên
bản GitHub Actions hàng tuần.

## macOS Nightly diagnostics (`nightly.yml`)

Chạy hàng tuần hoặc thủ công để thực hiện Xcode static analysis và nhóm regression
concurrency với Thread Sanitizer. Kết quả và analyze log được giữ 14 ngày; workflow này không
thay thế CI bắt buộc trên pull request.

## macOS Release (`release.yml`)

Trigger bằng tag `v*.*.*` hoặc `workflow_dispatch` với một version hợp lệ.

Luồng công việc:

1. **verify** trên GitHub-hosted macOS: kiểm tra version, CHANGELOG, metadata,
   dictionary và chạy toàn bộ XCTest;
2. **build** trên self-hosted runner: tạo riêng bản `arm64` và `x86_64`, ký bằng
   Developer ID Application, đóng gói DMG, notarize/staple, ký Sparkle;
3. **release**: tạo GitHub Release với nội dung render từ đúng mục trong
   `CHANGELOG.md`;
4. **publish_appcast**: commit hai feed đã ký về `main`;
5. **update-homebrew**: cập nhật `Casks/phtv.rb` trong Homebrew tap.

Hai kiến trúc dùng DMG và appcast riêng; đây không phải một Universal DMG.

## Windows CI (`windows-core.yml`)

Chạy khi `Apps/Windows`, portable Core, C contract hoặc golden vectors thay đổi;
kiểm tra thêm runtime settings snapshot C#/C++ trước khi build TSF;
cũng có thể chạy thủ công:

1. kiểm tra nhanh solution/project boundary và từ chối artifact sinh tự động
   (`bin/`, `obj/`, `.vs/`) bị commit;
2. dùng Windows Server 2025 x64;
3. cache/tải bộ cài Swift 6.3.3 chính thức, xác minh SHA-256, cài Python 3.10,
   .NET 10 và dùng MSBuild v143;
4. kiểm tra entrypoint Swift `scripts/windows.swift doctor`;
5. build/chạy C++ input-mode state, sensitive scope và hai snapshot parser tests;
6. build/test `Shared/PHTVCore` và C ABI smoke executable;
7. build/chạy C++ Core bridge cùng C# config/golden-vector tests;
8. build TSF DLL, kiểm tra vòng đời COM/profile/category trong runner cô lập;
9. build WinUI Settings app.

Thay đổi chỉ ở output cục bộ `bin/`, `obj/` hoặc `.vs/` được loại khỏi path
filter; không làm CI chạy lại khi IDE tạo artifact tạm.

Workflow không gọi `regsvr32`: một test host nạp DLL, gọi entrypoint
registration, xác minh trạng thái rồi gỡ sạch. Nó chưa thay thế
Notepad/Office/Chromium integration tests, kiểm tra quyền cài đặt hay installer
lifecycle tests trên Windows client thật.
Nếu bước cài Swift lỗi, workflow tải lên log của installer trong bảy ngày.

## Linux workflows

Phiên bản Linux hiện chỉ có kiến trúc và tài liệu trong `Apps/Linux/`, chưa có target
có thể build. Linux CI sẽ được thêm khi `Shared/PHTVCore` build được trên Linux
và IBus PoC tồn tại; tiếp theo mới mở rộng ma trận Fcitx 5, Wayland/X11 và package
tests. Không thêm workflow chỉ kiểm tra placeholder.

## Secrets bắt buộc

- `CERTIFICATES_P12`
- `CERTIFICATE_PASSWORD`
- `APPLE_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- `APPLE_TEAM_ID`
- `SPARKLE_PRIVATE_KEY`
- `TAP_REPO_TOKEN`

`CERTIFICATES_P12` phải chứa **Developer ID Application**, không phải Apple
Development. `APPLE_APP_SPECIFIC_PASSWORD` dùng để gửi notarization. Không in,
upload hoặc lưu các secret này trong artifact.

## Chuẩn bị release

`CHANGELOG.md` là nguồn duy nhất cho nội dung cập nhật, changelog và GitHub Release
notes. Quy trình đầy đủ, rollback và checklist kiểm thử nằm tại
[docs/RELEASING.md](../../docs/RELEASING.md).
