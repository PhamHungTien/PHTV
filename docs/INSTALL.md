# Hướng Dẫn Cài Đặt PHTV

PHTV là bộ gõ tiếng Việt native cho macOS. Tài liệu này hướng dẫn cài đặt, cấp quyền, cấu hình ban đầu và xử lý các lỗi thường gặp.

[Trang chủ](../README.md) • [FAQ](FAQ.md) • [Báo lỗi](https://github.com/PhamHungTien/PHTV/issues)

---

## Mục Lục

- [Yêu cầu hệ thống](#yêu-cầu-hệ-thống)
- [Chuẩn bị trước khi cài đặt](#chuẩn-bị-trước-khi-cài-đặt)
- [Cài đặt](#cài-đặt)
- [Cấp quyền macOS](#cấp-quyền-macos)
- [Cấu hình ban đầu](#cấu-hình-ban-đầu)
- [Xử lý sự cố](#xử-lý-sự-cố)

---

## Yêu Cầu Hệ Thống

| Yêu cầu | Chi tiết |
| --- | --- |
| **macOS** | 14.0 Sonoma trở lên |
| **CPU** | Có DMG riêng cho Intel và Apple Silicon |
| **Dung lượng** | Khoảng 50 MB |
| **Quyền macOS** | Accessibility và Input Monitoring |
| **Build từ source** | Xcode mới nhất, Swift 6 |

Engine gõ tiếng Việt chạy offline trên máy và không gửi nội dung bạn gõ trong ứng dụng khác ra máy chủ. Sparkle và khu GIF/Sticker có kết nối mạng; xem [Quyền riêng tư](PRIVACY.md).

---

## Chuẩn Bị Trước Khi Cài Đặt

Để tránh macOS tự sửa chữ trước hoặc sau khi PHTV xử lý tiếng Việt, hãy tắt các tính năng tự động sửa lỗi của hệ thống:

1. Mở **System Settings > Keyboard > Edit Input Sources...**.
2. Tắt các mục sau:
   - **Correct spelling automatically**
   - **Capitalize words automatically**
   - **Show inline predictive text**
   - **Add period with double-space**
   - **Use smart quotes and dashes**

<div align="center">
<img src="images/setup/Input_Source_System_Settings.png" alt="Input Source settings" width="70%">
</div>

---

## Cài Đặt

### Homebrew

Khuyên dùng nếu bạn đã có Homebrew:

```bash
brew install --cask phamhungtien/tap/phtv
```

Cập nhật thủ công khi cần:

```bash
brew upgrade --cask phtv
```

Gỡ cài đặt:

```bash
brew uninstall --cask phtv
```

Gỡ sạch cả cấu hình:

```bash
brew uninstall --zap --cask phtv
```

### Tải DMG

1. Mở [phamhungtien.com/PHTV](https://phamhungtien.com/PHTV/) hoặc [GitHub Releases](https://github.com/PhamHungTien/PHTV/releases/latest).
2. Tải file `.dmg` mới nhất.
3. Mở DMG và kéo `PHTV.app` vào thư mục `Applications`.
4. Mở PHTV từ Launchpad, Spotlight hoặc `/Applications`.

### Build Từ Source

```bash
git clone https://github.com/PhamHungTien/PHTV.git
cd PHTV
xcodebuild -project App/PHTV.xcodeproj \
  -scheme PHTV \
  -configuration Debug \
  -destination 'platform=macOS' \
  build
```

Chạy test:

```bash
xcodebuild test -project App/PHTV.xcodeproj \
  -scheme PHTV \
  -configuration Debug \
  -destination 'platform=macOS'
```

Project hiện chỉ còn app target `PHTV` và test target `PHEngineTests`. Không còn target InputMethodKit riêng.

---

## Hướng Dẫn Có Ảnh

<div align="center">

**Bước 1: Tải về**
<img src="images/setup/step1-download.png" alt="Tải PHTV" width="70%">

**Bước 2: Mở ứng dụng**
<img src="images/setup/step2-open.png" alt="Mở PHTV" width="70%">

**Bước 3: PHTV hướng dẫn cấp quyền**
<img src="images/setup/step3-permissions.png" alt="Yêu cầu quyền macOS" width="70%">

**Bước 4: Bật PHTV trong System Settings**
<img src="images/setup/step4-grant-access.png" alt="Cấp quyền cho PHTV" width="70%">

**Bước 5: Hoàn tất**
<img src="images/setup/step5-complete.png" alt="Hoàn tất cài đặt" width="70%">

</div>

---

## Cấp Quyền macOS

PHTV cần đủ 2 quyền để bắt phím và gửi chữ đã xử lý vào ứng dụng bạn đang dùng.

| Quyền | Vị trí | Mục đích |
| --- | --- | --- |
| **Accessibility** | `System Settings > Privacy & Security > Accessibility` | Cho phép PHTV tương tác với ô nhập liệu và commit chữ. |
| **Input Monitoring** | `System Settings > Privacy & Security > Input Monitoring` | Cho phép PHTV nhận phím gõ từ macOS. |

### Luồng cấp quyền khuyên dùng

1. Mở PHTV.
2. Khi onboarding hiện trạng thái quyền, bấm nút mở quyền đang thiếu.
3. PHTV sẽ mở đúng mục trong System Settings.
4. Bật PHTV trong danh sách.
5. Nếu macOS yêu cầu mở lại ứng dụng, hãy cho phép.
6. PHTV sẽ tự kiểm tra lại và chuyển sang bước tiếp theo.

### Khi quyền bị kẹt

Một số phiên bản macOS có thể giữ lại entry TCC cũ sau khi app được cập nhật hoặc ký lại. Khi bạn bấm mở quyền đang thiếu, PHTV sẽ làm mới riêng entry TCC của quyền đó trước khi mở System Settings:

- `Accessibility` cho quyền Trợ năng.
- `ListenEvent` cho quyền Giám sát đầu vào.

Nếu vẫn chưa hoạt động sau khi bật lại cả hai quyền, hãy thoát hẳn PHTV và mở lại một lần để macOS áp dụng trạng thái TCC mới.

---

## Cấu Hình Ban Đầu

Sau khi cấp quyền, click icon **Vi/En** trên menu bar để mở menu nhanh hoặc Settings.

| Mục | Gợi ý |
| --- | --- |
| **Ngôn ngữ** | Chọn **Vi** để bật gõ tiếng Việt. |
| **Bộ gõ** | Chọn Telex, VNI hoặc Simple Telex trong Settings. |
| **Phím chuyển Việt/Anh** | Mặc định là **Control + Shift**, có thể đổi trong Settings. |
| **Bảng mã** | Dùng Unicode cho hầu hết ứng dụng hiện đại. |
| **Gõ tắt** | Thêm macro cá nhân trong tab Gõ tắt. |
| **PHTV Picker** | Dùng hotkey trong Settings để mở Emoji/GIF/Clipboard. |

---

## Xử Lý Sự Cố

### PHTV không gõ được tiếng Việt

Kiểm tra theo thứ tự:

1. Menu bar đang ở trạng thái **Vi**, không phải **En**.
2. `System Settings > Privacy & Security > Accessibility` đã bật PHTV.
3. `System Settings > Privacy & Security > Input Monitoring` đã bật PHTV.
4. Tắt các tính năng tự sửa chữ của macOS trong Keyboard settings.
5. Thử gõ trong Notes hoặc TextEdit để loại trừ lỗi riêng của ứng dụng đang dùng.
6. Thoát hẳn PHTV và mở lại nếu bạn vừa cấp quyền.

Nếu PHTV vẫn báo thiếu quyền dù đã bật, mở Settings của PHTV hoặc onboarding và bấm lại nút mở quyền. Ứng dụng sẽ làm mới entry TCC của quyền đang thiếu rồi mở đúng mục System Settings.

### macOS báo "PHTV is damaged" hoặc "can't be opened"

Nếu bạn tải app ngoài App Store và macOS giữ quarantine flag, thử:

```bash
xattr -cr /Applications/PHTV.app
```

Sau đó right-click `PHTV.app` và chọn **Open**.

### Phím tắt không hoạt động

1. Kiểm tra app hiện tại có chiếm phím tắt đó không.
2. Mở **System Settings > Keyboard > Keyboard Shortcuts** để tìm xung đột.
3. Đổi phím trong **PHTV > Settings > Phím tắt**.
4. Đảm bảo cả Accessibility và Input Monitoring đều đã bật.

### Gõ bị lặp hoặc xuất hiện ký tự lạ

Nguyên nhân thường gặp là macOS hoặc ứng dụng đích tự sửa chữ cùng lúc với PHTV. Hãy tắt các mục tự sửa trong [Chuẩn bị trước khi cài đặt](#chuẩn-bị-trước-khi-cài-đặt), sau đó thử lại trong Notes/TextEdit.

### Reset cấu hình

Thoát PHTV rồi chạy:

```bash
rm -f ~/Library/Preferences/com.phamhungtien.phtv.plist
rm -f ~/Library/Preferences/com.phamhungtien.phtv.debug.plist
killall cfprefsd
```

Mở lại PHTV và cấu hình từ đầu.

### Báo lỗi

Khi tạo issue, vui lòng gửi:

- Phiên bản PHTV.
- Phiên bản macOS và chip máy.
- Trạng thái Accessibility/Input Monitoring trong màn hình Báo lỗi của PHTV.
- Ứng dụng đang gõ khi lỗi xảy ra.
- Các bước tái hiện lỗi.

[Tạo issue trên GitHub](https://github.com/PhamHungTien/PHTV/issues/new)

---

[Trang chủ](../README.md) • [FAQ](FAQ.md)
