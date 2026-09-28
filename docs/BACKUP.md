# Nhập, xuất và sao lưu dữ liệu

Đối chiếu mã nguồn ngày 29/09/2026, sau thay đổi 3.6.1. **Nhập/xuất hiện chưa
phải bản sao đầy đủ của toàn bộ dữ liệu ứng dụng.** Hai luồng dưới đây có định
dạng và cách ghi đè khác nhau.

Nguồn đối chiếu: [SystemSettingsView](../Apps/macOS/PHTV/UI/SettingsTabs/SystemSettingsView.swift),
[MacroSettingsView](../Apps/macOS/PHTV/UI/SettingsTabs/MacroSettingsView.swift),
[MacroModels](../Apps/macOS/PHTV/Models/MacroModels.swift) và
[ClipboardHistoryState](../Apps/macOS/PHTV/State/ClipboardHistoryState.swift).

## Xuất/Nhập cấu hình trong Hệ thống

Mở **Cài đặt > Hệ thống > Dữ liệu & sao lưu > Xuất cấu hình**. File JSON có
`version: "2.0"`, ngày xuất và các phần dữ liệu tùy chọn. Phiên bản định dạng
backup độc lập với phiên bản ứng dụng.

| Nhóm dữ liệu | Có trong file xuất hiện tại? | Giới hạn |
| --- | --- | --- |
| Kiểu gõ, bảng mã, chính tả, Quick Telex, phụ âm nhanh | Có | Theo danh sách khóa trong `createBackup()` |
| Tự động khôi phục từ và chế độ khôi phục | Có | Cờ khôi phục phụ được đồng bộ lại khi nạp |
| Phím chuyển chính, phím khôi phục, phím tạm dừng, hotkey Picker | Có | Phím chuyển thứ hai và danh sách phím modifier đơn không được xuất |
| Macro và danh mục | Có | Lưu `MacroItem`, gồm loại snippet, ID và metadata sử dụng |
| Tiếng Anh theo ứng dụng, gõ từng phím, loại trừ viết hoa/gõ tắt | Có | File mới dùng các đối tượng chứa thông tin ứng dụng |
| Giao diện, âm báo, Safe Mode, layout compatibility, tùy chọn báo lỗi | Có một phần | Không bao gồm mọi khóa `UserDefaults` |
| Khởi động cùng macOS | Có khóa trong file | Khi nạp, trạng thái thực tế của `SMAppService` được ưu tiên; nhập không đăng ký login item |
| Dấu chấm khi gõ hai phím cách | Có | Nạp cấu hình áp dụng lại thiết lập hệ thống tương ứng |
| Clipboard: bật/tắt, hotkey, giới hạn, thời gian giữ | Không | Cần thiết lập lại riêng |
| Lịch sử Clipboard, mục ghim/đã lưu, nhóm, hotkey từng mục, ảnh/file đính kèm | Không | Nằm trong Application Support, ngoài định dạng backup này |
| Tùy chọn dùng Text Replacements của macOS | Không | `UseSystemTextReplacements` không có trong danh sách xuất |
| Phím tắt/cấu hình công cụ chuyển mã, thời gian lau bàn phím | Không | Không có trong danh sách xuất |
| Lịch sử Smart Switch theo ứng dụng, nội dung gần đây của Picker | Không | Không xuất toàn bộ trạng thái đã ghi nhớ |
| Quyền macOS, log, cache, mã cài đặt Klipy | Không | Quyền phải cấp trên máy đích; backup không phải ảnh chụp toàn bộ máy |

Nhập cấu hình **chỉ áp dụng những trường có trong file**. Khóa/phần bị thiếu
được giữ nguyên trên máy đích; đây không phải thao tác reset rồi thay thế toàn bộ.
Mảng macro hoặc danh sách ứng dụng có mặt trong file sẽ thay thế danh sách tương
ứng. Mảng rỗng sẽ xóa danh sách đó; trường bị thiếu không xóa.

File cũ có `excludedApps` là mảng bundle ID được chuyển sang đối tượng ứng dụng;
`excludedAppsV2` được ưu tiên nếu cả hai cùng có mặt. Tùy chọn cập nhật vẫn tuân
theo chính sách kênh stable và tự động cài đặt của ứng dụng.

