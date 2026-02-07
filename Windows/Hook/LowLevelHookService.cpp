#ifdef _WIN32

#include "LowLevelHookService.h"

#include <algorithm>
#include <array>
#include <chrono>
#include <cstddef>
#include <cstdlib>
#include <cwctype>
#include <filesystem>
#include <iostream>
#include <limits>
#include <objbase.h>
#include <oleauto.h>
#include <string>
#include <thread>
#include <uiautomationclient.h>
#include <unordered_set>
#include <utility>
#include <vector>
#include "Engine.h"
#include "DictionaryBootstrap.h"
#include "RuntimeConfig.h"
#include "Win32KeycodeAdapter.h"

#ifndef PROCESS_QUERY_LIMITED_INFORMATION
#define PROCESS_QUERY_LIMITED_INFORMATION PROCESS_QUERY_INFORMATION
#endif

namespace {

constexpr Uint32 kMaskShift = 0x01;
constexpr Uint32 kMaskControl = 0x02;
constexpr Uint32 kMaskAlt = 0x04;
constexpr Uint32 kMaskCapital = 0x08;
constexpr Uint32 kMaskWin = 0x10;

constexpr int kAppContextRefreshMs = 120;

constexpr int kCliBackspaceDelayFastUs = 8000;
constexpr int kCliWaitAfterBackspaceFastUs = 20000;
constexpr int kCliTextDelayFastUs = 6000;
constexpr int kCliBackspaceDelayMediumUs = 12000;
constexpr int kCliWaitAfterBackspaceMediumUs = 35000;
constexpr int kCliTextDelayMediumUs = 9000;
constexpr int kCliBackspaceDelaySlowUs = 18000;
constexpr int kCliWaitAfterBackspaceSlowUs = 50000;
constexpr int kCliTextDelaySlowUs = 12000;
constexpr int kCliBackspaceDelayDefaultUs = 10000;
constexpr int kCliWaitAfterBackspaceDefaultUs = 30000;
constexpr int kCliTextDelayDefaultUs = 8000;
constexpr int kStepByStepDelayDefaultUs = 3000;
constexpr int kBrowserBackspaceDelayUs = 1500;
constexpr int kAddressBarDetectRefreshMs = 150;

const std::unordered_set<std::wstring> kBrowserExecutables = {
    L"chrome.exe",
    L"msedge.exe",
    L"firefox.exe",
    L"brave.exe",
    L"opera.exe",
    L"launcher.exe", // Opera GX launcher
    L"vivaldi.exe",
    L"coccoc.exe",
    L"arc.exe",
    L"zen.exe",
    L"whale.exe",
    L"sidekick.exe",
    L"chromium.exe"
};

const std::unordered_set<std::wstring> kIdeExecutables = {
    L"code.exe",
    L"code-insiders.exe",
    L"cursor.exe",
    L"windsurf.exe",
    L"idea64.exe",
    L"pycharm64.exe",
    L"clion64.exe",
    L"webstorm64.exe",
    L"goland64.exe",
    L"rider64.exe",
    L"studio64.exe",
    L"devenv.exe",
    L"sublime_text.exe"
};

const std::unordered_set<std::wstring> kTerminalExecutables = {
    L"windowsterminal.exe",
    L"wt.exe",
    L"cmd.exe",
    L"powershell.exe",
    L"pwsh.exe",
    L"powershell_ise.exe",
    L"conhost.exe",
    L"alacritty.exe",
    L"ghostty.exe",
    L"kitty.exe",
    L"wezterm.exe",
    L"rio.exe",
    L"mintty.exe",
    L"hyper.exe",
    L"tabby.exe",
    L"mobaxterm.exe",
    L"tsh.exe",
    L"warp.exe"
};

const std::unordered_set<std::wstring> kFastTerminalExecutables = {
    L"alacritty.exe",
    L"ghostty.exe",
    L"rio.exe",
    L"warp.exe"
};

const std::unordered_set<std::wstring> kMediumTerminalExecutables = {
    L"windowsterminal.exe",
    L"wt.exe",
    L"cmd.exe",
    L"powershell.exe",
    L"pwsh.exe",
    L"conhost.exe",
    L"kitty.exe",
    L"wezterm.exe",
    L"mintty.exe",
    L"hyper.exe",
    L"tabby.exe"
};

const std::unordered_set<std::wstring> kSlowTerminalExecutables = {
    L"mobaxterm.exe",
    L"tsh.exe"
};

const std::array<std::wstring_view, 15> kTerminalTitleKeywords = {
    L"terminal",
    L"powershell",
    L"cmd",
    L"console",
    L"shell",
    L"bash",
    L"zsh",
    L"wsl",
    L"xterm",
    L"pty",
    L"tty",
    L"mingu",
    L"cygwin",
    L"msys",
    L"tool window: terminal"
};

const std::array<std::wstring_view, 10> kAddressBarKeywords = {
    L"address",
    L"search",
    L"omnibox",
    L"location",
    L"url",
    L"navigation",
    L"địa chỉ",
    L"tim kiem",
    L"tìm kiếm",
    L"nhập url"
};

const std::array<std::wstring_view, 12> kAddressBarClassKeywords = {
    L"omnibox",
    L"urlbar",
    L"address",
    L"autocomplete",
    L"searchbox",
    L"search_bar",
    L"location",
    L"edit",
    L"textbox",
    L"suggest",
    L"popup",
    L"view"
};

const std::array<std::wstring_view, 14> kWebContentClassKeywords = {
    L"renderwidget",
    L"webview",
    L"web area",
    L"document",
    L"mozilla",
    L"internet explorer_server",
    L"chrome legacy window",
    L"tabcontent",
    L"tab-content",
    L"renderer",
    L"chromium",
    L"edgewebview",
    L"cef",
    L"content"
};

const std::array<std::wstring_view, 10> kWebContentKeywords = {
    L"web area",
    L"webview",
    L"document",
    L"renderer",
    L"content",
    L"html",
    L"page",
    L"tab",
    L"edit area",
    L"textbox"
};

std::wstring toLowerWide(std::wstring value) {
    std::transform(value.begin(), value.end(), value.begin(), [](wchar_t c) {
        return static_cast<wchar_t>(std::towlower(c));
    });
    return value;
}

template <size_t N>
bool containsAnyKeyword(std::wstring_view value,
                        const std::array<std::wstring_view, N>& keywords) {
    if (value.empty()) {
        return false;
    }

    for (const auto keyword : keywords) {
        if (!keyword.empty() && value.find(keyword) != std::wstring_view::npos) {
            return true;
        }
    }
    return false;
}

std::wstring bstrToLower(BSTR value) {
    if (value == nullptr) {
        return {};
    }
    return toLowerWide(std::wstring(value, SysStringLen(value)));
}

std::wstring trimWide(const std::wstring& value) {
    size_t start = 0;
    while (start < value.size() &&
           std::iswspace(static_cast<wint_t>(value[start])) != 0) {
        start++;
    }

    size_t end = value.size();
    while (end > start &&
           std::iswspace(static_cast<wint_t>(value[end - 1])) != 0) {
        end--;
    }

    return value.substr(start, end - start);
}

std::wstring utf8ToWide(const std::string& value) {
    if (value.empty()) {
        return {};
    }

    int required = MultiByteToWideChar(CP_UTF8,
                                       MB_ERR_INVALID_CHARS,
                                       value.c_str(),
                                       static_cast<int>(value.size()),
                                       nullptr,
                                       0);
    if (required <= 0) {
        required = MultiByteToWideChar(CP_UTF8,
                                       0,
                                       value.c_str(),
                                       static_cast<int>(value.size()),
                                       nullptr,
                                       0);
    }

    if (required <= 0) {
        std::wstring fallback;
        fallback.reserve(value.size());
        for (const unsigned char c : value) {
            fallback.push_back(static_cast<wchar_t>(c));
        }
        return fallback;
    }

    std::wstring output(static_cast<size_t>(required), L'\0');
    if (MultiByteToWideChar(CP_UTF8,
                            0,
                            value.c_str(),
                            static_cast<int>(value.size()),
                            output.data(),
                            required) <= 0) {
        return {};
    }

    return output;
}

bool wildcardMatch(std::wstring_view text, std::wstring_view pattern) {
    size_t textIndex = 0;
    size_t patternIndex = 0;
    size_t starIndex = std::wstring_view::npos;
    size_t checkpoint = 0;

    while (textIndex < text.size()) {
        if (patternIndex < pattern.size() &&
            (pattern[patternIndex] == text[textIndex] ||
             pattern[patternIndex] == L'?')) {
            patternIndex++;
            textIndex++;
            continue;
        }

        if (patternIndex < pattern.size() && pattern[patternIndex] == L'*') {
            starIndex = patternIndex++;
            checkpoint = textIndex;
            continue;
        }

        if (starIndex != std::wstring_view::npos) {
            patternIndex = starIndex + 1;
            textIndex = ++checkpoint;
            continue;
        }

        return false;
    }

    while (patternIndex < pattern.size() && pattern[patternIndex] == L'*') {
        patternIndex++;
    }

    return patternIndex == pattern.size();
}

bool containsTerminalKeyword(const std::wstring& lowerValue) {
    if (lowerValue.empty()) {
        return false;
    }

    for (const auto keyword : kTerminalTitleKeywords) {
        if (lowerValue.find(keyword) != std::wstring::npos) {
            return true;
        }
    }

    return false;
}

bool hasFileExtension(const std::wstring& lowerRule) {
    const auto dotPos = lowerRule.find_last_of(L'.');
    return dotPos != std::wstring::npos && dotPos + 1 < lowerRule.size();
}

bool matchesRuntimeRule(const std::string& rawRule,
                        const std::wstring& processNameLower,
                        const std::wstring& processStemLower,
                        const std::wstring& processPathLower,
                        const std::wstring& titleLower) {
    std::wstring ruleLower = toLowerWide(trimWide(utf8ToWide(rawRule)));
    if (ruleLower.empty()) {
        return false;
    }

    const bool hasWildcard = ruleLower.find(L'*') != std::wstring::npos;
    if (hasWildcard) {
        return wildcardMatch(processNameLower, ruleLower) ||
               wildcardMatch(processStemLower, ruleLower) ||
               wildcardMatch(processPathLower, ruleLower) ||
               wildcardMatch(titleLower, ruleLower);
    }

    if (processNameLower == ruleLower ||
        processStemLower == ruleLower ||
        processPathLower == ruleLower ||
        titleLower == ruleLower) {
        return true;
    }

    if (!hasFileExtension(ruleLower) && !processStemLower.empty() && processStemLower == ruleLower) {
        return true;
    }

    return processNameLower.find(ruleLower) != std::wstring::npos ||
           processStemLower.find(ruleLower) != std::wstring::npos ||
           processPathLower.find(ruleLower) != std::wstring::npos ||
           titleLower.find(ruleLower) != std::wstring::npos;
}

bool isBrowserFixDebugEnabled() {
    static int cachedValue = -1;
    if (cachedValue < 0) {
        const char* envValue = std::getenv("PHTV_DEBUG_BROWSER_FIX");
        cachedValue = (envValue != nullptr && envValue[0] != '\0' && envValue[0] != '0') ? 1 : 0;
    }
    return cachedValue == 1;
}

} // namespace

