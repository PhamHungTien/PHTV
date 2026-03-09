# Changelog

All notable changes to PHTV will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.5.9] - 2026-02-23

### Added
- **Lịch sử Clipboard** — Tính năng mới lưu lại nội dung đã sao chép (văn bản, ảnh, đường dẫn file) và dán nhanh bằng phím tắt
  - Phím tắt mặc định: **⌃V** (Control + V), tuỳ chỉnh trong Cài đặt → Phím tắt
  - Tuỳ chỉnh số mục lưu tối đa (10–100, mặc định 30)
  - Tìm kiếm trong lịch sử clipboard
  - Giao diện Liquid Glass đồng bộ với PHTV Picker (macOS Tahoe)
  - Mặc định **tắt** — bật trong Cài đặt → Phím tắt → Lịch sử Clipboard
  - Toggle nhanh từ menu thanh trạng thái
- **Tuỳ chọn khôi phục phím khi gõ sai** — Đưa chức năng khôi phục phím khi gõ sai chính tả ra cài đặt để người dùng bật/tắt
  - Truy cập tại Cài đặt → Bộ gõ → Khôi phục phím khi gõ sai
  - Toggle nhanh từ menu thanh trạng thái → Tính năng → Khôi phục

## [2.1.4] - 2026-01-26

