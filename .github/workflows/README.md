# GitHub Actions Workflows

## Release Workflow

File `release.yml` tự động build, sign và tạo release cho PHTV.

### Tính năng

- ✅ Build tự động với Xcode trên macOS 26
- ✅ Tự động chọn chế độ phân phối:
  - `public`: `Developer ID Application` + notarization/stapling
  - `internal`: `Apple Development` (không notarization, test-only)
- ✅ Notarize + staple app/DMG khi chạy `public` mode
- ✅ Tạo DMG với Applications symlink
- ✅ Tạo ZIP + checksums cho release assets
- ✅ Verify lại app bundle trong cả DMG/ZIP (Info.plist + codesign + stapled ticket)
- ✅ Generate và ký `docs/appcast.xml` bằng Sparkle `generate_appcast`
- ✅ Tự động cập nhật Homebrew formula
- ✅ Sync với homebrew-tap repository
- ✅ Tự động set build number bằng `GITHUB_RUN_NUMBER` và commit Info.plist

### Các Jobs trong Workflow

| Job | Runner | Mô tả |
|-----|--------|-------|
| `build` | macos-26 | Build app, tạo DMG/ZIP, generate appcast |
| `release` | ubuntu-latest | Upload DMG/ZIP/checksums lên GitHub Releases |
| `publish-appcast` | ubuntu-latest | Commit `docs/appcast.xml` đã được Sparkle ký |
| `update-homebrew` | ubuntu-latest | Cập nhật Homebrew formula và sync tap |
| `update-plist` | ubuntu-latest | Commit `App/PHTV/Info.plist` về main |

### Cách sử dụng

#### 1. Trigger tự động khi push tag

```bash
git tag v1.4.5
git push origin v1.4.5
```

#### 2. Chạy thủ công (Manual Dispatch)

1. Vào tab **Actions** trên GitHub
2. Chọn **Build and Release**
3. Click **Run workflow**
4. Nhập version (ví dụ: `1.4.5`)
5. Click **Run workflow**

### Setup GitHub Secrets

Để workflow hoạt động đầy đủ, cần setup các secrets sau:

#### Bắt buộc

| Secret | Mô tả |
|--------|-------|
| `SPARKLE_PRIVATE_KEY` | EdDSA private key để sign Sparkle updates |
| `CERTIFICATES_P12` | Certificate `.p12` (Developer ID hoặc Apple Development) |
| `CERTIFICATE_PASSWORD` | Password của file .p12 |

#### Optional (để sync Homebrew tap)

| Secret | Mô tả |
|--------|-------|
| `TAP_REPO_TOKEN` | Personal Access Token để push sang homebrew-tap repo |

#### Optional (để bật public mode với notarization)

| Secret | Mô tả |
|--------|-------|
| `APPLE_NOTARY_API_KEY` | Nội dung private key `.p8` của App Store Connect API key |
| `APPLE_NOTARY_KEY_ID` | Key ID của App Store Connect API key |
| `APPLE_NOTARY_ISSUER_ID` | Issuer ID của App Store Connect API key |

---

### Hướng dẫn tạo Secrets

#### SPARKLE_PRIVATE_KEY

##### Nếu đã có private key trong Keychain:

```bash
# Export private key từ Keychain
security find-generic-password -l "Sparkle EdDSA Private Key" -w | pbcopy
```

Private key đã được copy vào clipboard!

##### Nếu chưa có, tạo key mới:

```bash
# Download Sparkle
cd /tmp
curl -LO https://github.com/sparkle-project/Sparkle/releases/latest/download/Sparkle-for-Swift-Package-Manager.zip
unzip Sparkle-for-Swift-Package-Manager.zip

# Generate keys
./Sparkle-for-Swift-Package-Manager/bin/generate_keys
```

Kết quả:
```
Public key (add to Info.plist):
SUPublicEDKey = "ABC123..."

Private key (keep secret, add to GitHub Secrets):
[private key content]
```

**Lưu ý**: Public key đã được thêm vào `App/PHTV/Info.plist` key `SUPublicEDKey`

#### CERTIFICATES_P12

```bash
# Export certificate từ Keychain Access:
# 1. Mở Keychain Access
# 2. Chọn một trong hai:
#    - "Developer ID Application: ..." (khuyến nghị cho public release)
#    - "Apple Development: ..." (internal/testing)
# 3. Export as .p12 file với password

# Convert to base64
base64 -i certificate.p12 | pbcopy
```

Paste kết quả vào secret `CERTIFICATES_P12`.

#### CERTIFICATE_PASSWORD

Password bạn đã dùng khi export file .p12.

#### Apple Notary Secrets

1. Vào App Store Connect -> Users and Access -> Integrations -> App Store Connect API
2. Tạo API key mới (quyền tối thiểu đủ để notarize)
3. Download file `AuthKey_XXXXXXX.p8`
4. Thêm secrets:
   - `APPLE_NOTARY_API_KEY`: paste toàn bộ nội dung `.p8`
   - `APPLE_NOTARY_KEY_ID`: ví dụ `ABC123DEFG`
   - `APPLE_NOTARY_ISSUER_ID`: UUID issuer (ví dụ `12345678-90ab-cdef-1234-567890abcdef`)

#### TAP_REPO_TOKEN

1. Vào https://github.com/settings/tokens
2. **Generate new token (classic)** với scope `repo`
3. Copy token và thêm vào secret `TAP_REPO_TOKEN`

---

### Thiếu certificate hoặc Sparkle key?

Release workflow hiện tại áp dụng fail-fast:
- ❌ Thiếu `CERTIFICATES_P12` hoặc `CERTIFICATE_PASSWORD` sẽ dừng ở bước import certificate
- ❌ Thiếu `SPARKLE_PRIVATE_KEY` sẽ dừng ở bước generate appcast
- ✅ Mục tiêu là không phát hành release/update feed ở trạng thái không ký hợp lệ

