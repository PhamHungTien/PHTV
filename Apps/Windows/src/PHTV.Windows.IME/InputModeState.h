#pragma once

#include <cstdint>

namespace phtv::windows::ime {

class InputModeState final {
public:
    explicit InputModeState(bool enabled = true) noexcept;

    [[nodiscard]] bool enabled() const noexcept;
    [[nodiscard]] std::uint64_t generation() const noexcept;

    /// Returns true only when the effective state changed.
    [[nodiscard]] bool set_enabled(bool enabled) noexcept;

    /// Applies the TSF VT_I4 convention: zero is closed, nonzero is open.
    [[nodiscard]] bool apply_open_close_value(
        std::int32_t value
    ) noexcept;

    [[nodiscard]] bool toggled_value() const noexcept;

private:
    bool enabled_;
    std::uint64_t generation_{};
};

}  // namespace phtv::windows::ime
