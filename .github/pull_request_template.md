<!--
Cảm ơn bạn đã gửi pull request! Vui lòng điền vào biểu mẫu này.
Thank you for submitting a pull request! Please fill in this form.
-->

## 📝 Mô tả (Description)

<!-- Mô tả ngắn gọn về PR của bạn -->

[Mô tả thay đổi của bạn]

## 🔗 Liên kết đến Issue (Linked Issue)

<!-- Đóng lỗi nào? Ví dụ: Closes #123 -->

Closes #[issue number]

## ✅ Loại thay đổi (Type of Change)

- [ ] 🐛 Bug fix - sửa lỗi không ảnh hưởng đến API/existing functionality
- [ ] ✨ New feature - thêm tính năng mới
- [ ] 💥 Breaking change - thay đổi có ảnh hưởng đến backward compatibility
- [ ] 🔧 Performance improvement - cải thiện hiệu suất
- [ ] ♻️ Refactoring - tái cấu trúc code không thay đổi functionality
- [ ] 📚 Documentation - cập nhật tài liệu, comments, README
- [ ] 🎨 Style/UI - thay đổi format, styling, hoặc UI/UX
- [ ] 🧪 Tests - thêm hoặc cập nhật tests
- [ ] 🏗️ Build/CI - thay đổi build system hoặc CI/CD

## 🧪 Testing

<!-- Bạn đã test những gì? Check tất cả các mục áp dụng -->

### Platforms Tested
- [ ] macOS 26.x (macOS 15.x Beta/Developer Preview)
- [ ] macOS 15.x (Sequoia)
- [ ] macOS 14.x (Sonoma)
- [ ] macOS 13.x (Ventura)

### Architecture Tested
- [ ] Apple Silicon (M1/M2/M3/M4)
- [ ] Intel

### Test Scenarios
- [ ] Tested locally in Debug mode
- [ ] Tested in Release mode
- [ ] Tested dark mode & light mode
- [ ] Tested with excluded apps feature
- [ ] Tested with multiple input methods (Telex, VNI)
- [ ] Tested Accessibility permission flow
- [ ] Tested with Safe Mode (if hardware-related)
- [ ] Tested keyboard shortcuts & hotkeys
- [ ] Tested macro functionality (if applicable)

### Test Results
**Cách tái hiện test:**

```
1. Bước 1
2. Bước 2
3. Expected result: ...
4. Actual result: ...
```

**Console logs (nếu cần):**
<details>
<summary>Click to expand logs</summary>

```
[Paste relevant logs here]
```

</details>

## 📋 Checklist

### Code Quality
- [ ] Code builds without errors or warnings
- [ ] Code follows project style guidelines (Swift/Objective-C conventions)
- [ ] No new compiler warnings introduced
- [ ] No debugging code left (NSLog spam, test code, commented code)
- [ ] No unnecessary dependencies added
- [ ] Memory leaks checked (Instruments, static analysis)
- [ ] Performance impact considered and acceptable

### Documentation
- [ ] Updated [CHANGELOG.md](../CHANGELOG.md) with changes
- [ ] Updated code comments for complex logic
- [ ] Updated README.md if user-facing changes
- [ ] Updated inline documentation for public APIs

### Testing
- [ ] Tested all changed functionality thoroughly
- [ ] Tested edge cases and error conditions
- [ ] Regression testing - existing features still work
- [ ] Tested on multiple macOS versions (if applicable)
- [ ] Verified Accessibility permissions flow (if applicable)

## 📸 Screenshots/Videos (nếu có liên quan)

<!-- Thêm screenshot/video nếu có thay đổi UI/UX hoặc behavior nhìn thấy được -->

<details>
<summary>Before/After Screenshots</summary>

**Before:**
[Add screenshot]

**After:**
[Add screenshot]

</details>

## 🎯 Notes for Reviewers

<!-- Điểm nào cần reviewer chú ý đặc biệt? -->
<!-- Có trade-offs nào cần discuss? -->
<!-- Có alternative approaches đã consider không? -->

**Key areas to review:**
- [ ] [Area 1]
- [ ] [Area 2]

**Known limitations/trade-offs:**
- [Limitation 1]
- [Limitation 2]

---

## 💭 Self-Review Checklist

<!-- Hãy tự review PR của bạn trước khi gửi - saves everyone time! -->

- [ ] Reviewed my own code line-by-line for obvious issues
- [ ] Removed all debug code (print statements, test code, TODOs)
- [ ] Verified no sensitive information committed (API keys, passwords, tokens)
- [ ] Checked for potential security issues (XSS, SQL injection, command injection)
- [ ] Ensured backward compatibility (or marked as breaking change)
- [ ] Added comments for complex/non-obvious logic
- [ ] Verified error handling is appropriate
- [ ] Checked for potential race conditions or concurrency issues
- [ ] Confirmed accessibility (VoiceOver, keyboard navigation) still works

---

## 🔄 Post-Merge Actions (if applicable)

<!-- Có actions nào cần làm sau khi merge? -->

- [ ] Update release notes
- [ ] Notify users about breaking changes
- [ ] Update documentation website
- [ ] Create follow-up issues for future improvements

---

**Cảm ơn vì đóng góp vào PHTV!** 🎉

<!-- Maintainers sẽ review và respond sớm nhất có thể -->
