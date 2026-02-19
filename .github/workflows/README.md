# GitHub Actions Workflows

## Release Workflow

File `release.yml` tự động build, sign và tạo release cho PHTV.

### Tính năng

- ✅ Build tự động với Xcode trên macOS 26
- ✅ Code signing với Apple Development certificate
- ✅ Tạo DMG với Applications symlink
- ✅ Tạo ZIP + checksums cho release assets
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
| `update-plist` | ubuntu-latest | Commit `macOS/PHTV/Info.plist` về main |

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
| `CERTIFICATES_P12` | Apple Development certificate (base64) |
| `CERTIFICATE_PASSWORD` | Password của file .p12 |

#### Optional (để sync Homebrew tap)

| Secret | Mô tả |
|--------|-------|
| `TAP_REPO_TOKEN` | Personal Access Token để push sang homebrew-tap repo |

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

**Lưu ý**: Public key đã được thêm vào `PHTV/Info.plist` key `SUPublicEDKey`

#### CERTIFICATES_P12

```bash
# Export certificate từ Keychain Access:
# 1. Mở Keychain Access
# 2. Chọn certificate "Apple Development: ..." hoặc "Developer ID Application: ..."
# 3. Export as .p12 file với password

# Convert to base64
base64 -i certificate.p12 | pbcopy
```

Paste kết quả vào secret `CERTIFICATES_P12`.

#### CERTIFICATE_PASSWORD

Password bạn đã dùng khi export file .p12.

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

# Test DMG creation
./scripts/create_dmg.sh

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
│  • Create DMG + ZIP                                         │
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
