# Phát triển PHTV for Windows

## Trạng thái hiện tại

Chưa có solution hoặc package có thể build. Tài liệu này xác định môi trường và
quy trình sẽ áp dụng khi PoC đầu tiên được tạo trên máy Windows thật.

## Yêu cầu dự kiến

- Windows 10 1809+ hoặc Windows 11, Developer Mode bật trên máy phát triển.
- Visual Studio 2022 với MSVC x64/x86, C++/WinRT và Windows SDK.
- .NET SDK tương ứng với Windows App SDK được khóa trong project.
- Swift toolchain chính thức cho Windows.
- Git for Windows và PowerShell 7.

Tham khảo:

- [Cài Swift trên Windows](https://www.swift.org/install/windows/)
- [Windows App SDK](https://learn.microsoft.com/windows/apps/windows-app-sdk/)
- [TSF API](https://learn.microsoft.com/windows/win32/api/_tsf/)

## Quy ước solution

Khi scaffold, solution phải giữ ranh giới sau:

```text
PHTV.Windows.sln
├── PHTV.Windows.IME       # C++/WinRT TSF DLL
├── PHTV.Windows.App       # C# WinUI 3 packaged app
├── PHTV.Windows.Contracts # DTO/config schema, không phụ thuộc UI
├── PHTV.CoreBridge        # C header + import/static library cho Swift core
└── *.Tests
```

Không commit thư mục `bin/`, `obj/`, `.vs/`, `.build/`, package cache, chứng thư
hoặc binary đã ký.

## Quy trình thay đổi

1. Viết hoặc cập nhật test vector độc lập nền tảng.
2. Thay đổi `PHTV.Core` mà không thêm import hệ điều hành.
3. Kiểm tra C ABI và memory ownership bằng sanitizer/test lặp.
4. Thay đổi adapter TSF hoặc WinUI ở project tương ứng.
5. Chạy test matrix trong [TESTING.md](TESTING.md).
6. Cập nhật ADR nếu thay đổi ranh giới component, IPC, installer hoặc dữ liệu.

## Quy tắc C ABI

- Mọi symbol public có prefix `phtv_` và version API rõ ràng.
- Chỉ dùng integer kích thước cố định, pointer + length và POD struct.
- Bên cấp phát bộ nhớ cũng phải cung cấp hàm giải phóng.
- Chuỗi qua biên dùng UTF-16 hoặc UTF-8 được ghi rõ cho từng API.
- Không ném Swift error hoặc C++ exception qua biên ABI.
- Mọi API phải xác định hành vi với null, buffer thiếu và version không hỗ trợ.

## Quy tắc code

- Swift: theo `.swift-format` của repository và Swift 6 strict concurrency.
- C++: C++20, RAII, smart pointer và không sở hữu COM pointer thô.
- C#: nullable reference types bật; UI state không chứa business logic engine.
- Không log nội dung nhập, Clipboard, macro hoặc dữ liệu trường đang focus.
- Dependency mới cần lý do, license, lockfile và cập nhật third-party notices.

## Công cụ build

Khi có project thật, repository sẽ cung cấp một entrypoint PowerShell hoặc Swift
chạy được trên Windows cho các lệnh `doctor`, `build`, `test`, `package`. Không
ghi các lệnh giả vào tài liệu trước khi script đó tồn tại và được CI kiểm chứng.

