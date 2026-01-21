# PHTV 1.6.1

Phiên bản 1.6.1 là bản cập nhật quan trọng tập trung vào **sửa lỗi gõ tiếng Việt trên trình duyệt** và **cải tiến công cụ báo cáo lỗi**.

## 🔥 Những thay đổi quan trọng

### 🌐 Sửa lỗi gõ tiếng Việt trên trình duyệt (Critical Fix)

**Vấn đề:** Khi gõ nhanh trên thanh địa chỉ browser (Safari, Chrome, Firefox, v.v.), các ký tự bị duplicate. Ví dụ: gõ "đ" nhưng ra "dđ", gõ "được" ra "dđược".

**Nguyên nhân:**
- Trước đây, delays và step-by-step sending chỉ được áp dụng khi chức năng "Auto English" hoạt động
- Khi gõ tiếng Việt bình thường, backspace và characters được gửi KHÔNG CÓ DELAY → race condition với browser autocomplete

**Giải pháp:**
- ✅ Áp dụng **delays cho TẤT CẢ thao tác** trên browser (không phân biệt Auto English bật/tắt)
- ✅ Backspace delay: **4ms** mỗi phím
- ✅ Character delay: **3.5ms** giữa các ký tự
- ✅ Settle delay: **10ms** sau tất cả backspaces
- ✅ Force **step-by-step sending** thay vì batch Unicode posting

**Kết quả:**
- 🎯 Gõ tiếng Việt trên browser **ổn định 100%** với Auto English BẬT hoặc TẮT
- 🎯 Hỗ trợ **14 browsers**: Safari, Chrome, Firefox, Edge, Arc, Brave, Vivaldi, Opera, Chromium, Cốc Cốc, DuckDuckGo, Orion, Zen, Dia
- 🎯 Hoạt động tốt ở address bar, search box, và text fields trong website

### ⚙️ Chức năng Auto English giờ BẬT mặc định

**Trước:** Auto English (tự động nhận diện từ tiếng Anh) TẮT khi cài đặt lần đầu

**Sau:** Auto English **BẬT** mặc định cho người dùng mới

**Lợi ích:**
- ✅ Người dùng mới có trải nghiệm tốt hơn ngay từ đầu
- ✅ Tự động khôi phục từ tiếng Anh: "tẻminal" → "terminal", "sẻarch" → "search"
- ✅ Giảm phiền nhiễu khi gõ các từ technical hoặc tên riêng

### 📊 Cải tiến công cụ báo cáo lỗi

**Email & Copy to Clipboard giờ ĐẦY ĐỦ NHẤT:**

| Tính năng | Email/Copy | GitHub Issues |
|-----------|-----------|---------------|
| Log entries | **200** ⬆️ | 20 |
| Settings | **17** ⬆️ | 7 |
| Browser info | **✅ Full** | ❌ |
| File logs | **✅ Full** | ❌ |

**Cách hoạt động mới:**
1. Click "📧 Gửi qua Email"
2. ✅ Báo cáo đầy đủ **tự động copy vào clipboard**
3. ✅ Mở email với hướng dẫn: *"Vui lòng dán (Cmd+V) báo cáo đầy đủ vào đây"*
4. User paste (Cmd+V) → Developer nhận báo cáo chi tiết

**Thông tin mới trong report:**
- ✅ **17 settings** (thêm: Quick Start/End Consonant, Allow Z/F/W/J, Macro in English mode, Vietnamese menubar icon, v.v.)
- ✅ Section **"🌐 Browser & App Detection"**:
  - List 14 browsers được hỗ trợ
  - Chi tiết delays (4ms, 3.5ms, 10ms)
  - Auto English status với HID tap
  - Current front app info
  - Terminal/IDE detection
  - Spotlight-like apps detection

**Lợi ích:**
- 🎯 Developer có **đủ thông tin để debug** ngay lập tức
- 🎯 Không cần hỏi lại user về settings/environment
- 🎯 Dễ dàng identify browser-related issues
- 🎯 Tránh giới hạn URL length của `mailto:` protocol

## 🛠 Các sửa lỗi kỹ thuật

### Swift Concurrency
- **Fix:** Main actor-isolated warnings trong `setupDeactivationObserver()`
- **Giải pháp:** Sử dụng `MainActor.assumeIsolated` để truy cập `NSApp.windows` an toàn

### Property references
- **Fix:** Build errors do tham chiếu properties không tồn tại
- **Sửa:** `grayIcon` → `useVietnameseMenubarIcon`
- **Xóa:** `fixBrowserRecommend`, `fixTextReplacement` (các fix đã hardcode trong engine)

## 🐛 Các lỗi đã sửa

| Mức độ | Vấn đề | Giải pháp |
|--------|--------|----------|
| 🔴 **Critical** | Duplicate characters trên browser (đ→dđ) | Áp dụng delays cho TẤT CẢ browser operations |
| 🟡 **Medium** | Auto English TẮT mặc định | BẬT mặc định cho user mới |
| 🟡 **Medium** | Bug report thiếu thông tin | Tăng logs 100→200, thêm browser detection info |
| 🟢 **Low** | Swift Concurrency warnings | Sử dụng MainActor.assumeIsolated |
| 🟢 **Low** | Build errors | Sửa property references |

## 📈 So sánh với 1.6.0

### Độ ổn định gõ tiếng Việt trên browser

| Tình huống | v1.6.0 | v1.6.1 |
|-----------|--------|--------|
| Gõ tiếng Việt (Auto English TẮT) | ⚠️ Có thể duplicate | ✅ Ổn định 100% |
| Gõ tiếng Việt (Auto English BẬT) | ⚠️ Có thể duplicate | ✅ Ổn định 100% |
| Auto English restore | ✅ Ổn định | ✅ Ổn định hơn (HID tap) |
| Gõ nhanh trên address bar | ⚠️ Race condition | ✅ Đã fix với delays |

### Bug report quality

| Metric | v1.6.0 | v1.6.1 |
|--------|--------|--------|
| Log entries (Email/Copy) | 100 | 200 ⬆️ |
| Settings trong report | 9 | 17 ⬆️ |
| Browser detection info | ❌ | ✅ Full section |
| URL length issue | ⚠️ Bị giới hạn | ✅ Copy to clipboard |

## 📦 Cài đặt & Cập nhật

### Homebrew (khuyên dùng)
```bash
brew upgrade --cask phtv
```

### Tự động cập nhật
Mở PHTV → Settings → Hệ thống → Kiểm tra cập nhật

### Thủ công
Tải file `.dmg` từ [GitHub Releases](https://github.com/PhamHungTien/PHTV/releases/latest)

## 🎯 Người dùng nên cập nhật nếu

- ✅ Bạn thường xuyên gõ tiếng Việt trên thanh địa chỉ browser (Safari, Chrome, Firefox, v.v.)
- ✅ Bạn gặp lỗi duplicate characters (đ→dđ, được→dđược)
- ✅ Bạn muốn Auto English bật mặc định
- ✅ Bạn cần gửi bug report chi tiết hơn

## 🙏 Cảm ơn

Cảm ơn người dùng đã báo cáo lỗi duplicate characters trên browser. Đây là fix quan trọng giúp PHTV hoạt động ổn định hơn trên môi trường web.

---

**Full Changelog**: [v1.6.0...v1.6.1](https://github.com/PhamHungTien/PHTV/compare/v1.6.0...v1.6.1)

**Commits:**
- `9ec8b0c` - fix: browser input stability and enable Auto English by default
- `08ef22c` - feat: enhance bug report with comprehensive information
- `902b45d` - fix: correct property names in BugReportView
