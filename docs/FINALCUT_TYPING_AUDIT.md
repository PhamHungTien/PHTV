# Rà soát lỗi gõ đầu từ trong marker Final Cut Pro

Ngày: 2026-10-04.

## Kết quả

Đã xác nhận bằng kiểm thử hai vấn đề trong đường xử lý phiên gõ. Chưa có Final Cut Pro trên máy kiểm thử, nên quan hệ với báo cáo thực tế là giả thuyết có bằng chứng từ mã và mô phỏng engine, chưa phải tái hiện giao diện Final Cut.

1. **Phím tắt chữ cái có thể trở thành tiền tố của từ đầu tiên.** Callback gửi các phím không có Command/Control/Option vào engine mà chưa phân biệt timeline với vùng nhập. Không có kiểm tra đổi AX focused element trong cùng ứng dụng. Chuỗi `mm` rồi `tieengs` khiến engine xem đây là một từ sai chính tả, thay vì nhận riêng `tieengs` để tạo `tiếng`. Backspace gỡ từng ký tự trong bộ đệm; lịch sử từ có thể được phục hồi khi xoá hết từ. Đây là cơ chế phù hợp với triệu chứng phải xoá nhiều lần, không chứng minh số lần cố định là 4–5 trên mọi cấu hình.
2. **Reset phiên đang dùng một sự kiện ngắt từ có thể sinh output.** `requestNewSessionInternal` trước đây gửi sự kiện mouse vào `handleWordBreak`. Nhánh tự phục hồi tiếng Anh có thể trả `restoreAndStartNewSession`; nhánh dọn phiên chỉ chạy đầy đủ khi output là `doNothing`. Output từ lần reset không được gửi, nhưng trạng thái phục hồi vẫn còn. Test với từ `terminal` xác nhận cách cũ để lại code `5`, backspaceCount `7`, newCharCount `8` sau reset; cách mới trả cả ba về `0`.

## Thay đổi

- Thêm `PHTVTextFocusSessionService`, chỉ áp dụng cho bundle ID `com.apple.FinalCut` (không phân biệt hoa thường).
- Đọc focused element trước khi xử lý phím chữ. Text field, text area, combo box và custom element có text selection được nhận là vùng nhập. Khi đổi element hoặc đổi trạng thái nhập, bỏ phiên cũ. Chỉ các role điều khiển hoặc timeline đã biết mới được coi là không phải vùng nhập; role tùy biến chưa rõ vẫn gõ bình thường và đổi focus vẫn reset. Khi AX xác định không phải vùng nhập, truyền nguyên phím cho Final Cut, không đưa vào engine tiếng Việt hay macro tiếng Anh.
- Theo dõi modifier và hotkey vẫn chạy; trạng thái tự viết hoa tiếng Anh được dọn khi đổi vùng nhập. Synthetic events của PHTV tiếp tục được bỏ qua trước kiểm tra focus.
- AX lỗi/timeout: giữ hành vi xử lý cũ, không tự coi là mất focus. Safe Mode bỏ qua kiểm tra AX. Các lần đọc AX chia sẻ ngân sách chờ 10 ms trên mỗi phím; không tính đây là bảo đảm độ trễ thực tế của toàn callback.
- Thêm `resetInputSession` riêng để bỏ composition, lịch sử, macro, cờ tắt tạm và output cũ trong engine lock. Không thay đổi `startNewSession` vốn còn được dùng khi kết thúc từ bình thường.
- Reset lifecycle của event tap dọn cả bộ theo dõi focus.

## Phạm vi rà soát

Rà soát cấu trúc repository và các điểm gọi xuyên suốt đường nhập, không khẳng định mọi dòng của toàn bộ UI và dịch vụ phụ đã được kiểm toán thủ công.

