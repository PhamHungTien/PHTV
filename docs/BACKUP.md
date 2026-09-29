# Nhập, xuất và sao lưu dữ liệu

Từ **PHTV 3.6.2**, Xuất cấu hình dùng định dạng JSON `3.0`, bao gồm cài đặt
di động được hỗ trợ và dữ liệu người dùng do PHTV lưu. Phiên bản định dạng độc
lập với phiên bản ứng dụng; vẫn nhập được bản `1.0` và `2.0`.

Nguồn triển khai: [SettingsBackup](../Apps/macOS/PHTV/Models/SettingsBackup.swift),
[SettingsBackupSchema](../Apps/macOS/PHTV/Services/SettingsBackupSchema.swift),
[SettingsBackupService](../Apps/macOS/PHTV/Services/SettingsBackupService.swift) và
[MacroTransferCodec](../Apps/macOS/PHTV/Services/MacroTransferCodec.swift).

## Xuất/Nhập cấu hình trong Hệ thống

Mở **Cài đặt > Hệ thống > Dữ liệu & sao lưu > Xuất cấu hình**.

| Nhóm dữ liệu | Phạm vi |
| --- | --- |
| Bộ gõ | Kiểu gõ, bảng mã, chính tả, phụ âm nhanh, tự động khôi phục từ và chế độ, tùy chọn gõ tắt |
| Phím tắt | Hai phím chuyển Việt/Anh, modifier đơn trái/phải/Fn, khôi phục, tạm dừng, Picker, Clipboard và chuyển mã |
| Macro/danh mục | Toàn bộ `MacroItem`: ID, nội dung, loại snippet, danh mục, thống kê và ngày tạo |
| Quy tắc ứng dụng | Tiếng Anh theo ứng dụng, gõ từng phím, loại trừ viết hoa và gõ tắt |
| Clipboard | Bật/tắt, hotkey, giới hạn/thời gian giữ, lịch sử, ghim, mục đã lưu, nhóm và hotkey từng mục |
| Đính kèm Clipboard | Ảnh và file đã được PHTV lưu cache được nhúng vào JSON; nhập tạo cache mới trên máy đích |
| Giao diện/hệ thống | Menu bar, Dock, âm báo, Safe Mode, layout compatibility, báo lỗi, cập nhật, lau bàn phím, chuyển mã |
| Trạng thái đã lưu | Smart Switch theo ứng dụng, từ điển tùy chỉnh, emoji gần đây/tần suất, ID GIF/Sticker gần đây và tab Picker |
| Tích hợp macOS | Lưu tùy chọn Text Replacements, dấu chấm hai phím cách và Login Items; không sao chép kho Text Replacements của macOS |

Nhập **chỉ thay thế những phần có trong file**. Khóa/phần bị thiếu giữ nguyên
trên máy đích; mảng rỗng có mặt trong file xóa danh sách tương ứng. Không reset
toàn bộ trước khi nhập. Nếu chỉ nhập danh mục làm mất tham chiếu của macro đang
có, ứng dụng báo lỗi thay vì tạo dữ liệu mồ côi.

File cũ chứa `excludedApps` là mảng bundle ID được chuyển sang đối tượng ứng
dụng; `excludedAppsV2` được ưu tiên khi có cả hai. Chế độ khôi phục phụ trong
file cũ được chuyển sang chế độ tương ứng. Kênh cập nhật vẫn là stable.

Sau khi nhập, ứng dụng nạp lại cài đặt, macro, quy tắc ứng dụng, Smart Switch và
Clipboard. Tác vụ lưu Smart Switch cũ bị vô hiệu hóa để không ghi đè dữ liệu mới.
Chính sách số lượng/thời gian giữ Clipboard tiếp tục áp dụng; mục ghim và thư
viện đã lưu không bị giới hạn lịch sử thường xóa.

## Xuất/Nhập trong Gõ tắt

JSON xuất riêng có `version: "1.0"`, `categories` và `macros` đầy đủ,
giữ nguyên snippet ngày/giờ/clipboard/random/counter, ID, metadata, Unicode,
xuống dòng và khoảng trắng nội dung. JSON cũ thiếu loại snippet vẫn được đọc
như văn bản tĩnh; không thể suy lại loại động đã bị bản cũ bỏ khỏi file.

Luồng nhập chấp nhận:

- JSON gồm `categories` và `macros`, hoặc mảng `MacroItem`/cặp shortcut–expansion cũ.
- CSV/văn bản UTF-8: hai cột shortcut,nội dung; hỗ trợ dấu nháy kép, dấu phẩy
  trong nội dung, nháy kép thoát bằng `""`, nội dung nhiều dòng, BOM và CRLF.
