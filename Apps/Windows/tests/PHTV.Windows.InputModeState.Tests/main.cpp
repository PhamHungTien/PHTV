#include <cstdint>
#include <iostream>

#include "InputModeState.h"

namespace {

using phtv::windows::ime::InputModeState;

[[nodiscard]] bool expect(
    const bool condition,
    const char* const message
) noexcept {
    if (!condition) {
        std::cerr << "FAILED: " << message << '\n';
    }
    return condition;
}

[[nodiscard]] bool initial_state_is_preserved() noexcept {
    const InputModeState enabled;
    const InputModeState disabled(false);
    return expect(enabled.enabled(), "default state is enabled")
        && expect(!disabled.enabled(), "explicit state is disabled")
        && expect(enabled.generation() == 0, "initial generation is zero")
        && expect(disabled.generation() == 0, "disabled generation is zero");
}

[[nodiscard]] bool generation_tracks_effective_changes() noexcept {
    InputModeState state;
    return expect(!state.set_enabled(true), "same value is idempotent")
        && expect(state.generation() == 0, "idempotent set keeps generation")
        && expect(state.set_enabled(false), "enabled to disabled changes")
        && expect(!state.enabled(), "state becomes disabled")
        && expect(state.generation() == 1, "first change increments generation")
        && expect(!state.set_enabled(false), "second same value is idempotent")
        && expect(state.generation() == 1, "same disabled value is stable")
        && expect(state.set_enabled(true), "disabled to enabled changes")
        && expect(state.generation() == 2, "second change increments generation");
}

[[nodiscard]] bool compartment_values_follow_tsf_convention() noexcept {
    InputModeState state;
    return expect(
            state.apply_open_close_value(0),
            "zero closes input mode"
        )
        && expect(!state.enabled(), "zero leaves mode disabled")
        && expect(
            !state.apply_open_close_value(0),
            "repeated zero is idempotent"
        )
        && expect(
            state.apply_open_close_value(-1),
            "negative nonzero opens input mode"
        )
        && expect(state.enabled(), "nonzero leaves mode enabled")
        && expect(
            !state.apply_open_close_value(42),
            "another nonzero value is idempotent"
        );
}

[[nodiscard]] bool toggle_value_is_side_effect_free() noexcept {
    InputModeState state(false);
    return expect(state.toggled_value(), "disabled toggles to enabled")
        && expect(!state.enabled(), "query does not mutate state")
        && expect(state.generation() == 0, "query does not increment generation")
        && expect(state.set_enabled(state.toggled_value()), "toggle can apply")
        && expect(!state.toggled_value(), "enabled toggles to disabled");
}

}  // namespace

int main() {
    if (!initial_state_is_preserved()
        || !generation_tracks_effective_changes()
        || !compartment_values_follow_tsf_convention()
        || !toggle_value_is_side_effect_free()) {
        return 1;
    }
    std::cout << "PHTV Windows input mode state tests passed\n";
    return 0;
}
