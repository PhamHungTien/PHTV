# Build Configurations

Thư mục này chứa các file cấu hình build cho dự án PHTV.

## Nội dung

- `SwiftUIConfig.xcconfig` - Cấu hình cho SwiftUI support

## Sử dụng

Các file `.xcconfig` được Xcode sử dụng để cấu hình build settings.

### SwiftUIConfig.xcconfig

Định nghĩa các settings cần thiết cho SwiftUI:
- Swift version
- Deployment target
- Framework search paths

## Thêm cấu hình mới

Để thêm file cấu hình mới:
1. Tạo file `.xcconfig` trong thư mục này
2. Thêm build settings cần thiết
3. Link file trong Xcode project settings
