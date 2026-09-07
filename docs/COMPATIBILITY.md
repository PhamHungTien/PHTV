# Ma trận tương thích PHTV

Tài liệu này phân biệt rõ kiểm thử tự động với xác nhận thủ công. Có test policy
không đồng nghĩa đã tương tác thực tế với mọi phiên bản ứng dụng bên thứ ba.

## Nhóm ứng dụng quan trọng

| Nhóm | Trường hợp đại diện | Bằng chứng tự động | Kiểm tra thủ công trước release |
| --- | --- | --- | --- |
| Terminal/CLI | Terminal, iTerm2, Warp, terminal tích hợp JetBrains | `CliProfileServiceTests`, `CompatibilityProfileResolverTests` | Telex/VNI, Backspace, lệnh dài, Claude Code |
| JetBrains editor | IntelliJ IDEA, Android Studio | Không coi editor là CLI; regression test cho profile | Không xuất hiện INSERT/DELETE, terminal tích hợp vẫn dùng CLI |
| TeXstudio | QEditor, bundle ID `texstudio` | `EngineRegressionTests/testIssue224*`, `TeXstudioUnicodeEventTests` | VNI `A44`, huỷ/đổi dấu liên tiếp, Unicode tổ hợp, macro và nội dung trước con trỏ |
| Notion | App native, Firefox, Chrome/Safari | `NotionCodeBlockPolicyTests`, strategy tests | Văn bản thường và code block, URL workspace thật |
| Chat/Electron | Zalo, Microsoft Teams, Slack, Discord | Text Replacement/strategy/profile tests | Chat, search box, macro ngắn và Unicode dài |
| AI web chat | Kimi, Grok, Gemini và các trang tương tự | Text Replacement host/title policy tests | Shortcut native trong ô chat, không lặp hoặc mất phần đầu nội dung |
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

## TeXstudio — hồi quy #224

TeXstudio có quy tắc riêng trong
[QEditor::keyPressEvent](https://github.com/texstudio-org/texstudio/blob/4.9.7/src/qcodeedit/lib/qeditor.cpp):
bỏ qua sự kiện phím có phần văn bản dài hơn một UTF-16 unit. Vì vậy chuỗi khôi
phục `A4` cần được gửi thành các ký tự riêng. Quy tắc này chỉ áp dụng cho bundle
`texstudio`; không suy rộng thành lỗi của mọi ứng dụng Qt.

Các bước kiểm tra lại trước release:

1. Chọn VNI, gõ `prefix A4` rồi thêm `4`: lần lượt nhận `prefix Ã` và
   `prefix A4`. Gõ tiếp ` a1` phải nhận `prefix A4 á`.
2. Huỷ lần lượt năm dấu với `a11 a22 a33 a44 a55`, rồi thử chữ hoa. Nội dung
   phía trước phải còn nguyên. Thử thêm `dang9 di9 an8 ha3`.
3. Lặp lại với Unicode/Unicode tổ hợp, bật/tắt gõ từng bước và tuỳ chọn sửa lỗi
   gợi ý trình duyệt. Với Telex và Simple Telex 1/2, thử `Ass as` → `As á`.
4. Gán macro tiếng Việt dài hơn 16 ký tự, mở rộng rồi gõ tiếp một từ có dấu;
   chuỗi macro phải đầy đủ và không bị lần đổi dấu sau xoá lấn.

Xác nhận ngày 2026-09-07: TeXstudio 4.9.7, macOS 27.0 beta (26A5425a), arm64.
Harness gọi engine, strategy, output và sender của bản PHTV vừa build, gửi sự
kiện vào TeXstudio thật rồi so sánh tệp `.tex` do ứng dụng lưu: **64/64 tình
huống đạt**. Đường gửi cũ đã tái hiện việc mất `A4` trước khi áp dụng bản sửa.
Đây là bằng chứng cho môi trường trên, không thay thế kiểm tra các phiên bản
macOS/TeXstudio khác trước release.

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
