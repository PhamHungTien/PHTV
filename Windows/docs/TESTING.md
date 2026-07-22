# Kiểm thử PHTV for Windows

## Mục tiêu

Đảm bảo cùng một chuỗi phím tạo cùng kết quả ngôn ngữ trên macOS và Windows,
trong khi adapter TSF tuân thủ composition model của từng ứng dụng Windows.

## Các lớp kiểm thử

### 1. Core unit tests

- Telex, VNI, Simple Telex và từng bảng mã;
- Backspace, Escape, modifier, Caps Lock và layout;
- Auto English, chính tả, macro và session reset;
- Unicode normalization và surrogate pair;
- fuzz key sequence và giới hạn buffer.

Test vector dùng định dạng dữ liệu trung lập, chứa key/action mong đợi và không
chứa dữ liệu người dùng thật.

### 2. ABI contract tests

- kích thước/alignment của struct;
- UTF-8/UTF-16 và ownership buffer;
- gọi lặp, gọi đồng thời, null và input lỗi;
- Swift runtime load/unload;
- tương thích ngược giữa app, IME và Core khác build number.

### 3. TSF integration tests

- activation/deactivation và language profile;
- focus/document/context lifecycle;
- composition start/update/commit/cancel;
- selection, undo/redo, clipboard paste và IME switch;
- sleep/wake, fast user switching và remote desktop;
- installer upgrade, repair và uninstall.

### 4. UI tests

- onboarding và trạng thái cài IME;
- Settings, tray, keyboard navigation, DPI và theme;
- import/export, migration và reset;
- thông báo lỗi không tiết lộ nội dung nhập.

## Ma trận ứng dụng tối thiểu

| Nhóm | Ứng dụng đại diện | Mức |
| --- | --- | --- |
| Win32 chuẩn | Notepad | P0 |
| Office | Word, Outlook | P0 |
| Chromium/Electron | Chrome, Edge, VS Code | P0 |
| WinUI/UWP | ứng dụng Settings/test host | P0 |
| IDE | Visual Studio, JetBrains | P1 |
| Terminal | Windows Terminal, PowerShell | P1 |
| Remote | Remote Desktop | P1 |
| Game/elevated | test host riêng | P2 |

Không khẳng định tương thích một ứng dụng chỉ dựa trên việc cùng framework; mỗi
workaround phải có case tái hiện và test giới hạn phạm vi.

## Câu stress bắt buộc

- câu tiếng Việt dài có nhiều lần đổi dấu;
- chuyển nhanh giữa từ Việt và Anh như `tiếng Việt scenario tiếp tục`;
- gõ nhanh, giữ phím, lặp Backspace và đổi focus giữa composition;
- emoji, combining marks, ký tự ngoài BMP và layout non-Latin;
- bật/tắt IME giữa chừng và đổi ứng dụng ngay sau Space/Enter.

## Điều kiện release

- Core/ABI/TSF/UI tests đạt không retry ẩn lỗi.
- Không có P0/P1 regression đang mở.
- Build Release được ký và cài trên máy sạch.
- Smoke test upgrade từ bản stable trước và uninstall sạch.
- Log kiểm thử đã được kiểm tra không chứa nội dung nhập.

