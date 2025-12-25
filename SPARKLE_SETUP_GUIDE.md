# PHTV Sparkle Auto-Update Setup Guide

## ✅ Đã hoàn thành (Code Implementation)

Tất cả code đã được implement xong! Các file đã được tạo/sửa:

### Files mới:
- ✅ `PHTV/Application/SparkleManager.h` - Sparkle manager header
- ✅ `PHTV/Application/SparkleManager.mm` - Sparkle manager implementation
- ✅ `PHTV/SwiftUI/Views/Components/UpdateBannerView.swift` - Update banner UI
- ✅ `PHTV/SwiftUI/Views/Components/ReleaseNotesView.swift` - Release notes viewer
- ✅ `docs/appcast.xml` - Stable releases feed
- ✅ `docs/appcast-beta.xml` - Beta releases feed
- ✅ `scripts/sign_update.sh` - DMG signing script

### Files đã chỉnh sửa:
- ✅ `PHTV/Info.plist` - Added Sparkle configuration keys
- ✅ `PHTV/Application/AppDelegate.mm` - Replaced GitHub API with Sparkle
- ✅ `PHTV/SwiftUI/PHTPApp.swift` - Added update settings & observers
- ✅ `PHTV/SwiftUI/Views/Settings/SystemSettingsView.swift` - Added update settings UI
- ✅ `.gitignore` - Added certificate exclusions

---

## 🔧 Các bước Manual cần thực hiện

### Bước 1: Add Sparkle Framework qua SPM

1. Mở Xcode project: `PHTV.xcodeproj`
2. Click vào project root → `PHTV` target
3. Chọn tab **"Package Dependencies"**
4. Click nút **"+"** (Add Package Dependency)
5. Nhập URL: `https://github.com/sparkle-project/Sparkle`
6. Version rule: **"Up to Next Major Version"** với minimum **2.6.0**
7. Click **"Add Package"**
8. Đảm bảo package được add vào target **PHTV**

### Bước 2: Add SparkleManager files vào Xcode Project

1. Trong Xcode, right-click vào folder `PHTV/Application`
2. Chọn **"Add Files to PHTV..."**
3. Navigate đến và select 2 files:
   - `PHTV/Application/SparkleManager.h`
   - `PHTV/Application/SparkleManager.mm`
4. ✅ Check **"Copy items if needed"**
5. ✅ Đảm bảo **"Add to targets: PHTV"** được checked
6. Click **"Add"**

### Bước 3: Enable Hardened Runtime

1. Trong Xcode, chọn **PHTV target** → **"Signing & Capabilities"** tab
2. Click nút **"+ Capability"**
3. Chọn **"Hardened Runtime"**
4. Capability sẽ được thêm vào (required by Sparkle)

### Bước 4: Verify Apple Developer Certificate

**✅ Bạn đã có certificate chính thức từ Apple Developer Program!**

Certificate của bạn:
- **Name:** `Apple Development: hungtien4944@icloud.com (QA6JWU37RW)`
- **Issuer:** Apple Worldwide Developer Relations Certification Authority
- **Expires:** Wednesday, 9 December 2026
- **Status:** ✅ Valid

**Không cần tạo self-signed certificate!** Bạn sẽ dùng certificate này.

**Ưu điểm:**
- ✅ macOS trust certificate ngay lập tức
- ✅ Users KHÔNG thấy "unidentified developer" warning
- ✅ Professional và secure hơn
- ✅ Ready cho Mac App Store distribution nếu cần

**Backup certificate (quan trọng!):**
1. Mở **Keychain Access**
2. Tìm certificate: `Apple Development: hungtien4944@icloud.com`
3. Right-click → **Export "Apple Development..."**
4. Save as: `AppleDevelopment-hungtien4944.p12`
5. Set password mạnh
6. Lưu file ở nơi an toàn (KHÔNG commit lên git - đã có trong .gitignore)

### Bước 5: Configure Code Signing in Xcode

1. Xcode → **PHTV target** → **"Signing & Capabilities"**
2. Trong section **"Signing"**:
   - **Team:** Chọn team của bạn (hungtien4944@icloud.com)
   - **Signing Certificate:** Chọn **"Apple Development"** (sẽ tự động chọn certificate hợp lệ)
3. Verify rằng **"Hardened Runtime"** capability đã enabled
4. Build Settings → Search "CODE_SIGN_IDENTITY"
   - Đảm bảo set to: `Apple Development`

### Bước 6: Generate EdDSA Keys for Sparkle Appcast Signing

**Tại sao cần:** Sparkle sử dụng EdDSA signatures để verify appcast.xml, ngăn chặn man-in-the-middle attacks.

**Các bước:**

```bash
# Download Sparkle binaries
cd /tmp
curl -LO https://github.com/sparkle-project/Sparkle/releases/latest/download/Sparkle-for-Swift-Package-Manager.zip
unzip Sparkle-for-Swift-Package-Manager.zip
cd Sparkle-for-Swift-Package-Manager

# Generate keys
./bin/generate_keys
```