namespace phtv::windows_hook {

LowLevelHookService* LowLevelHookService::instance_ = nullptr;

LowLevelHookService::LowLevelHookService()
    : keyboardHook_(nullptr),
      mouseHook_(nullptr),
      running_(false),
      hasThreadMessageQueue_(false),
      runtimeConfigLoaded_(false),
      hasConfigFile_(false),
      hasMacrosFile_(false),
      hasConfigWriteTime_(false),
      hasMacrosWriteTime_(false),
      nextConfigCheckAt_(std::chrono::steady_clock::time_point::min()),
      nextAppContextCheckAt_(std::chrono::steady_clock::time_point::min()),
      runtimeConfig_(),
      appContext_(),
      uiAutomation_(nullptr),
      uiAutomationReady_(false),
      comNeedsUninitialize_(false),
      nextDictionaryCheckAt_(std::chrono::steady_clock::time_point::min()),
      nextAddressBarCheckAt_(std::chrono::steady_clock::time_point::min()),
      cachedAddressBarFocusWindow_(nullptr),
      cachedIsAddressBar_(false),
      modifierMask_(0) {
}

LowLevelHookService::~LowLevelHookService() {
    stop();
}

bool LowLevelHookService::start() {
    if (running_) {
        return true;
    }

    instance_ = this;
    session_.startSession();
    clearSyncState();
    resetAddressBarCache();
    ensureDictionariesLoaded(true);
    initializeUiAutomation();
    refreshRuntimeConfigIfNeeded(true);
    refreshForegroundAppContext(true);

    MSG msg;
    PeekMessageW(&msg, nullptr, WM_USER, WM_USER, PM_NOREMOVE);
    hasThreadMessageQueue_ = true;

    HINSTANCE moduleHandle = GetModuleHandleW(nullptr);
    keyboardHook_ = SetWindowsHookExW(WH_KEYBOARD_LL, KeyboardHookProc, moduleHandle, 0);
    if (keyboardHook_ == nullptr) {
        shutdownUiAutomation();
        resetAddressBarCache();
        instance_ = nullptr;
        return false;
    }

    mouseHook_ = SetWindowsHookExW(WH_MOUSE_LL, MouseHookProc, moduleHandle, 0);
    if (mouseHook_ == nullptr) {
        UnhookWindowsHookEx(keyboardHook_);
        keyboardHook_ = nullptr;
        shutdownUiAutomation();
        resetAddressBarCache();
        instance_ = nullptr;
        return false;
    }

    running_ = true;
    return true;
}

void LowLevelHookService::stop() {
    if (!running_) {
        shutdownUiAutomation();
        resetAddressBarCache();
        return;
    }

    if (mouseHook_ != nullptr) {
        UnhookWindowsHookEx(mouseHook_);
        mouseHook_ = nullptr;
    }

    if (keyboardHook_ != nullptr) {
        UnhookWindowsHookEx(keyboardHook_);
        keyboardHook_ = nullptr;
    }

    running_ = false;
    clearSyncState();
    resetAddressBarCache();
    appContext_ = {};
    shutdownUiAutomation();

    if (hasThreadMessageQueue_) {
        PostQuitMessage(0);
    }

    if (instance_ == this) {
        instance_ = nullptr;
    }
}

int LowLevelHookService::runMessageLoop() {
    MSG msg {};
    while (running_ && GetMessageW(&msg, nullptr, 0, 0) > 0) {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }
    return static_cast<int>(msg.wParam);
}

LRESULT CALLBACK LowLevelHookService::KeyboardHookProc(int nCode, WPARAM wParam, LPARAM lParam) {
    if (nCode < 0 || instance_ == nullptr) {
        return CallNextHookEx(nullptr, nCode, wParam, lParam);
    }
    return instance_->handleKeyboard(wParam, lParam);
}

LRESULT CALLBACK LowLevelHookService::MouseHookProc(int nCode, WPARAM wParam, LPARAM lParam) {
    if (nCode < 0 || instance_ == nullptr) {
        return CallNextHookEx(nullptr, nCode, wParam, lParam);
    }
    return instance_->handleMouse(wParam, lParam);
}

LRESULT LowLevelHookService::handleKeyboard(WPARAM wParam, LPARAM lParam) {
    auto* keyData = reinterpret_cast<KBDLLHOOKSTRUCT*>(lParam);
    if (keyData == nullptr) {
        return CallNextHookEx(keyboardHook_, HC_ACTION, wParam, lParam);
    }

    if (keyData->dwExtraInfo == kInjectedEventTag) {
        return CallNextHookEx(keyboardHook_, HC_ACTION, wParam, lParam);
    }

    const bool isKeyDown = (wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN);
    const bool isKeyUp = (wParam == WM_KEYUP || wParam == WM_SYSKEYUP);
    if (!isKeyDown && !isKeyUp) {
        return CallNextHookEx(keyboardHook_, HC_ACTION, wParam, lParam);
    }

    const Uint16 vkCode = static_cast<Uint16>(keyData->vkCode);
    if (isKeyDown) {
        setModifierDown(vkCode);
    } else {
        setModifierUp(vkCode);
    }

    if (isModifierKey(vkCode)) {
        return CallNextHookEx(keyboardHook_, HC_ACTION, wParam, lParam);
    }

    if (!isKeyDown) {
        return CallNextHookEx(keyboardHook_, HC_ACTION, wParam, lParam);
    }

    refreshRuntimeConfigIfNeeded(false);
    ensureDictionariesLoaded(false);
    refreshForegroundAppContext(false);

    Uint16 engineKeyCode = 0;
    if (!phtv::windows_adapter::mapVirtualKeyToEngine(vkCode, engineKeyCode)) {
        return CallNextHookEx(keyboardHook_, HC_ACTION, wParam, lParam);
    }

    // CRITICAL: Immediate pass-through if language is set to English (0)
    // This ensures that when the user switches to English on tray, 
    // full Vietnamese processing is bypassed at the hook level.
    if (vLanguage == 0) {
        // Still allow macro processing in English mode if enabled
        if (runtimeConfig_.useMacro != 0 && runtimeConfig_.useMacroInEnglishMode != 0) {
            const auto output = session_.processKeyDown(engineKeyCode, currentCapsStatus(), hasOtherControlKey());
            if (output.code == vReplaceMaro) {
                processEngineOutput(output, engineKeyCode);
                return 1;
            }
        }
        return CallNextHookEx(keyboardHook_, HC_ACTION, wParam, lParam);
    }

    if (appContext_.isExcluded) {
        return CallNextHookEx(keyboardHook_, HC_ACTION, wParam, lParam);
    }

    const auto output = session_.processKeyDown(engineKeyCode, currentCapsStatus(), hasOtherControlKey());

    if (output.code == vDoNothing) {
        if (IS_DOUBLE_CODE(vCodeTable)) {
            if (output.extCode == 1) {
                clearSyncState();
            } else if (output.extCode == 2) {
                if (!syncKeyLengths_.empty()) {
                    const Uint8 length = syncKeyLengths_.back();
                    syncKeyLengths_.pop_back();
                    sendBackspaceRaw();
                    if (appContext_.useStepByStep && appContext_.backspaceDelayUs > 0) {
                        sleepMicroseconds(appContext_.backspaceDelayUs);
                    }
                    if (length > 1) {
                        sendBackspaceRaw();
                    }
                }
            } else if (output.extCode == 3) {
                pushSyncLength(1);
            }
        }
        return CallNextHookEx(keyboardHook_, HC_ACTION, wParam, lParam);
    }

    processEngineOutput(output, engineKeyCode);
    return 1;
}

LRESULT LowLevelHookService::handleMouse(WPARAM wParam, LPARAM lParam) {
    (void)lParam;

    switch (wParam) {
        case WM_LBUTTONDOWN:
        case WM_RBUTTONDOWN:
        case WM_MBUTTONDOWN:
        case WM_XBUTTONDOWN:
        case WM_NCXBUTTONDOWN:
        case WM_LBUTTONUP:
        case WM_RBUTTONUP:
        case WM_MBUTTONUP:
        case WM_XBUTTONUP:
        case WM_NCXBUTTONUP:
            refreshForegroundAppContext(true);
            session_.notifyMouseDown();
            if (IS_DOUBLE_CODE(vCodeTable)) {
                clearSyncState();
            }
            break;
        default:
            break;
    }

    return CallNextHookEx(mouseHook_, HC_ACTION, wParam, lParam);
}

void LowLevelHookService::setModifierDown(Uint16 virtualKey) {
    if (GetKeyState(VK_CAPITAL) == 1) {
        modifierMask_ |= kMaskCapital;
    } else {
        modifierMask_ &= ~kMaskCapital;
    }

    switch (virtualKey) {
        case VK_LSHIFT:
        case VK_RSHIFT:
            modifierMask_ |= kMaskShift;
            break;
        case VK_LCONTROL:
        case VK_RCONTROL:
            modifierMask_ |= kMaskControl;
            break;
        case VK_LMENU:
        case VK_RMENU:
            modifierMask_ |= kMaskAlt;
            break;
        case VK_LWIN:
        case VK_RWIN:
            modifierMask_ |= kMaskWin;
            break;
        default:
            break;
    }
}

void LowLevelHookService::setModifierUp(Uint16 virtualKey) {
    switch (virtualKey) {
        case VK_LSHIFT:
        case VK_RSHIFT:
            modifierMask_ &= ~kMaskShift;
            break;
        case VK_LCONTROL:
        case VK_RCONTROL:
            modifierMask_ &= ~kMaskControl;
            break;
        case VK_LMENU:
        case VK_RMENU:
            modifierMask_ &= ~kMaskAlt;
            break;
        case VK_LWIN:
        case VK_RWIN:
            modifierMask_ &= ~kMaskWin;
            break;
        default:
            break;
    }
}

bool LowLevelHookService::isModifierKey(Uint16 virtualKey) const {
    switch (virtualKey) {
        case VK_LSHIFT:
        case VK_RSHIFT:
        case VK_LCONTROL:
        case VK_RCONTROL:
        case VK_LMENU:
        case VK_RMENU:
        case VK_LWIN:
        case VK_RWIN:
            return true;
        default:
            return false;
    }
}

Uint8 LowLevelHookService::currentCapsStatus() const {
    const bool hasShift = (modifierMask_ & kMaskShift) != 0;
    const bool hasCapital = (modifierMask_ & kMaskCapital) != 0;

    if (hasShift && hasCapital) {
        return 0;
    }
    if (hasShift) {
        return 1;
    }
    if (hasCapital) {
        return 2;
    }
    return 0;
}

bool LowLevelHookService::hasOtherControlKey() const {
    return (modifierMask_ & (kMaskControl | kMaskAlt)) != 0;
}

void LowLevelHookService::initializeUiAutomation() {
    if (uiAutomationReady_ && uiAutomation_ != nullptr) {
        return;
    }

    HRESULT initHr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    if (initHr == S_OK || initHr == S_FALSE) {
        comNeedsUninitialize_ = true;
    } else if (initHr != RPC_E_CHANGED_MODE) {
        uiAutomationReady_ = false;
        return;
    }

    HRESULT hr = CoCreateInstance(CLSID_CUIAutomation,
                                  nullptr,
                                  CLSCTX_INPROC_SERVER,
                                  IID_IUIAutomation,
                                  reinterpret_cast<void**>(&uiAutomation_));
    if (SUCCEEDED(hr) && uiAutomation_ != nullptr) {
        uiAutomationReady_ = true;
        return;
    }

    uiAutomation_ = nullptr;
    uiAutomationReady_ = false;

    if (comNeedsUninitialize_) {
        CoUninitialize();
        comNeedsUninitialize_ = false;
    }
}

void LowLevelHookService::shutdownUiAutomation() {
    if (uiAutomation_ != nullptr) {
        uiAutomation_->Release();
        uiAutomation_ = nullptr;
    }
    uiAutomationReady_ = false;

    if (comNeedsUninitialize_) {
        CoUninitialize();
        comNeedsUninitialize_ = false;
    }
}

void LowLevelHookService::resetAddressBarCache() {
    nextAddressBarCheckAt_ = std::chrono::steady_clock::time_point::min();
    cachedAddressBarFocusWindow_ = nullptr;
    cachedIsAddressBar_ = false;
}

bool LowLevelHookService::detectAddressBarByFocusedClass(HWND focusedWindow,
                                                         std::wstring& outClassNameLower,
                                                         bool& outDetermined) const {
    outDetermined = false;
    outClassNameLower.clear();

    if (focusedWindow == nullptr) {
        return false;
    }

    wchar_t className[256] = {};
    const int classLength = GetClassNameW(focusedWindow, className, static_cast<int>(std::size(className)));
    if (classLength <= 0) {
        return false;
    }

    outClassNameLower = toLowerWide(std::wstring(className, static_cast<size_t>(classLength)));
    if (outClassNameLower.empty()) {
        return false;
    }

    if (containsAnyKeyword(outClassNameLower, kAddressBarClassKeywords) &&
        !containsAnyKeyword(outClassNameLower, kWebContentClassKeywords)) {
        outDetermined = true;
        return true;
    }

    if (containsAnyKeyword(outClassNameLower, kWebContentClassKeywords)) {
        outDetermined = true;
        return false;
    }

    return false;
}

bool LowLevelHookService::detectAddressBarByUiAutomation(HWND focusedWindow, bool& outDetermined) const {
    outDetermined = false;
    if (!uiAutomationReady_ || uiAutomation_ == nullptr) {
        return false;
    }

    IUIAutomationElement* focusedElement = nullptr;
    HRESULT hr = uiAutomation_->GetFocusedElement(&focusedElement);
    if ((FAILED(hr) || focusedElement == nullptr) && focusedWindow != nullptr) {
        hr = uiAutomation_->ElementFromHandle(focusedWindow, &focusedElement);
    }
    if (FAILED(hr) || focusedElement == nullptr) {
        return false;
    }

    auto classifyElement = [&](IUIAutomationElement* element) -> int {
        if (element == nullptr) {
            return 0;
        }

        CONTROLTYPEID controlType = 0;
        element->get_CurrentControlType(&controlType);

        BSTR nameValue = nullptr;
        BSTR automationIdValue = nullptr;
        BSTR classValue = nullptr;
        BSTR localizedTypeValue = nullptr;

        element->get_CurrentName(&nameValue);
        element->get_CurrentAutomationId(&automationIdValue);
        element->get_CurrentClassName(&classValue);
        element->get_CurrentLocalizedControlType(&localizedTypeValue);

        const std::wstring nameLower = bstrToLower(nameValue);
        const std::wstring automationIdLower = bstrToLower(automationIdValue);
        const std::wstring classLower = bstrToLower(classValue);
        const std::wstring localizedTypeLower = bstrToLower(localizedTypeValue);

        if (nameValue != nullptr) {
            SysFreeString(nameValue);
        }
        if (automationIdValue != nullptr) {
            SysFreeString(automationIdValue);
        }
        if (classValue != nullptr) {
            SysFreeString(classValue);
        }
        if (localizedTypeValue != nullptr) {
            SysFreeString(localizedTypeValue);
        }

        const bool hasAddressKeyword = containsAnyKeyword(nameLower, kAddressBarKeywords) ||
                                       containsAnyKeyword(automationIdLower, kAddressBarKeywords) ||
                                       containsAnyKeyword(classLower, kAddressBarClassKeywords) ||
                                       containsAnyKeyword(localizedTypeLower, kAddressBarKeywords);
        bool hasWebKeyword = containsAnyKeyword(nameLower, kWebContentKeywords) ||
                             containsAnyKeyword(automationIdLower, kWebContentKeywords) ||
                             containsAnyKeyword(classLower, kWebContentClassKeywords) ||
                             containsAnyKeyword(localizedTypeLower, kWebContentKeywords);

        if (controlType == UIA_DocumentControlTypeId) {
            hasWebKeyword = true;
        }

        if (hasWebKeyword) {
            return -1;
        }

        if (hasAddressKeyword) {
            return 1;
        }

        if (controlType == UIA_EditControlTypeId || controlType == UIA_ComboBoxControlTypeId) {
            return 1;
        }

        return 0;
    };

    bool foundAddressCandidate = false;
    int classification = classifyElement(focusedElement);
    if (classification < 0) {
        focusedElement->Release();
        outDetermined = true;
        return false;
    }
    if (classification > 0) {
        foundAddressCandidate = true;
    }

    IUIAutomationTreeWalker* walker = nullptr;
    if (SUCCEEDED(uiAutomation_->get_ControlViewWalker(&walker)) && walker != nullptr) {
        IUIAutomationElement* current = focusedElement;
        current->AddRef();
        for (int depth = 0; depth < 8; ++depth) {
            IUIAutomationElement* parent = nullptr;
            HRESULT parentHr = walker->GetParentElement(current, &parent);
            current->Release();
            current = nullptr;

            if (FAILED(parentHr) || parent == nullptr) {
                break;
            }

            current = parent;
            const int parentClassification = classifyElement(parent);
            if (parentClassification < 0) {
                current->Release();
                walker->Release();
                focusedElement->Release();
                outDetermined = true;
                return false;
            }
            if (parentClassification > 0) {
                foundAddressCandidate = true;
            }
        }

        if (current != nullptr) {
            current->Release();
        }
        walker->Release();
    }

    focusedElement->Release();
    if (foundAddressCandidate) {
        outDetermined = true;
        return true;
    }
    return false;
}

bool LowLevelHookService::isFocusedBrowserAddressBar(bool force) {
    if (!appContext_.isBrowser) {
        return false;
    }

    HWND focusedWindow = nullptr;
    GUITHREADINFO guiThreadInfo = {};
    guiThreadInfo.cbSize = sizeof(guiThreadInfo);
    if (GetGUIThreadInfo(0, &guiThreadInfo) != FALSE) {
        focusedWindow = guiThreadInfo.hwndFocus != nullptr
            ? guiThreadInfo.hwndFocus
            : guiThreadInfo.hwndActive;
    }
    if (focusedWindow == nullptr) {
        focusedWindow = appContext_.windowHandle;
    }

    const auto now = std::chrono::steady_clock::now();
    if (!force &&
        focusedWindow != nullptr &&
        focusedWindow == cachedAddressBarFocusWindow_ &&
        now < nextAddressBarCheckAt_) {
        return cachedIsAddressBar_;
    }

    bool determined = false;
    bool isAddressBar = false;
    std::wstring focusedClassLower;

    isAddressBar = detectAddressBarByFocusedClass(focusedWindow, focusedClassLower, determined);
    if (!determined) {
        isAddressBar = detectAddressBarByUiAutomation(focusedWindow, determined);
    }

    if (!determined && !focusedClassLower.empty()) {
        if (containsAnyKeyword(focusedClassLower, kAddressBarClassKeywords)) {
            isAddressBar = true;
            determined = true;
        } else if (containsAnyKeyword(focusedClassLower, kWebContentClassKeywords)) {
            isAddressBar = false;
            determined = true;
        }
    }

    if (!determined) {
        // Match macOS behavior: when browser focus cannot be classified reliably,
        // prefer address-bar mode to avoid first-char duplication in omnibox.
        isAddressBar = true;
        if (isBrowserFixDebugEnabled()) {
            std::cerr << "[PHTV BrowserFix] address-bar detection fallback=TRUE (undetermined)\n";
        }
    }

    cachedAddressBarFocusWindow_ = focusedWindow;
    cachedIsAddressBar_ = isAddressBar;
    nextAddressBarCheckAt_ = now + std::chrono::milliseconds(kAddressBarDetectRefreshMs);
    return cachedIsAddressBar_;
}

bool LowLevelHookService::shouldApplyBrowserAddressBarFix(
    const phtv::windows_host::EngineOutput& output,
    Uint16 engineKeyCode) const {
    if (runtimeConfig_.fixRecommendBrowser == 0 || !appContext_.isBrowser) {
        return false;
    }

    if (output.code == vDoNothing || output.code == vReplaceMaro) {
        return false;
    }

    if (output.extCode == 4 || output.backspaceCount == 0 || output.backspaceCount >= MAX_BUFF) {
        return false;
    }

    // Keep slash shortcuts (for example "/p") untouched.
    if (engineKeyCode == KEY_SLASH) {
        return false;
    }

    return true;
}

void LowLevelHookService::ensureDictionariesLoaded(bool force) {
    const auto now = std::chrono::steady_clock::now();
    if (!force && now < nextDictionaryCheckAt_) {
        return;
    }

    // Retry periodically until both dictionaries are ready.
    nextDictionaryCheckAt_ = now + std::chrono::seconds(2);

    const bool englishReady = isEnglishDictionaryInitialized();
    const bool vietnameseReady = getVietnameseDictionarySize() > 0;
    if (englishReady && vietnameseReady) {
        return;
    }

    const auto status = phtv::windows_runtime::ensureDictionariesLoaded();
    if (isBrowserFixDebugEnabled()) {
        std::cerr << "[PHTV Dict] reload attempted: EN="
                  << (status.englishLoaded ? "ok" : "missing")
                  << " VI="
                  << (status.vietnameseLoaded ? "ok" : "missing")
                  << "\n";
    }
}

void LowLevelHookService::refreshRuntimeConfigIfNeeded(bool force) {
    const auto now = std::chrono::steady_clock::now();
    if (!force && now < nextConfigCheckAt_) {
        return;
    }

    nextConfigCheckAt_ = now + std::chrono::milliseconds(250);

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

    std::filesystem::file_time_type configWriteTime {};
    std::filesystem::file_time_type macrosWriteTime {};
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

    phtv::windows_runtime::RuntimeConfig loadedConfig;
    std::string errorMessage;
    if (!phtv::windows_runtime::loadAndApplyRuntimeConfig(loadedConfig, errorMessage)) {
        if (!errorMessage.empty()) {
            std::cerr << "[PHTV] Runtime config load failed: " << errorMessage << "\n";
        }
        return;
    }

    runtimeConfig_ = std::move(loadedConfig);
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

    // Always ensure global vLanguage is perfectly in sync with config
    vLanguage = runtimeConfig_.language == 0 ? 0 : 1;

    std::cerr << "[PHTV] Config reloaded. Language: " << (vLanguage == 1 ? "VI" : "EN") 
              << ", Input: " << runtimeConfig_.inputType << "\n";

    nextAppContextCheckAt_ = std::chrono::steady_clock::time_point::min();
    resetAddressBarCache();
    refreshForegroundAppContext(true);
    clearSyncState();
    session_.startSession();
}

void LowLevelHookService::refreshForegroundAppContext(bool force) {
    const auto now = std::chrono::steady_clock::now();
    if (!force && now < nextAppContextCheckAt_) {
        return;
    }

    nextAppContextCheckAt_ = now + std::chrono::milliseconds(kAppContextRefreshMs);

    HWND foregroundWindow = GetForegroundWindow();
    if (foregroundWindow == nullptr) {
        return;
    }

    ForegroundAppContext newContext;
    newContext.windowHandle = foregroundWindow;

    DWORD processId = 0;
    GetWindowThreadProcessId(foregroundWindow, &processId);
    if (processId == 0) {
        return;
    }
    newContext.processId = processId;

    wchar_t titleBuffer[512] = {};
    const int titleLength = GetWindowTextW(foregroundWindow,
                                           titleBuffer,
                                           512);
    if (titleLength > 0) {
        newContext.windowTitle.assign(titleBuffer, static_cast<size_t>(titleLength));
    }

    HANDLE processHandle = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, processId);
    if (processHandle != nullptr) {
        std::wstring pathBuffer;
        pathBuffer.resize(32768);
        DWORD pathLength = static_cast<DWORD>(pathBuffer.size());
        if (QueryFullProcessImageNameW(processHandle,
                                       0,
                                       pathBuffer.data(),
                                       &pathLength) != FALSE &&
            pathLength > 0) {
            pathBuffer.resize(pathLength);
            newContext.processPath = std::move(pathBuffer);
        }
        CloseHandle(processHandle);
    }

