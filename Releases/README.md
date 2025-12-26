# Release Notes

Thư mục này chứa release notes chi tiết cho các phiên bản PHTV.

## Cấu trúc

Mỗi phiên bản có một file `RELEASE_NOTES_X.Y.Z.md` riêng với:
- Tính năng mới
- Cải tiến
- Sửa lỗi
- Breaking changes (nếu có)

## Quy trình release

1. Tạo file `RELEASE_NOTES_X.Y.Z.md` với nội dung chi tiết
2. Update `docs/appcast.xml` với changelog (HTML format)
3. Build và sign DMG file
4. Tạo GitHub Release với DMG attached
5. Tag version: `git tag vX.Y.Z && git push --tags`

## Xem thêm

- [GitHub Releases](https://github.com/PhamHungTien/PHTV/releases)
- [Appcast Feed](https://phamhungtien.com/PHTV/appcast.xml)
