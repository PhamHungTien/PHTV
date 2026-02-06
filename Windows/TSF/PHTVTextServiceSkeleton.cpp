#ifdef _WIN32

#include "PHTVTextServiceSkeleton.h"

#include <algorithm>
#include <mutex>
#include <new>
#include <string>
#include <vector>
#include "DictionaryBootstrap.h"
#include "Engine.h"
#include "RuntimeConfig.h"
#include "Vietnamese.h"
#include "Win32KeycodeAdapter.h"

namespace {

HMODULE g_moduleHandle = nullptr;
LONG g_dllRefCount = 0;
LONG g_serverLockCount = 0;
constexpr TfClientId kInvalidClientId = static_cast<TfClientId>(0);

template <typename T>
void safeRelease(T*& ptr) {
    if (ptr != nullptr) {
        ptr->Release();
        ptr = nullptr;
    }
}

std::wstring guidToString(REFGUID guid) {
    wchar_t buffer[64] = {};
    const int length = StringFromGUID2(guid, buffer, static_cast<int>(std::size(buffer)));
    if (length <= 1) {
        return L"";
    }
    return std::wstring(buffer, buffer + length - 1);
}

std::wstring moduleFilePath() {
    wchar_t path[MAX_PATH] = {};
    if (g_moduleHandle == nullptr) {
        return L"";
    }

    const DWORD length = GetModuleFileNameW(g_moduleHandle, path, static_cast<DWORD>(std::size(path)));
    if (length == 0 || length >= std::size(path)) {
        return L"";
    }

    return std::wstring(path, path + length);
}

void ensureDictionariesLoadedForTsf() {
    static std::once_flag once;
    std::call_once(once, []() {
        const std::wstring path = moduleFilePath();
        const auto status = phtv::windows_runtime::ensureDictionariesLoaded(
            path.empty() ? std::filesystem::path() : std::filesystem::path(path));

        std::wstring message = L"PHTV TSF dictionary load status: EN=";
        message += status.englishLoaded ? L"1" : L"0";
        message += L", VI=";
        message += status.vietnameseLoaded ? L"1" : L"0";

        if (!status.englishPath.empty()) {
            message += L", EN_PATH=";
            message += status.englishPath.wstring();
        }
        if (!status.vietnamesePath.empty()) {
            message += L", VI_PATH=";
            message += status.vietnamesePath.wstring();
        }

        OutputDebugStringW(message.c_str());
        OutputDebugStringW(L"\n");
    });
}

HRESULT setRegistryString(HKEY rootKey,
                          const std::wstring& subKey,
                          const wchar_t* valueName,
                          const std::wstring& value) {
    HKEY key = nullptr;
    const LONG createResult = RegCreateKeyExW(rootKey,
                                               subKey.c_str(),
                                               0,
                                               nullptr,
                                               REG_OPTION_NON_VOLATILE,
                                               KEY_SET_VALUE,
                                               nullptr,
                                               &key,
                                               nullptr);
    if (createResult != ERROR_SUCCESS) {
        return HRESULT_FROM_WIN32(createResult);
    }

    const DWORD byteCount = static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t));
    const LONG setResult = RegSetValueExW(key,
                                          valueName,
                                          0,
                                          REG_SZ,
                                          reinterpret_cast<const BYTE*>(value.c_str()),
                                          byteCount);
    RegCloseKey(key);
    if (setResult != ERROR_SUCCESS) {
        return HRESULT_FROM_WIN32(setResult);
    }

    return S_OK;
}

HRESULT deleteRegistryTree(HKEY rootKey, const std::wstring& subKey) {
    const LONG deleteResult = RegDeleteTreeW(rootKey, subKey.c_str());
    if (deleteResult == ERROR_SUCCESS || deleteResult == ERROR_FILE_NOT_FOUND || deleteResult == ERROR_PATH_NOT_FOUND) {
        return S_OK;
    }
    return HRESULT_FROM_WIN32(deleteResult);
}

class PHTVEditSession final : public ITfEditSession {
public:
    PHTVEditSession(ITfContext* context, LONG backspaceCount, std::wstring text)
        : refCount_(1),
          context_(context),
          backspaceCount_(backspaceCount),
          text_(std::move(text)) {
        if (context_ != nullptr) {
            context_->AddRef();
        }
    }