    if (!newContext.processPath.empty()) {
        const auto path = std::filesystem::path(newContext.processPath);
        const std::wstring fileName = path.filename().wstring();
        if (!fileName.empty()) {
            newContext.processName = fileName;
        }
    }

    if (newContext.processName.empty() && !newContext.processPath.empty()) {
        const size_t slashPos = newContext.processPath.find_last_of(L"\\/");
        if (slashPos == std::wstring::npos) {
            newContext.processName = newContext.processPath;
        } else if (slashPos + 1 < newContext.processPath.size()) {
            newContext.processName = newContext.processPath.substr(slashPos + 1);
        }
    }

    const std::wstring processNameLower = toLowerWide(newContext.processName);
    const std::wstring processPathLower = toLowerWide(newContext.processPath);
    const std::wstring titleLower = toLowerWide(newContext.windowTitle);

    std::wstring processStemLower = processNameLower;
    if (processStemLower.size() > 4 &&
        processStemLower.compare(processStemLower.size() - 4, 4, L".exe") == 0) {
        processStemLower.resize(processStemLower.size() - 4);
    }

    newContext.isBrowser = kBrowserExecutables.count(processNameLower) > 0;
    newContext.isIde = kIdeExecutables.count(processNameLower) > 0;
    newContext.isFastTerminal = kFastTerminalExecutables.count(processNameLower) > 0;
    newContext.isMediumTerminal = kMediumTerminalExecutables.count(processNameLower) > 0;
    newContext.isSlowTerminal = kSlowTerminalExecutables.count(processNameLower) > 0;
    newContext.isTerminal = kTerminalExecutables.count(processNameLower) > 0 ||
                            containsTerminalKeyword(titleLower);
    if (newContext.isFastTerminal || newContext.isMediumTerminal || newContext.isSlowTerminal) {
        newContext.isTerminal = true;
    }
    if (newContext.isIde && containsTerminalKeyword(titleLower)) {
        newContext.isTerminal = true;
    }