**Output sẽ hiển thị:**
```
A key has been generated and saved in your macOS Keychain.
Your EdDSA signature public key is:
XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

**QUAN TRỌNG:**
1. **Copy public key** (dòng dài ký tự)
2. Mở `PHTV/Info.plist` trong Xcode
3. Tìm key `SUPublicEDKey`
4. Thay thế giá trị `WILL_BE_GENERATED_IN_PHASE_2` bằng public key vừa copy
5. Save file

**Backup private key:**
1. Mở **Keychain Access**
2. Search "Sparkle"
3. Tìm private key (icon chìa khóa)
4. Right-click → Export
5. Save ở nơi an toàn (KHÔNG commit lên git!)

### Bước 7: Setup GitHub Pages for Appcast

**Appcast files đã tạo ở `docs/` folder. Bạn cần enable GitHub Pages:**

1. Commit files mới:
```bash
git add docs/appcast.xml docs/appcast-beta.xml
git commit -m "feat: add Sparkle appcast feeds for auto-update"
git push origin main
```

2. Trên GitHub repo → **Settings** → **Pages**
3. **Source:** Deploy from a branch
4. **Branch:** `main`
5. **Folder:** `/docs`
6. Click **"Save"**
7. Đợi ~2 phút để GitHub deploy
8. Test: `curl https://phamhungtien.github.io/PHTV/appcast.xml`

### Bước 8: Test Build

1. Build project trong Xcode (**Cmd + B**)
2. Sửa các build errors nếu có
3. Run app (**Cmd + R**)
4. Check Console logs - tìm messages từ `[Sparkle]`

**Expected logs:**
```
[Sparkle] Initialized - Beta channel: OFF
[Sparkle] Using STABLE feed
[Sparkle] Update found: 1.2.4 (1.2.4)
```

---

## 📦 Release Workflow (Cho mỗi phiên bản mới)

Khi bạn muốn release version mới (ví dụ: 1.2.5):

### 1. Build DMG

1. Archive app trong Xcode: **Product** → **Archive**
2. Export as Mac app (không sign qua Xcode - ta sẽ sign manual)
3. Tạo DMG từ .app file (có thể dùng Disk Utility hoặc script)
4. Đặt tên: `PHTV-1.2.5.dmg`

### 2. Sign DMG & Generate Signature

```bash
# Chạy script signing
./scripts/sign_update.sh ~/Desktop/PHTV-1.2.5.dmg
```

**Script sẽ output:**
- Version number
- Build number
- File size
- EdDSA signature
- XML snippet để add vào appcast.xml

### 3. Update Appcast

1. Copy XML snippet từ script output
2. Mở `docs/appcast.xml`
3. Paste XML snippet ở **ĐẦU** file (sau `<channel>`, trước item cũ)
4. Convert `RELEASE_NOTES_1.2.5.md` sang HTML
5. Paste HTML vào `<description><![CDATA[...]]></description>`
6. Commit changes:
```bash
git add docs/appcast.xml
git commit -m "chore: update appcast for v1.2.5"
git push
```

### 4. Create GitHub Release

1. GitHub repo → **Releases** → **Draft a new release**
2. **Tag:** `v1.2.5`
3. **Title:** `PHTV 1.2.5`
4. **Description:** Copy từ release notes
5. **Attach DMG:** Upload `PHTV-1.2.5.dmg`
6. Click **"Publish release"**

### 5. Verify Auto-Update

1. Build và run version cũ hơn (ví dụ: 1.2.4)
2. App sẽ tự động check updates
3. Banner sẽ hiển thị "Bản cập nhật mới có sẵn"
4. Click "Cập nhật" → Sparkle sẽ download và install

---

## 🎯 Features Đã Implement

✅ **Backend:**
- Sparkle 2 framework integration
- SparkleManager singleton với delegates
- Notification-based communication với SwiftUI
- Beta channel support

✅ **UI:**
- Custom update banner (thay vì Sparkle default dialog)
- Release notes viewer với WKWebView
- Update frequency settings (never/daily/weekly/monthly)
- Beta channel toggle
- Manual update check button

✅ **Configuration:**
- Info.plist với Sparkle keys
- UserDefaults persistence cho settings
- Appcast feeds (stable & beta)

✅ **Security:**
- Self-signed certificate support
- EdDSA signature verification
- .gitignore cho sensitive files

---

## ⚠️ Lưu Ý Quan Trọng

### Security

1. **NEVER commit certificates/keys:**
   - `*.p12` files
   - `*-private.key` files
   - Đã add vào `.gitignore` rồi

2. **Backup private keys:**
   - EdDSA private key (trong Keychain)
   - Code signing certificate
   - Mất keys = không thể release updates nữa!

### User Impact

✅ **Với Apple Developer certificate:**
- **First Install:** ✅ KHÔNG có warning! macOS tin tưởng ngay lập tức
- **Updates:** Hoạt động mượt mà và tự động
- **Auto-download:** App tự download updates trong background
- **User consent:** Hỏi user trước khi install (không tự động restart)
- **Professional:** App hiển thị "Verified by Apple" trong System Settings

### Testing

- Test với test appcast trước khi release production
- Tạo file `test-appcast.xml` với version 99.99.99
- Temporary change `SUFeedURL` trong Info.plist
- **NHỚ revert về production URL!**

---

## 🆘 Troubleshooting

### "Sparkle not found" build error
→ Chưa add Sparkle package qua SPM (Bước 1)

### "SUPublicEDKey" invalid
→ Chưa replace public key trong Info.plist (Bước 6)

### Update check không hoạt động
→ Check Console logs, verify appcast URL accessible

### Code signing failed
→ Certificate chưa được tạo hoặc chọn sai (Bước 4-5)

### App crash khi check update
→ SparkleManager files chưa được add vào Xcode project (Bước 2)

---

## 📚 References

- [Sparkle Documentation](https://sparkle-project.org/documentation/)
- [Sparkle GitHub](https://github.com/sparkle-project/Sparkle)
- [Code Signing Guide](https://developer.apple.com/support/code-signing/)
- [GitHub Pages Docs](https://docs.github.com/en/pages)

---

**Good luck! 🚀**

Nếu có vấn đề gì, check implementation plan tại:
`~/.claude/plans/giggly-beaming-marshmallow.md`
