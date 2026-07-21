# Chính sách bảo mật PHTV

## Báo cáo riêng tư

Không mở public issue nếu vấn đề có thể làm lộ nội dung gõ, clipboard, dữ liệu cá
nhân, khóa ký, hoặc cho phép thực thi mã trái phép.

Gửi báo cáo đến [phamhungtien.contact@gmail.com](mailto:phamhungtien.contact@gmail.com)
với tiêu đề `[SECURITY] <mô tả ngắn>`. Vui lòng kèm:

- phiên bản PHTV, macOS và kiến trúc máy;
- tác động và điều kiện cần để khai thác;
- bước tái hiện hoặc PoC tối thiểu;
- log/ảnh đã xóa dữ liệu nhạy cảm;
- cách khắc phục đề xuất, nếu có.

Bạn sẽ nhận được xác nhận sớm nhất có thể. Thời gian điều tra và phát hành phụ
thuộc mức độ nghiêm trọng; không có cam kết SLA cố định cho dự án cộng đồng này.
Vui lòng phối hợp về thời điểm công bố để người dùng có thời gian cập nhật.

## Phiên bản được hỗ trợ

Chỉ bản phát hành ổn định mới nhất được hỗ trợ chủ động. Báo cáo trên bản cũ vẫn
được tiếp nhận, nhưng người dùng có thể được yêu cầu nâng cấp để xác nhận lại.

## Phạm vi ưu tiên

- lạm dụng Accessibility hoặc Input Monitoring để đọc/gửi dữ liệu ngoài mục đích
  xử lý bộ gõ;
- rò rỉ nội dung gõ, clipboard, macro, từ khóa tìm GIF/Sticker hoặc định danh;
- thực thi mã, command injection, path traversal hoặc nhập cấu hình không an toàn;
- giả mạo cập nhật, lỗi chữ ký Sparkle, ký ứng dụng hoặc notarization;
- memory corruption, vượt quyền hoặc thay đổi cấu hình trái phép có tác động bảo mật.

Crash, chậm, lỗi tương thích và UX thông thường nên được gửi bằng
[mẫu báo lỗi](.github/ISSUE_TEMPLATE/bug_report.md), trừ khi chúng tạo ra tác động
bảo mật rõ ràng.

## Mô hình quyền và dữ liệu

PHTV cần **Accessibility** và **Input Monitoring** để nhận phím và đưa văn bản đã
xử lý vào ứng dụng đang dùng. PHTV không cần chạy bằng `sudo`.

Engine tiếng Việt chạy tại máy. Một số tính năng tùy chọn có thể kết nối mạng:

- Sparkle kiểm tra và tải bản cập nhật;
- PHTV Picker tìm GIF/Sticker qua Klipy và ghi nhận tương tác quảng cáo theo yêu
  cầu của dịch vụ đó.

Chi tiết dữ liệu, lưu trữ và cách xóa nằm trong [Chính sách quyền riêng tư](docs/PRIVACY.md).

## Thực hành của dự án

- Dependency Sparkle được khóa bằng `Package.resolved`; Dependabot theo dõi GitHub
  Actions.
- CI chạy toàn bộ XCTest, kiểm tra dictionary, metadata release, appcast, plist và
  privacy manifest mà không tự retry test thất bại.
- Workflow release chỉ phát hành sau bước verify; ứng dụng được ký Developer ID,
  notarize và appcast được ký EdDSA bởi Sparkle.
- GitHub Actions bên thứ ba được khóa bằng full commit SHA.
- Không ghi nội dung phím, clipboard, từ khóa tìm kiếm, API key hoặc URL có token
  vào log. Xem quy tắc tại [CONTRIBUTING.md](CONTRIBUTING.md).

Các thiết lập repository như branch protection, required reviewers và secret
scanning được cấu hình trên GitHub, không thể được chứng minh chỉ từ mã nguồn.
Maintainer nên bật chúng cho nhánh `main` và yêu cầu workflow `CI` thành công trước
khi merge.

## Phát hành bản vá

Với lỗi đã xác nhận, maintainer sẽ ưu tiên bản vá, thêm regression test khi khả
thi, phát hành theo [quy trình release](docs/RELEASING.md), rồi công bố GitHub
Security Advisory/CVE nếu mức độ ảnh hưởng phù hợp. Không đưa chi tiết khai thác
vào CHANGELOG trước khi bản vá đến được người dùng.

## Ghi nhận

Nhà nghiên cứu có thể chọn được ghi tên trong release notes hoặc giữ ẩn danh. Dự
án không có chương trình bug bounty trả thưởng.