    for (const auto& appRule : runtimeConfig_.excludedApps) {
        if (matchesRuntimeRule(appRule,
                               processNameLower,
                               processStemLower,
                               processPathLower,
                               titleLower)) {
            newContext.isExcluded = true;
            break;
        }
    }

    bool matchesStepByStepRule = false;
    for (const auto& appRule : runtimeConfig_.stepByStepApps) {
        if (matchesRuntimeRule(appRule,
                               processNameLower,
                               processStemLower,
                               processPathLower,
                               titleLower)) {
            matchesStepByStepRule = true;
            break;
        }
    }

    newContext.useStepByStep = runtimeConfig_.sendKeyStepByStep != 0 ||
                               matchesStepByStepRule ||
                               newContext.isTerminal;

    if (newContext.useStepByStep) {
        newContext.textDelayUs = kStepByStepDelayDefaultUs;

        if (newContext.isIde && newContext.isTerminal) {
            newContext.backspaceDelayUs = kCliBackspaceDelayMediumUs;
            newContext.waitAfterBackspaceUs = kCliWaitAfterBackspaceMediumUs;
            newContext.textDelayUs = kCliTextDelayMediumUs;
        } else if (newContext.isFastTerminal) {
            newContext.backspaceDelayUs = kCliBackspaceDelayFastUs;
            newContext.waitAfterBackspaceUs = kCliWaitAfterBackspaceFastUs;
            newContext.textDelayUs = kCliTextDelayFastUs;
        } else if (newContext.isMediumTerminal) {
            newContext.backspaceDelayUs = kCliBackspaceDelayMediumUs;
            newContext.waitAfterBackspaceUs = kCliWaitAfterBackspaceMediumUs;
            newContext.textDelayUs = kCliTextDelayMediumUs;
        } else if (newContext.isSlowTerminal) {
            newContext.backspaceDelayUs = kCliBackspaceDelaySlowUs;
            newContext.waitAfterBackspaceUs = kCliWaitAfterBackspaceSlowUs;
            newContext.textDelayUs = kCliTextDelaySlowUs;
        } else if (newContext.isTerminal) {
            newContext.backspaceDelayUs = kCliBackspaceDelayDefaultUs;
            newContext.waitAfterBackspaceUs = kCliWaitAfterBackspaceDefaultUs;
            newContext.textDelayUs = kCliTextDelayDefaultUs;
        }
    }

