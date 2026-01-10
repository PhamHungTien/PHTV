# Khắc phục lỗi "Khởi động cùng hệ thống" tự tắt sau restart

## Vấn đề

Khi bật "Khởi động cùng hệ thống" (Launch at Login) trong Settings:
- ✅ Toggle bật thành công
- ❌ Sau khi restart macOS, toggle tự động TẮT
- ❌ Phải bật lại thủ công mỗi lần khởi động lại máy

## Nguyên nhân

### 1. **SMAppService từ chối app không được sign đúng cách**

macOS 13+ sử dụng `SMAppService` API để quản lý Login Items. API này **YÊU CẦU**:
- App phải được ký với **Developer ID Application certificate** (KHÔNG phải Development certificate)
- App phải được **notarized** bởi Apple
- **KHÔNG hỗ trợ** ad-hoc signing (ký với `-` trong development)

**Nếu app không đáp ứng các yêu cầu:**
- `SMAppService.registerAndReturnError()` **âm thầm fail**
- Toggle UI vẫn hiện là ON (vì UserDefaults được lưu)
- macOS **KHÔNG** thực sự đăng ký app vào login items
- Khi restart → app không tự khởi động
- Khi mở lại app → `SMAppService.status` trả về `.notRegistered`
- SwiftUI Observer phát hiện mismatch → tự động TẮT toggle

### 2. **Error Code từ SMAppService**

Khi registration fail, macOS trả về error codes:

| Error Code | Constant | Nguyên nhân |
|-----------|----------|-------------|
| `1` | `kSMAppServiceErrorAlreadyRegistered` | App đã đăng ký (stale state) |
| `2` | `kSMAppServiceErrorInvalidSignature` | **Code signature không hợp lệ** |
| `3` | `kSMAppServiceErrorInvalidPlist` | Info.plist không đúng cấu hình |

**Phổ biến nhất:** Error code `2` - Invalid Signature

### 3. **Ad-hoc signing trong development**

Khi build từ Xcode với "Sign to Run Locally" hoặc ad-hoc signature:
```bash
codesign --verify --deep --strict PHTV.app
# Output: PHTV.app: invalid signature (code or signature have been modified)
```

SMAppService **từ chối** app này → Login Item không hoạt động.

## Giải pháp đã thực hiện

### ✅ 1. Enhanced Error Logging

