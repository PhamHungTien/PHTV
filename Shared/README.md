# Shared platform-neutral components

Thư mục này là ranh giới duy nhất cho mã và dữ liệu được chia sẻ giữa macOS,
Windows và Linux. Không đặt adapter hệ điều hành hoặc UI vào đây.

```text
Shared/
├── PHTVCore/      # Engine Swift portable
├── Contracts/     # C ABI, schema cấu hình và EditPlan
└── TestVectors/   # Golden vectors dùng chung giữa các nền tảng
```

## Quy tắc phụ thuộc

- `PHTVCore` có thể phụ thuộc `Contracts` và resource portable.
- Nền tảng phụ thuộc vào Shared; Shared không import mã trong `macOS/`,
  `Windows/` hoặc `Linux/`.
- Core không phát sự kiện bàn phím, truy cập UI, mạng hoặc global state của hệ
  điều hành.
- Thay đổi contract/schema phải có version, migration và test tương thích.
- Golden vectors là nguồn sự thật cho hành vi engine xuyên nền tảng.

`PHTVCore` đã là Swift package build được với session contract, C ABI version 1
và C smoke test. Engine tiếng Việt, schema cấu hình và golden vectors vẫn đang
được tách theo từng cổng chất lượng; xem
[`PHTVCore/README.md`](PHTVCore/README.md) để biết năng lực hiện có.
