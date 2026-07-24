#include "InputModeState.h"

namespace phtv::windows::ime {

InputModeState::InputModeState(const bool enabled) noexcept
    : enabled_(enabled) {}

bool InputModeState::enabled() const noexcept {
    return enabled_;
}

std::uint64_t InputModeState::generation() const noexcept {
    return generation_;
}

bool InputModeState::set_enabled(const bool enabled) noexcept {
    if (enabled_ == enabled) {
        return false;
    }
    enabled_ = enabled;
    ++generation_;
    return true;
}

bool InputModeState::apply_open_close_value(
    const std::int32_t value
) noexcept {
    return set_enabled(value != 0);
}

bool InputModeState::toggled_value() const noexcept {
    return !enabled_;
}

}  // namespace phtv::windows::ime