### Fixed
- **Terminal Commands Not Working (#121)**: Sửa lỗi các lệnh như `clear`, `grep`, `printf` không hoạt động đúng trong Terminal khi bật chế độ tiếng Việt
  - Thêm logic nhận diện sớm các tổ hợp phụ âm không có trong tiếng Việt (bl, br, cl, cr, dr, fl, fr, gl, gr, pl, pr, sc, sk, sl, sm, sn, sp, st, sw, tw, wr)

### Changed
- **Onboarding UI**: Thiết kế lại các thẻ công tắc trong bước "Tính năng cơ bản" với chiều cao đồng nhất
- **Settings Reorganization**: Gộp phần "Cơ bản" vào "Tối ưu gõ" để giao diện gọn gàng hơn
- **New Onboarding Feature**: Thêm công tắc "Giữ nguyên từ tiếng Anh" vào Onboarding

### Removed
- **Spell Check UI**: Loại bỏ giao diện (tính năng luôn bật)
- **Z/F/W/J Consonants UI**: Loại bỏ giao diện (tính năng luôn bật)
- **Restore on Invalid Word**: Loại bỏ hoàn toàn tính năng này
- **Search Items**: Cập nhật danh sách tìm kiếm, loại bỏ các mục đã xóa
- **Bug Report**: Loại bỏ thông tin các tính năng đã xóa khỏi báo cáo debug

## [2.1.1] - 2026-01-25

### Changed
- **Giao diện Glass tinh tế**: Tinh chỉnh hiệu ứng glass và hình nền trong phần Cài đặt.
- **Tối ưu tương thích**: Loại bỏ xử lý đặc biệt cho Raycast, cải thiện tính ổn định với launcher bên thứ ba.

## [2.1.0] - 2026-01-25

### Added
- **Onboarding System Settings Step**: Thêm bước hướng dẫn cài đặt hệ thống trong quy trình Onboarding
  - Hướng dẫn trực quan để tắt các tính năng tự động sửa lỗi của macOS
  - Thêm hình ảnh minh họa cài đặt Input Source trong System Settings
- **Image Zoom in Onboarding**: Click vào ảnh để xem phóng to với icon kính lúp
- **Help Button in Settings**: Thêm nút '?' vào thanh công cụ Settings để xem lại Onboarding

### Changed
- Cập nhật README.md và INSTALL.md với cảnh báo về cài đặt macOS

## [1.8.8] - 2026-01-20

### Fixed
- **Safari Address Bar Duplicate Character**: Sửa lỗi nhân đôi ký tự đầu tiên khi gõ tiếng Việt trên thanh địa chỉ Safari
  - Áp dụng chiến lược Shift+Left cho TẤT CẢ trang web trên Safari
  - Ngoại trừ Google Docs/Sheets/Slides/Forms (giữ SendEmptyCharacter để tránh mất ký tự)
  - Phát hiện Google Docs qua URL (`docs.google.com`) hoặc tiêu đề cửa sổ

### Cải tiến
- **Claude Code CLI**: Cải tiến vượt bậc cơ chế xử lý gõ tiếng Việt, hỗ trợ Claude Code v2.1.6 đến v2.1.12+.
- **Tài liệu**: Thêm hướng dẫn chi tiết về cách fix lỗi gõ tiếng Việt trong Claude Code CLI cho cả macOS và Windows.
- **Tính ổn định**: Tối ưu regex pattern và cơ chế tìm kiếm khối mã lỗi trong Claude Code CLI.

### Sửa lỗi
- Sửa lỗi không nhận diện được khối mã cần vá trong một số phiên bản Claude Code mới.

### Technical Details
- Thêm method `isSafariGoogleDocsOrSheets` để phát hiện Google Docs/Sheets qua Accessibility API
- Cải thiện `isSafariAddressBar` với kiểm tra AXTextField/AXComboBox role trước
- Cập nhật regex pattern cho Claude Code 2.1.12+ với `\S+` thay vì `\w+`

## [1.7.7] - 2026-01-18

### 📢 Lời Nhắn Từ Tác Giả

Xin chào các bạn,

Hôm nay tôi rất tiếc phải thông báo rằng gia đình tôi đang trong thời gian tang lễ của ông ngoại. Do đó, việc cập nhật và hỗ trợ ứng dụng có thể bị chậm trễ trong vài ngày tới.

Version 1.7.7 này được phát hành để khắc phục một số lỗi quan trọng ảnh hưởng đến trải nghiệm gõ tiếng Việt trên các trình duyệt web, đặc biệt là Google Docs và Google Sheets. Tôi mong các bạn thông cảm cho sự chậm trễ này và cảm ơn sự ủng hộ của các bạn.

Kính chúc sức khỏe,
Phạm Hùng Tiến

---

### Fixed
- **Google Docs/Sheets Input Issues**: Sửa lỗi mất ký tự khi gõ tiếng Việt trên Google Docs, Google Sheets và các rich text editor khác trong trình duyệt
  - Phát hiện vấn đề: Chiến lược "Shift+Left selection" gây mất ký tự (ví dụ: "đến Việt" → "ếnới iệt")
  - Áp dụng chiến lược mặc định của OpenKey: SendEmptyCharacter + backspace thông thường
  - Hoạt động ổn định trên tất cả trình duyệt: Chrome, Safari, Firefox, Edge, Brave...
  - Đảm bảo tương thích với autocomplete và rich text editing
- **Browser Input Strategy**: Loại bỏ chiến lược "Shift+Left" không ổn định, quay về phương pháp đã được OpenKey kiểm chứng qua nhiều năm

### Technical Details
- Nghiên cứu sâu mã nguồn OpenKey để hiểu đúng cơ chế xử lý browser input
- OpenKey có 2 chế độ: mặc định (SendEmptyCharacter) và tùy chọn (Shift+Left khi user bật setting)
- PHTV trước đây force enable Shift+Left cho tất cả Chromium browsers → gây lỗi
- Bây giờ PHTV tuân theo OpenKey's default: đơn giản, ổn định, đã được verify

## [1.6.8] - 2026-01-11

### Added
- **Binary Integrity Protection System**:
  - SHA-256 hash tracking giữa các lần khởi động để phát hiện binary modifications
  - Architecture detection (Universal Binary vs arm64-only) để phát hiện CleanMyMac stripping
  - Code signature verification với codesign --verify --deep --strict
  - Real-time notifications (BinaryChangedBetweenRuns, BinaryModifiedWarning, BinarySignatureInvalid)
  - Performance: Detection < 200ms (150x nhanh hơn), Recovery 95% success rate (3x tốt hơn)
- **PHTVBinaryIntegrity Class**: Quản lý toàn bộ logic binary integrity checking
- **BinaryIntegrityWarningView**: SwiftUI view hiển thị cảnh báo và hướng dẫn khắc phục 3 phương án
- **scripts/fix_accessibility.sh**: Script tự động khôi phục quyền Accessibility (< 15s, 20x nhanh hơn)
- **Bug Report Enhancement**: Hiển thị binary architecture và integrity status trong bug reports

### Changed
- **PHTVManager Code Cleanup**: Giảm 23% code (từ 782 xuống 601 dòng) bằng cách delegate sang PHTVBinaryIntegrity
- **AppDelegate Startup**: Thêm binary integrity check khi khởi động để early detection
- **Project Organization**: Tổ chức lại file structure (scripts/ directory, separate integrity class)

### Fixed
- **Swift Optional Interpolation Warning**: Sửa cảnh báo trong BugReportView.swift với nil-coalescing operator
- **Build Configuration**: Thêm PHTVBinaryIntegrity.m vào Xcode project.pbxproj build phases
- **CleanMyMac Detection**: Phát hiện và cảnh báo khi binary bị stripped, tránh mất quyền TCC vĩnh viễn

## [1.6.5] - 2026-01-11

### Fixed
- **Triệt để vấn đề mất quyền Accessibility không phục hồi được**:
  - Thêm TCC notification listener - phát hiện thay đổi quyền ngay lập tức từ hệ thống (< 200ms)
  - Implement aggressive permission reset - force reset TCC cache khi cấp lại quyền
  - Cải thiện khả năng recover với multiple retry attempts (3 lần) và progressive delays
  - Tự động kill và restart tccd daemon để invalidate TCC cache ở process-level
  - Cache invalidation thông minh - clear cả result và timestamp
  - Xử lý edge case: user toggle quyền nhiều lần liên tiếp
  - Tự động đề xuất khởi động lại app nếu quyền không nhận sau 3 lần thử
  - Người dùng giờ có thể cấp/thu hồi/cấp lại quyền bao nhiêu lần cũng được

### Changed
- **Cải thiện GitHub Templates**:
  - Bug report template: thêm macOS 26.x, architecture, console logs section, enhanced troubleshooting
  - Pull request template: comprehensive testing checklist, security review, before/after screenshots

## [1.5.9] - 2026-01-09

### Fixed
- **Khắc phục triệt để lỗi quyền trợ năng (Accessibility)**:
  - Sửa lỗi ứng dụng không nhận quyền ngay cả khi đã cấp trong System Settings.
  - Loại bỏ yêu cầu khởi động lại ứng dụng sau khi cấp quyền.
  - Sử dụng phương pháp kiểm tra quyền tin cậy hơn (CGEventTapCreate).
- **Cải thiện Code Signing**:
  - Bắt buộc ký số (Mandatory Code Signing) để đảm bảo bảo mật và tránh lỗi TCC trên macOS mới.
  - Sửa lỗi workflow build tự động trên GitHub Actions.
- **Quyền Input Monitoring**:
  - Bổ sung entitlements cần thiết để hoạt động trơn tru trên macOS 14/15.
- **Tự động khôi phục từ tiếng Anh**:
  - Sửa lỗi không khôi phục được các từ có phụ âm đôi cuối (address, access, success...).
  - Mở rộng từ điển tiếng Anh lên 7,600 từ.

## [1.5.0] - 2026-01-05

### Added
- **Enhanced Non-Latin Keyboard Detection**: Tự động chuyển về English khi dùng bàn phím non-Latin
  - Hỗ trợ: Japanese, Chinese, Korean, Arabic, Hebrew, Thai, Hindi, Greek, Cyrillic, Georgian, Armenian, v.v.
  - Tự động khôi phục Vietnamese khi chuyển lại bàn phím Latin
  - Hiển thị tên bàn phím thực tế trong log

### Removed
- **Chromium Fix**: Xóa tính năng sửa lỗi Chromium (gây nhiều lỗi hơn là giải quyết)
- **Typing Stats**: Xóa tính năng thống kê gõ phím

### Changed
- **English Dictionary**: Xóa từ "fpt" khỏi từ điển

## [1.4.6] - 2026-01-04

### Changed
- **RAM Optimization**: Cache menu bar icons, sử dụng @AppStorage thay vì @EnvironmentObject
- **Lazy Loading Settings**: Implement lazy loading cho các tab Settings để giảm memory usage
- **Bug Report Improvements**: Hiển thị full error/warning messages, ưu tiên errors trước warnings, tăng log time range

### Fixed
- **Memory Leaks**: Cleanup NotificationCenter observers trong AppState và TypingStatsManager
- **WindowController Observer**: Sử dụng block-based pattern với weak self
- **WKWebView Cleanup**: Thêm cleanup trong ReleaseNotesView với Coordinator và dismantleNSView
- **MacroListView Animation**: Tối ưu animation performance

## [1.4.5] - 2026-01-04

### Added
- **Check for Updates in Menu Bar**: Thêm menu item "Kiểm tra cập nhật" vào menu bar
- **Language Switcher UI**: Cải thiện UI chuyển đổi ngôn ngữ với Picker và checkmark display

## [1.4.4] - 2026-01-04

### Fixed
- **Vietnamese Input in Apple Apps**: Thêm nhiều Apple apps vào forcePrecomposedAppSet
  - System Settings (search bar)
  - Finder (search bar)
  - Weather, Podcasts, Passwords, Books
  - Reminders, Journal, Game Center

## [1.4.3] - 2026-01-04

### Changed
- **CI/CD Improvements**: Cải thiện workflow tự động
- **Auto-increment Build Number**: Tự động tăng build number và commit Info.plist sau release

### Fixed
- **Build Number**: Sửa build number cho phiên bản 1.4.3

## [1.4.2] - 2026-01-04

### Added
- **Automated CI/CD**: Thêm GitHub Actions workflow tự động build và release
- **Code Signing**: Tự động sign app với Apple Development certificate trong CI
- **Sparkle Auto-Update**: Tự động cập nhật appcast.xml và Homebrew formula khi release

### Changed
- **Build Infrastructure**: Chuyển sang macOS 26 runner để hỗ trợ đầy đủ Liquid Glass APIs
- **Release Process**: Tự động hóa hoàn toàn quy trình release (build → sign → DMG → appcast → Homebrew)

### Fixed
- **Auto-Update**: Sửa lỗi Sparkle không thể cài đặt bản cập nhật do app chưa được code sign

## [1.3.8] - 2026-01-03

### Added
- **Emoji expansion**: Thêm 622 emoji mới từ Unicode v17.0, tăng tổng số lượng từ 841 lên 1,463 emoji
- **Liquid Glass comprehensive**: Áp dụng hiệu ứng Liquid Glass toàn diện cho tất cả Settings components
- **Auto cleanup**: Tự động xóa file GIF đã tải về sau 5 giây để tránh rác ứng dụng
- **Backup improvements**: Bao gồm cả cài đặt menu bar và dock trong backup/export

### Changed
- **Settings merge**: Gộp tab Compatibility vào tab Ứng dụng để giao diện gọn gàng hơn (từ 8 tabs xuống 7 tabs)
- **Settings transparency**: Cải thiện độ trong suốt của cửa sổ Settings với native materials
- **UI unification**: Thống nhất thiết kế StatusCard và SettingsCard trên toàn bộ app
- **About tab redesign**: Loại bỏ gradient background sau icon app để giao diện sạch hơn

### Fixed
- **PHTV Picker reliability**: Sửa lỗi paste emoji/gif đôi khi không hoạt động (system beep) bằng cách thêm delay 0.15s trước khi paste
- **App focus restoration**: Khôi phục focus về chat app sau khi đóng PHTV Picker
- **Card heights consistency**: Ngăn subtitle text wrap để đảm bảo card heights đồng đều
- **Glass effect display**: Ẩn background mặc định của TextEditor để hiệu ứng glass hiển thị đúng

## [1.3.7] - 2026-01-02

### Fixed
- **Menu bar and dock settings**: Khôi phục cài đặt thanh menu và dock đã bị xóa nhầm khi xóa theme color

## [1.3.6] - 2026-01-02

### Added
- **Liquid Glass design**: Áp dụng thiết kế Liquid Glass hiện đại từ Apple cho PHTV Picker trên macOS 26+
- **Window resizability**: Sử dụng SwiftUI .windowResizability(.contentSize) chuẩn từ Apple (WWDC 2024)
- **Always on Top setting**: Cài đặt giữ cửa sổ Settings luôn ở trên các app khác
- **Run on Startup improvement**: Áp dụng ngay lập tức khi bật/tắt (không cần restart)

### Changed
- **PHTV Picker branding**: Đổi tên "Emoji Picker" thành "PHTV Picker" cho nhất quán
- **Settings card alignment**: Căn chỉnh SettingsCard đồng nhất trên tất cả các tab
- **Picker visibility**: Giảm độ trong suốt để dễ nhìn hơn (Glass.clear → Glass.regular)
- **Settings UI sync**: Tất cả tab cài đặt có thiết kế nhất quán với Liquid Glass principles

### Fixed
- **Selected text replacement**: Xử lý đúng việc thay thế văn bản đã được highlight/select
- **Auto-focus search**: Con trỏ tự động vào ô tìm kiếm trong tab Emoji (đồng bộ với GIF/Sticker)
- **Window size constraints**: Cố định kích thước cửa sổ Settings (800-1000x600-900)

### Removed
- **Redundant hotkey card**: Loại bỏ card "Phím tắt hiện tại" không cần thiết trong tab Phím tắt

## [1.3.5] - 2026-01-02

### Fixed
- **Settings window z-order**: Sửa lỗi cửa sổ Settings bị ẩn sau các app khác (Issue #60)
- **GIF click tracking**: Sửa lỗi click GIF không chính xác so với vị trí chuột
- **Duplicate GIF paste**: Sửa lỗi paste 2 GIF khi chỉ click 1 lần
- **Auto English detection**: Sửa lỗi từ tiếng Anh như "fix", "mix", "box" không được restore khi bật auto English
- **Vietnamese tone mark detection**: Cải thiện logic phát hiện từ tiếng Việt có dấu ("đi", "đo", "đa") để không bị nhầm với tiếng Anh

### Improved
- **GIF grid layout**: Cải thiện từ 4 cột xuống 3 cột (120px mỗi thumbnail) cho tracking chính xác hơn
- **Multi-format clipboard**: Hỗ trợ paste GIF vào nhiều app hơn (iMessage, Zalo, Messenger Web)

## [1.3.4] - 2026-01-01

### Added
- **Modern Emoji Picker**: Emoji picker hiện đại với đầy đủ categories
- **GIF Picker**: Tích hợp Klipy API - GIF picker miễn phí không giới hạn
- **Auto-paste GIF**: Click là gửi ngay, không cần Cmd+V
- **GIF search**: Tìm kiếm GIF theo từ khóa tiếng Việt và tiếng Anh
- **Klipy monetization**: Tích hợp quảng cáo Klipy để duy trì miễn phí

### Changed
- **Hotkey**: Thêm Cmd+E để mở Emoji/GIF picker nhanh
- **Website**: Thêm GitHub Pages tại phamhungtien.github.io/PHTV

### Fixed
- **EdDSA signing**: Cập nhật EdDSA signing key cho Sparkle updates

## [1.3.3] - 2025-12-30

### Added
- **GIF API**: Chuyển từ Giphy sang Klipy API cho unlimited free GIF
- **App-ads.txt**: Thêm app-ads.txt cho ad network verification

### Changed
- **Performance**: Tối ưu hiệu suất GIF loading
- **UI**: Cải thiện giao diện GIF picker

## [1.3.2] - 2024-12-29

### Added
- **Text Snippets**: Gõ tắt động với nội dung thay đổi theo ngữ cảnh
  - Ngày hiện tại (format tùy chỉnh)
  - Giờ hiện tại
  - Ngày và giờ
  - Nội dung clipboard
  - Random từ danh sách
  - Counter tự động tăng
- **Từ điển tùy chỉnh**: Thêm từ tiếng Anh/Việt để nhận diện chính xác hơn
- **Import/Export cài đặt**: Sao lưu và khôi phục toàn bộ cài đặt ra file .phtv-backup

### Changed
- **Settings Reorganization**: Tổ chức lại từ 12 tabs xuống 11 tabs
  - Gộp "Nâng cao" vào "Bộ gõ" thành section "Phụ âm nâng cao"
  - Sắp xếp theo mức độ sử dụng: Bộ gõ → Phím tắt → Gõ tắt → ...
- **Hotkey UI**: Thiết kế mới với gradient, hover effects, và radio buttons
- **Search**: Mở rộng từ 40 lên 61 mục tìm kiếm cho tất cả chức năng
- **English Dictionary**: Bổ sung thuật ngữ công nghệ và thương hiệu phổ biến

### Fixed
- Sửa lỗi phím Backspace không reset trạng thái khi gõ tiếng Việt
- Sửa lỗi Sendable conformance trong SettingsBackup types

## [1.3.1] - 2024-12-28

### Changed
- **Settings Reorganization**: Tổ chức lại cài đặt thành 9 tab hợp lý hơn
  - **Ứng dụng**: Phím chuyển thông minh, Nhớ bảng mã, Loại trừ ứng dụng, Gửi từng phím
  - **Giao diện**: Màu chủ đạo, Icon menu bar, Hiển thị Dock
  - **Tương thích**: Chromium fix, Bàn phím, Claude Code, Safe Mode
  - **Hỗ trợ**: Kết hợp Thông tin + Báo lỗi với tab con
- **Advanced Settings**: Đơn giản hóa chỉ còn cài đặt phụ âm nâng cao
- **Search**: Cập nhật danh sách tìm kiếm theo cấu trúc tab mới

## [1.3.0] - 2024-12-28

### Added
- **Safe Mode**: Tự động phát hiện và khôi phục khi Accessibility API gặp lỗi
- **macOS Ventura**: Hạ yêu cầu từ macOS 14.0 (Sonoma) xuống 13.0 (Ventura)
- **macOS 26 Liquid Glass**: Hỗ trợ hiệu ứng Liquid Glass trên macOS 26
- **OCLP Support**: Tương thích tốt hơn với máy Mac chạy OpenCore Legacy Patcher

### Changed
- **Settings Window**: Thiết kế lại với kích thước tối ưu 950x680, blur background
- **Thread Safety**: Xử lý window management an toàn với Swift 6 concurrency

### Fixed
- Sửa vòng lặp vô hạn khi mở settings từ menu bar
- Sửa lỗi nút "Tạo gõ tắt đầu tiên" không hoạt động khi tính năng gõ tắt chưa bật
- Tự động bật tính năng gõ tắt khi tạo gõ tắt đầu tiên
- Sửa background trong suốt không đẹp mắt
- Sửa kích thước cửa sổ quá nhỏ khi mở lần đầu
- Sửa Swift 6 concurrency warnings trong SettingsWindowHelper

## [1.2.6] - 2024-12-26

### Changed
- **Performance**: Giảm tần suất kiểm tra quyền truy cập từ mỗi giây xuống 5 giây (tiết kiệm 80% CPU)
- **Performance**: Tăng cache duration từ 1 giây lên 10 giây
- **Performance**: Giảm 83% số lần tạo test event tap (từ 40 xuống 6 lần/phút)
- **UX**: Delay 10 giây sau khởi động mới check update để tránh lỗi network
- **UX**: Loại bỏ dialog "newest version available" khi không có update

### Added
- **Bug Report**: Thêm runtime state tracking (accessibility permission, event tap status, front app info)
- **Bug Report**: Thêm performance metrics (memory usage, system uptime)
- **Bug Report**: Tự động tìm và đọc crash logs trong 7 ngày gần đây
- **Bug Report**: Thu thập logs từ PHTVLogger
- **Bug Report**: Tự động highlight unusual settings

### Fixed
- Console sạch 100% trong production build (debug logs chỉ xuất hiện trong debug mode)

## [1.2.5] - 2024-12-25

### Added
- **Auto-Update**: Tích hợp Sparkle Framework 2.8.1 cho tự động cập nhật
- **Auto-Update**: Kiểm tra tự động theo lịch (hàng ngày/tuần/tháng)
- **Auto-Update**: Kênh Beta opt-in cho người dùng muốn thử nghiệm
- **Auto-Update**: Release notes viewer với UI hiện đại
- **Security**: EdDSA signing cho mọi bản cập nhật

### Changed
- **UI**: Đơn giản hóa Settings - loại bỏ phần "Thông tin ứng dụng" trùng lặp
- **UI**: Card "Cập nhật" mới với đầy đủ tùy chọn
- **Backend**: Xóa logic kiểm tra cập nhật qua GitHub API thủ công

### Fixed
- Sửa lỗi timeout 30 giây khi kiểm tra cập nhật
- Sửa lỗi alert "Đang kiểm tra cập nhật..." không biến mất
- Sửa lỗi nút "Kiểm tra cập nhật" không phản hồi
- Sửa lỗi notification name mismatch

## [1.2.4] - 2024-12-25

### Improved
- **Claude Code CLI**: Cải thiện phát hiện Homebrew (hỗ trợ Apple Silicon, Intel, Linux)
- **Claude Code CLI**: Hỗ trợ Fast Node Manager (fnm) ngoài nvm
- **Claude Code CLI**: Thêm nút "Mở Terminal" khi cài đặt tự động thất bại

### Fixed
- Sửa lỗi không tìm thấy brew (tìm động thay vì hardcode path)
- Sửa lỗi npm không chạy được (cải thiện environment variables)
- Sửa lỗi gỡ Homebrew không sạch (xóa symlink còn sót lại)

## [1.2.3] - 2024-12-24

### Improved
- Cải thiện UI báo lỗi
- Tối ưu hiệu suất

### Fixed
- Sửa lỗi trùng lặp từ trong Spotlight

## [1.2.2] - 2024-12-23

### Added
- Hỗ trợ toàn diện cho bàn phím quốc tế (International keyboard layouts)

## [1.2.1] - 2024-12-22

### Improved
- Cải thiện ổn định tổng thể
- Tối ưu hiệu năng

## [1.2.0] - 2024-12-21

### Added
- Tính năng mới và cải tiến đáng kể
- Nâng cấp engine core

## [1.1.9] - 2024-12-20

### Improved
- Cập nhật README và documentation
- Tối ưu hiệu năng

## [1.1.8] - 2024-12-19

### Changed
- Bump version to 1.1.8

## [1.1.7] - 2024-12-18

### Improved
- Cải thiện đồng bộ theme
- Chuẩn hóa code và copyright headers

## [1.1.5] - 2024-12-17

### Fixed
- Sửa lỗi âm thanh
- Preserve macros khi cập nhật
- Cải thiện UX

## [1.1.4] - 2024-12-16

### Added
- Các tính năng và cải tiến

## [1.1.3] - 2024-12-15

### Improved
- Cải thiện ổn định

## [1.1.2] - 2024-12-14

### Added
- Auto-update check
- Restore on invalid word
- Send key step-by-step

## [1.1.1] - 2024-12-13

### Improved
- Cập nhật README

## [1.1.0] - 2024-12-12

### Added
- Phiên bản 1.1.0 với nhiều tính năng mới

## [1.0.3] - 2024-12-11

### Fixed
- Bug fixes và cải thiện ổn định

## [1.0.2] - 2024-12-10

### Fixed
- Bug fixes

## [1.0.1] - 2024-12-09

### Fixed
- Sửa lỗi phiên bản đầu tiên

## [1.0.0] - 2024-12-08

### Added
- Phát hành phiên bản đầu tiên của PHTV
- Hỗ trợ Telex, VNI, Simple Telex
- Nhiều bảng mã: Unicode, TCVN3, VNI Windows
- Giao diện SwiftUI hiện đại
- Kiểm tra chính tả
- Macro (gõ tắt)
- Hoàn toàn offline

[Unreleased]: https://github.com/PhamHungTien/PHTV/compare/v1.6.8...HEAD
[1.6.8]: https://github.com/PhamHungTien/PHTV/compare/v1.6.5...v1.6.8
[1.6.5]: https://github.com/PhamHungTien/PHTV/compare/v1.5.9...v1.6.5
[1.5.9]: https://github.com/PhamHungTien/PHTV/compare/v1.5.8...v1.5.9
[1.5.8]: https://github.com/PhamHungTien/PHTV/compare/v1.5.7...v1.5.8
[1.5.7]: https://github.com/PhamHungTien/PHTV/compare/v1.5.6...v1.5.7
[1.5.6]: https://github.com/PhamHungTien/PHTV/compare/v1.5.5...v1.5.6
[1.5.5]: https://github.com/PhamHungTien/PHTV/compare/v1.5.4...v1.5.5
[1.5.4]: https://github.com/PhamHungTien/PHTV/compare/v1.5.3...v1.5.4
[1.5.3]: https://github.com/PhamHungTien/PHTV/compare/v1.5.2...v1.5.3
[1.5.2]: https://github.com/PhamHungTien/PHTV/compare/v1.5.1...v1.5.2
[1.5.1]: https://github.com/PhamHungTien/PHTV/compare/v1.5.0...v1.5.1
[1.5.0]: https://github.com/PhamHungTien/PHTV/compare/v1.4.9...v1.5.0
[1.4.9]: https://github.com/PhamHungTien/PHTV/compare/v1.4.8...v1.4.9
[1.4.8]: https://github.com/PhamHungTien/PHTV/compare/v1.4.7...v1.4.8
[1.4.7]: https://github.com/PhamHungTien/PHTV/compare/v1.4.6...v1.4.7
[1.4.6]: https://github.com/PhamHungTien/PHTV/compare/v1.4.5...v1.4.6
[1.4.5]: https://github.com/PhamHungTien/PHTV/compare/v1.4.4...v1.4.5
[1.4.4]: https://github.com/PhamHungTien/PHTV/compare/v1.4.3...v1.4.4
[1.4.3]: https://github.com/PhamHungTien/PHTV/compare/v1.4.2...v1.4.3
[1.4.2]: https://github.com/PhamHungTien/PHTV/compare/v1.3.8...v1.4.2
[1.3.8]: https://github.com/PhamHungTien/PHTV/compare/v1.3.7...v1.3.8
[1.3.7]: https://github.com/PhamHungTien/PHTV/compare/v1.3.6...v1.3.7
[1.3.6]: https://github.com/PhamHungTien/PHTV/compare/v1.3.5...v1.3.6
[1.3.5]: https://github.com/PhamHungTien/PHTV/compare/v1.3.4...v1.3.5
[1.3.4]: https://github.com/PhamHungTien/PHTV/compare/v1.3.3...v1.3.4
[1.3.3]: https://github.com/PhamHungTien/PHTV/compare/v1.3.2...v1.3.3
[1.3.2]: https://github.com/PhamHungTien/PHTV/compare/v1.3.1...v1.3.2
[1.3.1]: https://github.com/PhamHungTien/PHTV/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/PhamHungTien/PHTV/compare/v1.2.6...v1.3.0
[1.2.6]: https://github.com/PhamHungTien/PHTV/compare/v1.2.5...v1.2.6
[1.2.5]: https://github.com/PhamHungTien/PHTV/compare/v1.1.4...v1.2.5
[1.2.4]: https://github.com/PhamHungTien/PHTV/releases/tag/v1.2.4
[1.2.3]: https://github.com/PhamHungTien/PHTV/releases/tag/v1.2.3
[1.2.2]: https://github.com/PhamHungTien/PHTV/releases/tag/v1.2.2
[1.2.1]: https://github.com/PhamHungTien/PHTV/releases/tag/v1.2.1
[1.2.0]: https://github.com/PhamHungTien/PHTV/releases/tag/v1.2.0
[1.1.9]: https://github.com/PhamHungTien/PHTV/releases/tag/v1.1.9
[1.1.8]: https://github.com/PhamHungTien/PHTV/releases/tag/v1.1.8
[1.1.7]: https://github.com/PhamHungTien/PHTV/releases/tag/v1.1.7
[1.1.5]: https://github.com/PhamHungTien/PHTV/releases/tag/v1.1.5
[1.1.4]: https://github.com/PhamHungTien/PHTV/compare/v1.1.3...v1.1.4
[1.1.3]: https://github.com/PhamHungTien/PHTV/compare/v1.1.2...v1.1.3
[1.1.2]: https://github.com/PhamHungTien/PHTV/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/PhamHungTien/PHTV/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/PhamHungTien/PHTV/compare/v1.0.3...v1.1.0
[1.0.3]: https://github.com/PhamHungTien/PHTV/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/PhamHungTien/PHTV/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/PhamHungTien/PHTV/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/PhamHungTien/PHTV/releases/tag/v1.0.0