    // IUnknown
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void** ppvObject) override {
        if (ppvObject == nullptr) {
            return E_INVALIDARG;
        }
        *ppvObject = nullptr;

        if (riid == IID_IUnknown || riid == IID_ITfEditSession) {
            *ppvObject = static_cast<ITfEditSession*>(this);
            AddRef();
            return S_OK;
        }

        return E_NOINTERFACE;
    }

    ULONG STDMETHODCALLTYPE AddRef() override {
        return static_cast<ULONG>(InterlockedIncrement(&refCount_));
    }

    ULONG STDMETHODCALLTYPE Release() override {
        const LONG ref = InterlockedDecrement(&refCount_);
        if (ref == 0) {
            delete this;
        }
        return static_cast<ULONG>(ref);
    }

    // ITfEditSession
    HRESULT STDMETHODCALLTYPE DoEditSession(TfEditCookie editCookie) override {
        if (context_ == nullptr) {
            return E_FAIL;
        }

        TF_SELECTION selection = {};
        ULONG fetched = 0;
        HRESULT hr = context_->GetSelection(editCookie, TF_DEFAULT_SELECTION, 1, &selection, &fetched);
        if (FAILED(hr) || fetched == 0 || selection.range == nullptr) {
            if (text_.empty()) {
                return FAILED(hr) ? hr : E_FAIL;
            }

            ITfInsertAtSelection* insertAtSelection = nullptr;
            hr = context_->QueryInterface(IID_ITfInsertAtSelection,
                                          reinterpret_cast<void**>(&insertAtSelection));
            if (FAILED(hr) || insertAtSelection == nullptr) {
                return FAILED(hr) ? hr : E_FAIL;
            }

            ITfRange* insertedRange = nullptr;
            hr = insertAtSelection->InsertTextAtSelection(editCookie,
                                                          0,
                                                          text_.c_str(),
                                                          static_cast<LONG>(text_.size()),
                                                          &insertedRange);
            safeRelease(insertedRange);
            insertAtSelection->Release();
            return hr;
        }

        ITfRange* range = selection.range;
        if (backspaceCount_ > 0) {
            LONG shifted = 0;
            range->ShiftStart(editCookie, -backspaceCount_, &shifted, nullptr);
        }

        hr = range->SetText(editCookie, 0, text_.c_str(), static_cast<LONG>(text_.size()));
        if (SUCCEEDED(hr)) {
            range->Collapse(editCookie, TF_ANCHOR_END);
            TF_SELECTION caretSelection = {};
            caretSelection.range = range;
            caretSelection.style.ase = TF_AE_NONE;
            caretSelection.style.fInterimChar = FALSE;
            context_->SetSelection(editCookie, 1, &caretSelection);
        }

        range->Release();
        return hr;
    }

private:
    ~PHTVEditSession() {
        safeRelease(context_);
    }

    LONG refCount_;
    ITfContext* context_;
    LONG backspaceCount_;
    std::wstring text_;
};

class PHTVClassFactory final : public IClassFactory {
public:
    PHTVClassFactory() : refCount_(1) {
        InterlockedIncrement(&g_dllRefCount);
    }

    // IUnknown
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void** ppvObject) override {
        if (ppvObject == nullptr) {
            return E_INVALIDARG;
        }
        *ppvObject = nullptr;

        if (riid == IID_IUnknown || riid == IID_IClassFactory) {
            *ppvObject = static_cast<IClassFactory*>(this);
            AddRef();
            return S_OK;
        }

        return E_NOINTERFACE;
    }

    ULONG STDMETHODCALLTYPE AddRef() override {
        return static_cast<ULONG>(InterlockedIncrement(&refCount_));
    }

    ULONG STDMETHODCALLTYPE Release() override {
        const LONG ref = InterlockedDecrement(&refCount_);
        if (ref == 0) {
            delete this;
        }
        return static_cast<ULONG>(ref);
    }

    // IClassFactory
    HRESULT STDMETHODCALLTYPE CreateInstance(IUnknown* outer, REFIID riid, void** ppvObject) override {
        if (ppvObject == nullptr) {
            return E_INVALIDARG;
        }
        *ppvObject = nullptr;

        if (outer != nullptr) {
            return CLASS_E_NOAGGREGATION;
        }

        auto* service = new (std::nothrow) phtv::windows_tsf::PHTVTextService();
        if (service == nullptr) {
            return E_OUTOFMEMORY;
        }

        const HRESULT hr = service->QueryInterface(riid, ppvObject);
        service->Release();
        return hr;
    }

    HRESULT STDMETHODCALLTYPE LockServer(BOOL lock) override {
        if (lock != FALSE) {
            InterlockedIncrement(&g_serverLockCount);
        } else {
            InterlockedDecrement(&g_serverLockCount);
        }
        return S_OK;
    }