    if (runtimeConfig_.fixRecommendBrowser != 0 &&
        newContext.isBrowser &&
        newContext.backspaceDelayUs < kBrowserBackspaceDelayUs) {
        newContext.backspaceDelayUs = kBrowserBackspaceDelayUs;
    }

    vUpperCaseExcludedForCurrentApp = newContext.isTerminal ? 1 : 0;

    const bool appChanged = force ||
                            newContext.windowHandle != appContext_.windowHandle ||
                            newContext.processId != appContext_.processId ||
                            newContext.isExcluded != appContext_.isExcluded ||
                            newContext.useStepByStep != appContext_.useStepByStep ||
                            newContext.isTerminal != appContext_.isTerminal;

    appContext_ = std::move(newContext);

    if (appChanged) {
        resetAddressBarCache();
        clearSyncState();
        session_.startSession();
    }
}

void LowLevelHookService::processEngineOutput(const phtv::windows_host::EngineOutput& output,
                                              Uint16 engineKeyCode) {
    const bool useStepByStep = appContext_.useStepByStep;
    const Uint8 capsStatus = currentCapsStatus();
    int backspaceCount = output.backspaceCount;

    if (shouldApplyBrowserAddressBarFix(output, engineKeyCode)) {
        const bool isAddressBar = isFocusedBrowserAddressBar(true);
        if (isBrowserFixDebugEnabled()) {
            std::cerr << "[PHTV BrowserFix] key=" << engineKeyCode
                      << " backspace=" << backspaceCount
                      << " extCode=" << static_cast<int>(output.extCode)
                      << " isAddressBar=" << (isAddressBar ? 1 : 0)
                      << "\n";
        }

        if (isAddressBar) {
            sendEmptyCharacter();
            if (backspaceCount < (MAX_BUFF - 1)) {
                backspaceCount++;
            }
        }
    }

    // Safety guard against accidental mass deletion caused by stale state/race.
    backspaceCount = std::clamp(backspaceCount, 0, 15);

    if (backspaceCount > 0 && backspaceCount < MAX_BUFF) {
        for (int i = 0; i < backspaceCount; ++i) {
            sendBackspace(useStepByStep);
            if (useStepByStep && appContext_.backspaceDelayUs > 0) {
                sleepMicroseconds(appContext_.backspaceDelayUs);
            }
        }

        if (useStepByStep && appContext_.waitAfterBackspaceUs > 0) {
            sleepMicroseconds(appContext_.waitAfterBackspaceUs);
        }
    }

    if (output.code == vReplaceMaro) {
        sendEngineSequence(output.macroChars, false, useStepByStep);

        Uint32 rawKey = engineKeyCode;
        if (currentCapsStatus() != 0) {
            rawKey |= CAPS_MASK;
        }
        sendEngineData(rawKey);
        if (useStepByStep && appContext_.textDelayUs > 0) {
            sleepMicroseconds(appContext_.textDelayUs);
        }
        return;
    }

    sendEngineSequence(output.committedChars, true, useStepByStep);

    if (output.code == vRestore || output.code == vRestoreAndStartNewSession) {
        // Keep the original break key (space/comma/enter/...) like macOS path.
        sendRestoreBreakKey(engineKeyCode, capsStatus);
        if (useStepByStep && appContext_.textDelayUs > 0) {
            sleepMicroseconds(appContext_.textDelayUs);
        }
    }

    if (output.code == vRestoreAndStartNewSession) {
        session_.startSession();
    }
}

