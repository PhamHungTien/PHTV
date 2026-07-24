#include "TextService.h"

#include <array>
#include <climits>
#include <iterator>
#include <limits>
#include <new>
#include <utility>

#include <windows.h>
#include <initguid.h>
#include <inputscope.h>
#include <oleauto.h>

#include "ApplicationIdentity.h"
#include "Guids.h"
#include "InputScopePolicy.h"
#include "ModuleState.h"
#include "SettingsStore.h"

namespace phtv::windows::ime {
namespace {

namespace core = phtv::windows::core;

enum class EditSessionOperation {
    replace,
    commit,
};

constexpr TF_PRESERVEDKEY toggle_language_key{
    VK_SPACE,
    TF_MOD_CONTROL,
};
constexpr wchar_t toggle_language_description[] = L"Chuyển Việt/Anh";

enum class InputScopeReadResult {
    standard,
    sensitive,
    unavailable,
};

class ScopedVariant final {
public:
    ScopedVariant() noexcept {
        VariantInit(&value_);
    }
    ~ScopedVariant() noexcept {
        static_cast<void>(VariantClear(&value_));
    }

    ScopedVariant(const ScopedVariant&) = delete;
    ScopedVariant& operator=(const ScopedVariant&) = delete;

    [[nodiscard]] VARIANT* get() noexcept {
        return &value_;
    }

    [[nodiscard]] const VARIANT& value() const noexcept {
        return value_;
    }

private:
    VARIANT value_{};
};

[[nodiscard]] InputScopeReadResult read_input_scope(
    ITfContext* const context,
    const TfEditCookie edit_cookie
) noexcept {
    if (context == nullptr) {
        return InputScopeReadResult::unavailable;
    }

    TF_SELECTION selection{};
    ULONG fetched{};
    HRESULT result = context->GetSelection(
        edit_cookie,
        TF_DEFAULT_SELECTION,
        1,
        &selection,
        &fetched
    );
    if (FAILED(result) || fetched != 1 || selection.range == nullptr) {
        return InputScopeReadResult::unavailable;
    }

    Microsoft::WRL::ComPtr<ITfRange> range;
    range.Attach(selection.range);

    Microsoft::WRL::ComPtr<ITfReadOnlyProperty> property;
    result = context->GetAppProperty(
        GUID_PROP_INPUTSCOPE,
        property.GetAddressOf()
    );
    if (result == S_FALSE || result == E_NOTIMPL) {
        return InputScopeReadResult::standard;
    }
    if (FAILED(result) || property == nullptr) {
        return InputScopeReadResult::unavailable;
    }

    ScopedVariant property_value;
    result = property->GetValue(
        edit_cookie,
        range.Get(),
        property_value.get()
    );
    if (result == S_FALSE || property_value.value().vt == VT_EMPTY) {
        return InputScopeReadResult::standard;
    }
    if (FAILED(result)) {
        return InputScopeReadResult::unavailable;
    }

    IUnknown* value_object = nullptr;
    if (property_value.value().vt == VT_UNKNOWN) {
        value_object = property_value.value().punkVal;
    } else if (property_value.value().vt == VT_DISPATCH) {
        value_object = property_value.value().pdispVal;
    }
    if (value_object == nullptr) {
        return InputScopeReadResult::unavailable;
    }

    Microsoft::WRL::ComPtr<ITfInputScope> input_scope;
    result = value_object->QueryInterface(IID_PPV_ARGS(&input_scope));
    if (FAILED(result) || input_scope == nullptr) {
        return InputScopeReadResult::unavailable;
    }

    InputScope* scopes = nullptr;
    UINT scope_count{};
    result = input_scope->GetInputScopes(&scopes, &scope_count);
    if (FAILED(result) || (scope_count != 0 && scopes == nullptr)) {
        CoTaskMemFree(scopes);
        return InputScopeReadResult::unavailable;
    }

    bool sensitive{};
    for (UINT index = 0; index < scope_count; ++index) {
        if (is_sensitive_input_scope(
                static_cast<std::int32_t>(scopes[index])
            )) {
            sensitive = true;
            break;
        }
    }
    CoTaskMemFree(scopes);
    return sensitive
        ? InputScopeReadResult::sensitive
        : InputScopeReadResult::standard;
}

class InputScopeEditSession final : public ITfEditSession {
public:
    explicit InputScopeEditSession(ITfContext* context) noexcept
        : context_(context) {}

