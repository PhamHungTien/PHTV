# Ma trận tương thích PHTV

Tài liệu này phân biệt rõ kiểm thử tự động với xác nhận thủ công. Có test policy
không đồng nghĩa đã tương tác thực tế với mọi phiên bản ứng dụng bên thứ ba.

## Nhóm ứng dụng quan trọng

| Nhóm | Trường hợp đại diện | Bằng chứng tự động | Kiểm tra thủ công trước release |
| --- | --- | --- | --- |
| Terminal/CLI | Terminal, iTerm2, Warp, terminal tích hợp JetBrains | `CliProfileServiceTests`, `CompatibilityProfileResolverTests` | Telex/VNI, Backspace, lệnh dài, Claude Code |
| JetBrains editor | IntelliJ IDEA, Android Studio | Không coi editor là CLI; regression test cho profile | Không xuất hiện INSERT/DELETE, terminal tích hợp vẫn dùng CLI |
| Notion | App native, Firefox, Chrome/Safari | `NotionCodeBlockPolicyTests`, strategy tests | Văn bản thường và code block, URL workspace thật |
| Chat/Electron | Zalo, Microsoft Teams, Slack, Discord | Text Replacement/strategy/profile tests | Chat, search box, macro ngắn và Unicode dài |
| Trình duyệt/editor web | Firefox, Chrome, Safari, Edge | Browser/address-bar và compatibility strategy tests | Address bar, form, contenteditable, autocomplete |
| Google Workspace | Sheets, Docs | Google Sheets context và backspace-plan tests | Autocomplete, `dd`, macro, chuyển ô |
| Video editor | DaVinci Resolve | Bundle/profile low-latency tests | Space playback và ô title/subtitle |
| Floating panels | Clipboard History, PHTV Picker | Hotkey/panel lifecycle logic tests | Mở/đóng nhanh, đổi panel, nhiều màn hình, mất focus |
| Input source khác Latin | Trung, Nhật, Hàn và các layout khác | Menu bar/input-source policy tests | Icon macOS, fallback E, khôi phục Việt/Anh |

## Cấu hình gõ tối thiểu

Mỗi bản release cần lấy mẫu các tổ hợp sau:

- Telex, Simple Telex 1/2 và VNI.
- Unicode, Unicode Compound và ít nhất một bảng mã legacy.
- Chính tả cũ/mới, kiểm tra chính tả bật/tắt, Quick Telex bật/tắt.
- chữ thường, Title Case, Shift và Caps Lock.
- Space, dấu câu, Enter, Tab, Backspace và phím điều hướng.
- US, Dvorak hoặc Colemak nếu thay đổi layout mapping.

## Nền tảng

CI chạy trên macOS runner hiện hành. Trước một bản lớn hoặc thay đổi EventTap/TCC,
nên xác nhận thủ công trên:

- macOS 14 (minimum deployment target);
- macOS stable mới nhất;
- macOS beta đang được dự án hỗ trợ;
- Apple Silicon;
- Intel khi có thay đổi packaging, Sparkle hoặc mã phụ thuộc kiến trúc.

## Ghi kết quả

Trong pull request hoặc issue, ghi version chính xác của macOS, PHTV và ứng dụng
đích; chip; kiểu gõ; bảng mã; cấu hình liên quan; bước tái hiện và video nếu lỗi
phụ thuộc timing. Không đánh dấu “đã hỗ trợ” chỉ dựa trên bundle ID hoặc suy luận
từ ứng dụng tương tự.
