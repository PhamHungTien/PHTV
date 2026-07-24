#pragma once

#include <string>

namespace phtv::windows::ime {

struct CurrentApplicationIdentity final {
    std::string executable_identity;
    std::string package_family_name;

    [[nodiscard]] bool is_valid() const noexcept {
        return !executable_identity.empty();
    }
};

/// Resolves the identity of the process hosting the TSF DLL. The executable
/// value is a normalized base filename, never a full user path.
[[nodiscard]] CurrentApplicationIdentity
resolve_current_application_identity() noexcept;

}  // namespace phtv::windows::ime
