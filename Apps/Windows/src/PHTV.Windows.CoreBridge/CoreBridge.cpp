#include "CoreBridge.h"

#include <array>
#include <new>
#include <utility>
#include <vector>

#include <PHTVCoreContracts.h>

namespace phtv::windows::core {
namespace {

constexpr std::size_t initial_replacement_capacity = 128;

[[nodiscard]] Status to_status(const phtv_core_status_t status) noexcept {
    switch (status) {
        case PHTV_CORE_STATUS_OK:
            return Status::ok;
        case PHTV_CORE_STATUS_INVALID_ARGUMENT:
            return Status::invalid_argument;
        case PHTV_CORE_STATUS_UNSUPPORTED_ABI:
            return Status::unsupported_abi;
        case PHTV_CORE_STATUS_BUFFER_TOO_SMALL:
            return Status::buffer_too_small;
        default:
            return Status::internal_error;
    }
}

[[nodiscard]] phtv_core_key_event_t to_contract(
    const KeyEvent& event
) noexcept {
    phtv_core_key_event_t result{};
    result.struct_size = sizeof(result);
    result.kind = static_cast<phtv_core_event_kind_t>(event.kind);
    result.hardware_key = event.hardware_usage;
    result.logical_scalar = static_cast<std::uint32_t>(event.logical_scalar);
    result.modifiers = event.modifiers;
    result.is_repeat = event.is_repeat ? 1U : 0U;
    return result;
}

[[nodiscard]] phtv_core_input_context_t to_contract(
    const InputContext& context
) noexcept {
    phtv_core_input_context_t result{};
    result.struct_size = sizeof(result);
    result.language_mode =
        static_cast<phtv_core_language_mode_t>(context.language_mode);
    result.app_rule =
        static_cast<phtv_core_app_rule_t>(context.application_rule);
    result.input_method =
        static_cast<phtv_core_input_method_t>(context.input_method);
    result.flags = context.flags;
    return result;
}

void copy_plan(
    const phtv_core_edit_plan_t& source,
    const std::uint16_t* replacement,
    EditPlan& destination
) {
    destination.action = static_cast<EditAction>(source.action);
    destination.delete_before_utf16 = source.delete_before_utf16;
    destination.delete_after_utf16 = source.delete_after_utf16;
    destination.replacement.resize(source.replacement_length_utf16);
    for (std::uint32_t index = 0;
         index < source.replacement_length_utf16;
         ++index) {
        destination.replacement[index] =
            static_cast<char16_t>(replacement[index]);
    }
    destination.consumes_key =
        (source.flags & PHTV_CORE_EDIT_CONSUMES_KEY) != 0;
    destination.ends_composition =
        (source.flags & PHTV_CORE_EDIT_ENDS_COMPOSITION) != 0;
    destination.session_generation = source.session_generation;
}

}  // namespace

Session::~Session() noexcept {
    if (handle_ != nullptr) {
        static_cast<void>(phtv_core_session_destroy(handle_));
        handle_ = nullptr;
    }
}

Status Session::initialize() noexcept {
    if (handle_ != nullptr) {
        return Status::ok;
    }

    if (phtv_core_abi_version() != PHTV_CORE_ABI_VERSION
        || phtv_core_key_event_size() != sizeof(phtv_core_key_event_t)
        || phtv_core_input_context_size() != sizeof(phtv_core_input_context_t)
        || phtv_core_edit_plan_size() != sizeof(phtv_core_edit_plan_t)) {
        return Status::unsupported_abi;
    }

    constexpr auto required_capabilities =
        PHTV_CORE_CAPABILITY_SESSION_ABI
        | PHTV_CORE_CAPABILITY_VIETNAMESE_ENGINE;
    if ((phtv_core_capabilities() & required_capabilities)
        != required_capabilities) {
        return Status::unsupported_abi;
    }

    return to_status(phtv_core_session_create(&handle_));
}

Status Session::reset() noexcept {
    if (handle_ == nullptr) {
        return Status::invalid_argument;
    }
    return to_status(phtv_core_session_reset(handle_));
}

Status Session::handle(
    const KeyEvent& event,
    const InputContext& context,
    EditPlan& output
) noexcept {
    if (handle_ == nullptr) {
        return Status::invalid_argument;
    }

    const auto contract_event = to_contract(event);
    const auto contract_context = to_contract(context);
    phtv_core_edit_plan_t contract_plan{};
    contract_plan.struct_size = sizeof(contract_plan);
    std::array<std::uint16_t, initial_replacement_capacity> initial_buffer{};

    phtv_core_status_t status = phtv_core_session_handle_event(
        handle_,
        &contract_event,
        &contract_context,
        &contract_plan,
        initial_buffer.data(),
        initial_buffer.size()
    );

    try {
        if (status == PHTV_CORE_STATUS_OK) {
            copy_plan(contract_plan, initial_buffer.data(), output);
            return Status::ok;
        }

        if (status != PHTV_CORE_STATUS_BUFFER_TOO_SMALL) {
            return to_status(status);
        }

        std::vector<std::uint16_t> retry_buffer(
            contract_plan.replacement_length_utf16
        );
        contract_plan = {};
        contract_plan.struct_size = sizeof(contract_plan);

        status = phtv_core_session_handle_event(
            handle_,
            &contract_event,
            &contract_context,
            &contract_plan,
            retry_buffer.data(),
            retry_buffer.size()
        );
        if (status != PHTV_CORE_STATUS_OK) {
            return to_status(status);
        }

        copy_plan(contract_plan, retry_buffer.data(), output);
        return Status::ok;
    } catch (const std::bad_alloc&) {
        return Status::internal_error;
    } catch (...) {
        return Status::internal_error;
    }
}

bool Session::is_initialized() const noexcept {
    return handle_ != nullptr;
}

}  // namespace phtv::windows::core