private:
    ~PHTVClassFactory() {
        InterlockedDecrement(&g_dllRefCount);
    }

    LONG refCount_;
};

HRESULT registerComServerInRegistry() {
    const std::wstring clsidText = guidToString(phtv::windows_tsf::CLSID_PHTVTextService);
    if (clsidText.empty()) {
        return E_FAIL;
    }

    const std::wstring modulePath = moduleFilePath();
    if (modulePath.empty()) {
        return E_FAIL;
    }

    const std::wstring classRoot = L"Software\\Classes\\CLSID\\" + clsidText;
    HRESULT hr = setRegistryString(HKEY_CURRENT_USER, classRoot, nullptr, L"PHTV Vietnamese Text Service");
    if (FAILED(hr)) {
        return hr;
    }

    hr = setRegistryString(HKEY_CURRENT_USER, classRoot + L"\\InprocServer32", nullptr, modulePath);
    if (FAILED(hr)) {
        return hr;
    }

    hr = setRegistryString(HKEY_CURRENT_USER,
                           classRoot + L"\\InprocServer32",
                           L"ThreadingModel",
                           L"Apartment");
    return hr;
}

HRESULT unregisterComServerFromRegistry() {
    const std::wstring clsidText = guidToString(phtv::windows_tsf::CLSID_PHTVTextService);
    if (clsidText.empty()) {
        return E_FAIL;
    }

    const std::wstring classRoot = L"Software\\Classes\\CLSID\\" + clsidText;
    return deleteRegistryTree(HKEY_CURRENT_USER, classRoot);
}

HRESULT registerProfiles() {
    HRESULT hrCoInit = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    const bool shouldUninitialize = SUCCEEDED(hrCoInit);
    if (FAILED(hrCoInit) && hrCoInit != RPC_E_CHANGED_MODE) {
        return hrCoInit;
    }

    HRESULT hr = S_OK;
    ITfInputProcessorProfiles* profiles = nullptr;
    hr = CoCreateInstance(CLSID_TF_InputProcessorProfiles,
                          nullptr,
                          CLSCTX_INPROC_SERVER,
                          IID_ITfInputProcessorProfiles,
                          reinterpret_cast<void**>(&profiles));
    if (FAILED(hr) || profiles == nullptr) {
        if (shouldUninitialize) {
            CoUninitialize();
        }
        return FAILED(hr) ? hr : E_FAIL;
    }

    hr = profiles->Register(phtv::windows_tsf::CLSID_PHTVTextService);
    if (FAILED(hr) && hr != TF_E_ALREADY_EXISTS) {
        profiles->Release();
        if (shouldUninitialize) {
            CoUninitialize();
        }
        return hr;
    }

    const std::wstring modulePath = moduleFilePath();
    const wchar_t description[] = L"PHTV Vietnamese Input";
    const LANGID vietnameseLangId = MAKELANGID(LANG_VIETNAMESE, SUBLANG_DEFAULT);
    hr = profiles->AddLanguageProfile(phtv::windows_tsf::CLSID_PHTVTextService,
                                      vietnameseLangId,
                                      phtv::windows_tsf::GUID_PHTVLanguageProfile,
                                      description,
                                      static_cast<ULONG>(std::size(description) - 1),
                                      modulePath.c_str(),
                                      static_cast<ULONG>(modulePath.size()),
                                      0);
    if (FAILED(hr) && hr != TF_E_ALREADY_EXISTS) {
        profiles->Release();
        if (shouldUninitialize) {
            CoUninitialize();
        }
        return hr;
    }

    ITfCategoryMgr* categoryMgr = nullptr;
    hr = CoCreateInstance(CLSID_TF_CategoryMgr,
                          nullptr,
                          CLSCTX_INPROC_SERVER,
                          IID_ITfCategoryMgr,
                          reinterpret_cast<void**>(&categoryMgr));
    if (SUCCEEDED(hr) && categoryMgr != nullptr) {
        categoryMgr->RegisterCategory(phtv::windows_tsf::CLSID_PHTVTextService,
                                      GUID_TFCAT_TIP_KEYBOARD,
                                      phtv::windows_tsf::CLSID_PHTVTextService);
        categoryMgr->Release();
    }

    profiles->Release();
    if (shouldUninitialize) {
        CoUninitialize();
    }
    return S_OK;
}

