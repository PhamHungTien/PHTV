# Changelog

All notable changes to PHTV will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
- **Thống kê gõ phím**: Theo dõi số từ, ký tự, thời gian gõ với biểu đồ 7 ngày

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
- **Claude Code Patcher**: Cải thiện phát hiện Homebrew (hỗ trợ Apple Silicon, Intel, Linux)
- **Claude Code Patcher**: Hỗ trợ Fast Node Manager (fnm) ngoài nvm
- **Claude Code Patcher**: Thêm nút "Mở Terminal" khi cài đặt tự động thất bại

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

[Unreleased]: https://github.com/PhamHungTien/PHTV/compare/v1.3.5...HEAD
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
