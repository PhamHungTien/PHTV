# GitHub Actions của PHTV

## macOS CI (`ci.yml`)

Chạy trên mọi push/PR vào `main` với quyền `contents: read`:

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

## Windows workflows

Phiên bản Windows hiện chỉ có kiến trúc và tài liệu trong `Windows/`, chưa có
project có thể build. Chỉ thêm Windows CI sau khi Swift Core và TSF PoC tồn tại;
workflow khi đó phải dùng Windows runner và không làm thay đổi pipeline macOS.

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