    HRESULT STDMETHODCALLTYPE QueryInterface(
        REFIID interface_id,
        void** object
    ) noexcept override {
        if (object == nullptr) {
            return E_POINTER;
        }
        *object = nullptr;
        if (IsEqualIID(interface_id, IID_IUnknown)
            || IsEqualIID(interface_id, IID_ITfEditSession)) {
            *object = static_cast<ITfEditSession*>(this);
            AddRef();
            return S_OK;
        }
        return E_NOINTERFACE;
    }

    ULONG STDMETHODCALLTYPE AddRef() noexcept override {
        return reference_count_.fetch_add(1, std::memory_order_relaxed) + 1;
    }

    ULONG STDMETHODCALLTYPE Release() noexcept override {
        const ULONG remaining =
            reference_count_.fetch_sub(1, std::memory_order_acq_rel) - 1;
        if (remaining == 0) {
            delete this;
        }
        return remaining;
    }

    HRESULT STDMETHODCALLTYPE DoEditSession(
        const TfEditCookie edit_cookie
    ) noexcept override {
        result_ = read_input_scope(context_.Get(), edit_cookie);
        return S_OK;
    }

    [[nodiscard]] InputScopeReadResult result() const noexcept {
        return result_;
    }

private:
    ~InputScopeEditSession() noexcept = default;

    std::atomic<ULONG> reference_count_{1};
    Microsoft::WRL::ComPtr<ITfContext> context_;
    InputScopeReadResult result_{InputScopeReadResult::unavailable};
};

class EditSession final : public ITfEditSession {
public:
    EditSession(
        TextService* owner,
        ITfContext* context,
        EditSessionOperation operation,
        core::EditPlan plan
    ) noexcept
        : owner_(owner),
          context_(context),
          operation_(operation),
          plan_(std::move(plan)) {
        owner_->AddRef();
    }

    HRESULT STDMETHODCALLTYPE QueryInterface(
        REFIID interface_id,
        void** object
    ) noexcept override {
        if (object == nullptr) {
            return E_POINTER;
        }
        *object = nullptr;

        if (IsEqualIID(interface_id, IID_IUnknown)
            || IsEqualIID(interface_id, IID_ITfEditSession)) {
            *object = static_cast<ITfEditSession*>(this);
            AddRef();
            return S_OK;
        }
        return E_NOINTERFACE;
    }

    ULONG STDMETHODCALLTYPE AddRef() noexcept override {
        return reference_count_.fetch_add(1, std::memory_order_relaxed) + 1;
    }

    ULONG STDMETHODCALLTYPE Release() noexcept override {
        const ULONG remaining =
            reference_count_.fetch_sub(1, std::memory_order_acq_rel) - 1;
        if (remaining == 0) {
            delete this;
        }
        return remaining;
    }

    HRESULT STDMETHODCALLTYPE DoEditSession(
        const TfEditCookie edit_cookie
    ) noexcept override {
        if (operation_ == EditSessionOperation::commit) {
            return owner_->commit_composition(edit_cookie);
        }
        return owner_->apply_replacement(
            context_.Get(),
            edit_cookie,
            plan_
        );
    }

private:
    ~EditSession() noexcept {
        owner_->Release();
    }

