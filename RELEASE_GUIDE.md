# Hướng dẫn tạo GitHub Release v1.0.0

Để hoàn tất phát hành v1.0.0 của PHTV, hãy làm theo các bước sau:

## 📋 Danh sách kiểm tra

- ✅ Git tag `v1.0.0` đã được tạo và push
- ✅ DMG file: `/Users/phamhungtien/Desktop/PHTV_1.0.0.dmg` (2.2 MB)
- ✅ SHA256: `6ff2f005a9e3d37efc9feea5a0c43310e46595c26db7204b19b02c9e3a0a96e1`
- ✅ Tất cả tài liệu đã được cập nhật
- ✅ Homebrew formula đã được tạo tại `Formula/phtv.rb`

## 🚀 Bước 1: Tạo Release trên GitHub

1. **Vào GitHub Releases:**
   - URL: https://github.com/PhamHungTien/PHTV/releases

2. **Click "Create a new release"** hoặc **"Draft a new release"**

3. **Chọn tag:** 
   - Chọn `v1.0.0` từ dropdown "Choose a tag"

4. **Điền Release Title:**
   ```
   PHTV v1.0.0 - Vietnamese Input Method for macOS
   ```

5. **Điền Release Description:**
   Dán nội dung sau (từ CHANGELOG.md):

   ```markdown
   PHTV v1.0.0 là phiên bản đầu tiên - một bộ gõ tiếng Việt hiện đại cho macOS, được xây dựng trên nền tảng SwiftUI với giao diện Liquid Glass.

   ## ✨ Tính năng chính

   **📝 Phương pháp gõ (4 loại)**
   - Telex
   - VNI
   - Simple Telex 1
   - Simple Telex 2

   **🔤 Bảng mã ký tự (5 loại)**
   - Unicode (mặc định)
   - TCVN3 (ABC)
   - VNI Windows
   - Unicode Composite
   - Vietnamese Locale (CP1258)

   **⚙️ Chức năng nâng cao**
   - Giao diện Menu Bar với truy cập nhanh đến tùy chọn chính
   - Kiểm tra chính tả (spell checking) với từ điển tiếng Việt
   - Quản lý macro (gõ tắt) - tạo các từ viết tắt tùy chỉnh
   - Excluded apps - tự động tắt tiếng Việt cho ứng dụng chỉ định
   - Tùy chỉnh phím tắt chuyển đổi ngôn ngữ
   - Hỗ trợ Dark Mode
   - Thống kê sử dụng
   - Khởi động cùng hệ thống (auto-launch)
   - Smart Switch Key - tự động chuyển đổi theo ứng dụng

   ### 🎨 Giao diện
   - Xây dựng hoàn toàn bằng SwiftUI với Liquid Glass design
   - Hỗ trợ macOS 12.0+
   - Status bar controller cho quick access
   - Settings panel mới tổ chức tốt hơn

   ## 🎯 Điểm nổi bật
   - ✅ Hoàn toàn offline - không cần kết nối Internet
   - ✅ Mã nguồn mở - GPL v3.0
   - ✅ Hiệu năng cao - tối ưu cho macOS
   - ✅ Tùy chỉnh linh hoạt - nhiều tùy chọn cấu hình

   ## 📥 Cài đặt
   - Download từ bản release này
   - Hoặc xem [INSTALL.md](https://github.com/PhamHungTien/PHTV/blob/main/INSTALL.md) cho hướng dẫn chi tiết

   ## 📝 License
   GNU General Public License v3.0

   ## 🤝 Cảm ơn
   Cảm ơn [OpenKey](https://github.com/tuyenvm/OpenKey) - dự án mã nguồn mở tiếng Việt lâu năm đã cung cấp engine nhập liệu.
   ```

6. **Upload DMG file:**
   - Kéo file `PHTV_1.0.0.dmg` vào khu vực "Attach binaries..."
   - Hoặc click để chọn file từ máy

7. **Tùy chọn:**
   - ✅ Có thể check "This is a pre-release" nếu muốn, hoặc bỏ để là release chính thức
   - ✅ Check "Create a discussion for this release" để tạo discussion (optional)

8. **Nhấn "Publish release"**

## 🎉 Hoàn tất!

Sau khi publish, release v1.0.0 sẽ:
- ✅ Hiển thị trên trang Releases
- ✅ Được gắn tag v1.0.0 (đã có)
- ✅ Có DMG file sẵn để download
- ✅ Có release notes chi tiết

## 📊 Xem kết quả

Sau khi publish, bạn có thể:
1. Vào https://github.com/PhamHungTien/PHTV/releases để xem release
2. Chia sẻ link download: `https://github.com/PhamHungTien/PHTV/releases/download/v1.0.0/PHTV_1.0.0.dmg`
3. Các users có thể tải về và cài đặt dễ dàng

## 🔄 Bước tiếp theo (Optional)

### Submit lên Homebrew (chính thức)
1. Fork: https://github.com/Homebrew/homebrew-casks
2. Thêm file `Casks/phtv.rb` với nội dung từ `Formula/phtv.rb`
3. Tạo Pull Request
4. Homebrew team sẽ review và merge (1-2 tuần)
5. Sau đó users có thể: `brew install --cask phtv`

### Quảng bá
- Share link release trên GitHub, Reddit, Twitter, v.v.
- Post trên các group tiếng Việt trên Facebook
- Submit vào repositories tiếng Việt

---

**Ghi chú**: File `PHTV_1.0.0.dmg` hiện tại ở Desktop, sẽ được upload lên GitHub Release và có thể access mãi từ link release download.