Workflow tự chọn mode:
- Nếu có `Developer ID Application` và đủ `APPLE_NOTARY_*` -> chạy `public` mode
- Nếu chỉ có `Apple Development`, hoặc thiếu `APPLE_NOTARY_*` -> fallback `internal` mode

---

### Build Number Tự động

Workflow tự động:
1. Dùng `GITHUB_RUN_NUMBER` làm `CFBundleVersion`
2. Build app với `MARKETING_VERSION` và `CURRENT_PROJECT_VERSION`
3. Sau khi release thành công, commit lại Info.plist với version/build number mới

Ví dụ:
- Release 1.4.4 → build 18
- Release 1.4.5 → build 19
- Release 1.4.6 → build 20

---

## Troubleshooting

### Build failed: Xcode version không đúng

Workflow sử dụng `macos-26` runner. Nếu GitHub chưa có runner này, sẽ cần thay đổi.

### Code signing failed

1. Kiểm tra `CERTIFICATES_P12` đã encode base64 đúng
2. Kiểm tra `CERTIFICATE_PASSWORD` đúng
3. Certificate còn valid và chưa hết hạn

### DMG không có Applications symlink

Kiểm tra step "Create DMG" - step này tạo symlink trước khi build DMG.

### VirusTotal báo `MissingPlist` cho binary

Workflow hiện đã fail-fast nếu artifact không chứa `.app` bundle hợp lệ (thiếu `Contents/Info.plist`) hoặc chữ ký app không hợp lệ.

Lưu ý: nếu upload riêng file `PHTV.app/Contents/MacOS/PHTV` lên VirusTotal thì đó là executable rời, không phải app bundle, có thể dẫn tới cảnh báo dạng `MissingPlist`.

### macOS báo "chứa phần mềm độc hại" / app bị chuyển vào thùng rác

1. Kiểm tra release workflow có pass step notarization cho app và DMG
2. Kiểm tra artifact được stapled ticket thành công (`xcrun stapler validate`)
3. Đảm bảo release chạy `public` mode (`Developer ID Application` + `APPLE_NOTARY_*`)
4. Không phát hành artifact từ local build chưa notarize

Lưu ý: nếu workflow fallback `internal` mode thì cảnh báo Gatekeeper vẫn có thể xảy ra.

### Notarization failed

1. Kiểm tra `APPLE_NOTARY_API_KEY`, `APPLE_NOTARY_KEY_ID`, `APPLE_NOTARY_ISSUER_ID`
2. Đảm bảo key `.p8` còn hiệu lực và đúng issuer/key id
3. Mở log step `Notarize and staple ...` để xem `notarytool log` chi tiết

### Auto-update không hoạt động

1. Verify `SPARKLE_PRIVATE_KEY` đã được add vào secrets
2. Check public key trong `Info.plist` (`SUPublicEDKey`) match với private key
3. Kiểm tra appcast.xml đã được cập nhật trên GitHub Pages
4. Đảm bảo build number mới **cao hơn** build hiện tại

### Homebrew không cập nhật

1. Kiểm tra `TAP_REPO_TOKEN` đã được set
2. Verify token có quyền `repo`
3. Check job "Update Homebrew" trong workflow logs

---

## Testing Locally

```bash
# Test build
xcodebuild -scheme PHTV -configuration Release clean build

# Verify local app bundle signature/plist
bash scripts/release/verify_app_bundle_signature.sh "App/build/Build/Products/Release/PHTV.app" "Local build"

# Test DMG creation
APP_PATH="App/build/Build/Products/Release/PHTV.app"
TMP_DIR=$(mktemp -d)
ditto "$APP_PATH" "$TMP_DIR/PHTV.app"
ln -s /Applications "$TMP_DIR/Applications"
hdiutil create -volname "PHTV" -srcfolder "$TMP_DIR" -ov -format UDZO -imagekey zlib-level=9 "PHTV-local.dmg"
rm -rf "$TMP_DIR"

# Test Sparkle appcast generation (sau khi có ZIP)
SPARKLE_PRIVATE_KEY="..." /tmp/Sparkle/bin/generate_appcast /path/to/archives
```

---

## Flow Hoàn Chỉnh

```
Push tag v1.4.5
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│  BUILD (macos-26)                                           │
│  • Checkout code                                            │
│  • Import certificate                                       │
│  • Compute build number từ GITHUB_RUN_NUMBER                │
│  • Build with Xcode                                         │
│  • Notarize + staple app bundle                             │
│  • Create DMG + ZIP                                         │
│  • Notarize + staple DMG                                    │
│  • Generate signed docs/appcast.xml với Sparkle             │
└─────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│  RELEASE (ubuntu-latest)                                    │
│  • Create GitHub Release                                    │
│  • Upload DMG/ZIP/checksums as assets                       │
└─────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│  PUBLISH-APPCAST (ubuntu-latest)                            │
│  • Commit docs/appcast.xml artifact                         │
│  • Push to main                                              │
│  • GitHub Pages auto-deploy                                 │
└─────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│  UPDATE-HOMEBREW (ubuntu-latest)                            │
│  • Update homebrew/phtv.rb with new SHA256                  │
│  • Commit to PHTV repo                                      │
│  • Sync to homebrew-tap repo                                │
│  • Update Info.plist with new build number                  │
│  • Commit to main                                           │
└─────────────────────────────────────────────────────────────┘
    │
    ▼
🎉 Release Complete!
   • Users thấy update trong Sparkle
   • brew upgrade --cask phtv hoạt động
```

---

## Support

Có vấn đề? Mở issue trên GitHub repository.
