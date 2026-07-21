# Công cụ phát triển PHTV

## Lệnh chính

Chạy từ thư mục gốc repository:

```bash
scripts/dev.swift env-check
scripts/dev.swift build
scripts/dev.swift test
scripts/dev.swift analyze
scripts/dev.swift metadata-check
scripts/dev.swift dict-check
scripts/dev.swift release-build
```

`scripts/dev.swift` ưu tiên `DEVELOPER_DIR`, sau đó dùng Xcode đang được
`xcode-select` chọn, `/Applications/Xcode.app`, hoặc bản `Xcode*.app` khả dụng.
Vì vậy Xcode beta có thể dùng mà không cần đổi thiết lập toàn hệ thống:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer scripts/dev.swift test
DERIVED_DATA_PATH=/tmp/phtv-derived-data scripts/dev.swift build
```

`format` sửa định dạng Swift. `format-check` hiện là công cụ hỗ trợ cải tiến dần,
chưa phải CI gate cho toàn bộ mã nguồn cũ:

```bash
scripts/dev.swift format-check
scripts/dev.swift format
```

Để build và mở app bằng một lệnh, dùng:

```bash
scripts/build_and_run.swift run
scripts/build_and_run.swift debug
scripts/build_and_run.swift logs
scripts/build_and_run.swift verify
```

## Dictionary

Nguồn chuẩn được lưu tại:

- `docs/dictionary/en_words.txt`
- `docs/dictionary/vi_words.txt`

Các lệnh bảo trì:

```bash
swift scripts/tools/generate_dict_binary.swift --check-sources
swift scripts/tools/generate_dict_binary.swift --strict-check-sources
swift scripts/tools/generate_dict_binary.swift --normalize-sources
swift scripts/tools/generate_dict_binary.swift
```

Hai file `.bin` sinh ra phải được commit cùng thay đổi nguồn. CI sẽ thất bại nếu
nguồn không hợp lệ hoặc binary đã cũ.

## Release notes và appcast

`CHANGELOG.md` là nguồn nội dung duy nhất. Công cụ Swift render Markdown cho
GitHub Release và HTML tương đương cho Sparkle:

```bash
scripts/tools/release_notes.swift latest
scripts/tools/release_notes.swift render --version 3.4.2 --format markdown
scripts/tools/release_notes.swift check --version 3.4.2 \
  --appcast docs/appcast.xml --appcast docs/appcast-intel.xml
scripts/tools/release_notes.swift self-test
scripts/tools/repository_policy.swift check
```

Thông thường không cần tự sửa `<description>` trong appcast; workflow release sẽ
render và chèn nội dung trước khi publish.

## Tự động hóa

CI và release được định nghĩa tại `.github/workflows/`. Script trong repository
chỉ cung cấp các primitive có thể chạy lại ở local; khóa ký và notarization vẫn
chỉ được dùng trong môi trường release được bảo vệ.
