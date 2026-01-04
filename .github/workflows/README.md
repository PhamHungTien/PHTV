# GitHub Actions Workflows

## Release Workflow

File `release.yml` tự động build, sign và tạo release cho PHTV.

### Tính năng

- ✅ Build tự động với Xcode
- ✅ Code signing (nếu có certificate)
- ✅ Tạo DMG với Applications symlink
- ✅ Sign update với Sparkle
- ✅ Tạo GitHub Release với artifacts
- ✅ Generate appcast entry

### Cách sử dụng

#### 1. Trigger tự động khi push tag

```bash
git tag v1.3.9
git push origin v1.3.9
```

#### 2. Chạy thủ công

1. Vào tab "Actions" trên GitHub
2. Chọn "Build and Release"
3. Click "Run workflow"
4. Nhập version (ví dụ: 1.3.9)
5. Click "Run workflow"

### Setup GitHub Secrets

Để workflow hoạt động đầy đủ, cần setup các secrets sau:

#### Bắt buộc cho Sparkle Auto-Update

**`SPARKLE_PRIVATE_KEY`** - Private key để sign update

##### Nếu đã có private key trong Keychain:

```bash
# Tìm tên của key trong Keychain
security find-generic-password -l "Sparkle"

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
A key has been generated and saved in your keychain under "Sparkle ..." name.

Public key (add to Info.plist):
SUPublicEDKey = "ABC123..."

Private key (keep secret, add to GitHub Secrets):
[private key content]
```

##### Thêm vào GitHub Secrets:

1. Copy **private key** (toàn bộ nội dung hoặc từ clipboard)
2. Vào GitHub repo → Settings → Secrets and variables → Actions
3. Tạo secret mới: `SPARKLE_PRIVATE_KEY`
4. Paste private key vào

**Lưu ý**: Public key đã được thêm vào `PHTV/Info.plist` key `SUPublicEDKey`

#### Optional: Code Signing (để app được Apple verify)

**`CERTIFICATES_P12`** - Certificate ở format base64

```bash
# Export certificate từ Keychain
# 1. Mở Keychain Access
# 2. Chọn certificate "Developer ID Application: ..."
# 3. Export as .p12 file với password

# Convert to base64
base64 -i certificate.p12 | pbcopy
```

**`CERTIFICATE_PASSWORD`** - Password của file .p12

**`CODE_SIGN_IDENTITY`** - Identity để sign (ví dụ: "Developer ID Application: Your Name (TEAMID)")

```bash
# Xem danh sách identities
security find-identity -v -p codesigning
```

**`DEVELOPMENT_TEAM`** - Team ID (10 ký tự)

Tìm trong Apple Developer Portal hoặc từ identity name.

### Không có Code Signing Certificate?

Workflow vẫn hoạt động! App sẽ:
- ✅ Build thành công
- ✅ Tạo DMG với Applications symlink
- ✅ Tạo release trên GitHub
- ✅ Auto-update vẫn hoạt động (nếu có SPARKLE_PRIVATE_KEY)
- ⚠️  macOS sẽ hiện cảnh báo "unidentified developer" khi mở lần đầu

Users có thể bypass bằng cách:
1. Click chuột phải vào app
2. Chọn "Open"
3. Click "Open" trong dialog

## Update Homebrew Workflow

File `update-homebrew.yml` tự động cập nhật Homebrew formula sau khi release.

### Hoạt động

- Trigger tự động khi có GitHub Release mới
- Download DMG từ release
- Tính SHA256
- Cập nhật `homebrew/phtv.rb`
- Commit và push

## Workflow Khác

Có thể thêm workflows khác như:
- CI testing
- Linting
- Security scanning
- Beta releases

## Troubleshooting

### Build failed: "xcodebuild: command not found"

Runner đang sử dụng Xcode version cũ. Update `setup-xcode` step trong workflow.

### Code signing failed

1. Kiểm tra secrets đã được tạo đúng
2. Verify certificate còn valid
3. Check Team ID và Bundle ID match

### DMG không có Applications symlink

Kiểm tra step "Create DMG" - step này tạo symlink trước khi build DMG.

### Auto-update không hoạt động

1. Verify SPARKLE_PRIVATE_KEY đã được add vào secrets
2. Check public key trong Info.plist match với private key
3. Xem appcast entry trong release artifacts

## Testing

Để test workflow locally:

```bash
# Test build
xcodebuild -scheme PHTV -configuration Release clean build

# Test DMG creation
./scripts/create_dmg.sh

# Test Sparkle signing
./scripts/sign_update.sh ~/Desktop/PHTV-1.3.9.dmg
```

## Support

Có vấn đề? Mở issue trên GitHub repository.
