# Phát triển PHTV for Windows

## Trạng thái hiện tại

Đã có solution, portable Core, native Core bridge, TSF DLL, WinUI Settings app và
bảy executable contract/integration test. Đây là source của PoC, chưa phải
binary cài đặt:
registration, composition và cleanup vẫn cần xác nhận trên Windows client thật.

## Yêu cầu dự kiến

- Windows 10 1809+ hoặc Windows 11, Developer Mode bật trên máy phát triển.
- Visual Studio 2026 18.0+ cho .NET 10 và solution đầy đủ.
- MSVC v143 x64 cùng Windows SDK 10.0.26100.0.
- .NET SDK 10.0.100 và Windows App SDK 2.3.1 stable.
- Swift 6.3.3 chính thức cho Windows (`Swift.Toolchain`).
- Git for Windows và PowerShell 7.

Tham khảo:

- [Cài Swift trên Windows](https://www.swift.org/install/windows/)
- [Windows App SDK](https://learn.microsoft.com/windows/apps/windows-app-sdk/)
- [TSF API](https://learn.microsoft.com/windows/win32/api/_tsf/)

## Quy ước solution

Khi scaffold, solution phải giữ ranh giới sau:

```text
PHTV.Windows.slnx
├── PHTV.Windows.IME       # C++/WinRT TSF DLL
├── PHTV.Windows.App       # C# WinUI companion app
├── PHTV.Windows.Contracts # DTO/config schema, không phụ thuộc UI
├── PHTV.CoreBridge        # C header + import/static library cho Swift core
└── *.Tests
```

Không commit thư mục `bin/`, `obj/`, `.vs/`, `.build/`, package cache, chứng thư
hoặc binary đã ký.

## Build Core hiện tại

Từ thư mục gốc repository:

```text
swift build --package-path Shared/PHTVCore
swift test --package-path Shared/PHTVCore
swift run --package-path Shared/PHTVCore PHTVCoreABISmoke
```

Lệnh cuối build một chương trình C liên kết với Swift dynamic library và gọi
toàn bộ vòng đời ABI tối thiểu. Nó không thay thế test TSF trên Windows thật.

## Build Windows projects

Entry point khuyến nghị là công cụ Swift ở thư mục gốc. Công cụ tự kiểm tra
đường dẫn solution, phát hiện toolchain và chạy đúng thứ tự lệnh mà không phụ
thuộc PowerShell hoặc file `.sh`:

```text
swift scripts/windows.swift doctor       # kiểm tra môi trường và cấu trúc repo
swift scripts/windows.swift core-test    # chạy Core + C ABI smoke trên mọi host
swift scripts/windows.swift build        # Windows: Core, native tests và WinUI
swift scripts/windows.swift test         # Windows: Core tests và native tests
```

Trên macOS/Linux chỉ các lệnh `doctor`, `core-build` và `core-test` được kỳ vọng
thành công; các lệnh native/WinUI sẽ dừng sớm với thông báo cần Windows runner.
CI vẫn có thể gọi MSBuild trực tiếp để tách log từng bước.

Sau khi `swift build` tạo `PHTVCore.lib`/`PHTVCore.dll`, đặt
`PHTVCoreLibraryDir` thành thư mục chứa hai file đó rồi chạy:

```text
msbuild Apps\Windows\tests\PHTV.Windows.InputModeState.Tests\PHTV.Windows.InputModeState.Tests.vcxproj /m /p:Configuration=Release /p:Platform=x64
msbuild Apps\Windows\tests\PHTV.Windows.InputScopePolicy.Tests\PHTV.Windows.InputScopePolicy.Tests.vcxproj /m /p:Configuration=Release /p:Platform=x64
msbuild Apps\Windows\tests\PHTV.Windows.SettingsSnapshot.Tests\PHTV.Windows.SettingsSnapshot.Tests.vcxproj /m /p:Configuration=Release /p:Platform=x64
msbuild Apps\Windows\tests\PHTV.Windows.ApplicationRulesSnapshot.Tests\PHTV.Windows.ApplicationRulesSnapshot.Tests.vcxproj /m /p:Configuration=Release /p:Platform=x64
msbuild Apps\Windows\tests\PHTV.Windows.CoreBridge.Tests\PHTV.Windows.CoreBridge.Tests.vcxproj /m /p:Configuration=Release /p:Platform=x64 /p:PHTVCoreLibraryDir="<core-dir>"
msbuild Apps\Windows\src\PHTV.Windows.IME\PHTV.Windows.IME.vcxproj /m /p:Configuration=Release /p:Platform=x64 /p:PHTVCoreLibraryDir="<core-dir>"
msbuild Apps\Windows\tests\PHTV.Windows.Registration.Tests\PHTV.Windows.Registration.Tests.vcxproj /m /p:Configuration=Release /p:Platform=x64
dotnet run --project Apps\Windows\tests\PHTV.Windows.Contracts.Tests\PHTV.Windows.Contracts.Tests.csproj --configuration Release
dotnet build Apps\Windows\src\PHTV.Windows.App\PHTV.Windows.App.csproj --configuration Release --runtime win-x64 /p:Platform=x64
```

Workflow `windows-core.yml` là nguồn tham chiếu cho thứ tự build chính xác và
có chạy vòng đời đăng ký/gỡ TSF trong runner cô lập. Test từ chối chạy nếu phát
hiện dấu vết cài đặt PHTV có sẵn và luôn cố gỡ phần nó vừa tạo khi thất bại.
Không chạy test registration hoặc gọi `regsvr32` trên máy làm việc chính; hãy
dùng runner sạch hay VM/máy thử có snapshot phục hồi.

Registration dùng `ITfInputProcessorProfileMgr`, API Microsoft khuyến nghị từ
Windows Vista để đăng ký/gỡ và duyệt profile. Profile được đăng ký ở trạng thái
chưa tự bật; bật profile thuộc luồng onboarding/installer có sự đồng ý.

## Quy trình thay đổi

1. Viết hoặc cập nhật test vector độc lập nền tảng.
2. Thay đổi `Shared/PHTVCore` mà không thêm import hệ điều hành.
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

Các lệnh SwiftPM, MSBuild và dotnet phía trên là entrypoint hiện có. Trước khi
đóng gói, repository vẫn cần một orchestration tool viết bằng Swift cho
`doctor`, `build`, `test` và `package`; không dùng PowerShell script cục bộ để
né quy tắc tooling Swift-only.
