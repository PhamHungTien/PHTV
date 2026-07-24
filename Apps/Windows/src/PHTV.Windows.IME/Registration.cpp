#include "ModuleState.h"

#include <array>
#include <string>
#include <string_view>

#include <msctf.h>
#include <objbase.h>
#include <wrl/client.h>

#include "Guids.h"

namespace phtv::windows::ime {
namespace {

constexpr std::wstring_view service_name = L"PHTV Tiếng Việt";
constexpr LANGID vietnamese_language =
    MAKELANGID(LANG_VIETNAMESE, SUBLANG_VIETNAMESE_VIETNAM);

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

    [[nodiscard]] HRESULT result() const noexcept {
        return result_ == RPC_E_CHANGED_MODE ? S_OK : result_;
    }

private:
    HRESULT result_;
    bool owns_initialization_;
};

[[nodiscard]] HRESULT module_path(std::wstring& output) {
    std::array<wchar_t, 32768> buffer{};
    const DWORD length = GetModuleFileNameW(
        module_instance,
        buffer.data(),
        static_cast<DWORD>(buffer.size())
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

[[nodiscard]] HRESULT clsid_string(std::wstring& output) {
    std::array<wchar_t, 64> buffer{};
    const int length = StringFromGUID2(
        text_service_clsid,
        buffer.data(),
        static_cast<int>(buffer.size())
    );
    if (length == 0) {
        return E_FAIL;
    }
    output.assign(buffer.data(), static_cast<std::size_t>(length - 1));
    return S_OK;
}

[[nodiscard]] HRESULT set_registry_string(
    HKEY root,
    const std::wstring& path,
    const wchar_t* value_name,
    const std::wstring_view value
) noexcept {
    HKEY key{};
    const LSTATUS create_result = RegCreateKeyExW(
        root,
        path.c_str(),
        0,
        nullptr,
        REG_OPTION_NON_VOLATILE,
        KEY_SET_VALUE,
        nullptr,
        &key,
        nullptr
    );
    if (create_result != ERROR_SUCCESS) {
        return HRESULT_FROM_WIN32(create_result);
    }

    const LSTATUS set_result = RegSetValueExW(
        key,
        value_name,
        0,
        REG_SZ,
        reinterpret_cast<const BYTE*>(value.data()),
        static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t))
    );
    RegCloseKey(key);
    return HRESULT_FROM_WIN32(set_result);
}

[[nodiscard]] HRESULT register_com_server(
    const std::wstring_view dll_path
) {
    std::wstring class_id;
    HRESULT result = clsid_string(class_id);
    if (FAILED(result)) {
        return result;
    }

    const std::wstring class_path =
        L"Software\\Classes\\CLSID\\" + class_id;
    result = set_registry_string(
        HKEY_CURRENT_USER,
        class_path,
        nullptr,
        service_name
    );
    if (FAILED(result)) {
        return result;
    }

    const std::wstring server_path = class_path + L"\\InprocServer32";
    result = set_registry_string(
        HKEY_CURRENT_USER,
        server_path,
        nullptr,
        dll_path
    );
    if (FAILED(result)) {
        return result;
    }
    return set_registry_string(
        HKEY_CURRENT_USER,
        server_path,
        L"ThreadingModel",
        L"Apartment"
    );
}

[[nodiscard]] HRESULT unregister_com_server() noexcept {
    std::wstring class_id;
    HRESULT result = clsid_string(class_id);
    if (FAILED(result)) {
        return result;
    }

    const std::wstring class_path =
        L"Software\\Classes\\CLSID\\" + class_id;
    const LSTATUS status = RegDeleteTreeW(
        HKEY_CURRENT_USER,
        class_path.c_str()
    );
    if (status == ERROR_FILE_NOT_FOUND) {
        return S_OK;
    }
    return HRESULT_FROM_WIN32(status);
}

[[nodiscard]] HRESULT register_profile(
    const std::wstring_view dll_path
) noexcept {
    Microsoft::WRL::ComPtr<ITfInputProcessorProfiles> profiles;
    HRESULT result = CoCreateInstance(
        CLSID_TF_InputProcessorProfiles,
        nullptr,
        CLSCTX_INPROC_SERVER,
        IID_PPV_ARGS(&profiles)
    );
    if (FAILED(result)) {
        return result;
    }

    result = profiles->Register(text_service_clsid);
    if (FAILED(result)) {
        return result;
    }

    result = profiles->AddLanguageProfile(
        text_service_clsid,
        vietnamese_language,
        vietnamese_profile_guid,
        service_name.data(),
        static_cast<ULONG>(service_name.size()),
        dll_path.data(),
        static_cast<ULONG>(dll_path.size()),
        0
    );
    if (FAILED(result)) {
        static_cast<void>(profiles->Unregister(text_service_clsid));
    }
    return result;
}

[[nodiscard]] HRESULT unregister_profile() noexcept {
    Microsoft::WRL::ComPtr<ITfInputProcessorProfiles> profiles;
    const HRESULT create_result = CoCreateInstance(
        CLSID_TF_InputProcessorProfiles,
        nullptr,
        CLSCTX_INPROC_SERVER,
        IID_PPV_ARGS(&profiles)
    );
    if (FAILED(create_result)) {
        return create_result;
    }
    return profiles->Unregister(text_service_clsid);
}

[[nodiscard]] HRESULT register_categories() noexcept {
    Microsoft::WRL::ComPtr<ITfCategoryMgr> categories;
    HRESULT result = CoCreateInstance(
        CLSID_TF_CategoryMgr,
        nullptr,
        CLSCTX_INPROC_SERVER,
        IID_PPV_ARGS(&categories)
    );
    if (FAILED(result)) {
        return result;
    }

    result = categories->RegisterCategory(
        text_service_clsid,
        GUID_TFCAT_TIP_KEYBOARD,
        text_service_clsid
    );
    if (FAILED(result)) {
        return result;
    }

    result = categories->RegisterCategory(
        text_service_clsid,
        GUID_TFCAT_TIPCAP_IMMERSIVESUPPORT,
        text_service_clsid
    );
    if (FAILED(result)) {
        static_cast<void>(categories->UnregisterCategory(
            text_service_clsid,
            GUID_TFCAT_TIP_KEYBOARD,
            text_service_clsid
        ));
    }
    return result;
}

[[nodiscard]] HRESULT unregister_categories() noexcept {
    Microsoft::WRL::ComPtr<ITfCategoryMgr> categories;
    const HRESULT create_result = CoCreateInstance(
        CLSID_TF_CategoryMgr,
        nullptr,
        CLSCTX_INPROC_SERVER,
        IID_PPV_ARGS(&categories)
    );
    if (FAILED(create_result)) {
        return create_result;
    }

    const HRESULT immersive_result = categories->UnregisterCategory(
        text_service_clsid,
        GUID_TFCAT_TIPCAP_IMMERSIVESUPPORT,
        text_service_clsid
    );
    const HRESULT keyboard_result = categories->UnregisterCategory(
        text_service_clsid,
        GUID_TFCAT_TIP_KEYBOARD,
        text_service_clsid
    );
    return FAILED(immersive_result) ? immersive_result : keyboard_result;
}

}  // namespace

HRESULT register_server() noexcept {
    try {
        ComApartment apartment;
        if (FAILED(apartment.result())) {
            return apartment.result();
        }

        std::wstring dll_path;
        HRESULT result = module_path(dll_path);
        if (FAILED(result)) {
            return result;
        }

        result = register_com_server(dll_path);
        if (FAILED(result)) {
            return result;
        }

        result = register_profile(dll_path);
        if (FAILED(result)) {
            static_cast<void>(unregister_com_server());
            return result;
        }

        result = register_categories();
        if (FAILED(result)) {
            static_cast<void>(unregister_profile());
            static_cast<void>(unregister_com_server());
        }
        return result;
    } catch (...) {
        return E_FAIL;
    }
}

HRESULT unregister_server() noexcept {
    try {
        ComApartment apartment;
        if (FAILED(apartment.result())) {
            return apartment.result();
        }

        const HRESULT category_result = unregister_categories();
        const HRESULT profile_result = unregister_profile();
        const HRESULT com_result = unregister_com_server();

        if (FAILED(category_result)) {
            return category_result;
        }
        if (FAILED(profile_result)) {
            return profile_result;
        }
        return com_result;
    } catch (...) {
        return E_FAIL;
    }
}

}  // namespace phtv::windows::ime