void LowLevelHookService::sendEngineSequence(const std::vector<Uint32>& sequence,
                                             bool reverseOrder,
                                             bool useStepByStep) {
    if (sequence.empty()) {
        return;
    }

    if (reverseOrder) {
        for (auto it = sequence.rbegin(); it != sequence.rend(); ++it) {
            sendEngineData(*it);
            if (useStepByStep && appContext_.textDelayUs > 0) {
                sleepMicroseconds(appContext_.textDelayUs);
            }
        }
        return;
    }

    for (const Uint32 value : sequence) {
        sendEngineData(value);
        if (useStepByStep && appContext_.textDelayUs > 0) {
            sleepMicroseconds(appContext_.textDelayUs);
        }
    }
}

void LowLevelHookService::sendEngineData(Uint32 data) {
    Uint16 value = static_cast<Uint16>(data & CHAR_MASK);

    if (!(data & CHAR_CODE_MASK)) {
        if (IS_DOUBLE_CODE(vCodeTable)) {
            pushSyncLength(1);
        }

        Uint16 mappedChar = keyCodeToCharacter(data);
        if (mappedChar != 0) {
            sendUnicode(mappedChar);
            return;
        }

        Uint16 virtualKey = 0;
        if (phtv::windows_adapter::mapEngineKeyToVirtualKey(value, virtualKey)) {
            sendVirtualKey(virtualKey, true);
            sendVirtualKey(virtualKey, false);
        }
        return;
    }

    if (vCodeTable == 0) { // Unicode
        sendUnicode(value);
        return;
    }

    if (vCodeTable == 1 || vCodeTable == 2 || vCodeTable == 4) {
        const Uint16 hi = HIBYTE(value);
        const Uint16 lo = LOBYTE(value);
        sendUnicode(lo);

        if (hi > 32) {
            if (vCodeTable == 2) {
                pushSyncLength(2);
            }
            sendUnicode(hi);
        } else if (vCodeTable == 2) {
            pushSyncLength(1);
        }
        return;
    }

    if (vCodeTable == 3) { // Unicode Compound
        const Uint16 mark = (value >> 13);
        const Uint16 base = value & 0x1FFF;

        pushSyncLength(mark > 0 ? 2 : 1);
        sendUnicode(base);
        if (mark > 0) {
            sendUnicode(_unicodeCompoundMark[mark - 1]);
        }
    }
}

