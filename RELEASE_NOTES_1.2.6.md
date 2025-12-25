# PHTV 1.2.6 - Performance & UX Optimization

## Cải tiến hiệu năng

### Tối ưu kiểm tra quyền truy cập
- **Giảm tần suất kiểm tra**: Từ mỗi giây xuống còn mỗi 5 giây (tiết kiệm 80% CPU)
- **Cache thông minh**: Tăng cache duration từ 1 giây lên 10 giây
- **Giảm console spam**: Chỉ log khi trạng thái thay đổi, không log mỗi giây nữa
- **Debug logs**: Các log chi tiết chỉ xuất hiện trong debug build, production hoàn toàn sạch
- **Kết quả**:
  - Giảm 83% số lần tạo test event tap (từ 40 xuống 6 lần/phút)
  - Console sạch 100% trong production build
  - Vẫn phát hiện permission revoke trong tối đa 5 giây

### Tối ưu kiểm tra cập nhật
- **Delay khởi động**: Đợi 10 giây sau khi app khởi động mới check update
  - Tránh lỗi "An error occurred in retrieving update information" khi vừa khởi động lại máy
  - Cho phép network có thời gian sẵn sàng
- **Im lặng khi không có update**:
  - Loại bỏ hoàn toàn dialog "PHTV is currently the newest version available"
  - Chỉ thông báo khi thực sự có bản mới
  - Background check hoàn toàn im lặng
- **Kết quả**: Không còn phiền người dùng với các thông báo không cần thiết

## Cải tiến chức năng

### Nâng cấp hệ thống báo lỗi
- **Thông tin hệ thống đầy đủ hơn**:
  - Tất cả cài đặt hiện tại (Check spelling, Macro, Smart switch, Modern orthography, Quick Telex, v.v.)
  - Advanced settings (Chromium fix, Layout compat, Send key step-by-step, v.v.)
  - Trạng thái chế độ (Tiếng Việt/English)

- **Runtime state tracking**:
  - **Accessibility Permission**: Hiển thị trạng thái granted/denied
  - **Event Tap Status**: Đang chạy hay không
  - **Front App**: App hiện đang active (kèm bundle ID)
  - **Excluded Apps**: Danh sách chi tiết các app bị loại trừ
  - **Send Key Step-by-Step Apps**: Danh sách apps đặc biệt

- **Performance metrics**:
  - Memory usage (MB)
  - Total RAM (GB)
  - System uptime

- **Crash logs tự động**:
  - Tự động tìm và đọc crash logs từ ~/Library/Logs/DiagnosticReports
  - Lọc chỉ crash logs của PHTV trong 7 ngày gần đây
  - Extract Exception Type, Termination Reason, và crashed thread stacktrace
  - Giúp debug crash cực nhanh

- **File logs**:
  - Thu thập logs từ PHTVLogger (persistent logs)
  - Bổ sung cho OSLog (system logs)
  - Giới hạn 2000 ký tự cuối để không quá dài

- **Smart reporting**:
  - Tự động highlight unusual settings (settings khác default)
  - GitHub/Email compact format với thông tin quan trọng nhất
  - Format markdown đẹp, dễ đọc với icons và sections rõ ràng

## Cải tiến trải nghiệm người dùng

### Update check thông minh
- ✅ Chỉ thông báo khi có bản mới
- ✅ Không hiện dialog "Up to date" làm phiền
- ✅ Không hiện dialog lỗi khi network chưa sẵn sàng
- ✅ Background check hoàn toàn silent

### Console logs sạch sẽ
- ✅ Production build không có debug logs spam
- ✅ Debug build có logs chi tiết để phát triển
- ✅ Chỉ log khi có sự kiện quan trọng (permission change, errors)

### Bug reporting mạnh mẽ
- ✅ Thu thập đầy đủ context để reproduce bug
- ✅ Tự động phát hiện crash logs
- ✅ Hiển thị settings bất thường
- ✅ Performance info để phát hiện memory leaks
- ✅ Format đẹp, dễ đọc cho developer

## Kỹ thuật

### Performance optimization
- Giảm CPU usage bằng cách giảm tần suất polling
- Smart caching để tránh tạo test event tap quá thường xuyên
- Conditional logging với #ifdef DEBUG

### UX improvement
- Silent background operations
- Only notify when necessary
- No more annoying "up to date" dialogs

### Debug capability
- Comprehensive bug reports
- Automatic crash log collection
- Runtime state snapshot
- Performance metrics

---

**Phiên bản này tập trung vào tối ưu hiệu năng và trải nghiệm người dùng, giảm thiểu resource usage và loại bỏ các thông báo không cần thiết, đồng thời nâng cấp khả năng debug để fix bugs nhanh hơn.**

## So sánh với v1.2.5

| Aspect | v1.2.5 | v1.2.6 |
|--------|--------|--------|
| Permission checks | 60/minute | 12/minute (-80%) |
| Console logs (production) | ~120 lines/minute | 0 lines (chỉ khi có event) |
| "Up to date" dialogs | Hiện mỗi khi check | Không hiện |
| Boot time update check | Ngay lập tức (lỗi khi mạng chưa ready) | Delay 10s (ổn định) |
| Bug report info | Cơ bản | Đầy đủ (settings, runtime, crashes, logs) |
| Test event taps | ~40/minute | ~6/minute (-85%) |

**Download**: [PHTV-1.2.6.zip](https://github.com/phamhungtien/PHTV/releases/download/v1.2.6/PHTV-1.2.6.zip)