File: [PHTV/Application/AppDelegate.mm](../PHTV/Application/AppDelegate.mm#L1889-L2015)

**Thay đổi:**
- ✅ Log chi tiết error code, domain, userInfo
- ✅ Verify code signature trước khi register
- ✅ Phát hiện và giải thích các error codes phổ biến
- ✅ Retry logic cho stale state (error code 1)
- ✅ Hướng dẫn giải pháp cho từng loại lỗi

**Output mới khi toggle "Khởi động cùng hệ thống":**

```
[LoginItem] Current SMAppService status: 0
✅ [LoginItem] Code signature verified
✅ [LoginItem] Registered with SMAppService
```

**Hoặc nếu fail:**

```
[LoginItem] Current SMAppService status: 0
⚠️ [LoginItem] Code signature verification failed: ... invalid signature...
⚠️ [LoginItem] SMAppService may reject unsigned/ad-hoc signed apps
❌ [LoginItem] Failed to register with SMAppService
   Error: The operation couldn't be completed. (SMAppServiceErrorDomain error 2.)
   Error Domain: SMAppServiceErrorDomain
   Error Code: 2
   → Invalid code signature. App must be properly signed with Developer ID
   → Ad-hoc signed apps (for development) are NOT supported by SMAppService
   → Solution: Sign with Apple Developer ID certificate or use notarization
```

### ✅ 2. Code Signature Verification

Trước khi attempt registration, code tự động verify:

```objective-c
// Check if app is properly code signed
NSTask *verifyTask = [[NSTask alloc] init];
verifyTask.launchPath = @"/usr/bin/codesign";
verifyTask.arguments = @[@"--verify", @"--deep", @"--strict", bundlePath];
```

Nếu verification fail → log warning để user biết nguyên nhân.

### ✅ 3. Retry Logic cho Stale State

Nếu SMAppService trả về "Already Registered" (error code 1):
- Tự động unregister
- Chờ 0.5 giây
- Retry registration

```objective-c
case 1: // kSMAppServiceErrorAlreadyRegistered
    NSLog(@"   → App already registered (stale state). Trying to unregister first...");
    [appService unregisterAndReturnError:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSError *retryError = nil;
        if ([appService registerAndReturnError:&retryError]) {
            NSLog(@"✅ [LoginItem] Registration succeeded on retry");
        }
    });
    break;
```

### ✅ 4. Detailed Error Messages

Với mỗi error code, log hướng dẫn cụ thể:

**Error Code 2 (Invalid Signature):**
```
→ Invalid code signature. App must be properly signed with Developer ID
→ Ad-hoc signed apps (for development) are NOT supported by SMAppService
→ Solution: Sign with Apple Developer ID certificate or use notarization
```

## Cách kiểm tra và fix

### Bước 1: Kiểm tra Code Signature hiện tại

```bash
# Kiểm tra app đang chạy
codesign -dv --verbose=4 /Applications/PHTV.app

# Output mong đợi (GOOD):
Identifier=com.phamhungtien.phtv
Authority=Developer ID Application: Phạm Hùng Tiến (F9XPW22T8M)
Authority=Developer ID Certification Authority
Authority=Apple Root CA
Signed Time=...
```

**Nếu thấy:**
```
Signature=adhoc
# HOẶC
Authority=Apple Development: ...
```
→ **App KHÔNG được sign đúng cách** → SMAppService sẽ reject

### Bước 2: Check SMAppService Status

Mở Console.app và filter "PHTV", sau đó toggle "Khởi động cùng hệ thống":

**GOOD:**
```
[LoginItem] Current SMAppService status: 0
✅ [LoginItem] Code signature verified
✅ [LoginItem] Registered with SMAppService
```

**BAD:**
```
[LoginItem] Current SMAppService status: 0
❌ [LoginItem] Failed to register with SMAppService
   Error Domain: SMAppServiceErrorDomain
   Error Code: 2
```

### Bước 3: Fix với Proper Code Signing

#### **Option A: Development (Temporary Fix)**

Để test nhanh trong development:

```bash
# Remove quarantine
xattr -cr /Applications/PHTV.app

# Ad-hoc sign (CHỈ dùng cho dev, KHÔNG work với SMAppService)
codesign --force --deep --sign - /Applications/PHTV.app
```

**Lưu ý:** Ad-hoc signing **KHÔNG** làm cho SMAppService hoạt động. Chỉ để app chạy được mà thôi.

#### **Option B: Production (Proper Solution)**

**1. Sign với Developer ID:**

```bash
# Sử dụng script tự động
./scripts/codesign_and_notarize.sh /Applications/PHTV.app \
    "Developer ID Application: Phạm Hùng Tiến (F9XPW22T8M)"
```

**2. Hoặc manual:**

```bash
# Sign với Developer ID
codesign --force --sign "Developer ID Application: Phạm Hùng Tiến (F9XPW22T8M)" \
    --entitlements PHTV/PHTV.entitlements \
    --timestamp \
    --options runtime \
    --deep \
    /Applications/PHTV.app

# Verify
codesign --verify --deep --strict /Applications/PHTV.app
spctl --assess --type execute --verbose=4 /Applications/PHTV.app
```

**3. Notarize với Apple:**

Xem chi tiết tại [FIX_MACOS_MALWARE_WARNING.md](FIX_MACOS_MALWARE_WARNING.md)

### Bước 4: Test lại

1. Quit PHTV hoàn toàn
2. Mở lại PHTV đã signed đúng cách
3. Vào Settings > Hệ thống > Bật "Khởi động cùng hệ thống"
4. Check Console.app → phải thấy `✅ [LoginItem] Registered with SMAppService`
5. Restart macOS
6. PHTV phải tự động khởi động
7. Mở Settings → toggle vẫn phải là ON

## Giải pháp cho GitHub Actions

GitHub Actions workflow đã được cập nhật với notarization:

1. Build app với **Developer ID Application certificate**
2. **Notarize** với Apple
3. Staple notarization ticket
4. DMG release đã fully signed và notarized

**Setup cần thiết:**

Thêm GitHub Secrets:
- `APPLE_ID` = `hungtien4944@icloud.com`
- `APPLE_TEAM_ID` = `F9XPW22T8M`
- `APPLE_APP_PASSWORD` = App-specific password

Sau đó mọi release đều có proper code signing → SMAppService hoạt động!

## Workaround cho Development

Nếu đang develop và chưa có Developer ID certificate:

### Option 1: Skip Launch at Login trong Dev

Comment out code trong [AppDelegate.mm](../PHTV/Application/AppDelegate.mm):

```objective-c
-(void)setRunOnStartup:(BOOL)val {
    #if DEBUG
        NSLog(@"⚠️ [LoginItem] Skipping in DEBUG mode (requires proper code signing)");
        return;
    #endif
    // ... rest of code
}
```

### Option 2: Sử dụng launchd (Manual)

Tạo file `~/Library/LaunchAgents/com.phamhungtien.phtv.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.phamhungtien.phtv</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/PHTV.app/Contents/MacOS/PHTV</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
```

Load:
```bash
launchctl load ~/Library/LaunchAgents/com.phamhungtien.phtv.plist
```

**Lưu ý:** Workaround này **bypass** SMAppService nhưng app vẫn sẽ auto-start.

## Kết luận

### ✅ Root Cause
SMAppService **YÊU CẦU** app được ký với Developer ID và notarize. Ad-hoc signing hoặc Development certificate **KHÔNG** được hỗ trợ.

### ✅ Solution
1. **Development:** Skip feature hoặc dùng launchd workaround
2. **Production:** Sign với Developer ID + Notarize với Apple
3. **CI/CD:** GitHub Actions đã setup notarization tự động

### ✅ Enhanced Logging
Code mới sẽ log chi tiết error khi SMAppService fail, giúp debug dễ dàng hơn.

---

**Next Steps:**
1. Setup Apple Developer ID certificate
2. Add GitHub Secrets cho notarization
3. Release qua GitHub Actions → app fully signed
4. "Khởi động cùng hệ thống" sẽ hoạt động bình thường!
