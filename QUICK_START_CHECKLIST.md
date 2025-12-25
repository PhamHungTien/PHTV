# ✅ PHTV Sparkle Auto-Update - Quick Start Checklist

## 🎯 Bạn cần làm gì tiếp theo?

✅ **Code đã xong 100%!** Chỉ cần setup trong Xcode và generate keys.

---

## 📋 Checklist (5-10 phút)

### ☐ 1. Add Sparkle Package (2 phút)

**Trong Xcode:**
1. Mở `PHTV.xcodeproj`
2. Project → PHTV target → **Package Dependencies** tab
3. Click **"+"** button
4. URL: `https://github.com/sparkle-project/Sparkle`
5. Version: **2.6.0** or later (Up to Next Major)
6. Add to target: **PHTV**

---

### ☐ 2. Add SparkleManager Files (1 phút)

**Trong Xcode:**
1. Right-click folder `PHTV/Application` (trong Project Navigator)
2. **"Add Files to PHTV..."**
3. Select 2 files:
   - `PHTV/Application/SparkleManager.h`
   - `PHTV/Application/SparkleManager.mm`
4. ✅ Check **"Copy items if needed"**
5. ✅ Check **"Add to targets: PHTV"**
6. Click **"Add"**

---

### ☐ 3. Enable Hardened Runtime (30 giây)

**Trong Xcode:**
1. PHTV target → **Signing & Capabilities** tab
2. Click **"+ Capability"**
3. Choose **"Hardened Runtime"**
4. Done!

---

### ☐ 4. Configure Code Signing (1 phút)

**Trong Xcode:**
1. PHTV target → **Signing & Capabilities** tab
2. **Team:** Select `hungtien4944@icloud.com (Personal Team)`
3. **Signing Certificate:** Select **"Apple Development"**
   - Should show: `Apple Development: hungtien4944@icloud.com (QA6JWU37RW)`
4. Verify **"Hardened Runtime"** is enabled

✅ **Certificate expires:** 9 December 2026 (still valid for 2 years!)

---

### ☐ 5. Generate EdDSA Keys (2 phút)

**Trong Terminal:**

```bash
# Download Sparkle tools
cd /tmp
curl -LO https://github.com/sparkle-project/Sparkle/releases/latest/download/Sparkle-for-Swift-Package-Manager.zip
unzip Sparkle-for-Swift-Package-Manager.zip
cd Sparkle-for-Swift-Package-Manager

# Generate keys
./bin/generate_keys
```

**Output sẽ hiển thị public key:**
```
Your EdDSA signature public key is:
XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

**QUAN TRỌNG:**
1. Copy public key (dòng dài ký tự)
2. Mở `PHTV/Info.plist` trong Xcode
3. Tìm key `SUPublicEDKey`
4. Replace `WILL_BE_GENERATED_IN_PHASE_2` với public key vừa copy
5. **Cmd+S** để save

---

### ☐ 6. Test Build (1 phút)

**Trong Xcode:**
1. **Cmd+B** để build
2. Sửa errors nếu có
3. **Cmd+R** để run
4. Mở Console (Cmd+Shift+Y)
5. Tìm messages: `[Sparkle]`

**Expected logs:**
```
[Sparkle] Initialized - Beta channel: OFF
[Sparkle] Using STABLE feed
```

---

### ☐ 7. Setup GitHub Pages (2 phút)

**Commit và push:**
```bash
cd /Users/phamhungtien/Documents/PHTV
git add docs/appcast.xml docs/appcast-beta.xml scripts/
git commit -m "feat: add Sparkle auto-update support"
git push origin main
```

**Enable GitHub Pages:**
1. GitHub repo → **Settings** → **Pages**
2. Source: **Deploy from a branch**
3. Branch: `main`, Folder: `/docs`
4. Click **"Save"**
5. Wait 2 minutes

**Verify:**
```bash
curl https://phamhungtien.github.io/PHTV/appcast.xml
```

Should return XML content.

---

### ☐ 8. Backup Keys (1 phút)

**Critical - Làm ngay!**

**EdDSA Private Key:**
1. Keychain Access → Search "Sparkle"
2. Right-click private key → Export
3. Save secure location (NOT in git!)

**Apple Developer Certificate:**
1. Keychain Access → Search "Apple Development"
2. Right-click certificate → Export
3. Save as: `AppleDevelopment-hungtien4944.p12`
4. Set strong password
5. Store safely

⚠️ **Mất keys = không thể release updates!**

---

## 🎉 Done!

Sau khi hoàn thành 8 bước trên, auto-update đã sẵn sàng!

### Testing Auto-Update:

1. Open Settings (Cmd+,)
2. Go to **"Hệ thống"** tab
3. Scroll to **"Cập nhật"** section
4. Click **"Kiểm tra cập nhật"**
5. Should show: "Phiên bản hiện tại (1.2.4) là mới nhất"

### Features Available:

✅ Update frequency: Never/Daily/Weekly/Monthly
✅ Beta channel toggle
✅ Manual check button
✅ Custom update banner
✅ Release notes viewer
✅ Auto-download in background

---

## 📚 Full Documentation

Xem chi tiết đầy đủ tại: `SPARKLE_SETUP_GUIDE.md`

---

## 🆘 Need Help?

### Common Issues:

**Build error "Sparkle not found"**
→ Step 1 not done: Add Sparkle package via SPM

**Build error "SparkleManager.h not found"**
→ Step 2 not done: Add SparkleManager files to Xcode project

**"SUPublicEDKey invalid" warning**
→ Step 5 not done: Replace placeholder in Info.plist

**Code signing failed**
→ Step 4 not done: Select Apple Development certificate

---

**Ước tính tổng thời gian: 10-15 phút** ⏱️

Good luck! 🚀