- Với định dạng dòng cũ không có nháy, mọi phần sau dấu phẩy đầu tiên vẫn là
  nội dung. Dòng trống và dòng bắt đầu bằng `#` được bỏ qua; dòng lỗi khiến
  toàn bộ lần nhập bị từ chối, không âm thầm bỏ mất macro.

Macro nhập được **gộp** vào danh sách hiện có. ID trùng hoặc shortcut trùng sau
chuẩn hóa Unicode/cắt khoảng trắng/không phân biệt hoa thường được thay bằng
mục nhập sau. Nội dung không bị cắt khoảng trắng. Danh mục cùng ID được cập
nhật, danh mục mới được thêm. Macro và danh mục được ghi trong cùng giao dịch.

## Kiểm tra dữ liệu và phục hồi khi có lỗi

Trước khi ghi, kiểm tra phiên bản, khóa cài đặt cho phép, kiểu/miền giá trị,
giới hạn engine, ID/tham chiếu danh mục, cấu trúc Clipboard, dữ liệu Smart Switch
và đính kèm. Giá trị không hỗ trợ báo lỗi, không chuyển thành chuỗi rỗng.
Dữ liệu nguồn hỏng hoặc cache bị mất không bị coi là dữ liệu rỗng khi xuất.

Giao dịch lưu bản cũ vào `Application Support/PHTV/backup-import-journal.json`
trước khi thay đổi preferences hoặc file. Ghi thất bại sẽ hoàn tác; nếu ứng
dụng bị dừng giữa chừng, lần mở sau phục hồi trước khi nạp trạng thái. Nếu
phục hồi cũng thất bại, ứng dụng giữ journal, thông báo rồi thoát để tránh ghi
đè tiếp. Khắc phục dung lượng/quyền ghi trước khi mở lại; không xóa journal.

Đường dẫn trong file nhập không được dùng trực tiếp làm đích ghi. Cache được
tạo với tên mới trong kho PHTV; đường dẫn symlink bị từ chối. Giới hạn bảo vệ:
file cấu hình tối đa 512 MB, tổng ảnh/file nhúng tối đa 256 MB, file nhập Gõ tắt
tối đa 64 MB. Vượt giới hạn thì báo lỗi, không xuất/nhập một phần.

## Ranh giới và chuyển máy

- File gốc bên ngoài **chưa được PHTV cache** chỉ có tham chiếu; ứng dụng
  thông báo số tham chiếu cần chuyển riêng. Không đọc đệ quy thư mục cá nhân.
- Quyền Accessibility, quyền riêng tư macOS, kho Text Replacements của macOS,
  log, bản cứu hộ dữ liệu hỏng, cache mạng/GIF tạm, mã cài đặt Klipy và trạng
  thái phiên gõ không nằm trong backup. Bộ đếm snippet trong RAM vẫn reset khi
  khởi động lại như trước; loại snippet và prefix được giữ.
- Lịch sử GIF/Sticker lưu ID, không phải thư viện media offline; hiển thị còn
  phụ thuộc nội dung được dịch vụ tải về.
- Login Items được thử áp dụng trên máy đích. Nếu macOS cần duyệt hoặc đăng ký
  thất bại, thông báo phân biệt rõ “đã nhập dữ liệu” với “chưa áp dụng Login
  Items”. Phím tắt Clipboard không khả dụng/trùng cũng được cảnh báo.
- Giữ bản nguồn cho đến khi kiểm tra dữ liệu trên máy đích. Hủy hộp thoại
  không nhập dữ liệu. Bản 3.0 nên được nhập bằng PHTV 3.6.2 trở lên.

File xuất là JSON **không mã hóa**, có thể chứa văn bản/ảnh/file Clipboard,
macro, đường dẫn và dữ liệu riêng tư. Lưu ở nơi an toàn; không đưa nguyên file
lên issue công khai. File xuất do bạn chọn vị trí không tự xóa khi gỡ PHTV.

## Kiểm thử

`SettingsBackupServiceTests` dùng defaults suite và thư mục tạm riêng: round-trip
sang kho trống, đủ nhóm cài đặt, macro động/metadata, ảnh và cache file, thư viện
Clipboard, tương thích file cũ, thiếu/rỗng, đầu vào hỏng, lỗi ghi từng giai đoạn,
phục hồi journal, từ chối symlink và CSV. Xem [Kiểm thử](TESTING.md).

[Trang chủ](../README.md) • [Quyền riêng tư](PRIVACY.md)