void LowLevelHookService::sendRestoreBreakKey(Uint16 engineKeyCode, Uint8 capsStatus) {
    Uint32 rawKey = engineKeyCode;
    if (capsStatus != 0) {
        rawKey |= CAPS_MASK;
    }

    const Uint16 mappedChar = keyCodeToCharacter(rawKey);
    if (mappedChar != 0) {
        sendUnicode(mappedChar);
        return;
    }

    Uint16 virtualKey = 0;
    if (phtv::windows_adapter::mapEngineKeyToVirtualKey(engineKeyCode, virtualKey)) {
        sendVirtualKey(virtualKey, true);
        sendVirtualKey(virtualKey, false);
    }
}

void LowLevelHookService::sendEmptyCharacter() {
    if (IS_DOUBLE_CODE(vCodeTable)) {
        pushSyncLength(1);
    }
    // Use ZERO WIDTH SPACE (0x200B) instead of NARROW NO-BREAK SPACE
    // as it is less likely to cause visual artifacts in modern address bars.
    sendUnicode(0x200B);
}

void LowLevelHookService::sendUnicode(Uint16 unicodeChar) {
    INPUT inputs[2] = {};

    inputs[0].type = INPUT_KEYBOARD;
    inputs[0].ki.wVk = 0;
    inputs[0].ki.wScan = unicodeChar;
    inputs[0].ki.dwFlags = KEYEVENTF_UNICODE;
    inputs[0].ki.dwExtraInfo = kInjectedEventTag;

    inputs[1] = inputs[0];
    inputs[1].ki.dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;

    SendInput(2, inputs, sizeof(INPUT));
}