    std::atomic<ULONG> reference_count_{1};
    TextService* owner_;
    Microsoft::WRL::ComPtr<ITfContext> context_;
    EditSessionOperation operation_;
    core::EditPlan plan_;
};

[[nodiscard]] std::uint32_t current_modifiers() noexcept {
    std::uint32_t result = core::modifier_none;
    if ((GetKeyState(VK_SHIFT) & 0x8000) != 0) {
        result |= core::modifier_shift;
    }
    if ((GetKeyState(VK_CONTROL) & 0x8000) != 0) {
        result |= core::modifier_control;
    }
    if ((GetKeyState(VK_MENU) & 0x8000) != 0) {
        result |= core::modifier_alt;
    }
    if ((GetKeyState(VK_LWIN) & 0x8000) != 0
        || (GetKeyState(VK_RWIN) & 0x8000) != 0) {
        result |= core::modifier_command;
    }
    if ((GetKeyState(VK_CAPITAL) & 0x0001) != 0) {
        result |= core::modifier_caps_lock;
    }
    return result;
}

[[nodiscard]] char32_t logical_scalar(
    const WPARAM virtual_key,
    const LPARAM key_data
) noexcept {
    std::array<BYTE, 256> keyboard_state{};
    if (GetKeyboardState(keyboard_state.data()) == FALSE) {
        return U'\0';
    }

    std::array<wchar_t, 4> buffer{};
    const UINT scan_code =
        static_cast<UINT>((static_cast<ULONG_PTR>(key_data) >> 16U) & 0xFFU);
    const HKL keyboard_layout = GetKeyboardLayout(0);
    const int count = ToUnicodeEx(
        static_cast<UINT>(virtual_key),
        scan_code,
        keyboard_state.data(),
        buffer.data(),
        static_cast<int>(buffer.size()),
        4,
        keyboard_layout
    );

    if (count == 1) {
        return static_cast<char32_t>(buffer[0]);
    }
    if (count >= 2 && IS_HIGH_SURROGATE(buffer[0])
        && IS_LOW_SURROGATE(buffer[1])) {
        return static_cast<char32_t>(
            0x10000
            + ((static_cast<std::uint32_t>(buffer[0]) - 0xD800U) << 10U)
            + (static_cast<std::uint32_t>(buffer[1]) - 0xDC00U)
        );
    }
    return U'\0';
}

[[nodiscard]] bool is_ascii_word_scalar(const char32_t scalar) noexcept {
    return (scalar >= U'a' && scalar <= U'z')
        || (scalar >= U'A' && scalar <= U'Z')
        || (scalar >= U'0' && scalar <= U'9');
}

[[nodiscard]] core::KeyEvent make_key_event(
    const WPARAM virtual_key,
    const LPARAM key_data
) noexcept {
    return {
        .kind = core::EventKind::key_down,
        .hardware_usage = virtual_key == VK_BACK ? 0x2AU : 0U,
        .logical_scalar = logical_scalar(virtual_key, key_data),
        .modifiers = current_modifiers(),
        .is_repeat =
            (static_cast<ULONG_PTR>(key_data) & (1ULL << 30ULL)) != 0,
    };
}

[[nodiscard]] bool context_is_writable(ITfContext* context) noexcept {
    TF_STATUS status{};
    if (context == nullptr || FAILED(context->GetStatus(&status))) {
        return false;
    }
    return (status.dwDynamicFlags & TF_SD_READONLY) == 0;
}

}  // namespace

TextService::TextService() noexcept {
    module_add_ref();
}

TextService::~TextService() noexcept {
    static_cast<void>(Deactivate());
    module_release();
}

HRESULT TextService::QueryInterface(
    REFIID interface_id,
    void** const object
) noexcept {
    if (object == nullptr) {
        return E_POINTER;
    }
    *object = nullptr;

    if (IsEqualIID(interface_id, IID_IUnknown)
        || IsEqualIID(interface_id, IID_ITfTextInputProcessor)
        || IsEqualIID(interface_id, IID_ITfTextInputProcessorEx)) {
        *object = static_cast<ITfTextInputProcessorEx*>(this);
    } else if (IsEqualIID(interface_id, IID_ITfKeyEventSink)) {
        *object = static_cast<ITfKeyEventSink*>(this);
    } else if (IsEqualIID(interface_id, IID_ITfCompositionSink)) {
        *object = static_cast<ITfCompositionSink*>(this);
    } else if (IsEqualIID(interface_id, IID_ITfCompartmentEventSink)) {
        *object = static_cast<ITfCompartmentEventSink*>(this);
    } else {
        return E_NOINTERFACE;
    }

    AddRef();
    return S_OK;
}

ULONG TextService::AddRef() noexcept {
    return reference_count_.fetch_add(1, std::memory_order_relaxed) + 1;
}

ULONG TextService::Release() noexcept {
    const ULONG remaining =
        reference_count_.fetch_sub(1, std::memory_order_acq_rel) - 1;
    if (remaining == 0) {
        delete this;
    }
    return remaining;
}

HRESULT TextService::Activate(
    ITfThreadMgr* const thread_manager,
    const TfClientId client_id
) noexcept {
    return ActivateEx(thread_manager, client_id, 0);
}

HRESULT TextService::ActivateEx(
    ITfThreadMgr* const thread_manager,
    const TfClientId client_id,
    const DWORD flags
) noexcept {
    UNREFERENCED_PARAMETER(flags);

    if (thread_manager == nullptr || client_id == TF_CLIENTID_NULL) {
        return E_INVALIDARG;
    }
    if (active_) {
        return S_FALSE;
    }
    if (core_session_.initialize() != core::Status::ok) {
        return E_FAIL;
    }

    settings_snapshot_ = load_user_settings_snapshot();
    const ApplicationRulesSnapshot application_rules =
        load_user_application_rules_snapshot(settings_snapshot_.revision);
    const CurrentApplicationIdentity application_identity =
        resolve_current_application_identity();
    application_rule_ = application_identity.is_valid()
        ? application_rule_for_identity(
            application_rules,
            application_identity.executable_identity,
            application_identity.package_family_name
        )
        : SnapshotApplicationRule::inherit;
    thread_manager_ = thread_manager;
    client_id_ = client_id;

    Microsoft::WRL::ComPtr<ITfKeystrokeMgr> keystroke_manager;
    HRESULT result = thread_manager_->QueryInterface(
        IID_PPV_ARGS(&keystroke_manager)
    );
    if (SUCCEEDED(result)) {
        result = keystroke_manager->AdviseKeyEventSink(
            client_id_,
            this,
            TRUE
        );
    }
    if (FAILED(result)) {
        thread_manager_.Reset();
        client_id_ = TF_CLIENTID_NULL;
        static_cast<void>(core_session_.reset());
        return result;
    }

    active_ = true;
    result = initialize_input_mode();
    if (FAILED(result)) {
        static_cast<void>(Deactivate());
        return result;
    }

    result = register_toggle_key();
    if (FAILED(result)) {
        static_cast<void>(Deactivate());
        return result;
    }
    return S_OK;
}

HRESULT TextService::Deactivate() noexcept {
    if (!active_ && thread_manager_ == nullptr) {
        return S_OK;
    }

    HRESULT cleanup_result = S_OK;
    const auto record_failure = [&cleanup_result](const HRESULT result) {
        if (SUCCEEDED(cleanup_result) && FAILED(result)) {
            cleanup_result = result;
        }
    };

    record_failure(unregister_toggle_key());
    record_failure(shutdown_input_mode());

    if (thread_manager_ != nullptr && client_id_ != TF_CLIENTID_NULL) {
        Microsoft::WRL::ComPtr<ITfKeystrokeMgr> keystroke_manager;
        const HRESULT query_result = thread_manager_->QueryInterface(
            IID_PPV_ARGS(&keystroke_manager)
        );
        if (SUCCEEDED(query_result)) {
            record_failure(
                keystroke_manager->UnadviseKeyEventSink(client_id_)
            );
        } else {
            record_failure(query_result);
        }
    }

    clear_runtime_state();
    thread_manager_.Reset();
    client_id_ = TF_CLIENTID_NULL;
    application_rule_ = SnapshotApplicationRule::inherit;
    active_ = false;
    return cleanup_result;
}

HRESULT TextService::OnSetFocus(const BOOL foreground) noexcept {
    if (foreground == FALSE) {
        clear_runtime_state();
    }
    return S_OK;
}

HRESULT TextService::OnTestKeyDown(
    ITfContext* const context,
    const WPARAM virtual_key,
    const LPARAM key_data,
    BOOL* const eaten
) noexcept {
    if (eaten == nullptr) {
        return E_POINTER;
    }
    *eaten = FALSE;

    if (!active_ || context == nullptr || !context_is_writable(context)) {
        return S_OK;
    }

    switch_context(context);
    if (!could_process_key(virtual_key, key_data)) {
        tested_scope_pending_ = false;
        return S_OK;
    }

    tested_virtual_key_ = virtual_key;
    tested_key_data_ = key_data;
    tested_scope_allowed_ = input_scope_allows_processing(context);
    tested_scope_pending_ = true;
    if (!tested_scope_allowed_) {
        prepare_sensitive_passthrough(context);
        return S_OK;
    }

    *eaten = TRUE;
    return S_OK;
}

HRESULT TextService::OnTestKeyUp(
    ITfContext* const context,
    const WPARAM virtual_key,
    const LPARAM key_data,
    BOOL* const eaten
) noexcept {
    UNREFERENCED_PARAMETER(context);
    UNREFERENCED_PARAMETER(virtual_key);
    UNREFERENCED_PARAMETER(key_data);

    if (eaten == nullptr) {
        return E_POINTER;
    }
    *eaten = FALSE;
    return S_OK;
}

HRESULT TextService::OnKeyDown(
    ITfContext* const context,
    const WPARAM virtual_key,
    const LPARAM key_data,
    BOOL* const eaten
) noexcept {
    if (eaten == nullptr) {
        return E_POINTER;
    }
    *eaten = FALSE;

    if (!active_ || context == nullptr || !context_is_writable(context)) {
        return S_OK;
    }

    switch_context(context);
    if (!could_process_key(virtual_key, key_data)) {
        tested_scope_pending_ = false;
        return S_OK;
    }

    const bool tested_key_matches =
        tested_scope_pending_
        && tested_virtual_key_ == virtual_key
        && tested_key_data_ == key_data;
    const bool scope_allowed = tested_key_matches
        ? tested_scope_allowed_
        : input_scope_allows_processing(context);
    tested_scope_pending_ = false;
    if (!scope_allowed) {
        prepare_sensitive_passthrough(context);
        return S_OK;
    }

    const core::KeyEvent event = make_key_event(virtual_key, key_data);
    const bool is_word_key =
        virtual_key == VK_BACK || is_ascii_word_scalar(event.logical_scalar);

    if (!is_word_key) {
        if (composition_ != nullptr) {
            static_cast<void>(request_commit(context));
        }
        static_cast<void>(core_session_.reset());
        return S_OK;
    }

    core::InputContext input_context;
    input_context.language_mode = input_mode_state_.enabled()
        ? core::LanguageMode::vietnamese
        : core::LanguageMode::english;
    input_context.input_method =
        settings_snapshot_.input_method == SnapshotInputMethod::vni
        ? core::InputMethod::vni
        : core::InputMethod::telex;
    switch (application_rule_) {
        case SnapshotApplicationRule::prefer_english:
            input_context.application_rule =
                core::ApplicationRule::prefer_english;
            break;
        case SnapshotApplicationRule::lock_english:
            input_context.application_rule =
                core::ApplicationRule::lock_english;
            break;
        case SnapshotApplicationRule::inherit:
            input_context.application_rule =
                core::ApplicationRule::inherit;
            break;
    }
    input_context.flags = core::context_supports_composition;

    core::EditPlan plan;
    const core::Status status =
        core_session_.handle(event, input_context, plan);
    if (status != core::Status::ok) {
        clear_runtime_state();
        return S_OK;
    }

    if (plan.action == core::EditAction::pass_through) {
        return S_OK;
    }
    if (plan.action != core::EditAction::replace || !plan.consumes_key) {
        clear_runtime_state();
        return S_OK;
    }

    const HRESULT result = request_replacement(context, plan);
    if (FAILED(result)) {
        clear_runtime_state();
        return S_OK;
    }

    *eaten = TRUE;
    return S_OK;
}

HRESULT TextService::OnKeyUp(
    ITfContext* const context,
    const WPARAM virtual_key,
    const LPARAM key_data,
    BOOL* const eaten
) noexcept {
    return OnTestKeyUp(context, virtual_key, key_data, eaten);
}

HRESULT TextService::OnPreservedKey(
    ITfContext* const context,
    REFGUID preserved_key,
    BOOL* const eaten
) noexcept {
    if (eaten == nullptr) {
        return E_POINTER;
    }
    *eaten = FALSE;

    if (!active_
        || !IsEqualGUID(
            preserved_key,
            toggle_language_preserved_key_guid
        )) {
        return S_OK;
    }

    if (application_rule_ == SnapshotApplicationRule::lock_english) {
        *eaten = TRUE;
        return S_OK;
    }

    if (SUCCEEDED(set_input_mode_enabled(
            input_mode_state_.toggled_value(),
            context
        ))) {
        *eaten = TRUE;
    }
    return S_OK;
}

HRESULT TextService::OnCompositionTerminated(
    const TfEditCookie edit_cookie,
    ITfComposition* const composition
) noexcept {
    UNREFERENCED_PARAMETER(edit_cookie);

    if (composition_.Get() == composition) {
        composition_.Reset();
    }
    if (!ending_for_replacement_) {
        static_cast<void>(core_session_.reset());
    }
    return S_OK;
}

HRESULT TextService::OnChange(REFGUID compartment) noexcept {
    if (!IsEqualGUID(
            compartment,
            GUID_COMPARTMENT_KEYBOARD_OPENCLOSE
        )
        || open_close_compartment_ == nullptr) {
        return S_OK;
    }

    ScopedVariant value;
    const HRESULT result = open_close_compartment_->GetValue(value.get());
    if (result == S_FALSE || value.value().vt == VT_EMPTY) {
        return S_OK;
    }
    if (FAILED(result) || value.value().vt != VT_I4) {
        return S_OK;
    }

    const std::int32_t effective_value =
        application_rule_ == SnapshotApplicationRule::lock_english
        ? 0
        : value.value().lVal;
    if (input_mode_state_.apply_open_close_value(effective_value)) {
        reset_for_input_mode_change(active_context_.Get());
    }
    return S_OK;
}

HRESULT TextService::apply_replacement(
    ITfContext* const context,
    const TfEditCookie edit_cookie,
    const core::EditPlan& plan
) noexcept {
    if (context == nullptr
        || plan.replacement.size() > static_cast<std::size_t>(LONG_MAX)
        || plan.delete_before_utf16
            > static_cast<std::uint32_t>(LONG_MAX)) {
        return E_INVALIDARG;
    }

    if (composition_ != nullptr) {
        ending_for_replacement_ = true;
        const HRESULT end_result = composition_->EndComposition(edit_cookie);
        ending_for_replacement_ = false;
        composition_.Reset();
        if (FAILED(end_result)) {
            return end_result;
        }
    }

    TF_SELECTION selection{};
    ULONG fetched{};
    HRESULT result = context->GetSelection(
        edit_cookie,
        TF_DEFAULT_SELECTION,
        1,
        &selection,
        &fetched
    );
    if (FAILED(result) || fetched != 1 || selection.range == nullptr) {
        return FAILED(result) ? result : E_FAIL;
    }

    Microsoft::WRL::ComPtr<ITfRange> replacement_range;
    replacement_range.Attach(selection.range);

    LONG shifted{};
    const LONG requested_shift =
        -static_cast<LONG>(plan.delete_before_utf16);
    result = replacement_range->ShiftStart(
        edit_cookie,
        requested_shift,
        &shifted,
        nullptr
    );
    if (FAILED(result) || shifted != requested_shift) {
        return FAILED(result) ? result : TF_E_INVALIDPOS;
    }

    Microsoft::WRL::ComPtr<ITfContextComposition> composition_context;
    result = context->QueryInterface(IID_PPV_ARGS(&composition_context));
    if (FAILED(result)) {
        return result;
    }

    result = composition_context->StartComposition(
        edit_cookie,
        replacement_range.Get(),
        this,
        composition_.ReleaseAndGetAddressOf()
    );
    if (FAILED(result) || composition_ == nullptr) {
        return FAILED(result) ? result : E_FAIL;
    }

    static_assert(sizeof(wchar_t) == sizeof(char16_t));
    result = replacement_range->SetText(
        edit_cookie,
        0,
        reinterpret_cast<const wchar_t*>(plan.replacement.data()),
        static_cast<LONG>(plan.replacement.size())
    );
    if (FAILED(result)) {
        static_cast<void>(composition_->EndComposition(edit_cookie));
        composition_.Reset();
        return result;
    }

    result = replacement_range->Collapse(edit_cookie, TF_ANCHOR_END);
    if (FAILED(result)) {
        return result;
    }

    TF_SELECTION updated_selection{};
    updated_selection.range = replacement_range.Get();
    updated_selection.style.ase = TF_AE_NONE;
    updated_selection.style.fInterimChar = FALSE;
    return context->SetSelection(edit_cookie, 1, &updated_selection);
}

HRESULT TextService::commit_composition(
    const TfEditCookie edit_cookie
) noexcept {
    if (composition_ == nullptr) {
        return S_FALSE;
    }

    const HRESULT result = composition_->EndComposition(edit_cookie);
    if (SUCCEEDED(result)) {
        composition_.Reset();
        static_cast<void>(core_session_.reset());
    }
    return result;
}

bool TextService::could_process_key(
    const WPARAM virtual_key,
    const LPARAM key_data
) const noexcept {
    if (!input_mode_state_.enabled()
        || application_rule_ == SnapshotApplicationRule::lock_english) {
        return false;
    }

    const std::uint32_t modifiers = current_modifiers();
    constexpr std::uint32_t shortcut_modifiers =
        core::modifier_control | core::modifier_alt | core::modifier_command;
    if ((modifiers & shortcut_modifiers) != 0) {
        return false;
    }

    if (composition_ != nullptr || virtual_key == VK_BACK) {
        return true;
    }
    return is_ascii_word_scalar(logical_scalar(virtual_key, key_data));
}

HRESULT TextService::request_replacement(
    ITfContext* const context,
    const core::EditPlan& plan
) noexcept {
    EditSession* session = nullptr;
    try {
        session = new EditSession(
            this,
            context,
            EditSessionOperation::replace,
            plan
        );
    } catch (const std::bad_alloc&) {
        return E_OUTOFMEMORY;
    } catch (...) {
        return E_FAIL;
    }

    HRESULT session_result = E_FAIL;
    const HRESULT request_result = context->RequestEditSession(
        client_id_,
        session,
        TF_ES_SYNC | TF_ES_READWRITE,
        &session_result
    );
    session->Release();

    return FAILED(request_result) ? request_result : session_result;
}

HRESULT TextService::request_commit(ITfContext* const context) noexcept {
    EditSession* session = nullptr;
    try {
        session = new EditSession(
            this,
            context,
            EditSessionOperation::commit,
            {}
        );
    } catch (const std::bad_alloc&) {
        return E_OUTOFMEMORY;
    } catch (...) {
        return E_FAIL;
    }

    HRESULT session_result = E_FAIL;
    const HRESULT request_result = context->RequestEditSession(
        client_id_,
        session,
        TF_ES_SYNC | TF_ES_READWRITE,
        &session_result
    );
    session->Release();

    return FAILED(request_result) ? request_result : session_result;
}

HRESULT TextService::request_commit_for_mode_change(
    ITfContext* const context
) noexcept {
    EditSession* session = nullptr;
    try {
        session = new EditSession(
            this,
            context,
            EditSessionOperation::commit,
            {}
        );
    } catch (const std::bad_alloc&) {
        return E_OUTOFMEMORY;
    } catch (...) {
        return E_FAIL;
    }

    HRESULT session_result = E_FAIL;
    const HRESULT request_result = context->RequestEditSession(
        client_id_,
        session,
        TF_ES_ASYNCDONTCARE | TF_ES_READWRITE,
        &session_result
    );
    session->Release();

    return FAILED(request_result) ? request_result : session_result;
}

bool TextService::input_scope_allows_processing(
    ITfContext* const context
) noexcept {
    InputScopeEditSession* session =
        new (std::nothrow) InputScopeEditSession(context);
    if (session == nullptr) {
        return false;
    }

    HRESULT session_result = E_FAIL;
    const HRESULT request_result = context->RequestEditSession(
        client_id_,
        session,
        TF_ES_SYNC | TF_ES_READ,
        &session_result
    );
    const InputScopeReadResult scope_result = session->result();
    session->Release();

    return SUCCEEDED(request_result)
        && SUCCEEDED(session_result)
        && scope_result == InputScopeReadResult::standard;
}

HRESULT TextService::initialize_input_mode() noexcept {
    const bool starts_in_english =
        application_rule_ == SnapshotApplicationRule::prefer_english
        || application_rule_ == SnapshotApplicationRule::lock_english;
    static_cast<void>(
        input_mode_state_.set_enabled(
            settings_snapshot_.vietnamese_enabled && !starts_in_english
        )
    );

    Microsoft::WRL::ComPtr<ITfCompartmentMgr> compartment_manager;
    HRESULT result = thread_manager_->QueryInterface(
        IID_PPV_ARGS(&compartment_manager)
    );
    if (FAILED(result)) {
        return result;
    }

    Microsoft::WRL::ComPtr<ITfCompartment> compartment;
    result = compartment_manager->GetCompartment(
        GUID_COMPARTMENT_KEYBOARD_OPENCLOSE,
        compartment.GetAddressOf()
    );
    if (FAILED(result)) {
        return result;
    }

    VARIANT initial_value{};
    initial_value.vt = VT_I4;
    initial_value.lVal = input_mode_state_.enabled() ? 1 : 0;
    result = compartment->SetValue(client_id_, &initial_value);
    if (FAILED(result)) {
        return result;
    }

    Microsoft::WRL::ComPtr<ITfSource> source;
    result = compartment.As(&source);
    if (FAILED(result)) {
        return result;
    }

    DWORD cookie = TF_INVALID_COOKIE;
    result = source->AdviseSink(
        IID_ITfCompartmentEventSink,
        static_cast<ITfCompartmentEventSink*>(this),
        &cookie
    );
    if (FAILED(result)) {
        return result;
    }

    open_close_compartment_ = std::move(compartment);
    open_close_source_ = std::move(source);
    open_close_cookie_ = cookie;
    return S_OK;
}

HRESULT TextService::shutdown_input_mode() noexcept {
    HRESULT result = S_OK;
    if (open_close_source_ != nullptr
        && open_close_cookie_ != TF_INVALID_COOKIE) {
        result = open_close_source_->UnadviseSink(open_close_cookie_);
    }
    open_close_cookie_ = TF_INVALID_COOKIE;
    open_close_source_.Reset();
    open_close_compartment_.Reset();
    return result;
}

HRESULT TextService::register_toggle_key() noexcept {
    if (toggle_key_registered_) {
        return S_FALSE;
    }

    Microsoft::WRL::ComPtr<ITfKeystrokeMgr> keystroke_manager;
    HRESULT result = thread_manager_->QueryInterface(
        IID_PPV_ARGS(&keystroke_manager)
    );
    if (FAILED(result)) {
        return result;
    }

    result = keystroke_manager->PreserveKey(
        client_id_,
        toggle_language_preserved_key_guid,
        &toggle_language_key,
        toggle_language_description,
        static_cast<ULONG>(std::size(toggle_language_description) - 1)
    );
    if (SUCCEEDED(result)) {
        toggle_key_registered_ = true;
    }
    return result;
}

HRESULT TextService::unregister_toggle_key() noexcept {
    if (!toggle_key_registered_) {
        return S_OK;
    }

    HRESULT result = E_UNEXPECTED;
    Microsoft::WRL::ComPtr<ITfKeystrokeMgr> keystroke_manager;
    if (thread_manager_ != nullptr
        && SUCCEEDED(thread_manager_->QueryInterface(
            IID_PPV_ARGS(&keystroke_manager)
        ))) {
        result = keystroke_manager->UnpreserveKey(
            toggle_language_preserved_key_guid,
            &toggle_language_key
        );
    }
    toggle_key_registered_ = false;
    return result;
}

HRESULT TextService::set_input_mode_enabled(
    const bool enabled,
    ITfContext* const context
) noexcept {
    if (enabled
        && application_rule_ == SnapshotApplicationRule::lock_english) {
        return E_ACCESSDENIED;
    }
    if (open_close_compartment_ == nullptr) {
        return E_UNEXPECTED;
    }

    VARIANT value{};
    value.vt = VT_I4;
    value.lVal = enabled ? 1 : 0;
    const HRESULT result =
        open_close_compartment_->SetValue(client_id_, &value);
    if (SUCCEEDED(result)
        && input_mode_state_.set_enabled(enabled)) {
        reset_for_input_mode_change(context);
    }
    return result;
}

void TextService::reset_for_input_mode_change(
    ITfContext* const context
) noexcept {
    if (composition_ != nullptr && context != nullptr) {
        static_cast<void>(request_commit_for_mode_change(context));
    }
    tested_scope_pending_ = false;
    if (core_session_.is_initialized()) {
        static_cast<void>(core_session_.reset());
    }
}

void TextService::prepare_sensitive_passthrough(
    ITfContext* const context
) noexcept {
    if (composition_ != nullptr) {
        static_cast<void>(request_commit(context));
    }
    if (core_session_.is_initialized()) {
        static_cast<void>(core_session_.reset());
    }
}

void TextService::switch_context(ITfContext* const context) noexcept {
    if (active_context_.Get() == context) {
        return;
    }

    composition_.Reset();
    active_context_ = context;
    tested_scope_pending_ = false;
    static_cast<void>(core_session_.reset());
}

void TextService::clear_runtime_state() noexcept {
    composition_.Reset();
    active_context_.Reset();
    tested_scope_pending_ = false;
    if (core_session_.is_initialized()) {
        static_cast<void>(core_session_.reset());
    }
}

HRESULT create_text_service(
    REFIID interface_id,
    void** const object
) noexcept {
    if (object == nullptr) {
        return E_POINTER;
    }
    *object = nullptr;

    TextService* service = new (std::nothrow) TextService();
    if (service == nullptr) {
        return E_OUTOFMEMORY;
    }

    const HRESULT result = service->QueryInterface(interface_id, object);
    service->Release();
    return result;
}

}  // namespace phtv::windows::ime
