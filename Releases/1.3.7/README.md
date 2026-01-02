# PHTV 1.3.7 Release Instructions

## Các file đã chuẩn bị

✅ **DMG File**: `/Users/phamhungtien/Desktop/PHTV-1.3.7.dmg` (13.5 MB)
✅ **Release Notes**: `Releases/1.3.7/RELEASE_NOTES.md`
✅ **CHANGELOG**: Đã cập nhật
✅ **Version bumped**: Info.plist, project.pbxproj
✅ **Appcast.xml**: Đã thêm entry cho v1.3.7 (cần signature)

## Bước tiếp theo

### 1. Tạo signature cho DMG

Bạn cần private key EdDSA để sign DMG. Nếu chưa có, tạo mới:

```bash
# Tạo key pair (chỉ làm 1 lần)
~/Library/Developer/Xcode/DerivedData/PHTV-*/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys

# Lưu private key vào file an toàn
```

Sau đó sign DMG:

```bash
# Sử dụng script tôi đã tạo
/tmp/sign_phtv_dmg.sh ~/Desktop/PHTV-1.3.7.dmg <path-to-private-key>
```

Hoặc sign trực tiếp:

```bash
~/Library/Developer/Xcode/DerivedData/PHTV-*/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update \
  ~/Desktop/PHTV-1.3.7.dmg \
  -f <path-to-private-key>
```

### 2. Cập nhật signature vào appcast.xml

Thay `SIGNATURE_PLACEHOLDER` trong `docs/appcast.xml` line 30 bằng signature vừa tạo:

```xml
sparkle:edSignature="<SIGNATURE_HERE>"
```

### 3. Commit và tạo Git tag

```bash
cd /Users/phamhungtien/Documents/PHTV

# Commit appcast với signature
git add docs/appcast.xml Releases/1.3.7/
git commit -m "chore: add appcast entry and release notes for v1.3.7"

# Tạo tag
git tag v1.3.7
git push origin main --tags
```

### 4. Tạo GitHub Release

1. Đi đến https://github.com/PhamHungTien/PHTV/releases/new
2. Chọn tag: `v1.3.7`
3. Release title: `PHTV 1.3.7`
4. Description: Copy nội dung từ `Releases/1.3.7/RELEASE_NOTES.md`
5. Upload file: `PHTV-1.3.7.dmg`
6. Publish release

### 5. Cập nhật Homebrew formula

Sau khi upload DMG lên GitHub releases, tính SHA256:

```bash
shasum -a 256 ~/Desktop/PHTV-1.3.7.dmg
```

Cập nhật `homebrew/phtv.rb` (đã có PLACEHOLDER_SHA256):
- Thay `PLACEHOLDER_SHA256` bằng SHA256 hash thực

Commit:

```bash
git add homebrew/phtv.rb
git commit -m "chore: update homebrew formula to v1.3.7"
git push
```

### 6. Test auto-update

Cài v1.3.6, sau đó check update để verify v1.3.7 xuất hiện.

## Tóm tắt

- ✅ Version: 1.3.7 (build 14)
- ✅ minimumSystemVersion: macOS 13.0
- ✅ DMG size: 13,540,250 bytes
- ✅ Universal Binary (Intel + Apple Silicon)
- ⏳ Cần: EdDSA signature
- ⏳ Cần: Upload lên GitHub releases
- ⏳ Cần: Cập nhật SHA256 cho Homebrew

---

**Lưu ý quan trọng:**
- Tất cả người dùng từ macOS Ventura (13.0) trở lên đều có thể update lên v1.3.7
- DMG đã có Applications symlink để dễ dàng cài đặt
- Appcast.xml đã được cấu hình đúng để Sparkle tự động phát hiện update