void LowLevelHookService::sendVirtualKey(Uint16 virtualKey, bool keyDown, DWORD extraFlags) {
    INPUT input = {};
    input.type = INPUT_KEYBOARD;
    input.ki.wVk = virtualKey;
    input.ki.dwFlags = keyDown ? extraFlags : (extraFlags | KEYEVENTF_KEYUP);
    input.ki.dwExtraInfo = kInjectedEventTag;
    SendInput(1, &input, sizeof(INPUT));
}

void LowLevelHookService::sleepMicroseconds(int microseconds) const {
    if (microseconds <= 0) {
        return;
    }

    constexpr int kMaxDelayUs = 250000;
    const int safeDelay = std::clamp(microseconds, 0, kMaxDelayUs);
    std::this_thread::sleep_for(std::chrono::microseconds(safeDelay));
}

void LowLevelHookService::sendBackspaceRaw() {
    sendVirtualKey(VK_BACK, true);
    sendVirtualKey(VK_BACK, false);
}

void LowLevelHookService::sendBackspace(bool useStepByStep) {
    sendBackspaceRaw();

    if (!IS_DOUBLE_CODE(vCodeTable) || syncKeyLengths_.empty()) {
        return;
    }

    const Uint8 length = syncKeyLengths_.back();
    syncKeyLengths_.pop_back();
    if (length > 1) {
        if (useStepByStep && appContext_.backspaceDelayUs > 0) {
            sleepMicroseconds(appContext_.backspaceDelayUs);
        }
        sendBackspaceRaw();
    }
}

void LowLevelHookService::clearSyncState() {
    syncKeyLengths_.clear();
}

void LowLevelHookService::pushSyncLength(Uint8 length) {
    syncKeyLengths_.push_back(length);
}

} // namespace phtv::windows_hook

#endif // _WIN32
