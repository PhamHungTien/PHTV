#include <array>
#include <cstdint>
#include <cstring>
#include <iomanip>
#include <iostream>
#include <string>
#include <string_view>
#include <utility>

#include <windows.h>
#include <msctf.h>
#include <objbase.h>
#include <wrl/client.h>

#include "Guids.h"

namespace {

using Microsoft::WRL::ComPtr;
using phtv::windows::ime::text_service_clsid;
using phtv::windows::ime::vietnamese_profile_guid;

constexpr LANGID vietnamese_language =
    MAKELANGID(LANG_VIETNAMESE, SUBLANG_VIETNAMESE_VIETNAM);
constexpr std::wstring_view service_name = L"PHTV Tiếng Việt";
using RegistrationFunction = HRESULT(STDAPICALLTYPE*)();

class ComApartment final {
public:
    ComApartment() noexcept
        : result_(CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED)),
          owns_initialization_(result_ == S_OK || result_ == S_FALSE) {}

    ~ComApartment() noexcept {
        if (owns_initialization_) {
            CoUninitialize();
        }
    }

    ComApartment(const ComApartment&) = delete;
    ComApartment& operator=(const ComApartment&) = delete;

    [[nodiscard]] HRESULT result() const noexcept {
        return result_;
    }

private:
    HRESULT result_;
    bool owns_initialization_;
};

class LoadedModule final {
public:
    explicit LoadedModule(const wchar_t* const path) noexcept
        : module_(LoadLibraryExW(path, nullptr, LOAD_WITH_ALTERED_SEARCH_PATH)) {}

    ~LoadedModule() noexcept {
        if (module_ != nullptr) {
            FreeLibrary(module_);
        }
    }

    LoadedModule(const LoadedModule&) = delete;
    LoadedModule& operator=(const LoadedModule&) = delete;

    [[nodiscard]] HMODULE get() const noexcept {
        return module_;
    }

private:
    HMODULE module_;
};

class RegistrationGuard final {
public:
    explicit RegistrationGuard(
        const RegistrationFunction unregister_server
    ) noexcept
        : unregister_server_(unregister_server) {}

    ~RegistrationGuard() noexcept {
        if (active_ && unregister_server_ != nullptr) {
            static_cast<void>(unregister_server_());
        }
    }

    RegistrationGuard(const RegistrationGuard&) = delete;
    RegistrationGuard& operator=(const RegistrationGuard&) = delete;

    void activate() noexcept {
        active_ = true;
    }

    void release() noexcept {
        active_ = false;
    }

private:
    RegistrationFunction unregister_server_;
    bool active_{false};
};

[[nodiscard]] bool expect(
    const bool condition,
    const char* const message
) noexcept {
    if (!condition) {
        std::cerr << "FAILED: " << message << '\n';
    }
    return condition;
}

[[nodiscard]] bool expect_hresult(
    const HRESULT result,
    const char* const operation
) noexcept {
    if (SUCCEEDED(result)) {
        return true;
    }
    std::cerr
        << "FAILED: "
        << operation
        << " returned HRESULT 0x"
        << std::hex
        << static_cast<unsigned long>(result)
        << std::dec
        << '\n';
    return false;
}

void report_utf16(
    const char* const label,
    const std::wstring_view value
) {
    std::cerr << label << " (" << value.size() << " UTF-16 units):";
    for (const wchar_t code_unit : value) {
        std::cerr
            << ' '
            << std::hex
            << std::setw(4)
            << std::setfill('0')
            << static_cast<std::uint16_t>(code_unit);
    }
    std::cerr << std::dec << '\n';
}

template <typename Function>
[[nodiscard]] Function exported_function(
    const HMODULE module,
    const char* const name
) noexcept {
    const FARPROC address = GetProcAddress(module, name);
    Function function{};
    static_assert(sizeof(function) == sizeof(address));
    std::memcpy(&function, &address, sizeof(function));
    return function;
}

[[nodiscard]] HRESULT class_registry_path(std::wstring& output) {
    std::array<wchar_t, 64> class_id{};
    if (StringFromGUID2(
            text_service_clsid,
            class_id.data(),
            static_cast<int>(class_id.size())
        ) == 0) {
        return E_FAIL;
    }
    output = L"Software\\Classes\\CLSID\\";
    output += class_id.data();
    return S_OK;
}

[[nodiscard]] HRESULT registry_key_exists(bool& exists) {
    std::wstring path;
    const HRESULT path_result = class_registry_path(path);
    if (FAILED(path_result)) {
        return path_result;
    }

    HKEY key{};
    const LSTATUS result = RegOpenKeyExW(
        HKEY_CURRENT_USER,
        path.c_str(),
        0,
        KEY_READ,
        &key
    );
    if (result == ERROR_FILE_NOT_FOUND || result == ERROR_PATH_NOT_FOUND) {
        exists = false;
        return S_OK;
    }
    if (result != ERROR_SUCCESS) {
        return HRESULT_FROM_WIN32(result);
    }
    RegCloseKey(key);
    exists = true;
    return S_OK;
}

