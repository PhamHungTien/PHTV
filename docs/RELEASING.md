# Phát hành PHTV

## Nguyên tắc

- `CHANGELOG.md` là nguồn duy nhất cho nội dung GitHub Release và Sparkle.
- Changelog của phiên bản mới phải có trong commit được tag.
- Không tái sử dụng version hoặc build number đã phát hành.
- Bản public gồm hai DMG riêng: Apple Silicon (`arm64`) và Intel (`x86_64`).

## Chuẩn bị release

1. Thêm `## [x.y.z] - YYYY-MM-DD` ngay dưới `Unreleased` trong `CHANGELOG.md`.
2. Chạy toàn bộ gate local:

   ```bash
   scripts/dev.swift metadata-check
   scripts/dev.swift dict-check
   scripts/dev.swift test
   scripts/dev.swift build
   scripts/dev.swift release-build
   scripts/dev.swift analyze
   ```

3. Kiểm tra nội dung GitHub Release sẽ được tạo:

   ```bash
   scripts/tools/release_notes.swift render \
     --version x.y.z \
     --format markdown
   ```

4. Merge/push commit chuẩn bị release vào `main` và chờ CI xanh.
5. Tạo annotated tag trên đúng commit:

   ```bash
   git tag -a vx.y.z -m "PHTV x.y.z"
   git push origin vx.y.z
   ```

Có thể chạy workflow thủ công với version hợp lệ, nhưng commit đang chọn vẫn
phải chứa changelog tương ứng.

## Workflow tự động

1. **Verify**: kiểm tra metadata/dictionary và chạy toàn bộ XCTest.
2. **Build**: tạo riêng arm64 và x86_64 bằng Developer ID Application.
3. **Package**: ký nested code, tạo DMG, notarize, staple và kiểm tra Gatekeeper.
4. **Sparkle**: ký EdDSA, giữ tối đa 30 phiên bản gần nhất và chèn HTML được
   render từ changelog.
5. **GitHub Release**: dùng Markdown từ cùng changelog, không dùng generated
   commit notes làm nội dung chính.
6. **Publish**: commit hai appcast và đồng bộ version/build mặc định của Xcode
   về `main`.
7. **Homebrew**: cập nhật URL và SHA256 theo kiến trúc.

Các GitHub Action được pin bằng commit SHA. Dependabot theo dõi phiên bản action;
Sparkle được pin bằng exact version trong Xcode project và revision trong
`Package.resolved`.

## Secrets cần thiết

- `CERTIFICATES_P12`
- `CERTIFICATE_PASSWORD`
- `APPLE_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- `APPLE_TEAM_ID`
- `SPARKLE_PRIVATE_KEY`
- `TAP_REPO_TOKEN`

Không in secret vào log. Certificate tạm phải nằm trong keychain riêng của job
và luôn được xóa ở bước `if: always()`.

## Xác minh sau phát hành

- Hai DMG có đúng version/build và đúng kiến trúc.
- `codesign --verify --deep --strict` thành công.
- `stapler validate` và `spctl` thành công.
- GitHub Release không phải draft và có đủ hai asset.
- Hai appcast có cùng version/build, description, chữ ký, URL và dung lượng đúng.
- Sparkle từ bản public trước nhận ra bản mới và hiển thị release notes.
- Homebrew cài đúng artifact trên Apple Silicon và Intel.

## Rollback và hotfix

Không sửa hoặc ký lại DMG dưới cùng version/build. Nếu artifact đã public có lỗi:

1. Tạm dừng appcast/Homebrew nếu bản lỗi gây mất dữ liệu hoặc crash nghiêm trọng.
2. Sửa trên `main`, tăng patch version và tạo build number mới.
3. Phát hành hotfix qua đầy đủ verify/sign/notarize gates.
4. Ghi rõ phạm vi ảnh hưởng và hướng khôi phục trong changelog.

Nếu chỉ appcast sai metadata nhưng DMG đúng, sửa appcast, chạy validator và commit
lại feed; không thay đổi `edSignature`, URL hoặc length bằng tay.
