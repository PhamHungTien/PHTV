# GitHub Actions Workflows

## Release Workflow

File: `.github/workflows/release.yml`

Workflow release hiện đã được đồng bộ theo mẫu LunarV, với cấu trúc đơn giản:

- `build` (macos-26): build, sign, tạo DMG/ZIP, generate Sparkle appcast
- `release` (ubuntu-latest): tạo GitHub Release + checksums
- `publish_appcast` (ubuntu-latest): commit `docs/appcast.xml` về `main`
- `update-homebrew` (ubuntu-latest): cập nhật `Casks/phtv.rb` trên `PhamHungTien/homebrew-tap`

## Trigger

- Tự động khi push tag: `v*.*.*`
- Chạy tay qua `workflow_dispatch` với input `version`

## Required Secrets

- `CERTIFICATES_P12`
- `CERTIFICATE_PASSWORD`
- `SPARKLE_PRIVATE_KEY`
- `TAP_REPO_TOKEN`

## Release Flow

1. Build app bằng `xcodebuild` (Release, manual signing)
2. Verify code signature của `PHTV.app`
3. Tạo `PHTV-<version>.dmg` và `PHTV-<version>.zip`
4. Generate + sign `docs/appcast.xml` bằng Sparkle `generate_appcast`
5. Upload assets lên GitHub Release
6. Commit `docs/appcast.xml` lên `main`
7. Cập nhật Homebrew tap (`Casks/phtv.rb`) với version + SHA256 mới

## Notes

- Release workflow không dùng shell script ngoài repo.
- Toàn bộ logic release/sign/package/tap update nằm trong GitHub Actions YAML.