[[nodiscard]] HRESULT read_registry_string(
    const std::wstring& path,
    const wchar_t* const value_name,
    std::wstring& output
) {
    DWORD type{};
    DWORD byte_count{};
    LSTATUS result = RegGetValueW(
        HKEY_CURRENT_USER,
        path.c_str(),
        value_name,
        RRF_RT_REG_SZ,
        &type,
        nullptr,
        &byte_count
    );
    if (result != ERROR_SUCCESS) {
        return HRESULT_FROM_WIN32(result);
    }
    if (byte_count < sizeof(wchar_t)
        || byte_count % sizeof(wchar_t) != 0) {
        return HRESULT_FROM_WIN32(ERROR_INVALID_DATA);
    }

    std::wstring value(byte_count / sizeof(wchar_t), L'\0');
    result = RegGetValueW(
        HKEY_CURRENT_USER,
        path.c_str(),
        value_name,
        RRF_RT_REG_SZ,
        &type,
        value.data(),
        &byte_count
    );
    if (result != ERROR_SUCCESS) {
        return HRESULT_FROM_WIN32(result);
    }
    if (byte_count % sizeof(wchar_t) != 0) {
        return HRESULT_FROM_WIN32(ERROR_INVALID_DATA);
    }
    value.resize(byte_count / sizeof(wchar_t));
    while (!value.empty() && value.back() == L'\0') {
        value.pop_back();
    }
    output = std::move(value);
    return S_OK;
}

[[nodiscard]] HRESULT profile_exists(bool& exists) {
    ComPtr<ITfInputProcessorProfileMgr> profiles;
    HRESULT result = CoCreateInstance(
        CLSID_TF_InputProcessorProfileMgr,
        nullptr,
        CLSCTX_INPROC_SERVER,
        IID_PPV_ARGS(&profiles)
    );
    if (FAILED(result)) {
        return result;
    }

    ComPtr<IEnumTfInputProcessorProfiles> enumerator;
    result = profiles->EnumProfiles(0, &enumerator);
    if (FAILED(result)) {
        return result;
    }

    exists = false;
    while (true) {
        TF_INPUTPROCESSORPROFILE profile{};
        ULONG fetched{};
        result = enumerator->Next(1, &profile, &fetched);
        if (result == S_FALSE) {
            return S_OK;
        }
        if (FAILED(result)) {
            return result;
        }
        if (fetched != 1) {
            return E_UNEXPECTED;
        }
        if (profile.dwProfileType == TF_PROFILETYPE_INPUTPROCESSOR
            && profile.langid == vietnamese_language
            && IsEqualCLSID(profile.clsid, text_service_clsid)
            && IsEqualGUID(profile.guidProfile, vietnamese_profile_guid)) {
            exists = true;
            return S_OK;
        }
    }
}

[[nodiscard]] HRESULT category_exists(
    const GUID& category_id,
    bool& exists
) {
    ComPtr<ITfCategoryMgr> categories;
    HRESULT result = CoCreateInstance(
        CLSID_TF_CategoryMgr,
        nullptr,
        CLSCTX_INPROC_SERVER,
        IID_PPV_ARGS(&categories)
    );
    if (FAILED(result)) {
        return result;
    }

    ComPtr<IEnumGUID> enumerator;
    result = categories->EnumItemsInCategory(category_id, &enumerator);
    if (FAILED(result)) {
        return result;
    }

    exists = false;
    while (true) {
        GUID item{};
        ULONG fetched{};
        result = enumerator->Next(1, &item, &fetched);
        if (result == S_FALSE) {
            return S_OK;
        }
        if (FAILED(result)) {
            return result;
        }
        if (fetched != 1) {
            return E_UNEXPECTED;
        }
        if (IsEqualGUID(item, text_service_clsid)) {
            exists = true;
            return S_OK;
        }
    }
}

[[nodiscard]] HRESULT activate_registered_text_service() noexcept {
    ComPtr<ITfTextInputProcessorEx> text_service;
    return CoCreateInstance(
        text_service_clsid,
        nullptr,
        CLSCTX_INPROC_SERVER,
        IID_PPV_ARGS(&text_service)
    );
}

[[nodiscard]] bool no_registration_footprint() {
    bool exists{};
    if (!expect_hresult(registry_key_exists(exists), "query COM registration")
        || !expect(!exists, "COM registration must be absent")) {
        return false;
    }
    if (!expect_hresult(profile_exists(exists), "query language profile")
        || !expect(!exists, "language profile must be absent")) {
        return false;
    }

    constexpr std::array<const GUID*, 3> category_ids{
        &GUID_TFCAT_TIP_KEYBOARD,
        &GUID_TFCAT_TIPCAP_IMMERSIVESUPPORT,
        &GUID_TFCAT_TIPCAP_INPUTMODECOMPARTMENT,
    };
    for (const GUID* const category_id : category_ids) {
        if (!expect_hresult(
                category_exists(*category_id, exists),
                "query TSF category"
            )
            || !expect(!exists, "TSF category must be absent")) {
            return false;
        }
    }
    return true;
}

