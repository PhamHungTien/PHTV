# GitHub Actions của PHTV

## macOS CI (`ci.yml`)

Chạy khi mã macOS, tooling release hoặc metadata appcast/changelog liên quan
thay đổi trên `main` với quyền `contents: read`:

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

Chạy thủ công mặc định `publish: false`: build/ký/đóng gói để thử nghiệm, không
tạo GitHub Release hoặc cập nhật appcast. Chọn `publish: true` mới xuất
bản các bước đó; trigger bằng tag luôn đi theo luồng publish.

Toàn bộ workflow phát hành chạy trên Mac cá nhân qua hai self-hosted runner.
Xcode được chọn bằng `DEVELOPER_DIR`, không đổi cấu hình Xcode toàn hệ thống.

Luồng công việc:

1. **verify** trên self-hosted Mac: kiểm tra version, CHANGELOG, metadata,
   dictionary và chạy toàn bộ XCTest;
2. **build** trên hai self-hosted runner riêng biệt cùng máy Mac: tạo song song
   bản `arm64` và `x86_64`, ký bằng
   Developer ID Application, đóng gói DMG, notarize/staple, ký Sparkle;
3. **release**: tạo draft với nội dung từ `CHANGELOG.md`, tải đủ hai DMG
   và `SHA256SUMS.txt` rồi mới public;
4. **publish_appcast**: commit hai feed đã ký về `main`;

PHTV hiện được phân phối qua `Homebrew/homebrew-cask`. Homebrew theo dõi
tag GitHub chuẩn để cập nhật cask; workflow release không còn ghi vào tap cũ.

DMG dùng `dmgbuild` với phiên bản dependency cố định trong môi trường Python riêng.
Bố cục `.DS_Store` được ghi trực tiếp, không điều khiển Finder qua Apple Events
(tránh lỗi timeout `-1712` trên runner). Nền thường/Retina được vẽ bằng Swift trong `scripts/packaging/`; cấu hình vị trí
biểu tượng được tạo tạm trong workflow, không thêm công cụ Python vào repository.

Hai kiến trúc dùng DMG và appcast riêng; đây không phải một Universal DMG.
Hai runner dùng thư mục cài đặt/workspace riêng và cùng nhãn `self-hosted`,
`macOS`, `ARM64`. Mỗi runner nhận một job để build hai kiến trúc đồng thời.
Keychain và thư mục tạm độc lập; không khôi phục đè danh sách keychain dùng chung.
Xcode build chưa ký; sau khi tách kiến trúc, `codesign` ký Developer ID từ trong
ra ngoài bằng keychain riêng, hardened runtime và entitlements của ứng dụng.
Job phát hành chờ cả hai hoàn tất. Notarization dùng
`notarytool submit --wait --timeout 5h` trong giới hạn job 360 phút.

Thay đổi chỉ trong README hoặc tài liệu Markdown thông thường không tự kích
hoạt CI theo `paths` hiện tại; vẫn chạy `scripts/dev.swift metadata-check` tại
local để kiểm tra link và quy chuẩn repository.

## Secrets bắt buộc

- `CERTIFICATES_P12`
- `CERTIFICATE_PASSWORD`
- `APPLE_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- `APPLE_TEAM_ID`
- `SPARKLE_PRIVATE_KEY`

`CERTIFICATES_P12` phải chứa **Developer ID Application**, không phải Apple
Development. `APPLE_APP_SPECIFIC_PASSWORD` dùng để gửi notarization. Không in,
upload hoặc lưu các secret này trong artifact.

## Chuẩn bị release

`CHANGELOG.md` là nguồn duy nhất cho nội dung cập nhật, changelog và GitHub Release
notes. Quy trình đầy đủ, rollback và checklist kiểm thử nằm tại
[docs/RELEASING.md](../../docs/RELEASING.md).
