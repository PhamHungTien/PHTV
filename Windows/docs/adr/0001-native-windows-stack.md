# ADR 0001: Native Windows stack

- Trạng thái: Accepted
- Ngày: 2026-07-22
- Phạm vi: nền móng PHTV for Windows

## Bối cảnh

PHTV hiện là ứng dụng macOS Swift/SwiftUI dùng CGEvent và Accessibility. Windows
có mô hình nhập liệu, UI, đóng gói và bảo mật khác. Mục tiêu là tái sử dụng logic
ngôn ngữ mà không mang workaround macOS sang nền tảng mới.

## Quyết định

1. Dùng Text Services Framework với C++/WinRT cho IME.
2. Dùng C# và WinUI 3 cho companion app.
3. Tách engine thành Swift Core portable, giao tiếp qua C ABI có version.
4. Không dùng global keyboard hook + `SendInput` làm đường nhập liệu chính.
5. Không yêu cầu toàn bộ Windows client viết bằng Swift.

## Lý do

- TSF là cơ chế input service do Windows cung cấp và làm việc theo document,
  selection, composition thay vì mô phỏng xoá/chèn toàn cục.
- WinUI 3 là UI native hiện đại của Windows App SDK.
- C++/WinRT phù hợp với COM/TSF; C# phù hợp với UI và tooling Windows.
- Swift Core bảo toàn phần đầu tư vào engine, từ điển và regression hiện có.

## Phương án đã cân nhắc

### Toàn bộ bằng Swift

Không chọn cho v1. Swift có toolchain Windows nhưng không có SwiftUI/WinUI
projection chính thức tương đương C#/C++; triển khai COM TSF trực tiếp làm tăng
rủi ro ABI, packaging và bảo trì.

### Global hook + `SendInput`

Không chọn làm kiến trúc chính. Cách này gần mô hình macOS hiện tại nhưng dễ xảy
ra race condition, selection sai và khác biệt theo integrity level/AppContainer.

### Port toàn bộ engine sang C++ hoặc C# ngay lập tức

Không chọn trước PoC vì làm mất khả năng dùng chung logic và tăng nguy cơ lệch
hành vi giữa macOS/Windows. Nếu nhúng Swift không vượt cổng phát hành, một ADR
mới sẽ đánh giá lại với số liệu PoC.

## Hệ quả

- Repository dùng đa ngôn ngữ có chủ đích: Swift, C++ và C#.
- C ABI, packaging Swift runtime và lifecycle DLL trở thành rủi ro cần kiểm thử
  sớm.
- UI macOS và Windows khác code nhưng dùng chung domain behavior/test vectors.
- Tính năng Windows phải tuân theo TSF, không sao chép cơ học CGEvent/AX.