HRESULT unregisterProfiles() {
    HRESULT hrCoInit = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    const bool shouldUninitialize = SUCCEEDED(hrCoInit);
    if (FAILED(hrCoInit) && hrCoInit != RPC_E_CHANGED_MODE) {
        return hrCoInit;
    }

    ITfInputProcessorProfiles* profiles = nullptr;
    HRESULT hr = CoCreateInstance(CLSID_TF_InputProcessorProfiles,
                                  nullptr,
                                  CLSCTX_INPROC_SERVER,
                                  IID_ITfInputProcessorProfiles,
                                  reinterpret_cast<void**>(&profiles));
    if (SUCCEEDED(hr) && profiles != nullptr) {
        const LANGID vietnameseLangId = MAKELANGID(LANG_VIETNAMESE, SUBLANG_DEFAULT);
        profiles->RemoveLanguageProfile(phtv::windows_tsf::CLSID_PHTVTextService,
                                        vietnameseLangId,
                                        phtv::windows_tsf::GUID_PHTVLanguageProfile);
        profiles->Unregister(phtv::windows_tsf::CLSID_PHTVTextService);
        profiles->Release();
    }

    ITfCategoryMgr* categoryMgr = nullptr;
    hr = CoCreateInstance(CLSID_TF_CategoryMgr,
                          nullptr,
                          CLSCTX_INPROC_SERVER,
                          IID_ITfCategoryMgr,
                          reinterpret_cast<void**>(&categoryMgr));
    if (SUCCEEDED(hr) && categoryMgr != nullptr) {
        categoryMgr->UnregisterCategory(phtv::windows_tsf::CLSID_PHTVTextService,
                                        GUID_TFCAT_TIP_KEYBOARD,
                                        phtv::windows_tsf::CLSID_PHTVTextService);
        categoryMgr->Release();
    }

    if (shouldUninitialize) {
        CoUninitialize();
    }
    return S_OK;
}

} // namespace

