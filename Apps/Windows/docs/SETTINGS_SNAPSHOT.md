# Runtime Settings Snapshot v1

WinUI giữ `%LocalAppData%\PHTV\settings.json` làm nguồn dữ liệu người dùng có
schema. TSF không parse JSON trong DLL nhập liệu; app tạo thêm
`%LocalAppData%\PHTV\settings.snapshot` có kích thước cố định để TSF đọc khi
`ITfTextInputProcessorEx::Activate`.

## Binary layout

Mọi số nguyên dùng little-endian. Snapshot v1 dài chính xác 36 byte:

| Offset | Size | Trường | Giá trị v1 |
| ---: | ---: | --- | --- |
| 0 | 8 | Magic | `PHTVCFG\0` |
| 8 | 2 | Format version | `1` |
| 10 | 2 | Byte length | `36` |
| 12 | 4 | Settings schema | `1` |
| 16 | 8 | Revision | số tăng theo lần ghi |
| 24 | 4 | Flags | bit 0: bật tiếng Việt |
| 28 | 4 | Input method | `0`: Telex, `1`: VNI |
| 32 | 4 | Checksum | FNV-1a 32-bit của byte `0..<32` |

Golden vector cho schema 1, revision `0x0102030405060708`, tắt tiếng Việt và
VNI:

```text
50485456434647000100240001000000
08070605040302010000000001000000
6c05a6e9
```

## Quy tắc đọc

Reader chỉ chấp nhận snapshot khi:

- kích thước, magic, format version và schema khớp hoàn toàn;
- checksum đúng;
- không có flag chưa biết;
- input method thuộc enum đã hỗ trợ.

Mọi lỗi đều fail closed về mặc định `Vietnamese + Telex`; TSF không sửa file,
không parse một phần và không log payload. FNV-1a chỉ phát hiện file ghi dở hoặc
hỏng dữ liệu, không phải chữ ký bảo mật.

## Quy tắc ghi và hiệu lực

App chuẩn hóa settings, ghi JSON atomically trước rồi ghi snapshot bằng temporary
file + replace + flush-to-disk. Nếu snapshot thiếu, hỏng hoặc không khớp JSON,
app tái tạo nó khi Settings được mở.

TSF v1 nạp snapshot trong lúc activation để không đọc file trên hot path của
`ITfKeyEventSink`. Thay đổi có hiệu lực sau khi người dùng kích hoạt lại profile
PHTV. Notification/TSF compartment để cập nhật tức thời sẽ được thêm sau khi
kiểm chứng AppContainer và vòng đời COM trên máy Windows thật.
