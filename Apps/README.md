# PHTV applications

`Apps/` chứa mã và tài liệu dành riêng cho từng hệ điều hành. Mỗi thư mục con là
một sản phẩm/adapter độc lập; chúng không được import trực tiếp mã của nhau.

| Ứng dụng | Công nghệ native | Trạng thái |
| --- | --- | --- |
| [`macOS`](macOS/) | Swift, SwiftUI, AppKit, CGEvent | Đang phát hành |
| [`Windows`](Windows/) | C++/WinRT TSF, C# WinUI 3 | Đang triển khai |
| [`Linux`](Linux/) | IBus, Fcitx 5, GTK 4/libadwaita | Nền móng kiến trúc |

Mã xử lý ngôn ngữ, C ABI và golden vectors dùng chung nằm trong
[`Shared/`](../Shared/README.md). Công cụ phát triển/release nằm trong
[`scripts/`](../scripts/README.md), còn tài liệu sản phẩm chung nằm trong
[`docs/`](../docs/).

## Ranh giới phụ thuộc

```text
Apps/macOS ─────┐
Apps/Windows ───┼──► Shared
Apps/Linux ─────┘
```

- `Apps/*` có thể phụ thuộc `Shared`; `Shared` không phụ thuộc ngược vào
  `Apps/*`.
- Adapter hệ điều hành, UI, installer và tài liệu riêng nền tảng ở trong app
  tương ứng.
- Workflow có thể dùng đường dẫn ở nhiều app nhưng không tạo dependency giữa
  các app.
- Binary/build cache không được commit vào `Apps/`.