namespace phtv::windows_tsf {

const CLSID CLSID_PHTVTextService = {
    0x44f4c999, 0x7f50, 0x4f7e, {0xa6, 0x9e, 0x7a, 0x8d, 0xeb, 0x03, 0x52, 0x46}
};

const GUID GUID_PHTVLanguageProfile = {
    0x6aeff6e7, 0x95dd, 0x4ab3, {0x81, 0x8f, 0xc5, 0x46, 0x58, 0xe1, 0x5d, 0x14}
};

PHTVTextService::PHTVTextService()
    : refCount_(1),
      threadMgr_(nullptr),
      keyStrokeMgr_(nullptr),
      source_(nullptr),
      clientId_(kInvalidClientId),
      threadMgrEventSinkCookie_(TF_INVALID_COOKIE),
      activated_(false),
      runtimeConfigLoaded_(false),
      hasConfigFile_(false),
      hasMacrosFile_(false),
      hasConfigWriteTime_(false),
      hasMacrosWriteTime_(false),
      nextConfigCheckAt_(std::chrono::steady_clock::time_point::min()),
      hasPendingOutput_(false),
      pendingWParam_(0),
      pendingLParam_(0),
      pendingEngineKeyCode_(0),
      pendingCapsStatus_(0) {
    InterlockedIncrement(&g_dllRefCount);
}

HRESULT PHTVTextService::QueryInterface(REFIID riid, void** ppvObject) {
    if (ppvObject == nullptr) {
        return E_INVALIDARG;
    }
    *ppvObject = nullptr;

    if (riid == IID_IUnknown || riid == IID_ITfTextInputProcessor) {
        *ppvObject = static_cast<ITfTextInputProcessor*>(this);
    } else if (riid == IID_ITfThreadMgrEventSink) {
        *ppvObject = static_cast<ITfThreadMgrEventSink*>(this);
    } else if (riid == IID_ITfKeyEventSink) {
        *ppvObject = static_cast<ITfKeyEventSink*>(this);
    } else {
        return E_NOINTERFACE;
    }

    AddRef();
    return S_OK;
}

ULONG PHTVTextService::AddRef() {
    return static_cast<ULONG>(InterlockedIncrement(&refCount_));
}

ULONG PHTVTextService::Release() {
    const LONG ref = InterlockedDecrement(&refCount_);
    if (ref == 0) {
        delete this;
    }
    return static_cast<ULONG>(ref);
}

HRESULT PHTVTextService::Activate(ITfThreadMgr* threadMgr, TfClientId clientId) {
    if (threadMgr == nullptr) {
        return E_INVALIDARG;
    }

    if (activated_) {
        return S_OK;
    }

    threadMgr_ = threadMgr;
    threadMgr_->AddRef();
    clientId_ = clientId;

    ensureDictionariesLoadedForTsf();
    session_.startSession();
    refreshRuntimeConfigIfNeeded(true);

    HRESULT hr = threadMgr_->QueryInterface(IID_ITfSource, reinterpret_cast<void**>(&source_));
    if (SUCCEEDED(hr) && source_ != nullptr) {
        hr = source_->AdviseSink(IID_ITfThreadMgrEventSink,
                                 static_cast<ITfThreadMgrEventSink*>(this),
                                 &threadMgrEventSinkCookie_);
        if (FAILED(hr)) {
            source_->Release();
            source_ = nullptr;
        }
    }

    hr = threadMgr_->QueryInterface(IID_ITfKeystrokeMgr, reinterpret_cast<void**>(&keyStrokeMgr_));
    if (FAILED(hr) || keyStrokeMgr_ == nullptr) {
        Deactivate();
        return FAILED(hr) ? hr : E_FAIL;
    }

    hr = keyStrokeMgr_->AdviseKeyEventSink(clientId_,
                                           static_cast<ITfKeyEventSink*>(this),
                                           TRUE);
    if (FAILED(hr)) {
        Deactivate();
        return hr;
    }

    activated_ = true;
    return S_OK;
}

HRESULT PHTVTextService::Deactivate() {
    unadviseSinks();
    clearPendingOutput();
    safeRelease(keyStrokeMgr_);
    safeRelease(source_);
    safeRelease(threadMgr_);
    clientId_ = kInvalidClientId;
    activated_ = false;
    return S_OK;
}

HRESULT PHTVTextService::OnInitDocumentMgr(ITfDocumentMgr* documentMgr) {
    (void)documentMgr;
    return S_OK;
}

HRESULT PHTVTextService::OnUninitDocumentMgr(ITfDocumentMgr* documentMgr) {
    (void)documentMgr;
    return S_OK;
}

HRESULT PHTVTextService::OnSetFocus(ITfDocumentMgr* focus, ITfDocumentMgr* previousFocus) {
    (void)focus;
    (void)previousFocus;
    session_.notifyMouseDown();
    return S_OK;
}

HRESULT PHTVTextService::OnPushContext(ITfContext* context) {
    (void)context;
    return S_OK;
}

HRESULT PHTVTextService::OnPopContext(ITfContext* context) {
    (void)context;
    return S_OK;
}

HRESULT PHTVTextService::OnSetFocus(BOOL foreground) {
    (void)foreground;
    clearPendingOutput();
    return S_OK;
}

HRESULT PHTVTextService::OnTestKeyDown(ITfContext* context,
                                       WPARAM wParam,
                                       LPARAM lParam,
                                       BOOL* eaten) {
    if (eaten == nullptr) {
        return E_INVALIDARG;
    }
    *eaten = FALSE;

    if (context == nullptr || shouldBypassVirtualKey(wParam) || hasOtherControlKey()) {
        return S_OK;
    }

    refreshRuntimeConfigIfNeeded(false);

    Uint16 engineKeyCode = 0;
    if (!phtv::windows_adapter::mapVirtualKeyToEngine(static_cast<std::uint32_t>(wParam), engineKeyCode)) {
        return S_OK;
    }

    const Uint8 capsStatus = currentCapsStatus();
    pendingOutput_ = session_.processKeyDown(engineKeyCode, capsStatus, false);
    pendingWParam_ = wParam;
    pendingLParam_ = lParam;
    pendingEngineKeyCode_ = engineKeyCode;
    pendingCapsStatus_ = capsStatus;
    hasPendingOutput_ = true;

    *eaten = pendingOutput_.code == vDoNothing ? FALSE : TRUE;
    return S_OK;
}

HRESULT PHTVTextService::OnTestKeyUp(ITfContext* context,
                                     WPARAM wParam,
                                     LPARAM lParam,
                                     BOOL* eaten) {
    (void)context;
    (void)wParam;
    (void)lParam;
    if (eaten == nullptr) {
        return E_INVALIDARG;
    }
    *eaten = FALSE;
    return S_OK;
}

HRESULT PHTVTextService::OnKeyDown(ITfContext* context,
                                   WPARAM wParam,
                                   LPARAM lParam,
                                   BOOL* eaten) {
    if (eaten == nullptr) {
        return E_INVALIDARG;
    }
    *eaten = FALSE;

    if (context == nullptr || shouldBypassVirtualKey(wParam)) {
        return S_OK;
    }

    phtv::windows_host::EngineOutput output;
    Uint16 engineKeyCode = 0;
    Uint8 capsStatus = 0;

    if (hasPendingOutput_ && pendingWParam_ == wParam && pendingLParam_ == lParam) {
        output = pendingOutput_;
        engineKeyCode = pendingEngineKeyCode_;
        capsStatus = pendingCapsStatus_;
        clearPendingOutput();
    } else {
        if (hasOtherControlKey()) {
            return S_OK;
        }

        refreshRuntimeConfigIfNeeded(false);

        if (!phtv::windows_adapter::mapVirtualKeyToEngine(static_cast<std::uint32_t>(wParam), engineKeyCode)) {
            return S_OK;
        }

        capsStatus = currentCapsStatus();
        output = session_.processKeyDown(engineKeyCode, capsStatus, false);
    }

    if (output.code == vDoNothing) {
        return S_OK;
    }

    LONG backspaceCount = 0;
    std::wstring text;
    if (!buildCommitText(output, engineKeyCode, capsStatus, backspaceCount, text)) {
        if (output.code == vRestoreAndStartNewSession) {
            session_.startSession();
        }
        return S_OK;
    }

    const bool committed = requestEditSession(context, backspaceCount, text);
    if (committed) {
        *eaten = TRUE;
    }

    if (output.code == vRestoreAndStartNewSession) {
        session_.startSession();
    }
    return S_OK;
}

HRESULT PHTVTextService::OnKeyUp(ITfContext* context,
                                 WPARAM wParam,
                                 LPARAM lParam,
                                 BOOL* eaten) {
    (void)context;
    (void)wParam;
    (void)lParam;
    if (eaten == nullptr) {
        return E_INVALIDARG;
    }
    *eaten = FALSE;
    return S_OK;
}

HRESULT PHTVTextService::OnPreservedKey(ITfContext* context, REFGUID guid, BOOL* eaten) {
    (void)context;
    (void)guid;
    if (eaten == nullptr) {
        return E_INVALIDARG;
    }
    *eaten = FALSE;
    return S_OK;
}

void PHTVTextService::unadviseSinks() {
    if (keyStrokeMgr_ != nullptr && clientId_ != kInvalidClientId) {
        keyStrokeMgr_->UnadviseKeyEventSink(clientId_);
    }

    if (source_ != nullptr && threadMgrEventSinkCookie_ != TF_INVALID_COOKIE) {
        source_->UnadviseSink(threadMgrEventSinkCookie_);
        threadMgrEventSinkCookie_ = TF_INVALID_COOKIE;
    }
}

void PHTVTextService::clearPendingOutput() {
    hasPendingOutput_ = false;
    pendingWParam_ = 0;
    pendingLParam_ = 0;
    pendingEngineKeyCode_ = 0;
    pendingCapsStatus_ = 0;
    pendingOutput_ = {};
}

void PHTVTextService::refreshRuntimeConfigIfNeeded(bool force) {
    const auto now = std::chrono::steady_clock::now();
    if (!force && now < nextConfigCheckAt_) {
        return;
    }

    nextConfigCheckAt_ = now + std::chrono::milliseconds(750);

    const auto configPath = phtv::windows_runtime::runtimeConfigPath();
    const auto macrosPath = phtv::windows_runtime::runtimeMacrosPath();

    std::error_code ec;
    const bool hasConfig = std::filesystem::exists(configPath, ec);
    if (ec) {
        return;
    }

    ec.clear();
    const bool hasMacros = std::filesystem::exists(macrosPath, ec);
    if (ec) {
        return;
    }

    std::filesystem::file_time_type configWriteTime = {};
    std::filesystem::file_time_type macrosWriteTime = {};
    bool hasConfigWriteTime = false;
    bool hasMacrosWriteTime = false;

    if (hasConfig) {
        ec.clear();
        configWriteTime = std::filesystem::last_write_time(configPath, ec);
        hasConfigWriteTime = !ec;
    }

    if (hasMacros) {
        ec.clear();
        macrosWriteTime = std::filesystem::last_write_time(macrosPath, ec);
        hasMacrosWriteTime = !ec;
    }

    bool shouldReload = force || !runtimeConfigLoaded_;
    shouldReload = shouldReload || (hasConfig != hasConfigFile_);
    shouldReload = shouldReload || (hasMacros != hasMacrosFile_);

    if (hasConfigWriteTime) {
        shouldReload = shouldReload || !hasConfigWriteTime_ || configWriteTime != configWriteTime_;
    }

    if (hasMacrosWriteTime) {
        shouldReload = shouldReload || !hasMacrosWriteTime_ || macrosWriteTime != macrosWriteTime_;
    }

    if (!shouldReload) {
        return;
    }

    phtv::windows_runtime::RuntimeConfig config;
    std::string errorMessage;
    if (!phtv::windows_runtime::loadAndApplyRuntimeConfig(config, errorMessage)) {
        return;
    }

    runtimeConfigLoaded_ = true;
    hasConfigFile_ = hasConfig;
    hasMacrosFile_ = hasMacros;
    hasConfigWriteTime_ = hasConfigWriteTime;
    hasMacrosWriteTime_ = hasMacrosWriteTime;

    if (hasConfigWriteTime_) {
        configWriteTime_ = configWriteTime;
    }

    if (hasMacrosWriteTime_) {
        macrosWriteTime_ = macrosWriteTime;
    }

    session_.startSession();
    clearPendingOutput();
}

bool PHTVTextService::shouldBypassVirtualKey(WPARAM virtualKey) const {
    switch (virtualKey) {
        case VK_SHIFT:
        case VK_LSHIFT:
        case VK_RSHIFT:
        case VK_CONTROL:
        case VK_LCONTROL:
        case VK_RCONTROL:
        case VK_MENU:
        case VK_LMENU:
        case VK_RMENU:
        case VK_LWIN:
        case VK_RWIN:
        case VK_CAPITAL:
            return true;
        default:
            return false;
    }
}

Uint8 PHTVTextService::currentCapsStatus() const {
    const bool hasShift = (GetKeyState(VK_SHIFT) & 0x8000) != 0;
    const bool hasCaps = (GetKeyState(VK_CAPITAL) & 0x0001) != 0;

    if (hasShift && hasCaps) {
        return 0;
    }
    if (hasShift) {
        return 1;
    }
    if (hasCaps) {
        return 2;
    }
    return 0;
}

bool PHTVTextService::hasOtherControlKey() const {
    return ((GetKeyState(VK_CONTROL) & 0x8000) != 0) ||
           ((GetKeyState(VK_MENU) & 0x8000) != 0);
}

bool PHTVTextService::requestEditSession(ITfContext* context,
                                         LONG backspaceCount,
                                         const std::wstring& text) const {
    if (context == nullptr) {
        return false;
    }

    auto* editSession = new (std::nothrow) PHTVEditSession(context, backspaceCount, text);
    if (editSession == nullptr) {
        return false;
    }

    HRESULT editResult = E_FAIL;
    const HRESULT hr = context->RequestEditSession(clientId_,
                                                   editSession,
                                                   TF_ES_SYNC | TF_ES_READWRITE,
                                                   &editResult);
    editSession->Release();
    return SUCCEEDED(hr) && SUCCEEDED(editResult);
}

bool PHTVTextService::buildCommitText(const phtv::windows_host::EngineOutput& output,
                                      Uint16 engineKeyCode,
                                      Uint8 capsStatus,
                                      LONG& outBackspaceCount,
                                      std::wstring& outText) const {
    outBackspaceCount = output.backspaceCount;
    outText.clear();

    if (output.code == vReplaceMaro) {
        appendEngineSequence(output.macroChars, false, outText);

        Uint32 rawKey = engineKeyCode;
        if (capsStatus != 0) {
            rawKey |= CAPS_MASK;
        }
        appendEngineData(rawKey, outText);
    } else {
        appendEngineSequence(output.committedChars, true, outText);

        if (output.code == vRestore || output.code == vRestoreAndStartNewSession) {
            Uint32 rawKey = engineKeyCode;
            if (capsStatus != 0) {
                rawKey |= CAPS_MASK;
            }
            appendEngineData(rawKey, outText);
        }
    }

    return outBackspaceCount > 0 || !outText.empty();
}

void PHTVTextService::appendEngineSequence(const std::vector<Uint32>& sequence,
                                           bool reverseOrder,
                                           std::wstring& outText) const {
    if (sequence.empty()) {
        return;
    }

    if (reverseOrder) {
        for (auto it = sequence.rbegin(); it != sequence.rend(); ++it) {
            appendEngineData(*it, outText);
        }
        return;
    }

    for (const Uint32 value : sequence) {
        appendEngineData(value, outText);
    }
}

void PHTVTextService::appendEngineData(Uint32 data, std::wstring& outText) const {
    if ((data & CHAR_CODE_MASK) == 0) {
        const Uint16 mappedChar = keyCodeToCharacter(data);
        if (mappedChar != 0) {
            outText.push_back(static_cast<wchar_t>(mappedChar));
        }
        return;
    }

    const Uint16 value = static_cast<Uint16>(data & CHAR_MASK);
    if (vCodeTable == 0) {
        outText.push_back(static_cast<wchar_t>(value));
        return;
    }

    if (tryMapCodeTableValueToUnicode(value, outText)) {
        return;
    }

    if (vCodeTable == 3) {
        const Uint16 mark = static_cast<Uint16>(value >> 13);
        const Uint16 base = static_cast<Uint16>(value & 0x1FFF);
        outText.push_back(static_cast<wchar_t>(base));
        if (mark > 0) {
            outText.push_back(static_cast<wchar_t>(_unicodeCompoundMark[mark - 1]));
        }
        return;
    }

    const Uint16 low = LOBYTE(value);
    const Uint16 high = HIBYTE(value);
    if (low > 0) {
        outText.push_back(static_cast<wchar_t>(low));
    }
    if (high > 32) {
        outText.push_back(static_cast<wchar_t>(high));
    }
}

bool PHTVTextService::tryMapCodeTableValueToUnicode(Uint16 encodedValue, std::wstring& outText) const {
    if (vCodeTable <= 0 || vCodeTable > 4) {
        return false;
    }

    for (const auto& entry : _codeTable[vCodeTable]) {
        const auto keyCode = entry.first;
        const auto& sourceValues = entry.second;

        for (size_t i = 0; i < sourceValues.size(); ++i) {
            if (sourceValues[i] != encodedValue) {
                continue;
            }

            const auto unicodeEntry = _codeTable[0].find(keyCode);
            if (unicodeEntry == _codeTable[0].end()) {
                return false;
            }

            if (i >= unicodeEntry->second.size()) {
                return false;
            }

            outText.push_back(static_cast<wchar_t>(unicodeEntry->second[i]));
            return true;
        }
    }

    return false;
}

HRESULT registerTextServiceServer() {
    HRESULT hr = registerComServerInRegistry();
    if (FAILED(hr)) {
        return hr;
    }

    hr = registerProfiles();
    if (FAILED(hr)) {
        unregisterComServerFromRegistry();
        return hr;
    }

    return S_OK;
}

HRESULT unregisterTextServiceServer() {
    unregisterProfiles();
    return unregisterComServerFromRegistry();
}

} // namespace phtv::windows_tsf

