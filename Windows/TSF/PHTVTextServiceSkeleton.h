#pragma once

#ifdef _WIN32

#include <chrono>
#include <filesystem>
#include <msctf.h>
#include <windows.h>
#include "PHTVEngineSession.h"

namespace phtv::windows_tsf {

extern const CLSID CLSID_PHTVTextService;
extern const GUID GUID_PHTVLanguageProfile;

class PHTVTextService final : public ITfTextInputProcessor,
                              public ITfThreadMgrEventSink,
                              public ITfKeyEventSink {
public:
    PHTVTextService();

    // IUnknown
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void** ppvObject) override;
    ULONG STDMETHODCALLTYPE AddRef() override;
    ULONG STDMETHODCALLTYPE Release() override;

    // ITfTextInputProcessor
    HRESULT STDMETHODCALLTYPE Activate(ITfThreadMgr* threadMgr, TfClientId clientId) override;
    HRESULT STDMETHODCALLTYPE Deactivate() override;

    // ITfThreadMgrEventSink
    HRESULT STDMETHODCALLTYPE OnInitDocumentMgr(ITfDocumentMgr* documentMgr) override;
    HRESULT STDMETHODCALLTYPE OnUninitDocumentMgr(ITfDocumentMgr* documentMgr) override;
    HRESULT STDMETHODCALLTYPE OnSetFocus(ITfDocumentMgr* focus, ITfDocumentMgr* previousFocus) override;
    HRESULT STDMETHODCALLTYPE OnPushContext(ITfContext* context) override;
    HRESULT STDMETHODCALLTYPE OnPopContext(ITfContext* context) override;

    // ITfKeyEventSink
    HRESULT STDMETHODCALLTYPE OnSetFocus(BOOL foreground) override;
    HRESULT STDMETHODCALLTYPE OnTestKeyDown(ITfContext* context,
                                            WPARAM wParam,
                                            LPARAM lParam,
                                            BOOL* eaten) override;
    HRESULT STDMETHODCALLTYPE OnTestKeyUp(ITfContext* context,
                                          WPARAM wParam,
                                          LPARAM lParam,
                                          BOOL* eaten) override;
    HRESULT STDMETHODCALLTYPE OnKeyDown(ITfContext* context,
                                        WPARAM wParam,
                                        LPARAM lParam,
                                        BOOL* eaten) override;
    HRESULT STDMETHODCALLTYPE OnKeyUp(ITfContext* context,
                                      WPARAM wParam,
                                      LPARAM lParam,
                                      BOOL* eaten) override;
    HRESULT STDMETHODCALLTYPE OnPreservedKey(ITfContext* context,
                                             REFGUID guid,
                                             BOOL* eaten) override;

private:
    void unadviseSinks();
    void clearPendingOutput();
    void refreshRuntimeConfigIfNeeded(bool force);

    bool shouldBypassVirtualKey(WPARAM virtualKey) const;
    Uint8 currentCapsStatus() const;
    bool hasOtherControlKey() const;
    bool requestEditSession(ITfContext* context, LONG backspaceCount, const std::wstring& text) const;

    bool buildCommitText(const phtv::windows_host::EngineOutput& output,
                         Uint16 engineKeyCode,
                         Uint8 capsStatus,
                         LONG& outBackspaceCount,
                         std::wstring& outText) const;
    void appendEngineSequence(const std::vector<Uint32>& sequence,
                              bool reverseOrder,
                              std::wstring& outText) const;
    void appendEngineData(Uint32 data, std::wstring& outText) const;
    bool tryMapCodeTableValueToUnicode(Uint16 encodedValue, std::wstring& outText) const;

    LONG refCount_;
    ITfThreadMgr* threadMgr_;
    ITfKeystrokeMgr* keyStrokeMgr_;
    ITfSource* source_;
    TfClientId clientId_;
    DWORD threadMgrEventSinkCookie_;
    bool activated_;

    bool runtimeConfigLoaded_;
    bool hasConfigFile_;
    bool hasMacrosFile_;
    bool hasConfigWriteTime_;
    bool hasMacrosWriteTime_;
    std::filesystem::file_time_type configWriteTime_;
    std::filesystem::file_time_type macrosWriteTime_;
    std::chrono::steady_clock::time_point nextConfigCheckAt_;

    bool hasPendingOutput_;
    WPARAM pendingWParam_;
    LPARAM pendingLParam_;
    Uint16 pendingEngineKeyCode_;
    Uint8 pendingCapsStatus_;
    phtv::windows_host::EngineOutput pendingOutput_;

    phtv::windows_host::PHTVEngineSession session_;
};

HRESULT registerTextServiceServer();
HRESULT unregisterTextServiceServer();

} // namespace phtv::windows_tsf

#endif // _WIN32
