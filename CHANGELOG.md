# Changelog

All notable changes to PHTV will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [3.3.5] - 2026-07-13

### Tổng quan
PHTV 3.3.5 là bản bổ sung tính năng theo đề xuất của cộng đồng: viết hoa đầu câu nay có thể loại trừ **linh hoạt theo ngôn ngữ gõ** cho từng ứng dụng, và lịch sử Clipboard có thể **tự động xóa theo thời gian**. Cả hai đều được thiết kế để không làm thay đổi bất kỳ thiết lập nào bạn đang dùng.

### Điểm nổi bật
- **Viết hoa đầu câu: loại trừ linh hoạt theo ngôn ngữ gõ (#152)**
  - Trước đây, khi đưa một ứng dụng vào danh sách **Ứng dụng không viết hoa**, tính năng viết hoa đầu câu bị tắt cho **cả tiếng Việt lẫn tiếng Anh** — không thể tách riêng.
  - Nay mỗi ứng dụng trong danh sách có thêm lựa chọn phạm vi: **Cả hai** / **Chỉ khi gõ tiếng Anh** / **Chỉ khi gõ tiếng Việt**.
  - Ví dụ đúng nhu cầu thực tế: trong IDE, chọn *Chỉ khi gõ tiếng Anh* để không bị viết hoa khi gõ code, nhưng khi chuyển sang gõ tiếng Việt (viết chú thích) thì vẫn tự viết hoa đầu câu bình thường. Ứng dụng văn phòng như Word không nằm trong danh sách thì vẫn viết hoa bình thường ở cả hai ngôn ngữ.
  - **Tương thích ngược hoàn toàn**: các ứng dụng bạn đã thêm từ trước giữ nguyên phạm vi **Cả hai** — cập nhật không làm thay đổi thiết lập sẵn có.

- **Tự động xóa lịch sử Clipboard theo thời gian (#209)**
  - Tuỳ chọn mới trong **Cài đặt > Lịch sử Clipboard**: tự động xóa các mục cũ hơn **3 ngày / 1 tuần / 1 tháng / 3 tháng**, hoặc **Không giới hạn**.
  - **Mặc định là Không giới hạn** — PHTV không tự xóa lịch sử của bạn cho tới khi bạn chủ động chọn một mốc thời gian.
  - Mục hết hạn được dọn ngay khi: mở bảng lịch sử, sao chép nội dung mới, đổi cài đặt, khởi động ứng dụng, và tự quét lại mỗi giờ (mục vẫn cũ đi kể cả khi bạn không sao chép gì thêm).
  - Ảnh và file đính kèm của mục bị xóa cũng được dọn khỏi ổ đĩa, không để lại rác.
  - Giới hạn theo thời gian hoạt động song song với **Số mục tối đa** đã có: mục hết hạn bị xóa trước, sau đó mới áp giới hạn số lượng.

### Fixed and Improved
- Cơ chế loại trừ viết hoa được tách đúng theo hai đường xử lý riêng biệt của PHTV (viết hoa tiếng Việt nằm trong engine, viết hoa tiếng Anh nằm trong lớp xử lý sự kiện phím), nên phạm vi ngôn ngữ được áp dụng chính xác ở mọi tình huống — kể cả khi chuyển đổi ngôn ngữ giữa chừng.
- Thiết lập hỏng hoặc giá trị lạ không bao giờ âm thầm tắt viết hoa đầu câu, và mục clipboard có ngày ở tương lai (đổi giờ hệ thống, khôi phục backup) không bao giờ bị xóa nhầm.
- Bổ sung 18 test hồi quy cho hai tính năng, gồm cả kiểm chứng tương thích ngược của dữ liệu đã lưu. Toàn bộ test suite đạt **358/358 tests**.

### Ghi chú nâng cấp
- Không cần thao tác gì sau khi cập nhật: cả hai tính năng đều giữ nguyên hành vi cũ cho tới khi bạn chủ động thay đổi.
- Muốn dùng ngay: mở **Cài đặt > Gõ tiếng Việt** để chọn phạm vi ngôn ngữ cho từng ứng dụng không viết hoa, và **Cài đặt > Lịch sử Clipboard** để đặt thời gian tự động xóa.

## [3.3.4] - 2026-07-11

### Tổng quan
PHTV 3.3.4 sửa dứt điểm phần còn sót của lỗi gõ tắt có dấu (#146): khi bật đồng thời **Gõ Tắt** của PHTV và **Text Replacements** của macOS, các phím tắt có dấu (ví dụ `cđ`, `đc`) không được mở rộng.

### Điểm nổi bật
- **Gõ tắt có dấu hoạt động ổn định khi bật đồng thời macOS Text Replacements (#146)**
  - Nguyên nhân: khi bật cả **Gõ Tắt** của PHTV lẫn **Text Replacements** của macOS, PHTV nhường việc thay thế cho macOS đối với các phím tắt trùng nhau. Nhưng bộ thay thế của macOS căn cứ vào ký tự người dùng gõ trực tiếp, nên không thể nhận ra phím tắt có dấu (ví dụ `cđ`, `đc`) — vốn được PHTV tạo ra bằng biến đổi Telex ("cdd" → "cđ"). Kết quả: các phím tắt có dấu không được mở rộng.
  - PHTV nay **luôn tự xử lý mọi phím tắt có dấu** (chứa ký tự tiếng Việt), chỉ nhường cho macOS những phím tắt thuần ASCII — nơi macOS hoạt động ổn định và tránh nhân đôi.
  - Áp dụng cho cả phím tắt do người dùng tạo trong PHTV lẫn phím tắt nhập từ macOS Text Replacements: `cđ → cũng được`, `đc → được`… nay hoạt động ổn định.

### Fixed and Improved
- `PHTVSystemTextReplacementService`: chỉ nhường phím tắt thuần ASCII cho macOS; mọi phím tắt chứa ký tự tiếng Việt đều do PHTV tự mở rộng — không còn bị "nuốt" khi hai hệ thống cùng bật.
- Bổ sung 4 test hồi quy cho luồng nhường/xử lý phím tắt có dấu và ASCII; xác minh các test thất bại trên bản chưa sửa và đạt sau khi áp dụng fix. Toàn bộ test suite đạt **340/340 tests**.

### Ghi chú nâng cấp
- Nếu bạn dùng gõ tắt có dấu (ví dụ `cđ → cũng được`) và có bật **Text Replacements** của macOS, hãy cập nhật bản này — các phím tắt có dấu nay mở rộng đúng.

## [3.3.3] - 2026-07-09

### Tổng quan
PHTV 3.3.3 là bản sửa lỗi khẩn cấp: trên macOS 27, ứng dụng thoát ngay khi gõ phím đầu tiên. Đây là bản cập nhật bắt buộc cho người dùng macOS 27, đặc biệt nếu bạn dùng bàn phím không phải bố cục US.

### Điểm nổi bật
- **Sửa lỗi thoát ứng dụng khi gõ bất kỳ phím nào trên macOS 27 (#208)**
  - Nguyên nhân: từ 3.3.1, PHTV xử lý phím trên một luồng riêng để giao diện không làm chậm việc gõ. Nhưng bước quy đổi bố cục bàn phím (dành cho bàn phím không phải US) lại hỏi hệ thống về bố cục đang dùng ngay trên luồng đó — thao tác này bắt buộc phải chạy ở luồng chính, và macOS 27 kiểm tra nghiêm ngặt điều này nên làm ứng dụng thoát ngay ở phím đầu tiên.
  - PHTV nay **dựng sẵn bảng quy đổi bố cục bàn phím trên luồng chính** (lúc khởi động và mỗi khi đổi nguồn nhập liệu). Luồng xử lý phím chỉ đọc bảng đã dựng sẵn nên không còn chạm vào hệ thống bố cục bàn phím — vừa hết crash, vừa bỏ được một bước tra cứu khỏi đường gõ phím.
  - Lưu ý: tuỳ chọn tương thích bố cục bàn phím được PHTV **tự bật cho bàn phím không phải US**, nên lỗi này ảnh hưởng phần lớn người dùng bàn phím quốc tế trên macOS 27.
- **Sửa một lỗi tiềm ẩn khác trong cùng đường xử lý**
  - Các phím bổ trợ (Shift, Command, Option…) khi bị đem đi quy đổi bố cục có thể gây lỗi ở tầng hệ thống. PHTV nay bỏ qua chúng — các phím này vốn không cần quy đổi.

### Fixed and Improved
- Tách toàn bộ phần chạm vào Carbon TSM ra khỏi luồng bắt phím; bổ sung cơ chế dựng lại bảng quy đổi có gom nhóm (coalescing) để không dồn tác vụ khi gõ nhanh.
- Bổ sung 3 test hồi quy khoá chặt bất biến "luồng bắt phím không bao giờ tự quy đổi bố cục", có xác minh test thất bại trên bản chưa sửa và đạt sau khi áp dụng fix.
- Toàn bộ test suite đạt **336/336 tests**.

### Ghi chú nâng cấp
- **Người dùng macOS 27 nên cập nhật ngay.** Nếu ứng dụng đang thoát mỗi lần gõ, hãy tải bản này từ trang phát hành; bản cũ không tự cập nhật được nếu bạn không gõ được phím nào.
- Người dùng macOS 14–26 không gặp lỗi này, nhưng vẫn nên cập nhật vì đường xử lý phím được tinh gọn thêm.

## [3.3.2] - 2026-07-09

### Tổng quan
PHTV 3.3.2 sửa xung đột giữa hai tính năng gõ: khi bật **Thêm dấu chấm khi gõ 2 lần phím cách**, tính năng **Viết hoa đầu câu** ngừng hoạt động. Bản này cũng bổ sung một số tên thương hiệu vào từ điển tiếng Anh để chúng không bị Telex biến dạng khi gõ.

### Điểm nổi bật
- **Hai tính năng nay hoạt động cùng nhau**
  - Khi gõ hai lần phím cách, macOS thay chúng bằng ". " — nhưng PHTV không nhìn thấy phím chấm nào nên không biết câu đã kết thúc, dẫn tới chữ tiếp theo không được viết hoa.
  - PHTV nay hiểu rằng phím cách thứ hai chính là dấu kết thúc câu, và tự viết hoa chữ đầu câu tiếp theo — đúng như khi bạn gõ dấu chấm rồi phím cách.
  - Áp dụng cho cả chế độ gõ tiếng Việt và tiếng Anh. Gõ một phím cách bình thường giữa hai từ vẫn không bị viết hoa.
- **Bổ sung tên thương hiệu vào từ điển tiếng Anh**
  - Thêm `lapaz`, `lapazfood`, `lapazfoods`: trước đây gõ "lapazfoods" trong chế độ tiếng Việt bị Telex biến thành "lâpzfôds"; nay được nhận diện là từ tiếng Anh và giữ nguyên.

### Fixed and Improved
- Engine và lõi xử lý phím nhận thêm trạng thái "double-space tạo dấu chấm" để đồng bộ quyết định viết hoa đầu câu giữa hai chế độ gõ.
- Bổ sung test hồi quy cho cả hai chế độ (tiếng Việt và tiếng Anh), và test khôi phục từ thương hiệu từ từ điển tích hợp.
- Xác minh các test mới thất bại trên bản chưa sửa và đạt sau khi áp dụng fix; toàn bộ test suite đạt **333/333 tests**.

### Ghi chú nâng cấp
- Nếu bạn dùng tuỳ chọn **Thêm dấu chấm khi gõ 2 lần phím cách** (Cài đặt > Gõ tiếng Việt) cùng với **Viết hoa đầu câu**, hãy cập nhật bản này — hai tính năng nay phối hợp đúng.

## [3.3.1] - 2026-07-09

### Tổng quan
PHTV 3.3.1 tập trung sửa dứt điểm các lỗi được cộng đồng báo cáo: gõ tiếng Việt trong khung code của Notion, gõ tắt có dấu ngừng hoạt động sau khi cập nhật, treo máy khi dùng nhiều tài khoản macOS, và hiện tượng thi thoảng gõ ra chữ chậm. Lõi xử lý phím được chuyển sang luồng riêng ưu tiên cao — gõ phím không còn phụ thuộc vào bất kỳ tác vụ giao diện nào của ứng dụng. Bổ sung tuỳ chọn "Thêm dấu chấm khi gõ 2 lần phím cách" (mặc định tắt).

### Điểm nổi bật
- **Sửa lỗi gõ trong khung code (/code) của Notion**
  - Nguyên nhân gốc: Notion (Electron) chỉ mở cây accessibility khi có ứng dụng yêu cầu — PHTV chưa từng yêu cầu, nên cơ chế nhận diện khung code không hoạt động, backspace tổng hợp bị editor nuốt gây ra chữ lặp kiểu "chaào mưừng".
  - PHTV nay tự kích hoạt cây accessibility của Notion, nhận diện khung code chính xác và thay chữ bằng cơ chế **chọn vùng + gõ đè nguyên tử** — không còn phụ thuộc backspace; có cơ chế chờ ổn định con trỏ để gõ nhanh không bị lệch ký tự.
- **Gõ tắt / Text Replacements hoạt động ổn định với mọi bảng mã (#146)**
  - Sửa lỗi gõ tắt **có dấu** ngừng hoạt động sau khi cập nhật hoặc đổi bảng mã: bảng tra cứu gõ tắt trước đây bị "đóng khung" theo bảng mã tại thời điểm nạp; nay tự dựng lại theo đúng bảng mã đang dùng (kể cả khi Chuyển thông minh đổi bảng theo ứng dụng hoặc trong ngữ cảnh Spotlight).
  - Không còn phải mở tab Gõ tắt "gõ vài từ" để kích lại sau khi cập nhật.
- **Hết treo máy khi dùng nhiều tài khoản macOS (#196)**
  - Instance PHTV ở tài khoản nền không còn kiểm tra hay tự cài bản cập nhật: chỉ phiên đang giữ màn hình mới được phép — chấm dứt kịch bản tài khoản nền thay file ứng dụng ngay dưới chân tài khoản đang dùng.
  - Khi quay lại phiên, nếu lịch kiểm tra cập nhật đã quá hạn thì PHTV kiểm tra bù ngay.
- **Gõ phím không còn thi thoảng bị khựng (#205, #206)**
  - Bộ bắt phím được chuyển từ main thread sang **luồng riêng ưu tiên tương tác cao**: cửa sổ Cài đặt, kiểm tra cập nhật, picker hay bất kỳ việc giao diện nào cũng không thể làm chậm việc gõ nữa.
  - Đồng thời sửa lỗi crash tiềm ẩn trên macOS mới khi đọc nguồn bàn phím từ luồng bắt phím (TIS yêu cầu main thread): nay dùng cache và làm mới bất đồng bộ trên main thread.
- **Tuỳ chọn mới: "Thêm dấu chấm khi gõ 2 lần phím cách" (mặc định tắt)**
  - Nằm trong tab Gõ tiếng Việt > Tối ưu gõ, điều khiển trực tiếp thiết lập hệ thống macOS: mặc định PHTV tắt để hai phím cách ra đúng hai dấu cách khi gõ tiếng Việt; bật lại nếu bạn muốn dùng tính năng này của macOS.

### Fixed and Improved
- Thêm `ensureElectronAccessibility` (bật cây AX của Notion khi thành ứng dụng trước) và `selectBackwardForTypeover` (chọn vùng qua AX với retry-verify, tự khôi phục con trỏ khi thất bại).
- Bảng tra cứu gõ tắt lưu payload gốc và memoize theo từng bảng mã; nạp gõ tắt sau khi nạp cài đặt runtime lúc khởi động.
- Sparkle nhận biết phiên console (`PHTVSessionConsoleService` + chặn trong `SPUUpdaterDelegate`); chuyển kiểm tra nguồn bàn phím sang mô hình cache stale-while-revalidate; `autoEnableIfNeeded` của layout compat tự chuyển về main thread.
- Bổ sung 9 unit test mới (gõ tắt theo bảng mã, chính sách cập nhật theo phiên) — tổng cộng 325 test, tất cả đều đạt; kiểm chứng end-to-end tự động trên Notion và TextEdit.

### Ghi chú nâng cấp
- Bản cập nhật khuyến nghị cho tất cả người dùng, đặc biệt nếu bạn: gõ trong khung code của Notion, dùng gõ tắt có dấu, dùng nhiều tài khoản macOS trên một máy, hoặc từng thấy gõ thi thoảng bị chậm.
- Tuỳ chọn "Thêm dấu chấm khi gõ 2 lần phím cách" mặc định tắt — nếu bạn thích tính năng này của macOS, bật lại trong Cài đặt > Gõ tiếng Việt.

## [3.3.0] - 2026-07-08

### Tổng quan
PHTV 3.3.0 là bản cập nhật lớn về hiệu năng và độ gọn nhẹ: dung lượng sau cài đặt giảm khoảng **75 MB** nhờ định dạng từ điển hoàn toàn mới, lõi xử lý phím được tinh gọn để mỗi phím gõ tốn ít tài nguyên hơn đáng kể, trải nghiệm cấp quyền được thiết kế lại thân thiện hơn, và ứng dụng nay **tự dọn dẹp tàn dư của phiên bản cũ** sau mỗi lần cập nhật.

### Điểm nổi bật
- **Nhẹ hơn ~75 MB sau cài đặt — định dạng từ điển PHT5**
  - Từ điển tiếng Anh (phục vụ tính năng tự khôi phục từ tiếng Anh) giảm từ **81,4 MB xuống 8,2 MB**; từ điển Telex tiếng Việt giảm từ **1,85 MB xuống 0,19 MB**.
  - Định dạng trie nén thưa (sparse) mới: mỗi nút chỉ lưu các nhánh thực sự tồn tại thay vì bảng 26 con trỏ cố định, nhưng vẫn được nạp trực tiếp bằng memory-mapping — **không tốn thêm RAM hay thời gian giải nén khi khởi động**.
  - Đã xác minh tự động: đầy đủ 371.125 từ tra cứu chính xác, không có kết quả dương tính giả; giữ tương thích ngược với định dạng cũ.
- **Gõ phím nhẹ và mượt hơn**
  - Lõi xử lý sự kiện phím nay đọc toàn bộ trạng thái engine và cài đặt runtime bằng **một lần khóa duy nhất cho mỗi phím gõ** thay vì hơn 100 lần như trước, đồng thời đảm bảo mọi quyết định trong một phím gõ đều dựa trên một góc nhìn cài đặt nhất quán.
  - Vòng gửi ký tự (kể cả gõ tắt/macro) không còn khóa engine cho từng ký tự riêng lẻ.
  - Tìm kiếm emoji nhanh hơn rõ rệt: chỉ mục tìm kiếm được dựng sẵn một lần thay vì chuẩn hóa lại ~9.000 từ khóa cho mỗi ký tự người dùng nhập; bảng bỏ dấu tiếng Việt không còn bị khởi tạo lại ở mỗi lần gọi.
- **Trải nghiệm cấp quyền được thiết kế lại**
  - Khi PHTV phát hiện mất quyền (Trợ năng / Giám sát đầu vào), bảng hướng dẫn nay mở **thẳng vào bước "Quyền truy cập"** kèm đúng trang System Settings cần thiết — không phải bấm qua các bước giới thiệu như trước.
  - Trong lần cài đặt đầu tiên, System Settings không còn bật đè lên màn hình chào mừng; cửa sổ cấp quyền chỉ mở đúng lúc người dùng tới bước hướng dẫn cấp quyền, khi đang đọc chỉ dẫn từng bước.
  - Khi cả hai quyền được cấp đủ, onboarding hiển thị xác nhận rồi **tự động chuyển sang bước hoàn tất**; bổ sung ghi chú cho biết có thể cấp quyền sau nếu muốn.
  - Mục cấp quyền trên menu bar nay dẫn vào luồng hướng dẫn đầy đủ với trạng thái quyền cập nhật trực tiếp.
- **Tự dọn dẹp thông minh sau khi cập nhật**
  - Cơ chế bảo trì mới chạy **một lần duy nhất sau mỗi lần cập nhật phiên bản**, ở mức ưu tiên thấp, không ảnh hưởng khởi động.
  - Chỉ dọn theo danh sách cho phép tường minh trong các vị trí thuộc sở hữu của PHTV: khóa cài đặt cũ đã hoàn tất di trú (chỉ xóa khi giá trị mới đã tồn tại — không bao giờ làm mất cài đặt), và file media tạm cũ hơn 3 ngày.
  - Nền tảng này cho phép các phiên bản tương lai bổ sung quy tắc dọn dẹp một cách an toàn, có kiểm soát.

### Fixed and Improved
- Thêm `PHTVEngineHookSnapshot` và `PHTVEventDispatchSettings`: chụp kết quả engine + cài đặt runtime trong một lần khóa cho toàn bộ đường xử lý phím.
- Gom logic gửi ký tự từng bước có nhịp CLI (trước đây trùng lặp ở hai nơi) về `PHTVSendSequenceService.sendItemsStepByStep`; loại bỏ biến đếm không còn tác dụng trong đường gửi ký tự.
- `EmojiDatabase`: thêm chỉ mục tìm kiếm dựng sẵn và bảng tra cứu emoji theo ký tự, giúp lưới "dùng gần đây" không phải quét toàn bộ cơ sở dữ liệu mỗi lần hiển thị.
- Lịch sử Clipboard: loại so sánh trùng lặp toàn nội dung độ phức tạp bậc hai khi thêm mục mới; đường dẫn file lịch sử không còn tạo lại thư mục ở mỗi lần lưu.
- Bộ sinh từ điển (`generate_dict_binary.swift`) và bộ nạp trie đồng bộ định dạng PHT5, kèm kiểm tra biên đầy đủ khi đọc dữ liệu.
- Thêm `PHTVUpdateMaintenanceService` với phần chính sách tách thuần để kiểm thử; bổ sung 9 unit test mới (tổng cộng 316 test, tất cả đều đạt).

### Ghi chú nâng cấp
- Đây là bản cập nhật khuyến nghị cho tất cả người dùng: gõ nhẹ hơn, chiếm ít dung lượng đĩa hơn rõ rệt và quy trình cấp quyền dễ theo dõi hơn.
- Không cần thao tác gì sau khi cập nhật: từ điển định dạng mới nằm sẵn trong ứng dụng, và lần khởi động đầu tiên sẽ tự chạy dọn dẹp tàn dư phiên bản cũ một lần ở chế độ nền.
- Nếu trước đây bạn từng bị kẹt ở bước cấp quyền, hãy mở lại hướng dẫn từ menu bar — luồng mới sẽ đưa bạn thẳng tới đúng bước và đúng trang System Settings cần bật.

## [3.2.5] - 2026-06-11

### Tổng quan
PHTV 3.2.5 đồng bộ hóa toàn diện hệ thống phím tắt của PHTV Picker (Emoji) và Lịch sử Clipboard (Clipboard History), mang lại trải nghiệm phân biệt phím bổ trợ Trái/Phải (Left/Right Modifiers) nhất quán trên toàn bộ ứng dụng.

### Điểm nổi bật
- **Phân biệt phím sửa đổi Trái/Phải cho PHTV Picker & Clipboard**
  - Hỗ trợ ghi nhận đầy đủ cờ thiết bị của các phím bổ trợ khi người dùng gán phím tắt cho Picker và Clipboard.
  - Hiển thị trực quan nhãn phím tắt kèm chỉ thị "Trái" / "Phải" bằng Tiếng Việt (ví dụ: `⌥ Trái + E`, `⌃ Phải + V`).
- **Nâng cấp cơ chế so khớp phím tắt**
  - Tối ưu hóa `EmojiHotkeyManager` và `ClipboardHotkeyManager` để so khớp chính xác phím bổ trợ bên Trái hay bên Phải đối với cả tổ hợp phím thông thường (Key Down) và chế độ phím tắt đơn lẻ (Modifier-only).
  - Tự động tương thích ngược với các cấu hình phím tắt cũ (mặc định chấp nhận cả hai bên nếu cấu hình cũ không phân biệt Trái/Phải).

### Fixed and Improved
- Tích hợp hàm kiểm tra `matchesModifiers` linh hoạt cho cả hai trình quản lý phím tắt, giúp loại bỏ các hành vi kích hoạt nhầm phím tắt từ phím bổ trợ đối diện.
- Sửa đổi các view cấu hình phím tắt để lưu trữ chính xác thông tin cờ thiết bị thô (`rawFlags`).

## [3.2.4] - 2026-06-11

### Tổng quan
PHTV 3.2.4 mang đến hai cải tiến quan trọng về tính tương thích và hệ thống phím tắt: khắc phục triệt để lỗi xáo trộn chữ khi gõ tiếng Việt trên Safari (đặc biệt là các rich-text editor như TikTok Studio) và nâng cấp toàn diện hệ thống phím tắt chuyển đổi để phân biệt rõ ràng các phím bổ trợ bên Trái/Phải cũng như hoạt động ổn định với phím đơn lẻ.

### Điểm nổi bật
- **Khắc phục lỗi gõ tiếng Việt trong trình duyệt Safari**
  - Tự động nhận diện ngữ cảnh nhập liệu trong Safari: Khi người dùng gõ trên thanh địa chỉ (Address Bar), PHTV giữ nguyên chiến lược gõ từng bước để tránh lỗi nhân đôi ký tự.
  - Khi người dùng gõ trong nội dung trang web (Web Content - ví dụ như ô mô tả của TikTok Studio), PHTV tự động chuyển sang cơ chế gửi văn bản tổ hợp Unicode một lần (tương tự Chrome). Thay đổi này giúp DOM/React state của trang web không bị mất đồng bộ, giải quyết dứt điểm hiện tượng xáo trộn ký tự.
- **Phân biệt phím sửa đổi Trái/Phải (Left/Right Modifiers)**
  - Hệ thống phím tắt chuyển đổi ngôn ngữ hiện tại đã phân biệt chính xác các phím bổ trợ bên Trái hoặc bên Phải (ví dụ: `Option Trái + Z` sẽ không bị kích hoạt nhầm bởi `Option Phải + Z`).
  - Tên phím tắt hiển thị trong giao diện Cài đặt trực quan bằng Tiếng Việt (ví dụ: `⌥ Trái + Z`, `⌘ Phải + Space`).
- **Sửa lỗi phím tắt đơn lẻ ở phím tắt chính**
  - Khắc phục lỗi phím tắt chính không hoạt động khi được gán phím bổ trợ đơn lẻ (Shift, Fn, Control, Option, Command) trong khi phím tắt phụ vẫn hoạt động bình thường.
  - Đồng nhất và tối ưu hóa logic so khớp phím đơn lẻ cho cả phím tắt chính và phụ, đảm bảo nhận diện chính xác ở cả cấp độ KeyCode và Modifier Flags.

### Fixed and Improved
- Tích hợp kiểm tra `PHTVHotkeyService.singleModifierHotkeyStatus` vào `handleModifierPress` và `handleModifierRelease` để xử lý chính xác và ổn định các phím bổ trợ đơn lẻ.
- Cập nhật `phtv_normalizeSwitchKeyStatus` để cho phép các cờ Trái/Phải đi qua bộ lọc khi tải cấu hình từ UserDefaults.
- Bổ sung unit tests kiểm tra độ độc lập của phím bổ trợ Trái/Phải cho phím tắt đơn lẻ, đảm bảo tính ổn định lâu dài của hệ thống.

### Ghi chú nâng cấp
- Đây là bản cập nhật khuyến nghị cho tất cả người dùng Safari và những người dùng muốn cấu hình phím tắt chuyển đổi ngôn ngữ linh hoạt, chi tiết hơn.
- Nếu bạn gặp bất kỳ vấn đề nào sau khi cập nhật, hãy kiểm tra lại cấu hình phím tắt trong phần Cài đặt của PHTV để đảm bảo các phím tắt được ghi nhận chính xác theo mong muốn của bạn.

### Tổng quan
PHTV 3.1.8 tập trung sửa lỗi **Clipboard History không dán lại được ảnh hoặc file cũ**. Trước đây, một số ảnh chụp màn hình hoặc file đã copy có thể hiển thị trong lịch sử clipboard nhưng khi chọn lại và nhấn Enter thì không dán được, đặc biệt với các mục không phải mục clipboard gần nhất.

Nguyên nhân chính là clipboard của macOS có thể chứa cả dữ liệu ảnh và `file-url`. Khi lưu lịch sử, PHTV giữ được dữ liệu ảnh nhưng lúc dán lại lại ưu tiên đường dẫn file trước. Với screenshot hoặc file do app khác tạo, quyền truy cập file-url/sandbox extension có thể hết hiệu lực sau một thời gian, dẫn đến lỗi không dán được.

### Điểm nổi bật
- **Dán lại ảnh cũ ổn định hơn**
  - Nếu một mục Clipboard History có dữ liệu ảnh, PHTV nay ưu tiên dán lại chính dữ liệu ảnh đã lưu thay vì dán đường dẫn file tạm.
  - Sửa lỗi các mục kiểu `Screenshot ... .png` hiển thị trong lịch sử nhưng dán lại không ra nội dung.
  - Khi chuẩn bị paste ảnh, PHTV ghi lại cả PNG/TIFF phù hợp để nhiều ứng dụng đích nhận ảnh tốt hơn.
- **Dán lại file cũ đáng tin cậy hơn**
  - Khi clipboard chứa file, PHTV tạo thêm bản cache nội bộ cho các file nhỏ hợp lý.
  - Khi người dùng dán lại từ lịch sử, PHTV ưu tiên bản cache nội bộ; nếu cache không còn nhưng file gốc vẫn tồn tại thì tự fallback về đường dẫn gốc.
  - Cách này giảm phụ thuộc vào sandbox extension tạm thời của pasteboard macOS.
- **Dọn dữ liệu phụ tự động**
  - Cache file của Clipboard History được xoá khi người dùng xoá item, xoá toàn bộ lịch sử hoặc khi lịch sử bị giới hạn theo số mục tối đa.
  - Khi khởi động lại, PHTV cũng dọn các cache mồ côi không còn item tương ứng.
- **Hiển thị log cập nhật cho người dùng**
  - Cập nhật appcast arm64 và Intel để Sparkle hiển thị ghi chú bản 3.1.8 trong cửa sổ chuẩn bị cập nhật.
  - Người dùng có thể đọc rõ bản này sửa gì trước khi tải/cài đặt cập nhật.

### Fixed and Improved
- Thêm `ClipboardHistoryFileReference` để lưu metadata file, đường dẫn gốc và đường dẫn cache nội bộ.
- Thêm `ClipboardHistoryFileCache` để cache file clipboard vào Application Support của PHTV.
- Thêm resolver riêng cho paste payload, đảm bảo thứ tự ưu tiên: ảnh đã lưu > file khả dụng/cache > văn bản.
- Cải thiện xử lý pasteboard cho ảnh để tránh dán nhầm `public.file-url` đã hết quyền.
- Giữ tương thích với lịch sử clipboard cũ chưa có trường `fileReferences`.
- Bổ sung regression tests cho ảnh kèm file URL, cache file, fallback file gốc và decode lịch sử cũ.

### Ghi chú nâng cấp
- Đây là bản nên cập nhật nếu bạn dùng **Lịch sử Clipboard** để lưu ảnh chụp màn hình, ảnh copy từ app khác hoặc file trong Finder.
- Các mục ảnh/file mới được copy sau khi cập nhật sẽ ổn định nhất vì có thêm dữ liệu/cache mới.
- Một số mục file rất cũ vẫn có thể không dán lại được nếu file gốc đã bị xoá và trước đó chưa có cache nội bộ.

## [3.1.7] - 2026-05-21

### Tổng quan
PHTV 3.1.7 bổ sung chế độ **Lau bàn phím**, giúp người dùng tạm chặn phím bấm trong một khoảng thời gian ngắn để vệ sinh bàn phím an toàn hơn mà không cần thoát ứng dụng.

Bản này cũng hoàn thiện tài liệu người dùng và tài liệu kỹ thuật sau thay đổi quyền nhập liệu ở 3.1.6: PHTV nay giải thích rõ hai quyền cần thiết trên macOS là **Trợ năng** và **Giám sát đầu vào**, đồng thời mô tả cách xử lý khi quyền bị kẹt do TCC.

### Điểm nổi bật
- **Lau bàn phím**
  - Thêm tab `Lau bàn phím` trong Cài đặt.
  - Cho phép chọn thời lượng 30 giây, 1 phút, 2 phút hoặc 5 phút.
  - Khi bật, PHTV tạm bỏ qua `keyDown`, `keyUp` và `flagsChanged`; chuột/trackpad vẫn hoạt động để người dùng bấm Dừng.
  - Chế độ tự tắt khi hết thời gian để tránh người dùng bị kẹt.
  - Có thể mở nhanh từ menu bar: `Công cụ` > `Lau bàn phím...`.
- **Hiển thị release notes cho người dùng**
  - Cập nhật appcast arm64 và Intel để Sparkle hiển thị ghi chú bản 3.1.7 trong cửa sổ cập nhật.
  - Nội dung release notes tập trung vào tính năng mới, quyền cần thiết và lưu ý sau khi cập nhật.
- **Tài liệu đầy đủ hơn**
  - Cập nhật README, hướng dẫn cài đặt, FAQ, kiến trúc, đóng góp và bảo mật.
  - Làm rõ app hiện dùng event tap của app chính, không còn target InputMethodKit thử nghiệm.
  - Thêm hướng dẫn xử lý khi macOS báo thiếu quyền hoặc giữ quyền cũ.

### Fixed and Improved
- Thêm `PHTVKeyboardCleaningService` để quản lý trạng thái Lau bàn phím bằng state có khóa, tự hết hạn theo thời gian.
- Nối chế độ Lau bàn phím vào event tap hiện có để chặn sự kiện bàn phím ở tầng runtime.
- Thêm trạng thái, thanh tiến trình và nút Dừng trong giao diện Settings.
- Thêm regression tests cho việc chặn phím, tự hết hạn, dừng thủ công và giới hạn thời lượng an toàn.
- Dọn các script/artefact cũ liên quan đến `PHTVInputMethod` không còn dùng.

### Ghi chú nâng cấp
- Đây là bản nên cập nhật cho người dùng muốn vệ sinh bàn phím laptop hoặc bàn phím rời mà không vô tình nhập ký tự.
- Tính năng Lau bàn phím cần đủ hai quyền nhập liệu của PHTV: `Accessibility` và `Input Monitoring`.
- Nếu nút Bắt đầu bị khóa, hãy mở Cài đặt PHTV và cấp đủ quyền theo hướng dẫn trong tab Lau bàn phím hoặc Onboarding.

## [3.1.6] - 2026-05-20

### Tổng quan
PHTV 3.1.6 tập trung vào độ ổn định khi cấp quyền trên macOS và dọn lại project để chỉ giữ bộ gõ chính. Từ phiên bản này, ứng dụng nhận diện rõ cả hai quyền cần thiết để bộ gõ hoạt động ổn định: **Trợ năng** và **Giám sát đầu vào**.

Trên một số máy, PHTV có thể đã được cấp Trợ năng nhưng vẫn không bắt được phím vì thiếu Giám sát đầu vào. Bản cập nhật này hướng dẫn người dùng cấp đúng cả hai quyền và tự kiểm tra lại trạng thái quyền sau khi macOS áp dụng thay đổi.

Ngoài ra, nếu macOS giữ lại một mục quyền cũ/hỏng khiến PHTV vẫn báo mất Trợ năng dù người dùng đã cấp lại, PHTV sẽ làm mới riêng entry TCC của quyền đang thiếu trước khi mở System Settings để người dùng bật lại.

### Điểm nổi bật
- **Yêu cầu đủ 2 quyền nhập liệu**
  - PHTV nay kiểm tra riêng quyền `Accessibility` và `Input Monitoring`.
  - Onboarding hiển thị trạng thái của từng quyền để người dùng biết chính xác còn thiếu bước nào.
  - Nút hướng dẫn sẽ mở đúng mục cần cấp tiếp theo trong System Settings.
  - Khi người dùng cấp quyền xong, PHTV tự nhận diện lại và khởi tạo event tap tốt nhất có thể.
- **Tự phục hồi quyền tốt hơn**
  - Không còn retry event tap sai hướng khi máy đang thiếu Giám sát đầu vào.
  - Khi người dùng mở lại quyền đang thiếu, PHTV reset riêng entry TCC của Trợ năng hoặc Giám sát đầu vào để tránh trạng thái quyền bị kẹt.
  - TCC notification và polling runtime cùng cập nhật trạng thái hai quyền.
  - Trạng thái trên Settings, menu bar và báo cáo lỗi phản ánh đúng nguyên nhân: thiếu Trợ năng, thiếu Giám sát đầu vào, đang chờ khởi tạo, hoặc đã sẵn sàng.
- **Dọn project macOS**
  - Xoá target thử nghiệm `PHTVInputMethod`.
  - Xoá target test `PHTVInputMethodTests` và các source liên quan.
  - Scheme `PHTV` chỉ còn build app chính và `PHEngineTests`.
- **Sửa lỗi xoá văn bản đã chọn**
  - Cải thiện xử lý phím Delete/Backspace khi đang có vùng chọn.
  - Giảm khả năng bộ gõ can thiệp sai khi người dùng chỉ muốn xoá đoạn text đã bôi đen.

### Fixed and Improved
- Tách trạng thái runtime thành các pha riêng cho `accessibilityRequired`, `inputMonitoringRequired`, `waitingForEventTap`, `relaunchPending` và `ready`.
- Thêm kiểm tra `CGPreflightListenEventAccess()` và prompt `CGRequestListenEventAccess()` cho quyền Giám sát đầu vào.
- Cải thiện luồng mở System Settings cho cả Trợ năng và Giám sát đầu vào.
- Thêm guided repair dùng `tccutil reset Accessibility` và `tccutil reset ListenEvent` cho bundle hiện tại khi người dùng chủ động mở lại quyền đang thiếu.
- Cập nhật Onboarding, Settings status card, menu bar và bug report để hiển thị đủ thông tin quyền.
- Bổ sung regression tests cho readiness, guidance step, relaunch policy và event tap recovery khi thiếu Input Monitoring.
- Gỡ toàn bộ target `PHTVInputMethod`/`PHTVInputMethodTests` khỏi Xcode project.

### Ghi chú nâng cấp
- Đây là bản nên cập nhật cho tất cả người dùng, đặc biệt nếu PHTV không hoạt động dù đã cấp Trợ năng.
- Sau khi cập nhật, nếu macOS yêu cầu quyền, hãy cấp cả:
  - `System Settings` > `Privacy & Security` > `Accessibility` > bật PHTV.
  - `System Settings` > `Privacy & Security` > `Input Monitoring` > bật PHTV.
- Nếu PHTV vẫn chưa hoạt động ngay sau khi cấp quyền, hãy thoát hẳn PHTV và mở lại. Một số phiên bản macOS cần vài giây hoặc một lần mở lại ứng dụng để TCC áp dụng quyền mới.

## [3.1.5] - 2026-05-20

### Tổng quan
PHTV 3.1.5 là bản cập nhật quan trọng về phân phối và bảo mật. Từ phiên bản này, PHTV được build và ký bằng tài khoản Apple Developer với chứng chỉ Developer ID, giúp macOS nhận diện ứng dụng rõ ràng hơn và giảm cảnh báo khi cài đặt trên máy người dùng.

Do ứng dụng đã được ký bằng danh tính Apple Developer mới, macOS có thể yêu cầu người dùng cấp lại quyền Trợ năng một lần sau khi cập nhật. Đây là hành vi bình thường của macOS/TCC khi danh tính ký số của ứng dụng thay đổi.

### Điểm nổi bật
- **Ký bằng Apple Developer**
  - PHTV nay được ký bằng chứng chỉ Developer ID Application.
  - Bản phát hành có danh tính ứng dụng rõ ràng hơn với macOS.
  - Cải thiện độ tin cậy khi tải, cài đặt và chạy PHTV trên các phiên bản macOS mới.
- **Hỗ trợ notarization cho macOS**
  - Workflow phát hành đã sẵn sàng submit bản DMG lên Apple notarization.
  - DMG được staple notarization ticket sau khi Apple xác thực thành công.
  - Giảm khả năng macOS Gatekeeper chặn app khi người dùng mở lần đầu.
- **Cần cấp lại quyền Trợ năng một lần**
  - Sau khi cập nhật lên PHTV 3.1.5, nếu bộ gõ không hoạt động ngay, hãy mở `System Settings` > `Privacy & Security` > `Accessibility`.
  - Tìm `PHTV`, tắt rồi bật lại quyền cho PHTV, hoặc xóa PHTV cũ và thêm lại PHTV mới.
  - Thoát hẳn PHTV và mở lại ứng dụng.
  - Người dùng chỉ cần thực hiện bước này một lần sau khi chuyển sang bản đã ký bằng Apple Developer.

### Fixed and Improved
- Cải thiện quy trình build release cho macOS.
- Kiểm tra chữ ký ứng dụng và entitlements trong workflow phát hành.
- Giữ đúng quyền cần thiết của PHTV khi ký lại app bundle.
- Chuẩn bị quy trình phát hành ổn định hơn cho các bản cập nhật tiếp theo.

### Ghi chú nâng cấp
- Đây là bản nên cập nhật cho tất cả người dùng.
- Nếu PHTV báo đã có quyền Trợ năng nhưng không gõ được, hãy cấp lại quyền Trợ năng theo hướng dẫn ở trên.
- Nếu macOS vẫn giữ cache quyền cũ, hãy khởi động lại máy sau khi cấp lại quyền.

## [2.9.6] - 2026-04-19

### Fixed
- **Lặp phím dấu Telex trên từ đã mang dấu**: Sửa lỗi khi gõ lại cùng phím dấu trên một âm tiết đã có dấu có thể chèn thêm ký tự thường thay vì gỡ hoặc đổi dấu
  - Ví dụ: `porr` giờ trả về `por` thay vì `pỏr`
  - Nguyên nhân: nhánh ưu tiên giữ từ tiếng Anh đã chặn phím dấu quá sớm, khiến engine không kịp xử lý thao tác toggle dấu trên từ đang mang dấu
  - Đã bổ sung regression test cho cả render nội bộ và runtime output để tránh lỗi tái diễn

### Improved
- **Tương thích Apple Mail tốt hơn**: Thêm `com.apple.mail` vào các danh sách nhận diện ứng dụng dùng chiến lược gõ từng bước và Unicode tổ hợp
  - Cải thiện độ ổn định khi soạn thư trong Mail, đặc biệt ở các ô nhập có hành vi chỉnh sửa giống trình duyệt hoặc web app

## [2.6.7] - 2026-03-14

### Fixed
- **Backspace sau khôi phục tiếng Anh (#146)**: Sửa lỗi không thể xoá từ tiếng Anh được khôi phục để gõ lại tiếng Việt — phải xoá thêm cả dấu cách phía trước mới gõ được bình thường
  - Nguyên nhân: engine không lưu raw key states của từ vừa restore vào lịch sử (`typingStates`), khiến Backspace phục hồi sai trạng thái cũ và gây lệch giữa màn hình và engine
  - Cách sửa: lưu raw key states của từ tiếng Anh vào `typingStates` và xoá lịch sử cũ ngay khi restore; Backspace giờ hoạt động đúng: xoá space → khôi phục từ → xoá từng chữ → session sạch

### Added
- **Bản dựng riêng cho chip M và Intel**: Từ phiên bản này, PHTV được phân phối thành hai bản riêng biệt
  - `PHTV-2.6.7-arm64` dành cho Mac chip M (Apple Silicon) — nhẹ hơn, không mang code dư thừa
  - `PHTV-2.6.7-intel` dành cho Mac chip Intel (x86_64)
  - Bộ gõ tự động chọn đúng feed cập nhật theo CPU (`appcast.xml` cho arm64, `appcast-intel.xml` cho Intel)
  - **Người dùng Intel trên phiên bản cũ (≤ 2.6.6):** vui lòng tải thủ công `PHTV-2.6.7-intel.dmg` từ trang Releases

### Improved
- **Nhận diện từ tiếng Anh chính xác hơn**: Cải tiến logic phát hiện tổ hợp phụ âm không tồn tại trong tiếng Việt
  - Thêm nhận diện chữ cái đầu `f`, `j`, `w`, `z` (flutter, javascript, webpack, zoom)
  - Thêm tổ hợp 2 chữ: `kn` (knife, know)
  - Thêm tổ hợp 3 chữ: `chr`, `shr`, `str`, `spr`, `scr`, `thr` (chrome, shrink, string...)
  - Từ ≥ 7 ký tự có tổ hợp tiếng Anh được ưu tiên khôi phục dù trùng mẫu Telex
- **Từ điển tiếng Anh mở rộng** (+900 từ): Bổ sung hàng loạt từ chuyên ngành thường thiếu trong từ điển chuẩn
  - Viết tắt kỹ thuật: `sdk`, `gui`, `npm`, `pnpm`, `jwt`, `saml`, `oauth`, `grpc`, `tls`, `vpn`, `xss`, `csrf`, `cdn`, `ssr`, `pwa`...
  - AI/ML: `llm`, `gpt`, `openai`, `chatgpt`, `langchain`, `gemini`, `mistral`, `quantization`, `tokenizer`, `hallucination`
  - DevOps/Cloud: `kubectl`, `argocd`, `nginx`, `traefik`, `serverless`, `monorepo`, `webhook`, `hotfix`, `changelog`
  - Monitoring: `datadog`, `dynatrace`, `newrelic`, `splunk`, `kibana`, `opentelemetry`
  - Database/Messaging: `clickhouse`, `influxdb`, `rabbitmq`, `nats`, `protobuf`

### Performance
- **Tối ưu định dạng trie nhị phân (PHT4)**: Giảm kích thước `en_dict.bin` từ 103 MB xuống **78 MB** (−24%)
  - Con trỏ node: `UInt32` (4 byte) → `UInt24` (3 byte); kích thước node: 105 → 79 byte
  - Giữ nguyên toàn bộ 370.900+ từ, không trim

## [2.5.9] - 2026-02-23

### Added
- **Lịch sử Clipboard** — Tính năng mới lưu lại nội dung đã sao chép (văn bản, ảnh, đường dẫn file) và dán nhanh bằng phím tắt
  - Phím tắt mặc định: **⌃V** (Control + V), tuỳ chỉnh trong Cài đặt → Phím tắt
  - Tuỳ chỉnh số mục lưu tối đa (10–100, mặc định 30)
  - Tìm kiếm trong lịch sử clipboard
  - Giao diện Liquid Glass đồng bộ với PHTV Picker (macOS Tahoe)
  - Mặc định **tắt** — bật trong Cài đặt → Phím tắt → Lịch sử Clipboard
  - Toggle nhanh từ menu thanh trạng thái
- **Tuỳ chọn khôi phục phím khi gõ sai** — Đưa chức năng khôi phục phím khi gõ sai chính tả ra cài đặt để người dùng bật/tắt
  - Truy cập tại Cài đặt → Bộ gõ → Khôi phục phím khi gõ sai
  - Toggle nhanh từ menu thanh trạng thái → Tính năng → Khôi phục

## [2.1.4] - 2026-01-26

### Fixed
- **Terminal Commands Not Working (#121)**: Sửa lỗi các lệnh như `clear`, `grep`, `printf` không hoạt động đúng trong Terminal khi bật chế độ tiếng Việt
  - Thêm logic nhận diện sớm các tổ hợp phụ âm không có trong tiếng Việt (bl, br, cl, cr, dr, fl, fr, gl, gr, pl, pr, sc, sk, sl, sm, sn, sp, st, sw, tw, wr)

### Changed
- **Onboarding UI**: Thiết kế lại các thẻ công tắc trong bước "Tính năng cơ bản" với chiều cao đồng nhất
- **Settings Reorganization**: Gộp phần "Cơ bản" vào "Tối ưu gõ" để giao diện gọn gàng hơn
- **New Onboarding Feature**: Thêm công tắc "Giữ nguyên từ tiếng Anh" vào Onboarding

### Removed
- **Spell Check UI**: Loại bỏ giao diện (tính năng luôn bật)
- **Z/F/W/J Consonants UI**: Loại bỏ giao diện (tính năng luôn bật)
- **Restore on Invalid Word**: Loại bỏ hoàn toàn tính năng này
- **Search Items**: Cập nhật danh sách tìm kiếm, loại bỏ các mục đã xóa
- **Bug Report**: Loại bỏ thông tin các tính năng đã xóa khỏi báo cáo debug

## [2.1.1] - 2026-01-25

### Changed
- **Giao diện Glass tinh tế**: Tinh chỉnh hiệu ứng glass và hình nền trong phần Cài đặt.
- **Tối ưu tương thích**: Loại bỏ xử lý đặc biệt cho Raycast, cải thiện tính ổn định với launcher bên thứ ba.

## [2.1.0] - 2026-01-25

### Added
- **Onboarding System Settings Step**: Thêm bước hướng dẫn cài đặt hệ thống trong quy trình Onboarding
  - Hướng dẫn trực quan để tắt các tính năng tự động sửa lỗi của macOS
  - Thêm hình ảnh minh họa cài đặt Input Source trong System Settings
- **Image Zoom in Onboarding**: Click vào ảnh để xem phóng to với icon kính lúp
- **Help Button in Settings**: Thêm nút '?' vào thanh công cụ Settings để xem lại Onboarding

### Changed
- Cập nhật README.md và INSTALL.md với cảnh báo về cài đặt macOS

## [1.8.8] - 2026-01-20

### Fixed
- **Safari Address Bar Duplicate Character**: Sửa lỗi nhân đôi ký tự đầu tiên khi gõ tiếng Việt trên thanh địa chỉ Safari
  - Áp dụng chiến lược Shift+Left cho TẤT CẢ trang web trên Safari
  - Ngoại trừ Google Docs/Sheets/Slides/Forms (giữ SendEmptyCharacter để tránh mất ký tự)
  - Phát hiện Google Docs qua URL (`docs.google.com`) hoặc tiêu đề cửa sổ

### Cải tiến
- **Claude Code CLI**: Cải tiến vượt bậc cơ chế xử lý gõ tiếng Việt, hỗ trợ Claude Code v2.1.6 đến v2.1.12+.
- **Tài liệu**: Thêm hướng dẫn chi tiết về cách fix lỗi gõ tiếng Việt trong Claude Code CLI cho cả macOS và Windows.
- **Tính ổn định**: Tối ưu regex pattern và cơ chế tìm kiếm khối mã lỗi trong Claude Code CLI.

### Sửa lỗi
- Sửa lỗi không nhận diện được khối mã cần vá trong một số phiên bản Claude Code mới.

### Technical Details
- Thêm method `isSafariGoogleDocsOrSheets` để phát hiện Google Docs/Sheets qua Accessibility API
- Cải thiện `isSafariAddressBar` với kiểm tra AXTextField/AXComboBox role trước
- Cập nhật regex pattern cho Claude Code 2.1.12+ với `\S+` thay vì `\w+`

## [1.7.7] - 2026-01-18

### 📢 Lời Nhắn Từ Tác Giả

Xin chào các bạn,

Hôm nay tôi rất tiếc phải thông báo rằng gia đình tôi đang trong thời gian tang lễ của ông ngoại. Do đó, việc cập nhật và hỗ trợ ứng dụng có thể bị chậm trễ trong vài ngày tới.

Version 1.7.7 này được phát hành để khắc phục một số lỗi quan trọng ảnh hưởng đến trải nghiệm gõ tiếng Việt trên các trình duyệt web, đặc biệt là Google Docs và Google Sheets. Tôi mong các bạn thông cảm cho sự chậm trễ này và cảm ơn sự ủng hộ của các bạn.

Kính chúc sức khỏe,
Phạm Hùng Tiến

---

### Fixed
- **Google Docs/Sheets Input Issues**: Sửa lỗi mất ký tự khi gõ tiếng Việt trên Google Docs, Google Sheets và các rich text editor khác trong trình duyệt
  - Phát hiện vấn đề: Chiến lược "Shift+Left selection" gây mất ký tự (ví dụ: "đến Việt" → "ếnới iệt")
  - Áp dụng chiến lược mặc định của OpenKey: SendEmptyCharacter + backspace thông thường
  - Hoạt động ổn định trên tất cả trình duyệt: Chrome, Safari, Firefox, Edge, Brave...
  - Đảm bảo tương thích với autocomplete và rich text editing
- **Browser Input Strategy**: Loại bỏ chiến lược "Shift+Left" không ổn định, quay về phương pháp đã được OpenKey kiểm chứng qua nhiều năm

### Technical Details
- Nghiên cứu sâu mã nguồn OpenKey để hiểu đúng cơ chế xử lý browser input
- OpenKey có 2 chế độ: mặc định (SendEmptyCharacter) và tùy chọn (Shift+Left khi user bật setting)
- PHTV trước đây force enable Shift+Left cho tất cả Chromium browsers → gây lỗi
- Bây giờ PHTV tuân theo OpenKey's default: đơn giản, ổn định, đã được verify

## [1.6.8] - 2026-01-11

### Added
- **Binary Integrity Protection System**:
  - SHA-256 hash tracking giữa các lần khởi động để phát hiện binary modifications
  - Architecture detection (Universal Binary vs arm64-only) để phát hiện CleanMyMac stripping
  - Code signature verification với codesign --verify --deep --strict
  - Real-time notifications (BinaryChangedBetweenRuns, BinaryModifiedWarning, BinarySignatureInvalid)
  - Performance: Detection < 200ms (150x nhanh hơn), Recovery 95% success rate (3x tốt hơn)
- **PHTVBinaryIntegrity Class**: Quản lý toàn bộ logic binary integrity checking
- **BinaryIntegrityWarningView**: SwiftUI view hiển thị cảnh báo và hướng dẫn khắc phục 3 phương án
- **scripts/fix_accessibility.sh**: Script tự động khôi phục quyền Accessibility (< 15s, 20x nhanh hơn)
- **Bug Report Enhancement**: Hiển thị binary architecture và integrity status trong bug reports

### Changed
- **PHTVManager Code Cleanup**: Giảm 23% code (từ 782 xuống 601 dòng) bằng cách delegate sang PHTVBinaryIntegrity
- **AppDelegate Startup**: Thêm binary integrity check khi khởi động để early detection
- **Project Organization**: Tổ chức lại file structure (scripts/ directory, separate integrity class)

### Fixed
- **Swift Optional Interpolation Warning**: Sửa cảnh báo trong BugReportView.swift với nil-coalescing operator
- **Build Configuration**: Thêm PHTVBinaryIntegrity.m vào Xcode project.pbxproj build phases
- **CleanMyMac Detection**: Phát hiện và cảnh báo khi binary bị stripped, tránh mất quyền TCC vĩnh viễn

## [1.6.5] - 2026-01-11

### Fixed
- **Triệt để vấn đề mất quyền Accessibility không phục hồi được**:
  - Thêm TCC notification listener - phát hiện thay đổi quyền ngay lập tức từ hệ thống (< 200ms)
  - Implement aggressive permission reset - force reset TCC cache khi cấp lại quyền
  - Cải thiện khả năng recover với multiple retry attempts (3 lần) và progressive delays
  - Tự động kill và restart tccd daemon để invalidate TCC cache ở process-level
  - Cache invalidation thông minh - clear cả result và timestamp
  - Xử lý edge case: user toggle quyền nhiều lần liên tiếp
  - Tự động đề xuất khởi động lại app nếu quyền không nhận sau 3 lần thử
  - Người dùng giờ có thể cấp/thu hồi/cấp lại quyền bao nhiêu lần cũng được

### Changed
- **Cải thiện GitHub Templates**:
  - Bug report template: thêm macOS 26.x, architecture, console logs section, enhanced troubleshooting
  - Pull request template: comprehensive testing checklist, security review, before/after screenshots

## [1.5.9] - 2026-01-09

### Fixed
- **Khắc phục triệt để lỗi quyền trợ năng (Accessibility)**:
  - Sửa lỗi ứng dụng không nhận quyền ngay cả khi đã cấp trong System Settings.
  - Loại bỏ yêu cầu khởi động lại ứng dụng sau khi cấp quyền.
  - Sử dụng phương pháp kiểm tra quyền tin cậy hơn (CGEventTapCreate).
- **Cải thiện Code Signing**:
  - Bắt buộc ký số (Mandatory Code Signing) để đảm bảo bảo mật và tránh lỗi TCC trên macOS mới.
  - Sửa lỗi workflow build tự động trên GitHub Actions.
- **Quyền Input Monitoring**:
  - Bổ sung entitlements cần thiết để hoạt động trơn tru trên macOS 14/15.
- **Tự động khôi phục từ tiếng Anh**:
  - Sửa lỗi không khôi phục được các từ có phụ âm đôi cuối (address, access, success...).
  - Mở rộng từ điển tiếng Anh lên 7,600 từ.

## [1.5.0] - 2026-01-05

### Added
- **Enhanced Non-Latin Keyboard Detection**: Tự động chuyển về English khi dùng bàn phím non-Latin
  - Hỗ trợ: Japanese, Chinese, Korean, Arabic, Hebrew, Thai, Hindi, Greek, Cyrillic, Georgian, Armenian, v.v.
  - Tự động khôi phục Vietnamese khi chuyển lại bàn phím Latin
  - Hiển thị tên bàn phím thực tế trong log

### Removed
- **Chromium Fix**: Xóa tính năng sửa lỗi Chromium (gây nhiều lỗi hơn là giải quyết)
- **Typing Stats**: Xóa tính năng thống kê gõ phím

### Changed
- **English Dictionary**: Xóa từ "fpt" khỏi từ điển

## [1.4.6] - 2026-01-04

### Changed
- **RAM Optimization**: Cache menu bar icons, sử dụng @AppStorage thay vì @EnvironmentObject
- **Lazy Loading Settings**: Implement lazy loading cho các tab Settings để giảm memory usage
- **Bug Report Improvements**: Hiển thị full error/warning messages, ưu tiên errors trước warnings, tăng log time range

### Fixed
- **Memory Leaks**: Cleanup NotificationCenter observers trong AppState và TypingStatsManager
- **WindowController Observer**: Sử dụng block-based pattern với weak self
- **WKWebView Cleanup**: Thêm cleanup trong ReleaseNotesView với Coordinator và dismantleNSView
- **MacroListView Animation**: Tối ưu animation performance

## [1.4.5] - 2026-01-04

### Added
- **Check for Updates in Menu Bar**: Thêm menu item "Kiểm tra cập nhật" vào menu bar
- **Language Switcher UI**: Cải thiện UI chuyển đổi ngôn ngữ với Picker và checkmark display

## [1.4.4] - 2026-01-04

### Fixed
- **Vietnamese Input in Apple Apps**: Thêm nhiều Apple apps vào forcePrecomposedAppSet
  - System Settings (search bar)
  - Finder (search bar)
  - Weather, Podcasts, Passwords, Books
  - Reminders, Journal, Game Center

## [1.4.3] - 2026-01-04

### Changed
- **CI/CD Improvements**: Cải thiện workflow tự động
- **Auto-increment Build Number**: Tự động tăng build number và commit Info.plist sau release

### Fixed
- **Build Number**: Sửa build number cho phiên bản 1.4.3

## [1.4.2] - 2026-01-04

### Added
- **Automated CI/CD**: Thêm GitHub Actions workflow tự động build và release
- **Code Signing**: Tự động sign app với Apple Development certificate trong CI
- **Sparkle Auto-Update**: Tự động cập nhật appcast.xml và Homebrew formula khi release

### Changed
- **Build Infrastructure**: Chuyển sang macOS 26 runner để hỗ trợ đầy đủ Liquid Glass APIs
- **Release Process**: Tự động hóa hoàn toàn quy trình release (build → sign → DMG → appcast → Homebrew)

### Fixed
- **Auto-Update**: Sửa lỗi Sparkle không thể cài đặt bản cập nhật do app chưa được code sign

## [1.3.8] - 2026-01-03

### Added
- **Emoji expansion**: Thêm 622 emoji mới từ Unicode v17.0, tăng tổng số lượng từ 841 lên 1,463 emoji
- **Liquid Glass comprehensive**: Áp dụng hiệu ứng Liquid Glass toàn diện cho tất cả Settings components
- **Auto cleanup**: Tự động xóa file GIF đã tải về sau 5 giây để tránh rác ứng dụng
- **Backup improvements**: Bao gồm cả cài đặt menu bar và dock trong backup/export

### Changed
- **Settings merge**: Gộp tab Compatibility vào tab Ứng dụng để giao diện gọn gàng hơn (từ 8 tabs xuống 7 tabs)
- **Settings transparency**: Cải thiện độ trong suốt của cửa sổ Settings với native materials
- **UI unification**: Thống nhất thiết kế StatusCard và SettingsCard trên toàn bộ app
- **About tab redesign**: Loại bỏ gradient background sau icon app để giao diện sạch hơn

### Fixed
- **PHTV Picker reliability**: Sửa lỗi paste emoji/gif đôi khi không hoạt động (system beep) bằng cách thêm delay 0.15s trước khi paste
- **App focus restoration**: Khôi phục focus về chat app sau khi đóng PHTV Picker
- **Card heights consistency**: Ngăn subtitle text wrap để đảm bảo card heights đồng đều
- **Glass effect display**: Ẩn background mặc định của TextEditor để hiệu ứng glass hiển thị đúng

## [1.3.7] - 2026-01-02

### Fixed
- **Menu bar and dock settings**: Khôi phục cài đặt thanh menu và dock đã bị xóa nhầm khi xóa theme color

## [1.3.6] - 2026-01-02

### Added
- **Liquid Glass design**: Áp dụng thiết kế Liquid Glass hiện đại từ Apple cho PHTV Picker trên macOS 26+
- **Window resizability**: Sử dụng SwiftUI .windowResizability(.contentSize) chuẩn từ Apple (WWDC 2024)
- **Always on Top setting**: Cài đặt giữ cửa sổ Settings luôn ở trên các app khác
- **Run on Startup improvement**: Áp dụng ngay lập tức khi bật/tắt (không cần restart)

### Changed
- **PHTV Picker branding**: Đổi tên "Emoji Picker" thành "PHTV Picker" cho nhất quán
- **Settings card alignment**: Căn chỉnh SettingsCard đồng nhất trên tất cả các tab
- **Picker visibility**: Giảm độ trong suốt để dễ nhìn hơn (Glass.clear → Glass.regular)
- **Settings UI sync**: Tất cả tab cài đặt có thiết kế nhất quán với Liquid Glass principles

### Fixed
- **Selected text replacement**: Xử lý đúng việc thay thế văn bản đã được highlight/select
- **Auto-focus search**: Con trỏ tự động vào ô tìm kiếm trong tab Emoji (đồng bộ với GIF/Sticker)
- **Window size constraints**: Cố định kích thước cửa sổ Settings (800-1000x600-900)

### Removed
- **Redundant hotkey card**: Loại bỏ card "Phím tắt hiện tại" không cần thiết trong tab Phím tắt

## [1.3.5] - 2026-01-02

### Fixed
- **Settings window z-order**: Sửa lỗi cửa sổ Settings bị ẩn sau các app khác (Issue #60)
- **GIF click tracking**: Sửa lỗi click GIF không chính xác so với vị trí chuột
- **Duplicate GIF paste**: Sửa lỗi paste 2 GIF khi chỉ click 1 lần
- **Auto English detection**: Sửa lỗi từ tiếng Anh như "fix", "mix", "box" không được restore khi bật auto English
- **Vietnamese tone mark detection**: Cải thiện logic phát hiện từ tiếng Việt có dấu ("đi", "đo", "đa") để không bị nhầm với tiếng Anh

### Improved
- **GIF grid layout**: Cải thiện từ 4 cột xuống 3 cột (120px mỗi thumbnail) cho tracking chính xác hơn
- **Multi-format clipboard**: Hỗ trợ paste GIF vào nhiều app hơn (iMessage, Zalo, Messenger Web)

## [1.3.4] - 2026-01-01

### Added
- **Modern Emoji Picker**: Emoji picker hiện đại với đầy đủ categories
- **GIF Picker**: Tích hợp Klipy API - GIF picker miễn phí không giới hạn
- **Auto-paste GIF**: Click là gửi ngay, không cần Cmd+V
- **GIF search**: Tìm kiếm GIF theo từ khóa tiếng Việt và tiếng Anh
- **Klipy monetization**: Tích hợp quảng cáo Klipy để duy trì miễn phí

### Changed
- **Hotkey**: Thêm Cmd+E để mở Emoji/GIF picker nhanh
- **Website**: Thêm GitHub Pages tại phamhungtien.github.io/PHTV

### Fixed
- **EdDSA signing**: Cập nhật EdDSA signing key cho Sparkle updates

## [1.3.3] - 2025-12-30

### Added
- **GIF API**: Chuyển từ Giphy sang Klipy API cho unlimited free GIF
- **App-ads.txt**: Thêm app-ads.txt cho ad network verification

### Changed
- **Performance**: Tối ưu hiệu suất GIF loading
- **UI**: Cải thiện giao diện GIF picker

## [1.3.2] - 2024-12-29

### Added
- **Text Snippets**: Gõ tắt động với nội dung thay đổi theo ngữ cảnh
  - Ngày hiện tại (format tùy chỉnh)
  - Giờ hiện tại
  - Ngày và giờ
  - Nội dung clipboard
  - Random từ danh sách
  - Counter tự động tăng
- **Từ điển tùy chỉnh**: Thêm từ tiếng Anh/Việt để nhận diện chính xác hơn
- **Import/Export cài đặt**: Sao lưu và khôi phục toàn bộ cài đặt ra file .phtv-backup

### Changed
- **Settings Reorganization**: Tổ chức lại từ 12 tabs xuống 11 tabs
  - Gộp "Nâng cao" vào "Bộ gõ" thành section "Phụ âm nâng cao"
  - Sắp xếp theo mức độ sử dụng: Bộ gõ → Phím tắt → Gõ tắt → ...
- **Hotkey UI**: Thiết kế mới với gradient, hover effects, và radio buttons
- **Search**: Mở rộng từ 40 lên 61 mục tìm kiếm cho tất cả chức năng
- **English Dictionary**: Bổ sung thuật ngữ công nghệ và thương hiệu phổ biến

### Fixed
- Sửa lỗi phím Backspace không reset trạng thái khi gõ tiếng Việt
- Sửa lỗi Sendable conformance trong SettingsBackup types

## [1.3.1] - 2024-12-28

### Changed
- **Settings Reorganization**: Tổ chức lại cài đặt thành 9 tab hợp lý hơn
  - **Ứng dụng**: Phím chuyển thông minh, Nhớ bảng mã, Loại trừ ứng dụng, Gửi từng phím
  - **Giao diện**: Màu chủ đạo, Icon menu bar, Hiển thị Dock
  - **Tương thích**: Chromium fix, Bàn phím, Claude Code, Safe Mode
  - **Hỗ trợ**: Kết hợp Thông tin + Báo lỗi với tab con
- **Advanced Settings**: Đơn giản hóa chỉ còn cài đặt phụ âm nâng cao
- **Search**: Cập nhật danh sách tìm kiếm theo cấu trúc tab mới

## [1.3.0] - 2024-12-28

### Added
- **Safe Mode**: Tự động phát hiện và khôi phục khi Accessibility API gặp lỗi
- **macOS Ventura**: Hạ yêu cầu từ macOS 14.0 (Sonoma) xuống 13.0 (Ventura)
- **macOS 26 Liquid Glass**: Hỗ trợ hiệu ứng Liquid Glass trên macOS 26
- **OCLP Support**: Tương thích tốt hơn với máy Mac chạy OpenCore Legacy Patcher

### Changed
- **Settings Window**: Thiết kế lại với kích thước tối ưu 950x680, blur background
- **Thread Safety**: Xử lý window management an toàn với Swift 6 concurrency

### Fixed
- Sửa vòng lặp vô hạn khi mở settings từ menu bar
- Sửa lỗi nút "Tạo gõ tắt đầu tiên" không hoạt động khi tính năng gõ tắt chưa bật
- Tự động bật tính năng gõ tắt khi tạo gõ tắt đầu tiên
- Sửa background trong suốt không đẹp mắt
- Sửa kích thước cửa sổ quá nhỏ khi mở lần đầu
- Sửa Swift 6 concurrency warnings trong SettingsWindowHelper

## [1.2.6] - 2024-12-26

### Changed
- **Performance**: Giảm tần suất kiểm tra quyền truy cập từ mỗi giây xuống 5 giây (tiết kiệm 80% CPU)
- **Performance**: Tăng cache duration từ 1 giây lên 10 giây
- **Performance**: Giảm 83% số lần tạo test event tap (từ 40 xuống 6 lần/phút)
- **UX**: Delay 10 giây sau khởi động mới check update để tránh lỗi network
- **UX**: Loại bỏ dialog "newest version available" khi không có update

### Added
- **Bug Report**: Thêm runtime state tracking (accessibility permission, event tap status, front app info)
- **Bug Report**: Thêm performance metrics (memory usage, system uptime)
- **Bug Report**: Tự động tìm và đọc crash logs trong 7 ngày gần đây
- **Bug Report**: Thu thập logs từ PHTVLogger
- **Bug Report**: Tự động highlight unusual settings

### Fixed
- Console sạch 100% trong production build (debug logs chỉ xuất hiện trong debug mode)

## [1.2.5] - 2024-12-25

### Added
- **Auto-Update**: Tích hợp Sparkle Framework 2.8.1 cho tự động cập nhật
- **Auto-Update**: Kiểm tra tự động theo lịch (hàng ngày/tuần/tháng)
- **Auto-Update**: Kênh Beta opt-in cho người dùng muốn thử nghiệm
- **Auto-Update**: Release notes viewer với UI hiện đại
- **Security**: EdDSA signing cho mọi bản cập nhật

### Changed
- **UI**: Đơn giản hóa Settings - loại bỏ phần "Thông tin ứng dụng" trùng lặp
- **UI**: Card "Cập nhật" mới với đầy đủ tùy chọn
- **Backend**: Xóa logic kiểm tra cập nhật qua GitHub API thủ công

### Fixed
- Sửa lỗi timeout 30 giây khi kiểm tra cập nhật
- Sửa lỗi alert "Đang kiểm tra cập nhật..." không biến mất
- Sửa lỗi nút "Kiểm tra cập nhật" không phản hồi
- Sửa lỗi notification name mismatch

## [1.2.4] - 2024-12-25

### Improved
- **Claude Code CLI**: Cải thiện phát hiện Homebrew (hỗ trợ Apple Silicon, Intel, Linux)
- **Claude Code CLI**: Hỗ trợ Fast Node Manager (fnm) ngoài nvm
- **Claude Code CLI**: Thêm nút "Mở Terminal" khi cài đặt tự động thất bại

### Fixed
- Sửa lỗi không tìm thấy brew (tìm động thay vì hardcode path)
- Sửa lỗi npm không chạy được (cải thiện environment variables)
- Sửa lỗi gỡ Homebrew không sạch (xóa symlink còn sót lại)

## [1.2.3] - 2024-12-24

### Improved
- Cải thiện UI báo lỗi
- Tối ưu hiệu suất

### Fixed
- Sửa lỗi trùng lặp từ trong Spotlight

## [1.2.2] - 2024-12-23

### Added
- Hỗ trợ toàn diện cho bàn phím quốc tế (International keyboard layouts)

## [1.2.1] - 2024-12-22

### Improved
- Cải thiện ổn định tổng thể
- Tối ưu hiệu năng

## [1.2.0] - 2024-12-21

### Added
- Tính năng mới và cải tiến đáng kể
- Nâng cấp engine core

## [1.1.9] - 2024-12-20

### Improved
- Cập nhật README và documentation
- Tối ưu hiệu năng

## [1.1.8] - 2024-12-19

### Changed
- Bump version to 1.1.8

## [1.1.7] - 2024-12-18

### Improved
- Cải thiện đồng bộ theme
- Chuẩn hóa code và copyright headers

## [1.1.5] - 2024-12-17

### Fixed
- Sửa lỗi âm thanh
- Preserve macros khi cập nhật
- Cải thiện UX

## [1.1.4] - 2024-12-16

### Added
- Các tính năng và cải tiến

## [1.1.3] - 2024-12-15

### Improved
- Cải thiện ổn định

## [1.1.2] - 2024-12-14

### Added
- Auto-update check
- Restore on invalid word
- Send key step-by-step

## [1.1.1] - 2024-12-13

### Improved
- Cập nhật README

## [1.1.0] - 2024-12-12

### Added
- Phiên bản 1.1.0 với nhiều tính năng mới

## [1.0.3] - 2024-12-11

### Fixed
- Bug fixes và cải thiện ổn định

## [1.0.2] - 2024-12-10

### Fixed
- Bug fixes

## [1.0.1] - 2024-12-09

### Fixed
- Sửa lỗi phiên bản đầu tiên

## [1.0.0] - 2024-12-08

### Added
- Phát hành phiên bản đầu tiên của PHTV
- Hỗ trợ Telex, VNI, Simple Telex
- Nhiều bảng mã: Unicode, TCVN3, VNI Windows
- Giao diện SwiftUI hiện đại
- Kiểm tra chính tả
- Macro (gõ tắt)
- Hoàn toàn offline

[Unreleased]: https://github.com/PhamHungTien/PHTV/compare/v3.2.5...HEAD
[3.2.5]: https://github.com/PhamHungTien/PHTV/compare/v3.2.4...v3.2.5
[3.2.4]: https://github.com/PhamHungTien/PHTV/compare/v3.1.8...v3.2.4
[3.1.8]: https://github.com/PhamHungTien/PHTV/compare/v3.1.7...v3.1.8
[3.1.7]: https://github.com/PhamHungTien/PHTV/compare/v3.1.6...v3.1.7
[3.1.6]: https://github.com/PhamHungTien/PHTV/compare/v3.1.5...v3.1.6
[3.1.5]: https://github.com/PhamHungTien/PHTV/compare/v3.1.4...v3.1.5
[1.6.8]: https://github.com/PhamHungTien/PHTV/compare/v1.6.5...v1.6.8
[1.6.5]: https://github.com/PhamHungTien/PHTV/compare/v1.5.9...v1.6.5
[1.5.9]: https://github.com/PhamHungTien/PHTV/compare/v1.5.8...v1.5.9
[1.5.8]: https://github.com/PhamHungTien/PHTV/compare/v1.5.7...v1.5.8
[1.5.7]: https://github.com/PhamHungTien/PHTV/compare/v1.5.6...v1.5.7
[1.5.6]: https://github.com/PhamHungTien/PHTV/compare/v1.5.5...v1.5.6
[1.5.5]: https://github.com/PhamHungTien/PHTV/compare/v1.5.4...v1.5.5
[1.5.4]: https://github.com/PhamHungTien/PHTV/compare/v1.5.3...v1.5.4
[1.5.3]: https://github.com/PhamHungTien/PHTV/compare/v1.5.2...v1.5.3
[1.5.2]: https://github.com/PhamHungTien/PHTV/compare/v1.5.1...v1.5.2
[1.5.1]: https://github.com/PhamHungTien/PHTV/compare/v1.5.0...v1.5.1
[1.5.0]: https://github.com/PhamHungTien/PHTV/compare/v1.4.9...v1.5.0
[1.4.9]: https://github.com/PhamHungTien/PHTV/compare/v1.4.8...v1.4.9
[1.4.8]: https://github.com/PhamHungTien/PHTV/compare/v1.4.7...v1.4.8
[1.4.7]: https://github.com/PhamHungTien/PHTV/compare/v1.4.6...v1.4.7
[1.4.6]: https://github.com/PhamHungTien/PHTV/compare/v1.4.5...v1.4.6
[1.4.5]: https://github.com/PhamHungTien/PHTV/compare/v1.4.4...v1.4.5
[1.4.4]: https://github.com/PhamHungTien/PHTV/compare/v1.4.3...v1.4.4
[1.4.3]: https://github.com/PhamHungTien/PHTV/compare/v1.4.2...v1.4.3
[1.4.2]: https://github.com/PhamHungTien/PHTV/compare/v1.3.8...v1.4.2
[1.3.8]: https://github.com/PhamHungTien/PHTV/compare/v1.3.7...v1.3.8
[1.3.7]: https://github.com/PhamHungTien/PHTV/compare/v1.3.6...v1.3.7
[1.3.6]: https://github.com/PhamHungTien/PHTV/compare/v1.3.5...v1.3.6
[1.3.5]: https://github.com/PhamHungTien/PHTV/compare/v1.3.4...v1.3.5
[1.3.4]: https://github.com/PhamHungTien/PHTV/compare/v1.3.3...v1.3.4
[1.3.3]: https://github.com/PhamHungTien/PHTV/compare/v1.3.2...v1.3.3
[1.3.2]: https://github.com/PhamHungTien/PHTV/compare/v1.3.1...v1.3.2
[1.3.1]: https://github.com/PhamHungTien/PHTV/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/PhamHungTien/PHTV/compare/v1.2.6...v1.3.0
[1.2.6]: https://github.com/PhamHungTien/PHTV/compare/v1.2.5...v1.2.6
[1.2.5]: https://github.com/PhamHungTien/PHTV/compare/v1.1.4...v1.2.5
[1.2.4]: https://github.com/PhamHungTien/PHTV/releases/tag/v1.2.4
[1.2.3]: https://github.com/PhamHungTien/PHTV/releases/tag/v1.2.3
[1.2.2]: https://github.com/PhamHungTien/PHTV/releases/tag/v1.2.2
[1.2.1]: https://github.com/PhamHungTien/PHTV/releases/tag/v1.2.1
[1.2.0]: https://github.com/PhamHungTien/PHTV/releases/tag/v1.2.0
[1.1.9]: https://github.com/PhamHungTien/PHTV/releases/tag/v1.1.9
[1.1.8]: https://github.com/PhamHungTien/PHTV/releases/tag/v1.1.8
[1.1.7]: https://github.com/PhamHungTien/PHTV/releases/tag/v1.1.7
[1.1.5]: https://github.com/PhamHungTien/PHTV/releases/tag/v1.1.5
[1.1.4]: https://github.com/PhamHungTien/PHTV/compare/v1.1.3...v1.1.4
[1.1.3]: https://github.com/PhamHungTien/PHTV/compare/v1.1.2...v1.1.3
[1.1.2]: https://github.com/PhamHungTien/PHTV/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/PhamHungTien/PHTV/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/PhamHungTien/PHTV/compare/v1.0.3...v1.1.0
[1.0.3]: https://github.com/PhamHungTien/PHTV/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/PhamHungTien/PHTV/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/PhamHungTien/PHTV/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/PhamHungTien/PHTV/releases/tag/v1.0.0
