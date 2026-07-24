#pragma once

#include <atomic>

#include <msctf.h>
#include <wrl/client.h>

#include "CoreBridge.h"
#include "InputModeState.h"
#include "SettingsSnapshot.h"

namespace phtv::windows::ime {

class TextService final
    : public ITfTextInputProcessorEx,
      public ITfKeyEventSink,
      public ITfCompositionSink,
      public ITfCompartmentEventSink {
public:
    TextService() noexcept;

    TextService(const TextService&) = delete;
    TextService& operator=(const TextService&) = delete;

    // IUnknown
    HRESULT STDMETHODCALLTYPE QueryInterface(
        REFIID interface_id,
        void** object
    ) noexcept override;
    ULONG STDMETHODCALLTYPE AddRef() noexcept override;
    ULONG STDMETHODCALLTYPE Release() noexcept override;

    // ITfTextInputProcessor / ITfTextInputProcessorEx
    HRESULT STDMETHODCALLTYPE Activate(
        ITfThreadMgr* thread_manager,
        TfClientId client_id
    ) noexcept override;
    HRESULT STDMETHODCALLTYPE Deactivate() noexcept override;
    HRESULT STDMETHODCALLTYPE ActivateEx(
        ITfThreadMgr* thread_manager,
        TfClientId client_id,
        DWORD flags
    ) noexcept override;

    // ITfKeyEventSink
    HRESULT STDMETHODCALLTYPE OnSetFocus(BOOL foreground) noexcept override;
    HRESULT STDMETHODCALLTYPE OnTestKeyDown(
        ITfContext* context,
        WPARAM virtual_key,
        LPARAM key_data,
        BOOL* eaten
    ) noexcept override;
    HRESULT STDMETHODCALLTYPE OnTestKeyUp(
        ITfContext* context,
        WPARAM virtual_key,
        LPARAM key_data,
        BOOL* eaten
    ) noexcept override;
    HRESULT STDMETHODCALLTYPE OnKeyDown(
        ITfContext* context,
        WPARAM virtual_key,
        LPARAM key_data,
        BOOL* eaten
    ) noexcept override;
    HRESULT STDMETHODCALLTYPE OnKeyUp(
        ITfContext* context,
        WPARAM virtual_key,
        LPARAM key_data,
        BOOL* eaten
    ) noexcept override;
    HRESULT STDMETHODCALLTYPE OnPreservedKey(
        ITfContext* context,
        REFGUID preserved_key,
        BOOL* eaten
    ) noexcept override;

    // ITfCompositionSink
    HRESULT STDMETHODCALLTYPE OnCompositionTerminated(
        TfEditCookie edit_cookie,
        ITfComposition* composition
    ) noexcept override;

    // ITfCompartmentEventSink
    HRESULT STDMETHODCALLTYPE OnChange(REFGUID compartment) noexcept override;

    [[nodiscard]] HRESULT apply_replacement(
        ITfContext* context,
        TfEditCookie edit_cookie,
        const core::EditPlan& plan
    ) noexcept;
    [[nodiscard]] HRESULT commit_composition(
        TfEditCookie edit_cookie
    ) noexcept;

private:
    ~TextService() noexcept;

    [[nodiscard]] bool could_process_key(
        WPARAM virtual_key,
        LPARAM key_data
    ) const noexcept;
    [[nodiscard]] HRESULT request_replacement(
        ITfContext* context,
        const core::EditPlan& plan
    ) noexcept;
    [[nodiscard]] HRESULT request_commit(
        ITfContext* context
    ) noexcept;
    [[nodiscard]] HRESULT request_commit_for_mode_change(
        ITfContext* context
    ) noexcept;
    [[nodiscard]] bool input_scope_allows_processing(
        ITfContext* context
    ) noexcept;
    [[nodiscard]] HRESULT initialize_input_mode() noexcept;
    [[nodiscard]] HRESULT shutdown_input_mode() noexcept;
    [[nodiscard]] HRESULT register_toggle_key() noexcept;
    [[nodiscard]] HRESULT unregister_toggle_key() noexcept;
    [[nodiscard]] HRESULT set_input_mode_enabled(
        bool enabled,
        ITfContext* context
    ) noexcept;
    void reset_for_input_mode_change(ITfContext* context) noexcept;
    void prepare_sensitive_passthrough(
        ITfContext* context
    ) noexcept;
    void switch_context(ITfContext* context) noexcept;
    void clear_runtime_state() noexcept;

    std::atomic<ULONG> reference_count_{1};
    Microsoft::WRL::ComPtr<ITfThreadMgr> thread_manager_;
    Microsoft::WRL::ComPtr<ITfContext> active_context_;
    Microsoft::WRL::ComPtr<ITfComposition> composition_;
    Microsoft::WRL::ComPtr<ITfCompartment> open_close_compartment_;
    Microsoft::WRL::ComPtr<ITfSource> open_close_source_;
    TfClientId client_id_{TF_CLIENTID_NULL};
    DWORD open_close_cookie_{TF_INVALID_COOKIE};
    core::Session core_session_;
    SettingsSnapshot settings_snapshot_;
    InputModeState input_mode_state_;
    WPARAM tested_virtual_key_{};
    LPARAM tested_key_data_{};
    bool tested_scope_allowed_{};
    bool tested_scope_pending_{};
    bool toggle_key_registered_{};
    bool active_{};
    bool ending_for_replacement_{};
};

[[nodiscard]] HRESULT create_text_service(
    REFIID interface_id,
    void** object
) noexcept;

}  // namespace phtv::windows::ime