[[nodiscard]] bool registered_state_is_complete(
    const std::wstring& expected_dll_path
) {
    std::wstring class_path;
    if (!expect_hresult(
            class_registry_path(class_path),
            "format COM class path"
        )) {
        return false;
    }

    std::wstring value;
    if (!expect_hresult(
            read_registry_string(class_path, nullptr, value),
            "read COM display name"
        )) {
        return false;
    }
    if (value != service_name) {
        report_utf16("Actual COM display name", value);
        report_utf16("Expected COM display name", service_name);
        static_cast<void>(expect(false, "COM display name"));
        return false;
    }

    const std::wstring server_path = class_path + L"\\InprocServer32";
    if (!expect_hresult(
            read_registry_string(server_path, nullptr, value),
            "read COM server path"
        )
        || !expect(
            _wcsicmp(value.c_str(), expected_dll_path.c_str()) == 0,
            "COM server path"
        )) {
        return false;
    }
    if (!expect_hresult(
            read_registry_string(server_path, L"ThreadingModel", value),
            "read COM threading model"
        )
        || !expect(value == L"Apartment", "COM threading model")) {
        return false;
    }

    bool exists{};
    if (!expect_hresult(profile_exists(exists), "query registered profile")
        || !expect(exists, "language profile must be registered")) {
        return false;
    }

    constexpr std::array<const GUID*, 3> category_ids{
        &GUID_TFCAT_TIP_KEYBOARD,
        &GUID_TFCAT_TIPCAP_IMMERSIVESUPPORT,
        &GUID_TFCAT_TIPCAP_INPUTMODECOMPARTMENT,
    };
    for (const GUID* const category_id : category_ids) {
        if (!expect_hresult(
                category_exists(*category_id, exists),
                "query registered TSF category"
            )
            || !expect(exists, "TSF category must be registered")) {
            return false;
        }
    }
    return true;
}

[[nodiscard]] HRESULT full_path(
    const wchar_t* const input,
    std::wstring& output
) {
    std::array<wchar_t, 32768> buffer{};
    const DWORD length = GetFullPathNameW(
        input,
        static_cast<DWORD>(buffer.size()),
        buffer.data(),
        nullptr
    );
    if (length == 0) {
        return HRESULT_FROM_WIN32(GetLastError());
    }
    if (length >= static_cast<DWORD>(buffer.size())) {
        return HRESULT_FROM_WIN32(ERROR_INSUFFICIENT_BUFFER);
    }
    output.assign(buffer.data(), length);
    return S_OK;
}

}  // namespace

int wmain(const int argument_count, wchar_t* arguments[]) {
    if (argument_count != 2) {
        std::cerr
            << "Usage: PHTV.Windows.Registration.Tests.exe <TSF DLL>\n";
        return 2;
    }

    std::wstring dll_path;
    if (!expect_hresult(full_path(arguments[1], dll_path), "resolve DLL path")) {
        return 1;
    }

    LoadedModule module(dll_path.c_str());
    if (!expect(module.get() != nullptr, "load TSF DLL")) {
        std::cerr << "Win32 error: " << GetLastError() << '\n';
        return 1;
    }

    const RegistrationFunction register_server =
        exported_function<RegistrationFunction>(
            module.get(),
            "DllRegisterServer"
        );
    const RegistrationFunction unregister_server =
        exported_function<RegistrationFunction>(
            module.get(),
            "DllUnregisterServer"
        );
    const RegistrationFunction can_unload =
        exported_function<RegistrationFunction>(
            module.get(),
            "DllCanUnloadNow"
        );
    if (!expect(register_server != nullptr, "find DllRegisterServer")
        || !expect(unregister_server != nullptr, "find DllUnregisterServer")
        || !expect(can_unload != nullptr, "find DllCanUnloadNow")) {
        return 1;
    }

    ComApartment apartment;
    if (!expect_hresult(apartment.result(), "initialize COM")) {
        return 1;
    }

    // Refuse to overwrite or remove an existing installation when this test is
    // accidentally launched outside a clean runner or disposable VM.
    if (!no_registration_footprint()) {
        std::cerr
            << "Refusing to run because PHTV registration already exists.\n";
        return 1;
    }

    RegistrationGuard cleanup(unregister_server);
    const HRESULT register_result = register_server();
    cleanup.activate();
    if (!expect_hresult(register_result, "register TSF service")) {
        return 1;
    }
    if (!registered_state_is_complete(dll_path)) {
        return 1;
    }
    if (!expect_hresult(
            activate_registered_text_service(),
            "activate registered COM class"
        )
        || !expect(
            can_unload() == S_OK,
            "COM objects must release their module references"
        )) {
        return 1;
    }

    const HRESULT unregister_result = unregister_server();
    if (!expect_hresult(unregister_result, "unregister TSF service")) {
        return 1;
    }
    cleanup.release();
    if (!no_registration_footprint()) {
        return 1;
    }

    std::cout << "PHTV Windows registration lifecycle tests passed\n";
    return 0;
}
