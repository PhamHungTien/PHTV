#include <array>
#include <cstdint>
#include <iostream>

#include "InputScopePolicy.h"

namespace {

using phtv::windows::ime::contains_sensitive_input_scope;
using phtv::windows::ime::is_sensitive_input_scope;

[[nodiscard]] bool expect(
    const bool condition,
    const char* const message
) noexcept {
    if (!condition) {
        std::cerr << "FAILED: " << message << '\n';
    }
    return condition;
}

[[nodiscard]] bool sensitive_scopes_are_blocked() noexcept {
    constexpr std::array<std::int32_t, 6> sensitive{
        31,  // IS_PASSWORD
        61,  // IS_PRIVATE
        63,  // IS_NUMERIC_PASSWORD
        64,  // IS_NUMERIC_PIN
        65,  // IS_ALPHANUMERIC_PIN
        66,  // IS_ALPHANUMERIC_PIN_SET
    };
    for (const std::int32_t scope : sensitive) {
        if (!expect(is_sensitive_input_scope(scope), "sensitive scope")) {
            return false;
        }
    }
    return expect(
        contains_sensitive_input_scope(sensitive),
        "sensitive scope collection"
    );
}

[[nodiscard]] bool ordinary_scopes_remain_available() noexcept {
    constexpr std::array<std::int32_t, 10> ordinary{
        0,   // IS_DEFAULT
        1,   // IS_URL
        5,   // IS_EMAIL_SMTPEMAILADDRESS
        6,   // IS_LOGINNAME
        28,  // IS_DIGITS
        29,  // IS_NUMBER
        50,  // IS_SEARCH
        57,  // IS_TEXT
        58,  // IS_CHAT
        -1,  // IS_PHRASELIST
    };
    for (const std::int32_t scope : ordinary) {
        if (!expect(!is_sensitive_input_scope(scope), "ordinary scope")) {
            return false;
        }
    }
    return expect(
        !contains_sensitive_input_scope(ordinary),
        "ordinary scope collection"
    );
}

[[nodiscard]] bool any_sensitive_scope_wins() noexcept {
    constexpr std::array<std::int32_t, 4> mixed{57, 50, 64, 58};
    return expect(
        contains_sensitive_input_scope(mixed),
        "mixed scope collection"
    );
}

}  // namespace

int main() {
    if (!sensitive_scopes_are_blocked()
        || !ordinary_scopes_remain_available()
        || !any_sensitive_scope_wins()) {
        return 1;
    }
    std::cout << "PHTV Windows input scope policy tests passed\n";
    return 0;
}
