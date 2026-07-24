#pragma once

#include <cstdint>
#include <string>

namespace phtv::windows::core {

enum class Status : std::int32_t {
    ok = 0,
    invalid_argument = 1,
    unsupported_abi = 2,
    buffer_too_small = 3,
    internal_error = 4,
};

enum class EventKind : std::uint32_t {
    key_down = 1,
    key_up = 2,
};

enum class LanguageMode : std::uint32_t {
    english = 0,
    vietnamese = 1,
};

enum class InputMethod : std::uint32_t {
    telex = 0,
    vni = 1,
};

enum class ApplicationRule : std::uint32_t {
    inherit = 0,
    prefer_english = 1,
    lock_english = 2,
};

enum class EditAction : std::uint32_t {
    pass_through = 0,
    replace = 1,
    commit = 2,
    reset_session = 3,
};

enum Modifier : std::uint32_t {
    modifier_none = 0,
    modifier_shift = 1U << 0U,
    modifier_control = 1U << 1U,
    modifier_alt = 1U << 2U,
    modifier_command = 1U << 3U,
    modifier_caps_lock = 1U << 4U,
};

enum ContextFlag : std::uint64_t {
    context_none = 0,
    context_supports_composition = 1ULL << 0ULL,
    context_supports_surrounding_text = 1ULL << 1ULL,
    context_sensitive = 1ULL << 2ULL,
    context_terminal = 1ULL << 3ULL,
};

struct KeyEvent final {
    EventKind kind{EventKind::key_down};
    std::uint32_t hardware_usage{};
    char32_t logical_scalar{};
    std::uint32_t modifiers{modifier_none};
    bool is_repeat{};
};

struct InputContext final {
    LanguageMode language_mode{LanguageMode::vietnamese};
    ApplicationRule application_rule{ApplicationRule::inherit};
    InputMethod input_method{InputMethod::telex};
    std::uint64_t flags{context_supports_composition};
};

struct EditPlan final {
    EditAction action{EditAction::pass_through};
    std::uint32_t delete_before_utf16{};
    std::uint32_t delete_after_utf16{};
    std::u16string replacement;
    bool consumes_key{};
    bool ends_composition{};
    std::uint64_t session_generation{};
};

class Session final {
public:
    Session() noexcept = default;
    ~Session() noexcept;

    Session(const Session&) = delete;
    Session& operator=(const Session&) = delete;
    Session(Session&&) = delete;
    Session& operator=(Session&&) = delete;

    [[nodiscard]] Status initialize() noexcept;
    [[nodiscard]] Status reset() noexcept;
    [[nodiscard]] Status handle(
        const KeyEvent& event,
        const InputContext& context,
        EditPlan& output
    ) noexcept;
    [[nodiscard]] bool is_initialized() const noexcept;

private:
    void* handle_{};
};

}  // namespace phtv::windows::core
