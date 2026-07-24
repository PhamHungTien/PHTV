#include "TextService.h"

#include <array>
#include <climits>
#include <limits>
#include <new>
#include <utility>

#include <windows.h>

#include "ModuleState.h"
#include "SettingsStore.h"

namespace phtv::windows::ime {
namespace {

namespace core = phtv::windows::core;

enum class EditSessionOperation {
    replace,
    commit,
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
    const REFIID interface_id,
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
    return S_OK;
}

HRESULT TextService::Deactivate() noexcept {
    if (!active_ && thread_manager_ == nullptr) {
        return S_OK;
    }

    if (thread_manager_ != nullptr && client_id_ != TF_CLIENTID_NULL) {
        Microsoft::WRL::ComPtr<ITfKeystrokeMgr> keystroke_manager;
        if (SUCCEEDED(thread_manager_->QueryInterface(
                IID_PPV_ARGS(&keystroke_manager)
            ))) {
            static_cast<void>(
                keystroke_manager->UnadviseKeyEventSink(client_id_)
            );
        }
    }

    clear_runtime_state();
    thread_manager_.Reset();
    client_id_ = TF_CLIENTID_NULL;
    active_ = false;
    return S_OK;
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

    *eaten = could_process_key(virtual_key, key_data) ? TRUE : FALSE;
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
    input_context.language_mode = settings_snapshot_.vietnamese_enabled
        ? core::LanguageMode::vietnamese
        : core::LanguageMode::english;
    input_context.input_method =
        settings_snapshot_.input_method == SnapshotInputMethod::vni
        ? core::InputMethod::vni
        : core::InputMethod::telex;
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
    const REFGUID preserved_key,
    BOOL* const eaten
) noexcept {
    UNREFERENCED_PARAMETER(context);
    UNREFERENCED_PARAMETER(preserved_key);

    if (eaten == nullptr) {
        return E_POINTER;
    }
    *eaten = FALSE;
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
    if (!settings_snapshot_.vietnamese_enabled) {
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

void TextService::switch_context(ITfContext* const context) noexcept {
    if (active_context_.Get() == context) {
        return;
    }

    composition_.Reset();
    active_context_ = context;
    static_cast<void>(core_session_.reset());
}

void TextService::clear_runtime_state() noexcept {
    composition_.Reset();
    active_context_.Reset();
    if (core_session_.is_initialized()) {
        static_cast<void>(core_session_.reset());
    }
}

HRESULT create_text_service(
    const REFIID interface_id,
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
