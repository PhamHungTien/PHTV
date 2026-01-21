# PHTV 1.6.5 Release Notes

## 🎉 Phiên bản 1.6.5 - Ổn định và Tin cậy

Chúng tôi rất vui mừng giới thiệu PHTV 1.6.5 với những cải tiến quan trọng về độ tin cậy và trải nghiệm người dùng.

---

## 🔧 Cải tiến quan trọng

### ✅ Giải quyết triệt để vấn đề mất quyền Accessibility

Đây là bản cập nhật quan trọng nhất cho người dùng gặp vấn đề **mất quyền Accessibility không phục hồi được**.

**Vấn đề trước đây:**
- Ứng dụng đột nhiên mất quyền Accessibility và không hoạt động
- Cấp lại quyền trong System Settings nhưng app vẫn không nhận
- Phải restart máy hoặc reinstall app mới hoạt động lại

**Giải pháp mới:**
- ✅ **Phát hiện real-time**: Lắng nghe thông báo từ hệ thống khi quyền thay đổi (< 200ms)
- ✅ **Tự động phục hồi**: App tự động nhận lại quyền ngay khi bạn cấp trong Settings
- ✅ **Force reset TCC cache**: Tự động invalidate cache ở tất cả các layer của macOS
- ✅ **Multiple retry mechanism**: Thử lại nhiều lần với delays thông minh
- ✅ **Smart relaunch detection**: Tự động đề xuất restart app nếu thực sự cần thiết

**Kết quả:**
- 🚀 Cấp/thu hồi/cấp lại quyền **bao nhiêu lần cũng được**
- 🚀 App sync đúng trạng thái trong **< 500ms**
- 🚀 **Không cần restart** máy hay reinstall app
- 🚀 Hoạt động ổn định hơn **rất nhiều** trên macOS 14, 15, 26

---

## 📚 Developer Experience

### Cải thiện GitHub Templates

**Bug Report Template:**
- Thêm hỗ trợ macOS 26.x (Developer Preview)
- Thêm Architecture selection (Apple Silicon vs Intel)
- Thêm Console Logs section để dễ debug
- Cải thiện severity & frequency descriptions
- Thêm troubleshooting checklist chi tiết hơn

**Pull Request Template:**
- Cấu trúc lại testing checklist với platforms, architecture, scenarios
- Thêm Before/After screenshots section
- Thêm Security & Performance review checklist
- Thêm Notes for Reviewers và Post-Merge Actions
- Comprehensive self-review checklist (9 items)

---

## 🔍 Chi tiết kỹ thuật

### Architecture Changes

1. **TCC Notification Listener**
   - Lắng nghe distributed notifications: `com.apple.accessibility.api`, `com.apple.TCC.access.changed`
   - Tự động invalidate cache khi hệ thống thông báo

2. **Aggressive Permission Reset**
   - Kill & restart `tccd` daemon để force reload TCC database
   - Touch TCC.db để trigger reload
   - Verify 5 lần với delays 50ms

3. **Enhanced Recovery Logic**
   - Retry init event tap 3 lần với progressive delays (100ms, 200ms)
   - Smart cache invalidation (clear cả timestamp và result)
   - Graceful fallback với relaunch suggestion

### API Changes

**PHTVManager.h - New Methods:**
```objc
// Aggressive reset cho edge cases
+(void)aggressivePermissionReset;

// TCC notification listener
+(void)startTCCNotificationListener;
+(void)stopTCCNotificationListener;
```

**AppDelegate.mm - Enhanced Handlers:**
- `performAccessibilityGrantedRestart` với retry mechanism
- `handleAccessibilityRevoked` với aggressive reset
- `handleTCCDatabaseChanged` notification handler (mới)

---

## 📊 Compatibility

### Hỗ trợ

- ✅ macOS 13.0 (Ventura) trở lên
- ✅ Apple Silicon (M1/M2/M3/M4)
- ✅ Intel Macs
- ✅ macOS 26.x Beta/Developer Preview

### Đã test trên

- macOS 15.x (Sequoia)
- macOS 14.x (Sonoma)
- Apple Silicon & Intel
- Dark mode & Light mode

---

## 🐛 Known Issues

Không có known issues nghiêm trọng trong bản release này.

Nếu bạn gặp vấn đề, vui lòng:
1. Check Console.app logs (filter: "phtv")
2. Report tại: https://github.com/PhamHungTien/PHTV/issues
3. Kèm theo logs và system info để chúng tôi có thể giúp bạn nhanh hơn

---

## 📝 Changelog

### Fixed
- **Triệt để vấn đề mất quyền Accessibility không phục hồi được**:
  - Thêm TCC notification listener - phát hiện thay đổi quyền ngay lập tức từ hệ thống
  - Implement aggressive permission reset - force reset TCC cache khi cấp lại quyền
  - Cải thiện khả năng recover với multiple retry attempts và progressive delays
  - Tự động kill và restart tccd daemon để invalidate TCC cache
  - Cache invalidation thông minh - clear cả result và timestamp
  - Xử lý edge case: user toggle quyền nhiều lần liên tiếp
  - Tự động đề xuất khởi động lại app nếu quyền không nhận sau 3 lần thử

### Changed
- Cải thiện bug report template với macOS 26.x, architecture, console logs section
- Cải thiện pull request template với comprehensive testing & review checklists

---

## 🙏 Credits

Cảm ơn tất cả người dùng đã báo cáo vấn đề về Accessibility permissions và kiên nhẫn chờ đợi fix này.

Đặc biệt cảm ơn những người đã cung cấp logs và thông tin chi tiết giúp chúng tôi reproduce và fix vấn đề.

---

## 📥 Download

**Cài đặt qua Homebrew (Recommended):**
```bash
brew tap phamhungtien/tap
brew install --cask phtv
```

**Hoặc tải trực tiếp:**
- [GitHub Releases](https://github.com/PhamHungTien/PHTV/releases/tag/v1.6.5)

**Build từ source:**
```bash
git clone https://github.com/PhamHungTien/PHTV.git
cd PHTV
xcodebuild -scheme PHTV -configuration Release
```

---

## 🔄 Hướng dẫn Update

### Từ phiên bản cũ:

1. **Qua Homebrew:**
   ```bash
   brew upgrade phtv
   ```

2. **Manual update:**
   - Tải bản mới từ GitHub Releases
   - Quit PHTV hiện tại
   - Thay thế app cũ bằng app mới
   - Launch PHTV 1.6.5

3. **Lưu ý:**
   - Settings của bạn sẽ được giữ nguyên
   - Macros sẽ được giữ nguyên
   - Không cần cấp lại quyền Accessibility (trừ khi macOS yêu cầu)

---

## 💬 Support & Feedback

- **Issues**: https://github.com/PhamHungTien/PHTV/issues
- **Discussions**: https://github.com/PhamHungTien/PHTV/discussions
- **Email**: phamhungtien.contact@gmail.com

Nếu bản update này giải quyết được vấn đề của bạn, hãy để lại ⭐ trên GitHub!

---

## 🔜 What's Next?

Chúng tôi đang làm việc trên:
- Cải thiện performance cho macOS 15+
- Enhanced macro system
- Better excluded apps management
- More input method options

Stay tuned! 🚀

---

**Release Date**: January 11, 2026
**Version**: 1.6.5 (Build 58)
**Minimum macOS**: 13.0

---

**© 2026 Phạm Hùng Tiến. All rights reserved.**
