#include "ApplicationIdentity.h"

#include <array>
#include <climits>
#include <new>
#include <string>
#include <string_view>
#include <vector>

#include <windows.h>
#include <appmodel.h>

namespace phtv::windows::ime {
namespace {

[[nodiscard]] bool lowercase_invariant(
    const std::wstring_view input,
    std::wstring& output
) {
    if (input.empty()
        || input.size() > static_cast<std::size_t>(INT_MAX)) {
        return false;
    }

    const int required = LCMapStringEx(
        LOCALE_NAME_INVARIANT,
        LCMAP_LOWERCASE,
        input.data(),
        static_cast<int>(input.size()),
        nullptr,
        0,
        nullptr,
        nullptr,
        0
    );
    if (required <= 0) {
        return false;
    }

    output.resize(static_cast<std::size_t>(required));
    return LCMapStringEx(
        LOCALE_NAME_INVARIANT,
        LCMAP_LOWERCASE,
        input.data(),
        static_cast<int>(input.size()),
        output.data(),
        required,
        nullptr,
        nullptr,
        0
    ) == required;
}

[[nodiscard]] bool utf8(
    const std::wstring_view input,
    std::string& output
) {
    if (input.empty()
        || input.size() > static_cast<std::size_t>(INT_MAX)) {
        return false;
    }

    const int required = WideCharToMultiByte(
        CP_UTF8,
        WC_ERR_INVALID_CHARS,
        input.data(),
        static_cast<int>(input.size()),
        nullptr,
        0,
        nullptr,
        nullptr
    );
    if (required <= 0) {
        return false;
    }

    output.resize(static_cast<std::size_t>(required));
    return WideCharToMultiByte(
        CP_UTF8,
        WC_ERR_INVALID_CHARS,
        input.data(),
        static_cast<int>(input.size()),
        output.data(),
        required,
        nullptr,
        nullptr
    ) == required;
}

[[nodiscard]] bool normalized_utf8(
    const std::wstring_view input,
    std::string& output
) {
    std::wstring lowered;
    return lowercase_invariant(input, lowered) && utf8(lowered, output);
}

[[nodiscard]] bool executable_base_name(std::wstring_view& output) noexcept {
    static thread_local std::array<wchar_t, 32768> path{};
    const DWORD length = GetModuleFileNameW(
        nullptr,
        path.data(),
        static_cast<DWORD>(path.size())
    );
    if (length == 0 || length >= static_cast<DWORD>(path.size())) {
        return false;
    }

    const std::wstring_view full_path(path.data(), length);
    const std::size_t separator = full_path.find_last_of(L"\\/");
    output = separator == std::wstring_view::npos
        ? full_path
        : full_path.substr(separator + 1);
    return !output.empty();
}

[[nodiscard]] bool package_family_name(std::wstring& output) {
    UINT32 length{};
    const LONG size_result = GetCurrentPackageFamilyName(
        &length,
        nullptr
    );
    if (size_result == APPMODEL_ERROR_NO_PACKAGE) {
        output.clear();
        return true;
    }
    if (size_result != ERROR_INSUFFICIENT_BUFFER || length <= 1) {
        return false;
    }

    std::vector<wchar_t> buffer(length);
    const LONG read_result = GetCurrentPackageFamilyName(
        &length,
        buffer.data()
    );
    if (read_result != ERROR_SUCCESS || length <= 1) {
        return false;
    }
    output.assign(buffer.data(), static_cast<std::size_t>(length - 1));
    return true;
}

}  // namespace

CurrentApplicationIdentity resolve_current_application_identity() noexcept {
    CurrentApplicationIdentity result;
    try {
        std::wstring_view executable;
        if (!executable_base_name(executable)
            || !normalized_utf8(
                executable,
                result.executable_identity
            )) {
            return {};
        }

        std::wstring package;
        if (!package_family_name(package)) {
            return result;
        }
        if (!package.empty()
            && !normalized_utf8(
                package,
                result.package_family_name
            )) {
            result.package_family_name.clear();
        }
        return result;
    } catch (const std::bad_alloc&) {
        return {};
    } catch (...) {
        return {};
    }
}

}  // namespace phtv::windows::ime
