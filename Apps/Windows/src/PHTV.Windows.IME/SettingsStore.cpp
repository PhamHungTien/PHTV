#include "SettingsStore.h"

#include <array>
#include <new>
#include <string>
#include <vector>

#include <windows.h>
#include <shlobj.h>

namespace phtv::windows::ime {
namespace {

class UniqueHandle final {
public:
    explicit UniqueHandle(HANDLE value) noexcept : value_(value) {}
    ~UniqueHandle() noexcept {
        if (value_ != nullptr && value_ != INVALID_HANDLE_VALUE) {
            CloseHandle(value_);
        }
    }

    UniqueHandle(const UniqueHandle&) = delete;
    UniqueHandle& operator=(const UniqueHandle&) = delete;

    [[nodiscard]] HANDLE get() const noexcept {
        return value_;
    }

private:
    HANDLE value_;
};

[[nodiscard]] bool snapshot_path(
    const wchar_t* const file_name,
    std::wstring& output
) noexcept {
    PWSTR local_app_data = nullptr;
    const HRESULT result = SHGetKnownFolderPath(
        FOLDERID_LocalAppData,
        KF_FLAG_DEFAULT,
        nullptr,
        &local_app_data
    );
    if (FAILED(result) || local_app_data == nullptr) {
        CoTaskMemFree(local_app_data);
        return false;
    }

    try {
        output.assign(local_app_data);
        output.append(L"\\PHTV\\");
        output.append(file_name);
    } catch (const std::bad_alloc&) {
        CoTaskMemFree(local_app_data);
        return false;
    } catch (...) {
        CoTaskMemFree(local_app_data);
        return false;
    }
    CoTaskMemFree(local_app_data);
    return true;
}

}  // namespace

SettingsSnapshot load_user_settings_snapshot() noexcept {
    SettingsSnapshot result;
    try {
        std::wstring path;
        if (!snapshot_path(L"settings.snapshot", path)) {
            return result;
        }

        const UniqueHandle file(CreateFileW(
            path.c_str(),
            GENERIC_READ,
            FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
            nullptr,
            OPEN_EXISTING,
            FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN,
            nullptr
        ));
        if (file.get() == INVALID_HANDLE_VALUE) {
            return result;
        }

        LARGE_INTEGER size{};
        if (GetFileSizeEx(file.get(), &size) == FALSE
            || size.QuadPart
                != static_cast<LONGLONG>(settings_snapshot_byte_length)) {
            return result;
        }

        std::array<std::uint8_t, settings_snapshot_byte_length> contents{};
        DWORD bytes_read{};
        if (ReadFile(
                file.get(),
                contents.data(),
                static_cast<DWORD>(contents.size()),
                &bytes_read,
                nullptr
            ) == FALSE
            || bytes_read != static_cast<DWORD>(contents.size())) {
            return result;
        }

        SettingsSnapshot decoded;
        if (decode_settings_snapshot(contents, decoded)
            == SnapshotDecodeStatus::ok) {
            return decoded;
        }
    } catch (const std::bad_alloc&) {
        return result;
    } catch (...) {
        return result;
    }
    return result;
}

ApplicationRulesSnapshot load_user_application_rules_snapshot(
    const std::uint64_t expected_revision
) noexcept {
    ApplicationRulesSnapshot result;
    try {
        std::wstring path;
        if (!snapshot_path(L"application-rules.snapshot", path)) {
            return result;
        }

        const UniqueHandle file(CreateFileW(
            path.c_str(),
            GENERIC_READ,
            FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
            nullptr,
            OPEN_EXISTING,
            FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN,
            nullptr
        ));
        if (file.get() == INVALID_HANDLE_VALUE) {
            return result;
        }

        LARGE_INTEGER size{};
        if (GetFileSizeEx(file.get(), &size) == FALSE
            || size.QuadPart < 0
            || size.QuadPart
                > static_cast<LONGLONG>(
                    application_rules_snapshot_maximum_byte_length
                )) {
            return result;
        }

        std::vector<std::uint8_t> contents(
            static_cast<std::size_t>(size.QuadPart)
        );
        DWORD bytes_read{};
        if (ReadFile(
                file.get(),
                contents.data(),
                static_cast<DWORD>(contents.size()),
                &bytes_read,
                nullptr
            ) == FALSE
            || bytes_read != static_cast<DWORD>(contents.size())) {
            return result;
        }

        ApplicationRulesSnapshot decoded;
        if (decode_application_rules_snapshot(contents, decoded)
                == ApplicationRulesDecodeStatus::ok
            && decoded.revision == expected_revision) {
            return decoded;
        }
    } catch (const std::bad_alloc&) {
        return result;
    } catch (...) {
        return result;
    }
    return result;
}

}  // namespace phtv::windows::ime
