#include "InputScopePolicy.h"

namespace phtv::windows::ime {

bool is_sensitive_input_scope(const std::int32_t value) noexcept {
    switch (static_cast<InputScopeValue>(value)) {
        case InputScopeValue::password:
        case InputScopeValue::private_data:
        case InputScopeValue::numeric_password:
        case InputScopeValue::numeric_pin:
        case InputScopeValue::alphanumeric_pin:
        case InputScopeValue::alphanumeric_pin_set:
            return true;
        default:
            return false;
    }
}

bool contains_sensitive_input_scope(
    const std::span<const std::int32_t> values
) noexcept {
    for (const std::int32_t value : values) {
        if (is_sensitive_input_scope(value)) {
            return true;
        }
    }
    return false;
}

}  // namespace phtv::windows::ime
