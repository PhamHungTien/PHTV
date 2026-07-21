# GitHub Actions của PHTV

## CI (`ci.yml`)

Chạy trên mọi push/PR vào `main` với quyền `contents: read`:

1. kiểm tra Python release-note tests, appcast, plist và privacy manifest;
2. kiểm tra dictionary source và binary sinh ra;
3. build Debug;
4. chạy toàn bộ XCTest một lần, không retry và bật code coverage;
5. tải lên `.xcresult` và build log để điều tra khi lỗi.

Các action bên thứ ba được khóa bằng full commit SHA. Dependabot theo dõi phiên
bản GitHub Actions hàng tuần.

## Nightly diagnostics (`nightly.yml`)

Chạy hàng tuần hoặc thủ công để thực hiện Xcode static analysis và toàn bộ XCTest
với Thread Sanitizer. Kết quả và analyze log được giữ 14 ngày; workflow này không
thay thế CI bắt buộc trên pull request.

## Release (`release.yml`)

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
