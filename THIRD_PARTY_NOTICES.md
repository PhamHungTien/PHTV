# Third-Party Notices

PHTV được phát hành theo GNU AGPL v3. Tài liệu này liệt kê các thành phần và
nguồn dữ liệu bên thứ ba quan trọng; giấy phép gốc của từng dự án vẫn được áp
dụng cho thành phần tương ứng.

## Runtime và engine

- [Sparkle](https://github.com/sparkle-project/Sparkle) — framework cập nhật
  macOS, giấy phép MIT. Phiên bản và revision được pin trong Xcode project và
  `Package.resolved`.
- [UniKey](https://unikey.org/) — tham khảo thuật toán và quy tắc xử lý tiếng
  Việt; xem giấy phép/phân phối của dự án gốc.
- [OpenKey](https://github.com/tuyenvm/OpenKey) — tham khảo engine bộ gõ tiếng
  Việt; xem giấy phép trong repository gốc.

## Nội dung và dịch vụ

- [Unicode Emoji](https://unicode.org/emoji/) — dữ liệu và tên emoji theo
  Unicode; sử dụng theo [Unicode License](https://www.unicode.org/license.txt).
- [Klipy](https://klipy.com/api-overview) — API GIF/Sticker và nội dung quảng
  cáo. Việc dùng dịch vụ tuân theo điều khoản, attribution và
  [chính sách riêng tư của Klipy](https://klipy.com/support/privacy-policy).

## Công cụ build/phát hành

- [create-dmg](https://github.com/create-dmg/create-dmg) — tạo ảnh đĩa cài đặt.
- GitHub-maintained Actions (`checkout`, `upload-artifact`,
  `download-artifact`) và các action được liệt kê trong workflow. Workflow pin
  commit SHA để giảm rủi ro thay đổi tag ngoài ý muốn.

Nếu thêm dependency, dataset hoặc dịch vụ mới, pull request phải cập nhật file
này, privacy documentation/manifest nếu có dữ liệu ra khỏi máy và lockfile tương
ứng trước khi merge.
