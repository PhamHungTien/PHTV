# PHTV for macOS

`Apps/macOS/` là sản phẩm PHTV duy nhất trong repository. Ứng dụng được viết
bằng Swift, SwiftUI và AppKit; xử lý phím bằng CGEvent cùng Accessibility API
của macOS.

```text
Apps/macOS/
├── PHTV/           # Mã ứng dụng, engine, input, services và UI
├── Tests/          # XCTest regression tests
├── Fixtures/       # Dữ liệu kiểm thử tĩnh
└── PHTV.xcodeproj/ # Project và scheme phát hành
```

Công cụ phát triển/release nằm tại [`scripts/`](../scripts/README.md). Kiến
trúc, kiểm thử, quyền riêng tư và quy trình phát hành nằm tại [`docs/`](../docs/).
Binary và build cache không được commit vào `Apps/`.
