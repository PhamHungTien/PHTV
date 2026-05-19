# GitHub Actions Workflows

## Release Workflow

File: `.github/workflows/release.yml`

Workflow release hiện đã được đồng bộ theo mẫu LunarV, với cấu trúc release macOS đã ký Developer ID và notarize:

- `build` (macos-26): build, sign, tạo DMG, generate Sparkle appcast
- `release` (ubuntu-latest): tạo GitHub Release
- `publish_appcast` (ubuntu-latest): commit `docs/appcast.xml` + `docs/appcast-intel.xml` về `main`
- `update-homebrew` (ubuntu-latest): cập nhật `Casks/phtv.rb` trên `PhamHungTien/homebrew-tap`

## Trigger

- Tự động khi push tag: `v*.*.*`
- Chạy tay qua `workflow_dispatch` với input `version`

## Required Secrets

- `CERTIFICATES_P12`
- `CERTIFICATE_PASSWORD`
- `APPLE_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- `APPLE_TEAM_ID`
- `SPARKLE_PRIVATE_KEY`
- `TAP_REPO_TOKEN`

`CERTIFICATES_P12` phải là certificate `Developer ID Application` export dạng `.p12` rồi base64 encode. Không dùng certificate `Apple Development` hoặc `Mac Development` cho release public/notarized. `APPLE_APP_SPECIFIC_PASSWORD` là app-specific password của Apple ID dùng để submit notarization.

## Release Flow

1. Build app bằng `xcodebuild` (Release, manual signing, Developer ID Application)
2. Verify code signature và entitlements của `PHTV.app`
3. Tạo `PHTV-<version>-arm64.dmg` và `PHTV-<version>-intel.dmg` (nền hướng dẫn kéo-thả vào `Applications`, kèm file `Nhấp Đúp Nếu PHTV Không Mở Được`)
4. Submit DMG lên Apple notarization, staple ticket, rồi validate bằng `stapler` và `spctl`
5. Generate + sign `docs/appcast.xml` và `docs/appcast-intel.xml` bằng Sparkle `generate_appcast`
6. Upload DMG assets lên GitHub Release
7. Commit appcasts lên `main`
8. Cập nhật Homebrew tap (`Casks/phtv.rb`) với version + SHA256 mới

## Notes

- Release workflow không dùng shell script ngoài repo.
- Toàn bộ logic release/sign/package/tap update nằm trong GitHub Actions YAML.