extern "C" BOOL WINAPI DllMain(HINSTANCE instance, DWORD reason, LPVOID reserved) {
    (void)reserved;
    if (reason == DLL_PROCESS_ATTACH) {
        g_moduleHandle = instance;
        DisableThreadLibraryCalls(instance);
    }
    return TRUE;
}

#if defined(_MSC_VER)
#define PHTV_TSF_EXPORT extern "C" __declspec(dllexport) STDAPI
#else
#define PHTV_TSF_EXPORT extern "C" STDAPI
#endif

PHTV_TSF_EXPORT DllCanUnloadNow() {
    return (g_dllRefCount == 0 && g_serverLockCount == 0) ? S_OK : S_FALSE;
}

PHTV_TSF_EXPORT DllGetClassObject(REFCLSID clsid, REFIID iid, LPVOID* object) {
    if (object == nullptr) {
        return E_INVALIDARG;
    }
    *object = nullptr;

    if (clsid != phtv::windows_tsf::CLSID_PHTVTextService) {
        return CLASS_E_CLASSNOTAVAILABLE;
    }

    auto* factory = new (std::nothrow) PHTVClassFactory();
    if (factory == nullptr) {
        return E_OUTOFMEMORY;
    }

    const HRESULT hr = factory->QueryInterface(iid, object);
    factory->Release();
    return hr;
}

PHTV_TSF_EXPORT DllRegisterServer() {
    return phtv::windows_tsf::registerTextServiceServer();
}

PHTV_TSF_EXPORT DllUnregisterServer() {
    return phtv::windows_tsf::unregisterTextServiceServer();
}

#undef PHTV_TSF_EXPORT

#endif // _WIN32