## Xuất/Nhập trong Gõ tắt

File xuất riêng trong **Gõ tắt** chứa `categories` và danh sách macro với ba
trường `shortcut`, `expansion`, `categoryId`. **Không lưu `snippetType`, ID,
thống kê sử dụng hoặc ngày tạo.** Khi nhập lại, các mục được tạo như macro văn
bản tĩnh; snippet ngày/giờ/clipboard/random/counter không giữ được loại động.
Để giữ loại snippet, dùng **Xuất cấu hình** trong Hệ thống.

Luồng nhập Gõ tắt chấp nhận:

- JSON gồm `categories` và `macros`;
- JSON mảng các cặp `shortcut`/`expansion`;
- văn bản UTF-8, mỗi dòng `shortcut,expansion`; bỏ dòng trống và dòng bắt đầu
  bằng `#`. Đây là phép tách tại dấu phẩy đầu tiên, không phải parser CSV đầy đủ.

Macro nhập được **gộp** vào danh sách hiện có. Shortcut được chuẩn hóa Unicode,
cắt khoảng trắng đầu/cuối và so trùng không phân biệt hoa/thường; mục nhập sau
ghi đè mục trùng. Danh mục mới được thêm theo ID, danh mục cùng ID đang có được giữ.
Giá trị đếm hiện tại của snippet counter chỉ nằm trong bộ nhớ runtime, không nằm
trong cả hai định dạng xuất.

## Giới hạn cần khắc phục

Rà soát `SystemSettingsView.swift`, `MacroSettingsView.swift` và các model cho thấy:

1. Chưa có schema chung bao phủ mọi cài đặt/dữ liệu. Nhãn UI “toàn bộ cài đặt”
   hiện rộng hơn dữ liệu thực sự xuất.
2. Nhập cấu hình chưa kiểm tra phiên bản được hỗ trợ, danh sách khóa cho phép và
   kiểu/giới hạn giá trị từng khóa trước khi ghi `UserDefaults`.
3. `AnyCodableValue` chỉ hỗ trợ số nguyên, số thực, Bool và String; giá trị JSON
   không hỗ trợ có thể thành chuỗi rỗng thay vì báo lỗi.
4. Các phần được ghi lần lượt, chưa có rollback toàn bộ khi ghi thất bại;
   kết quả `MacroStorage.save` chưa được dùng để quyết định thông báo thành công.
5. `SettingsBackupDocument.init(configuration:)` tạo đối tượng trống thay vì
   đọc nội dung. Luồng **Nhập cấu hình** hiện dùng decoder riêng, nên vấn đề này
   thuộc đường đọc `FileDocument`, không phải mọi lần nhập đều nhận dữ liệu trống.
6. Kiểm thử hiện có xác nhận round-trip giá trị scalar và danh sách loại trừ
   macro, cùng lưu/nạp chế độ khôi phục. Chưa chứng minh quy trình xuất → nhập
   toàn bộ dữ liệu trên máy mới hay khả năng phục hồi khi ghi lỗi giữa chừng.

Lần rà soát này chạy **13/13 kiểm thử đạt** thuộc `SettingsBackupValueTests` và
`AutoRestoreSettingsPersistenceTests`; kết luận về các trường bị thiếu dựa trên
đối chiếu schema và đường đọc/ghi, không phải kiểm thử nhập lên dữ liệu thật.

## Trước khi chuyển máy hoặc reset

Xuất cấu hình trước, kiểm tra file có các phần cần giữ, và giữ bản sao dữ liệu
Application Support bằng công cụ sao lưu máy nếu cần lịch sử/mục Clipboard đã
lưu. Không chỉ dựa vào JSON cấu hình để xóa dữ liệu nguồn. Sau khi nhập, kiểm tra
macro động, danh sách ứng dụng, hotkey, Clipboard và bật lại login item/quyền
macOS trên máy đích nếu cần.

File xuất là JSON đọc được, không mã hóa. Nó có thể chứa nội dung macro và
đường dẫn ứng dụng; không đính kèm nguyên file vào issue công khai.

[Trang chủ](../README.md) • [Quyền riêng tư](PRIVACY.md) • [Kiểm thử](TESTING.md)