| Luồng | Kết quả |
| --- | --- |
| Event tap, synthetic events, permission, Secure Input, recovery | Có bỏ qua sự kiện do PHTV phát; bộ theo dõi focus mới được dọn cùng lifecycle. |
| Hotkey, modifier, pause, restore, layout compatibility | Giữ thứ tự nhận hotkey và theo dõi modifier trước khi trả phím timeline. |
| Engine Telex/VNI, spelling, auto-English, macro, Delete, lịch sử từ | Xác nhận tiền tố timeline làm bẩn từ đầu; tách reset khỏi commit/restore. |
| App activation, Smart Switch, danh sách tiếng Anh, input source | Chuyển ngôn ngữ/app không thay thế được việc nhận biết đổi ô nhập trong cùng Final Cut. |
| AX context, cache, compatibility profile | Không có profile focus riêng cho Final Cut trước bản sửa; không tái sử dụng cache focus có độ trễ cho guard này. |
| Backspace, sync-key, Unicode output, browser/CLI strategies | Giữ nguyên cách phát ký tự; gọi reset phiên hiện hữu để dọn sync-key theo bảng mã. Không có bằng chứng buộc phải tăng delay hay đổi cách phát Unicode cho Final Cut. |
| Native text replacement và clipboard insertion | Không có bằng chứng chúng gây lỗi từ đầu được báo; không thay đổi các dịch vụ này. |

## Kiểm chứng

- `scripts/dev.swift test`: 593 test, 0 lỗi, 2 microbenchmark bị skip vì chưa bật `PHTV_PERFORMANCE_TESTS`.
- 12 test mới: 3 regression engine/reset và 9 test focus policy (timeline → tên marker → ghi chú, cùng element, AX lỗi, Safe Mode/phạm vi bundle).
- Đối chứng: thay riêng lệnh reset mới bằng sự kiện mouse cũ, chạy `scripts/dev.swift engine-test`; test `testFocusResetCannotEmitAnEnglishRestoreForPreviousField` thất bại với ba assertion nêu trên. Đã khôi phục bản sửa và chạy lại suite.
- Test host dùng cấu hình `Testing` sẵn có của repository, không thay bản PHTV người dùng đang chạy.

## Giới hạn và bước xác nhận trên Final Cut

Cần kiểm tra thực tế trên phiên bản Final Cut/macOS của người báo lỗi, nhất là AX role/focus của ô marker và custom title editor. AX không trả lời hoặc Safe Mode sẽ giữ đường xử lý cũ, nên bản sửa không đảm bảo khắc phục trường hợp đó. Focus đổi giữa lúc đọc AX và lúc ứng dụng nhận phím vẫn là giới hạn của event tap.

1. Trên timeline, dùng các phím chữ và mở marker bằng bàn phím (thử M, Shift-M, Option-M theo thao tác đang dùng).
2. Gõ `tieengs Vieetj` ngay ở ô tên; kiểm tra từ đầu nhận dấu mà không cần xoá.
3. Chuyển tên/ghi chú bằng Tab, đóng và mở lại marker, lặp lại khi phát/dừng timeline.
4. Thử chữ `m` trong tên, giữ Shift gõ chữ hoa, Backspace đầu ô, bật/tắt macro và tự phục hồi tiếng Anh.
5. Kiểm tra các phím tắt timeline không bị chuyển thành ký tự có dấu; thử cả ô tìm kiếm và title editor.

Apple mô tả M để thêm marker và Option-M để thêm rồi mở thông tin tại [Add and remove markers](https://support.apple.com/en-mide/guide/final-cut-pro/verf3fd3b5c/mac), và Shift-M để sửa tại [Edit and move markers](https://support.apple.com/guide/final-cut-pro/edit-and-move-markers-ver39727e41/mac). Quy tắc timeout theo từng AX object được mô tả trong [AXUIElementSetMessagingTimeout](https://developer.apple.com/documentation/applicationservices/1459345-axuielementsetmessagingtimeout).

Lượt review bổ sung: giữ trạng thái modifier qua reset do focus, xoá focus cache khi đổi ứng dụng (kể cả chưa gõ phím), và bỏ kết quả AX cũ nếu lifecycle thay đổi trong lúc truy vấn.

Kiểm chứng trước commit: Debug build, Release build, Analyze và metadata-check đều đạt. Thread Sanitizer chạy 20 test focus/runtime, không lỗi và không báo race.
