#pragma once

#include <cstdint>
#include <span>

namespace phtv::windows::ime {

// Values mirror the stable Win32 InputScope enumeration without making the
// policy classifier depend on Windows headers.
enum class InputScopeValue : std::int32_t {
    password = 31,
    private_data = 61,
    numeric_password = 63,
    numeric_pin = 64,
    alphanumeric_pin = 65,
    alphanumeric_pin_set = 66,
};

[[nodiscard]] bool is_sensitive_input_scope(
    std::int32_t value
) noexcept;

[[nodiscard]] bool contains_sensitive_input_scope(
    std::span<const std::int32_t> values
) noexcept;

}  // namespace phtv::windows::ime
