#ifdef _WIN32

#include "LowLevelHookService.h"

#include <algorithm>
#include <array>
#include <chrono>
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <cwctype>
#include <filesystem>
#include <iostream>
#include <limits>
#include <objbase.h>
#include <oleauto.h>
#include <string>
#include <thread>
#include <tlhelp32.h>
#include <uiautomationclient.h>
#include <unordered_set>
#include <utility>
#include <vector>
#include <imm.h>
#include "Engine.h"
#include "DictionaryBootstrap.h"
#include "RuntimeConfig.h"
#include "Win32KeycodeAdapter.h"

#ifndef PROCESS_QUERY_LIMITED_INFORMATION
#define PROCESS_QUERY_LIMITED_INFORMATION PROCESS_QUERY_INFORMATION
#endif

#ifndef MOD_NOREPEAT
#define MOD_NOREPEAT 0x4000
#endif

namespace {

constexpr Uint32 kMaskShift = 0x01;
constexpr Uint32 kMaskControl = 0x02;
constexpr Uint32 kMaskAlt = 0x04;
constexpr Uint32 kMaskCapital = 0x08;
constexpr Uint32 kMaskWin = 0x10;
constexpr int kSwitchSystemHotkeyId = 0x5601;
constexpr int kEmojiSystemHotkeyId = 0x5602;
constexpr wchar_t kRuntimeConfigChangedEventName[] = L"Local\\PHTV.Windows.RuntimeConfigChanged";
constexpr auto kRegisteredHotkeySuppressWindow = std::chrono::milliseconds(180);

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
constexpr int kBrowserBackspaceDelayUs = 0;
constexpr int kAddressBarDetectRefreshMs = 100;

constexpr int kCliBackspaceDelayIdeUs = 8000;
constexpr int kCliWaitAfterBackspaceIdeUs = 25000;
constexpr int kCliTextDelayIdeUs = 8000;

constexpr int kCliPreBackspaceDelayUs = 4000;
constexpr int kCliPostSendBlockMinUs = 20000;

constexpr int64_t kCliSpeedFastThresholdUs = 20000;
constexpr int64_t kCliSpeedMediumThresholdUs = 32000;
constexpr int64_t kCliSpeedSlowThresholdUs = 48000;
constexpr double kCliSpeedFactorFast = 2.1;
constexpr double kCliSpeedFactorMedium = 1.6;
constexpr double kCliSpeedFactorSlow = 1.3;

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

const std::unordered_set<std::wstring> kChromiumExecutables = {
    L"chrome.exe",
    L"msedge.exe",
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

const std::array<std::wstring_view, 18> kTerminalTitleKeywords = {
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
    L"tool window: terminal",
    L"command prompt",
    L"git bash",
    L"npm"
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

const std::array<std::wstring_view, 14> kAddressBarClassKeywords = {
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
    L"view",
    L"viewsUI",
    L"omniboxview"
};

const std::array<std::wstring_view, 15> kWebContentClassKeywords = {
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
    L"content",
    L"chrome_renderwidgethosthwnd"
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

std::string wideToUtf8(const std::wstring& value) {
    if (value.empty()) {
        return {};
    }

    int required = WideCharToMultiByte(CP_UTF8,
                                       0,
                                       value.c_str(),
                                       static_cast<int>(value.size()),
                                       nullptr,
                                       0,
                                       nullptr,
                                       nullptr);
    if (required <= 0) {
        return {};
    }

    std::string output(static_cast<size_t>(required), '\0');
    if (WideCharToMultiByte(CP_UTF8,
                            0,
                            value.c_str(),
                            static_cast<int>(value.size()),
                            output.data(),
                            required,
                            nullptr,
                            nullptr) <= 0) {
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

std::wstring normalizePathSeparators(std::wstring value) {
    std::replace(value.begin(), value.end(), L'/', L'\\');
    return value;
}

std::wstring queryProcessNameById(DWORD processId) {
    if (processId == 0) {
        return {};
    }

    HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snapshot == INVALID_HANDLE_VALUE) {
        return {};
    }

    PROCESSENTRY32W entry {};
    entry.dwSize = sizeof(entry);
    std::wstring processName;

    if (Process32FirstW(snapshot, &entry) != FALSE) {
        do {
            if (entry.th32ProcessID == processId) {
                processName.assign(entry.szExeFile);
                break;
            }
        } while (Process32NextW(snapshot, &entry) != FALSE);
    }

    CloseHandle(snapshot);
    return processName;
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

    if (ruleLower.size() > 1 && ruleLower.front() == L'"' && ruleLower.back() == L'"') {
        ruleLower = trimWide(ruleLower.substr(1, ruleLower.size() - 2));
    }
    ruleLower = normalizePathSeparators(ruleLower);
    const std::wstring processPathComparable = normalizePathSeparators(processPathLower);

    const bool hasWildcard = ruleLower.find(L'*') != std::wstring::npos;
    if (hasWildcard) {
        return wildcardMatch(processNameLower, ruleLower) ||
               wildcardMatch(processStemLower, ruleLower) ||
               wildcardMatch(processPathComparable, ruleLower) ||
               wildcardMatch(titleLower, ruleLower);
    }

    if (processNameLower == ruleLower ||
        processStemLower == ruleLower ||
        processPathComparable == ruleLower ||
        titleLower == ruleLower) {
        return true;
    }

    if (!hasFileExtension(ruleLower) && !processStemLower.empty() && processStemLower == ruleLower) {
        return true;
    }

    return processNameLower.find(ruleLower) != std::wstring::npos ||
           processStemLower.find(ruleLower) != std::wstring::npos ||
           processPathComparable.find(ruleLower) != std::wstring::npos ||
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

bool isAppRuleDebugEnabled() {
    static int cachedValue = -1;
    if (cachedValue < 0) {
        const char* envValue = std::getenv("PHTV_DEBUG_APP_RULE");
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
      foregroundEventHook_(nullptr),
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
      modifierMask_(0),
      lastKeyDownTime_(),
      hasLastKeyDownTime_(false),
      cliSpeedFactor_(1.0),
      cliBlockUntil_(),
      pauseKeyPressed_(false),
      savedLanguageBeforePause_(0),
      restoreModifierPressed_(false),
      keyPressedWithRestoreModifier_(false),
      switchModifierOnlyArmed_(false),
      keyPressedWithSwitchModifiers_(false),
      emojiModifierOnlyArmed_(false),
      keyPressedWithEmojiModifiers_(false),
      switchHotkeyRegistered_(false),
      emojiHotkeyRegistered_(false),
      suppressSwitchHotkeyMessageUntil_(std::chrono::steady_clock::time_point::min()),
      suppressEmojiHotkeyMessageUntil_(std::chrono::steady_clock::time_point::min()),
      runtimeConfigChangedEvent_(nullptr),
      emojiPickerEvent_(nullptr) {
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
    initializeRuntimeConfigSignal();
    refreshRuntimeConfigIfNeeded(true);
    refreshForegroundAppContext(true);

    MSG msg;
    PeekMessageW(&msg, nullptr, WM_USER, WM_USER, PM_NOREMOVE);
    hasThreadMessageQueue_ = true;
    updateRegisteredSystemHotkeys();

    HINSTANCE moduleHandle = GetModuleHandleW(nullptr);
    keyboardHook_ = SetWindowsHookExW(WH_KEYBOARD_LL, KeyboardHookProc, moduleHandle, 0);
    if (keyboardHook_ == nullptr) {
        std::cerr << "[PHTV] SetWindowsHookEx(WH_KEYBOARD_LL) failed, error=" << GetLastError() << "\n";
        unregisterSystemHotkeys();
        shutdownRuntimeConfigSignal();
        shutdownUiAutomation();
        resetAddressBarCache();
        instance_ = nullptr;
        hasThreadMessageQueue_ = false;
        return false;
    }

    mouseHook_ = SetWindowsHookExW(WH_MOUSE_LL, MouseHookProc, moduleHandle, 0);
    if (mouseHook_ == nullptr) {
        std::cerr << "[PHTV] SetWindowsHookEx(WH_MOUSE_LL) failed, error=" << GetLastError() << "\n";
        UnhookWindowsHookEx(keyboardHook_);
        keyboardHook_ = nullptr;
        unregisterSystemHotkeys();
        shutdownRuntimeConfigSignal();
        shutdownUiAutomation();
        resetAddressBarCache();
        instance_ = nullptr;
        hasThreadMessageQueue_ = false;
        return false;
    }

    // Register for foreground window change events so that browser/terminal
    // detection is always up-to-date before the next keystroke arrives
    // (e.g. after Alt+Tab or taskbar click).
    foregroundEventHook_ = SetWinEventHook(
        EVENT_SYSTEM_FOREGROUND, EVENT_SYSTEM_FOREGROUND,
        nullptr, ForegroundEventProc,
        0, 0,
        WINEVENT_OUTOFCONTEXT | WINEVENT_SKIPOWNPROCESS);
    if (foregroundEventHook_ == nullptr) {
        std::cerr << "[PHTV] SetWinEventHook(EVENT_SYSTEM_FOREGROUND) failed, error="
                  << GetLastError() << " (non-fatal)\n";
    }

    running_ = true;
    std::cerr << "[PHTV] Hooks installed successfully. switchKeyStatus=0x"
              << std::hex << vSwitchKeyStatus << std::dec
              << " emojiEnabled=" << runtimeConfig_.emojiHotkeyEnabled
              << " emojiStatus=0x" << std::hex << runtimeConfig_.emojiHotkeyStatus << std::dec
              << " switchRegistered=" << switchHotkeyRegistered_
              << " emojiRegistered=" << emojiHotkeyRegistered_ << "\n";
    return true;
}

void LowLevelHookService::stop() {
    if (!running_) {
        unregisterSystemHotkeys();
        hasThreadMessageQueue_ = false;
        shutdownRuntimeConfigSignal();
        shutdownUiAutomation();
        resetAddressBarCache();
        return;
    }

    if (foregroundEventHook_ != nullptr) {
        UnhookWinEvent(foregroundEventHook_);
        foregroundEventHook_ = nullptr;
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
    unregisterSystemHotkeys();
    shutdownRuntimeConfigSignal();
    shutdownUiAutomation();

    if (hasThreadMessageQueue_) {
        PostQuitMessage(0);
        hasThreadMessageQueue_ = false;
    }

    if (instance_ == this) {
        instance_ = nullptr;
    }
}

int LowLevelHookService::runMessageLoop() {
    // Use MsgWaitForMultipleObjects to wake
    // immediately when the settings app signals a config change, instead of
    // only detecting changes on the next keystroke.  This ensures hotkey
    // re-registration happens within milliseconds of the user changing a
    // setting, even when no keyboard activity is occurring.
    const DWORD handleCount = (runtimeConfigChangedEvent_ != nullptr) ? 1 : 0;
    const HANDLE waitHandles[1] = { runtimeConfigChangedEvent_ };

    MSG msg {};
    while (running_) {
        const DWORD waitResult = MsgWaitForMultipleObjects(
            handleCount,
            waitHandles,
            FALSE,
            INFINITE,
            QS_ALLINPUT);

        if (!running_) {
            break;
        }

        // Config-change event signaled — reload config and re-register
        // hotkeys immediately, before processing any queued messages.
        if (waitResult == WAIT_OBJECT_0 && handleCount > 0) {
            refreshRuntimeConfigIfNeeded(true);
        }

        // Drain all pending messages (WM_HOTKEY, hook callbacks, WM_QUIT, …).
        while (PeekMessageW(&msg, nullptr, 0, 0, PM_REMOVE)) {
            if (msg.message == WM_QUIT) {
                running_ = false;
                return static_cast<int>(msg.wParam);
            }

            if (msg.message == WM_HOTKEY) {
                handleRegisteredHotkeyMessage(static_cast<int>(msg.wParam));
                continue;
            }

            TranslateMessage(&msg);
            DispatchMessageW(&msg);
        }
    }

    return 0;
}

void LowLevelHookService::initializeRuntimeConfigSignal() {
    if (runtimeConfigChangedEvent_ != nullptr) {
        return;
    }

    runtimeConfigChangedEvent_ = CreateEventW(
        nullptr,
        FALSE,
        FALSE,
        kRuntimeConfigChangedEventName);
    if (runtimeConfigChangedEvent_ == nullptr) {
        std::cerr << "[PHTV] CreateEvent for runtime config signal failed, error=" << GetLastError() << "\n";
    }

    // Try to open the emoji picker event (created by the C# app)
    if (emojiPickerEvent_ == nullptr) {
        emojiPickerEvent_ = OpenEventW(EVENT_MODIFY_STATE, FALSE, L"Local\\PHTV.Windows.OpenEmojiPicker");
        if (emojiPickerEvent_ == nullptr) {
            std::cerr << "[PHTV] OpenEvent for emoji picker failed (app may not be running), error=" << GetLastError() << "\n";
        }
    }
}

void LowLevelHookService::shutdownRuntimeConfigSignal() {
    if (runtimeConfigChangedEvent_ != nullptr) {
        CloseHandle(runtimeConfigChangedEvent_);
        runtimeConfigChangedEvent_ = nullptr;
    }

    if (emojiPickerEvent_ != nullptr) {
        CloseHandle(emojiPickerEvent_);
        emojiPickerEvent_ = nullptr;
    }
}

bool LowLevelHookService::consumeRuntimeConfigSignal() const {
    if (runtimeConfigChangedEvent_ == nullptr) {
        return false;
    }

    const DWORD waitResult = WaitForSingleObject(runtimeConfigChangedEvent_, 0);
    return waitResult == WAIT_OBJECT_0;
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

// Detect foreground window changes immediately via EVENT_SYSTEM_FOREGROUND
// so that browser/terminal context is always up-to-date before the next
// keystroke arrives.
void CALLBACK LowLevelHookService::ForegroundEventProc(
    HWINEVENTHOOK /*hWinEventHook*/,
    DWORD event,
    HWND /*hwnd*/,
    LONG /*idObject*/,
    LONG /*idChild*/,
    DWORD /*dwEventThread*/,
    DWORD /*dwmsEventTime*/) {
    if (event == EVENT_SYSTEM_FOREGROUND && instance_ != nullptr) {
        instance_->refreshForegroundAppContext(true);
    }
}

LRESULT LowLevelHookService::handleKeyboard(WPARAM wParam, LPARAM lParam) {
    auto* keyData = reinterpret_cast<KBDLLHOOKSTRUCT*>(lParam);
    if (keyData == nullptr) {
        return CallNextHookEx(keyboardHook_, HC_ACTION, wParam, lParam);
    }

    if (keyData->dwExtraInfo == kInjectedEventTag) {
        return CallNextHookEx(keyboardHook_, HC_ACTION, wParam, lParam);
    }

    // Skip events injected by other programs (virtual keyboards, remote
    // desktop, accessibility tools, macro software, etc.).  We check the
    // LLKHF_INJECTED flag which Windows sets on all SendInput / keybd_event
    // injected events, combined with non-zero dwExtraInfo.
    if ((keyData->flags & LLKHF_INJECTED) != 0 && keyData->dwExtraInfo != 0) {
        return CallNextHookEx(keyboardHook_, HC_ACTION, wParam, lParam);
    }

    // Skip processing when another IME (Japanese, Chinese, Korean, etc.) is
    // active to avoid conflicts between input methods.
    // Use SendMessageTimeoutW to avoid deadlocks in the low-level hook context.
    {
        HWND hForeground = GetForegroundWindow();
        if (hForeground != nullptr) {
            HWND hIME = ImmGetDefaultIMEWnd(hForeground);
            if (hIME != nullptr) {
                DWORD_PTR imeResult = 0;
                LRESULT sent = SendMessageTimeoutW(
                    hIME, WM_IME_CONTROL, IMC_GETOPENSTATUS, 0,
                    SMTO_ABORTIFHUNG, 10, &imeResult);
                if (sent != 0 && imeResult != 0) {
                    return CallNextHookEx(keyboardHook_, HC_ACTION, wParam, lParam);
                }
            }
        }
    }

    const bool isKeyDown = (wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN);
    const bool isKeyUp = (wParam == WM_KEYUP || wParam == WM_SYSKEYUP);
    if (!isKeyDown && !isKeyUp) {
        return CallNextHookEx(keyboardHook_, HC_ACTION, wParam, lParam);
    }

    const Uint16 vkCode = static_cast<Uint16>(keyData->vkCode);
    const Uint32 previousModifierMask = modifierMask_;
    if (isKeyDown) {
        setModifierDown(vkCode);
    } else {
        setModifierUp(vkCode);
    }

    const bool hasRuntimeSignal = consumeRuntimeConfigSignal();
    const bool configReloadedThisEvent = refreshRuntimeConfigIfNeeded(hasRuntimeSignal);
    updatePauseKeyState(previousModifierMask, modifierMask_);

    if (isModifierKey(vkCode)) {
        const bool consumedRestore = handleCustomRestoreOnModifierChange(vkCode, isKeyDown, previousModifierMask);
        // Modifier-only hotkeys (switch/emoji) still execute their action inside
        // handleModifierOnlyHotkeysOnModifierChange, but we intentionally let the
        // modifier key-up pass through to the application.  Consuming it would
        // leave the focused app with a stuck modifier (it saw the key-down but
        // never the matching key-up).
        handleModifierOnlyHotkeysOnModifierChange(vkCode, isKeyDown, previousModifierMask);
        if (consumedRestore) {
            return 1;
        }

        return CallNextHookEx(keyboardHook_, HC_ACTION, wParam, lParam);
    }

    if (!isKeyDown) {
        return CallNextHookEx(keyboardHook_, HC_ACTION, wParam, lParam);
    }

    if (isCliBlocked()) {
        return CallNextHookEx(keyboardHook_, HC_ACTION, wParam, lParam);
    }

    if (restoreModifierPressed_) {
        keyPressedWithRestoreModifier_ = true;
    }
    if (switchModifierOnlyArmed_ && hotkeyModifiersAreHeld(vSwitchKeyStatus, modifierMask_)) {
        keyPressedWithSwitchModifiers_ = true;
    }
    if (emojiModifierOnlyArmed_ &&
        runtimeConfig_.emojiHotkeyEnabled != 0 &&
        hotkeyModifiersAreHeld(runtimeConfig_.emojiHotkeyStatus, modifierMask_)) {
        keyPressedWithEmojiModifiers_ = true;
    }

    ensureDictionariesLoaded(false);
    refreshForegroundAppContext(false);

    if (appContext_.isTerminal) {
        updateCliSpeedFactor();
    } else {
        cliSpeedFactor_ = 1.0;
        hasLastKeyDownTime_ = false;
    }

    Uint16 engineKeyCode = 0;
    if (!phtv::windows_adapter::mapVirtualKeyToEngine(vkCode, engineKeyCode)) {
        return CallNextHookEx(keyboardHook_, HC_ACTION, wParam, lParam);
    }

    if (handleHotkeysOnKeyDown(engineKeyCode, configReloadedThisEvent)) {
        return 1;
    }

    // Win+key combinations are always system shortcuts (Win+E, Win+R, Win+D,
    // Win+L, etc.).  If the combination was not already consumed as a PHTV
    // hotkey above, pass it through immediately so the OS can handle it.
    if ((modifierMask_ & kMaskWin) != 0) {
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

bool LowLevelHookService::hotkeyModifiersMatchExact(int hotkeyStatus, Uint32 currentModifierMask) const {
    const bool hasShift = (currentModifierMask & kMaskShift) != 0;
    const bool hasControl = (currentModifierMask & kMaskControl) != 0;
    const bool hasOption = (currentModifierMask & kMaskAlt) != 0;
    const bool hasCommand = (currentModifierMask & kMaskWin) != 0;

    if (HAS_SHIFT(hotkeyStatus) != (hasShift ? 1 : 0)) {
        return false;
    }
    if (HAS_CONTROL(hotkeyStatus) != (hasControl ? 1 : 0)) {
        return false;
    }
    if (HAS_OPTION(hotkeyStatus) != (hasOption ? 1 : 0)) {
        return false;
    }
    if (HAS_COMMAND(hotkeyStatus) != (hasCommand ? 1 : 0)) {
        return false;
    }

    // Windows low-level hook does not expose a stable Fn flag.
    if (HAS_FN(hotkeyStatus)) {
        return false;
    }

    return true;
}

bool LowLevelHookService::hotkeyModifiersAreHeld(int hotkeyStatus, Uint32 currentModifierMask) const {
    const bool hasShift = (currentModifierMask & kMaskShift) != 0;
    const bool hasControl = (currentModifierMask & kMaskControl) != 0;
    const bool hasOption = (currentModifierMask & kMaskAlt) != 0;
    const bool hasCommand = (currentModifierMask & kMaskWin) != 0;

    if (HAS_SHIFT(hotkeyStatus) && !hasShift) {
        return false;
    }
    if (HAS_CONTROL(hotkeyStatus) && !hasControl) {
        return false;
    }
    if (HAS_OPTION(hotkeyStatus) && !hasOption) {
        return false;
    }
    if (HAS_COMMAND(hotkeyStatus) && !hasCommand) {
        return false;
    }

    // Windows low-level hook does not expose a stable Fn flag.
    if (HAS_FN(hotkeyStatus)) {
        return false;
    }

    return true;
}

bool LowLevelHookService::isModifierOnlyHotkey(int hotkeyStatus) const {
    return GET_SWITCH_KEY(hotkeyStatus) == 0xFE;
}

bool LowLevelHookService::isHotkeyMatch(int hotkeyStatus,
                                        Uint16 engineKeyCode,
                                        Uint32 currentModifierMask,
                                        bool checkKeyCode) const {
    if (!hotkeyModifiersMatchExact(hotkeyStatus, currentModifierMask)) {
        return false;
    }

    if (!checkKeyCode) {
        return true;
    }

    return GET_SWITCH_KEY(hotkeyStatus) == engineKeyCode;
}

bool LowLevelHookService::shouldHandleSwitchHotkeyWithHook(bool forceHookHotkeyHandling) const {
    if (isModifierOnlyHotkey(vSwitchKeyStatus)) {
        return true;
    }

    return forceHookHotkeyHandling || !switchHotkeyRegistered_;
}

bool LowLevelHookService::shouldHandleEmojiHotkeyWithHook(bool forceHookHotkeyHandling) const {
    if (runtimeConfig_.emojiHotkeyEnabled == 0) {
        return false;
    }

    if (isModifierOnlyHotkey(runtimeConfig_.emojiHotkeyStatus)) {
        return true;
    }

    return forceHookHotkeyHandling || !emojiHotkeyRegistered_;
}

bool LowLevelHookService::handleRegisteredHotkeyMessage(int hotkeyId) {
    const auto now = std::chrono::steady_clock::now();
    switch (hotkeyId) {
        case kSwitchSystemHotkeyId:
            if (now < suppressSwitchHotkeyMessageUntil_) {
                return true;
            }
            toggleLanguageByHotkey();
            return true;
        case kEmojiSystemHotkeyId:
            if (now < suppressEmojiHotkeyMessageUntil_) {
                return true;
            }
            triggerEmojiPanel();
            return true;
        default:
            return false;
    }
}

void LowLevelHookService::updateRegisteredSystemHotkeys() {
    if (!hasThreadMessageQueue_) {
        std::cerr << "[PHTV] updateRegisteredSystemHotkeys: no message queue yet\n";
        return;
    }

    unregisterSystemHotkeys();
    switchHotkeyRegistered_ = registerSystemHotkey(
        kSwitchSystemHotkeyId,
        vSwitchKeyStatus,
        true);
    emojiHotkeyRegistered_ = registerSystemHotkey(
        kEmojiSystemHotkeyId,
        runtimeConfig_.emojiHotkeyStatus,
        runtimeConfig_.emojiHotkeyEnabled != 0);
    std::cerr << "[PHTV] System hotkeys updated: switchReg=" << switchHotkeyRegistered_
              << " (isModOnly=" << isModifierOnlyHotkey(vSwitchKeyStatus) << ")"
              << " emojiReg=" << emojiHotkeyRegistered_
              << " (isModOnly=" << isModifierOnlyHotkey(runtimeConfig_.emojiHotkeyStatus) << ")"
              << "\n";
}

void LowLevelHookService::unregisterSystemHotkeys() {
    if (hasThreadMessageQueue_) {
        UnregisterHotKey(nullptr, kSwitchSystemHotkeyId);
        UnregisterHotKey(nullptr, kEmojiSystemHotkeyId);
    }

    switchHotkeyRegistered_ = false;
    emojiHotkeyRegistered_ = false;
}

bool LowLevelHookService::registerSystemHotkey(int hotkeyId, int hotkeyStatus, bool enabled) {
    if (!enabled || !hasThreadMessageQueue_) {
        return false;
    }

    UINT modifiers = 0;
    UINT virtualKey = 0;
    if (!tryBuildSystemHotkey(hotkeyStatus, modifiers, virtualKey)) {
        return false;
    }

    if (RegisterHotKey(nullptr, hotkeyId, modifiers, virtualKey) == 0) {
        std::cerr << "[PHTV] RegisterHotKey failed (id=" << hotkeyId
                  << ", error=" << GetLastError() << ")\n";
        return false;
    }

    std::cerr << "[PHTV] RegisterHotKey success (id=" << hotkeyId << ")\n";
    return true;
}

bool LowLevelHookService::tryBuildSystemHotkey(int hotkeyStatus,
                                               UINT& outModifiers,
                                               UINT& outVirtualKey) const {
    outModifiers = 0;
    outVirtualKey = 0;

    const int engineKeyCode = GET_SWITCH_KEY(hotkeyStatus);
    if (engineKeyCode == 0xFE || HAS_FN(hotkeyStatus)) {
        return false;
    }

    std::uint16_t virtualKey = 0;
    if (!phtv::windows_adapter::mapEngineKeyToVirtualKey(static_cast<Uint16>(engineKeyCode), virtualKey)) {
        return false;
    }

    UINT modifiers = MOD_NOREPEAT;
    if (HAS_CONTROL(hotkeyStatus)) {
        modifiers |= MOD_CONTROL;
    }
    if (HAS_OPTION(hotkeyStatus)) {
        modifiers |= MOD_ALT;
    }
    if (HAS_COMMAND(hotkeyStatus)) {
        modifiers |= MOD_WIN;
    }
    if (HAS_SHIFT(hotkeyStatus)) {
        modifiers |= MOD_SHIFT;
    }

    // Avoid claiming single-key global hotkeys; only combinations are supported.
    if ((modifiers & (MOD_CONTROL | MOD_ALT | MOD_WIN | MOD_SHIFT)) == 0) {
        return false;
    }

    outModifiers = modifiers;
    outVirtualKey = static_cast<UINT>(virtualKey);
    return true;
}

bool LowLevelHookService::handleHotkeysOnKeyDown(Uint16 engineKeyCode,
                                                 bool forceHookHotkeyHandling) {
    if (handleSwitchHotkey(engineKeyCode, forceHookHotkeyHandling)) {
        return true;
    }

    if (handleEmojiHotkey(engineKeyCode, forceHookHotkeyHandling)) {
        return true;
    }

    return false;
}

bool LowLevelHookService::handleSwitchHotkey(Uint16 engineKeyCode, bool forceHookHotkeyHandling) {
    if (!shouldHandleSwitchHotkeyWithHook(forceHookHotkeyHandling) || isModifierOnlyHotkey(vSwitchKeyStatus)) {
        return false;
    }

    if (!isHotkeyMatch(vSwitchKeyStatus, engineKeyCode, modifierMask_, true)) {
        return false;
    }

    if (switchHotkeyRegistered_) {
        suppressSwitchHotkeyMessageUntil_ = std::chrono::steady_clock::now() + kRegisteredHotkeySuppressWindow;
    }
    toggleLanguageByHotkey();
    return true;
}

bool LowLevelHookService::handleEmojiHotkey(Uint16 engineKeyCode, bool forceHookHotkeyHandling) {
    if (!shouldHandleEmojiHotkeyWithHook(forceHookHotkeyHandling)) {
        return false;
    }

    if (isModifierOnlyHotkey(runtimeConfig_.emojiHotkeyStatus)) {
        return false;
    }

    if (!isHotkeyMatch(runtimeConfig_.emojiHotkeyStatus, engineKeyCode, modifierMask_, true)) {
        return false;
    }

    if (emojiHotkeyRegistered_) {
        suppressEmojiHotkeyMessageUntil_ = std::chrono::steady_clock::now() + kRegisteredHotkeySuppressWindow;
    }
    triggerEmojiPanel();
    return true;
}

bool LowLevelHookService::handleModifierOnlyHotkeysOnModifierChange(Uint16 virtualKey,
                                                                    bool isKeyDown,
                                                                    Uint32 previousModifierMask) {
    (void)virtualKey;

    if (isKeyDown) {
        if (isModifierOnlyHotkey(vSwitchKeyStatus) &&
            hotkeyModifiersAreHeld(vSwitchKeyStatus, modifierMask_)) {
            switchModifierOnlyArmed_ = true;
            keyPressedWithSwitchModifiers_ = false;
        }

        if (runtimeConfig_.emojiHotkeyEnabled != 0 &&
            isModifierOnlyHotkey(runtimeConfig_.emojiHotkeyStatus) &&
            hotkeyModifiersAreHeld(runtimeConfig_.emojiHotkeyStatus, modifierMask_)) {
            emojiModifierOnlyArmed_ = true;
            keyPressedWithEmojiModifiers_ = false;
        }

        return false;
    }

    bool consumed = false;

    if (switchModifierOnlyArmed_) {
        const bool stillHeld = hotkeyModifiersAreHeld(vSwitchKeyStatus, modifierMask_);
        if (!stillHeld) {
            if (hotkeyModifiersMatchExact(vSwitchKeyStatus, previousModifierMask) &&
                !keyPressedWithSwitchModifiers_) {
                toggleLanguageByHotkey();
                consumed = true;
            }
            switchModifierOnlyArmed_ = false;
            keyPressedWithSwitchModifiers_ = false;
        }
    }

    if (emojiModifierOnlyArmed_) {
        const bool stillHeld = hotkeyModifiersAreHeld(runtimeConfig_.emojiHotkeyStatus, modifierMask_);
        if (!stillHeld) {
            if (runtimeConfig_.emojiHotkeyEnabled != 0 &&
                hotkeyModifiersMatchExact(runtimeConfig_.emojiHotkeyStatus, previousModifierMask) &&
                !keyPressedWithEmojiModifiers_) {
                triggerEmojiPanel();
                consumed = true;
            }
            emojiModifierOnlyArmed_ = false;
            keyPressedWithEmojiModifiers_ = false;
        }
    }

    return consumed;
}

void LowLevelHookService::toggleLanguageByHotkey() {
    const int newLanguage = vLanguage == 0 ? 1 : 0;
    std::cerr << "[PHTV] Switch hotkey fired: " << (newLanguage == 1 ? "EN→VI" : "VI→EN") << "\n";
    vLanguage = newLanguage;
    runtimeConfig_.language = newLanguage;
    persistRuntimeLanguageState();
    clearSyncState();
    session_.startSession();
}

void LowLevelHookService::triggerEmojiPanel() {
    std::cerr << "[PHTV] Emoji hotkey fired, modifierMask=0x"
              << std::hex << modifierMask_ << std::dec << "\n";

    // Release any physically-held modifier keys so they don't interfere
    // with the picker or the fallback Win+. shortcut.
    const Uint32 savedMask = modifierMask_;
    if (savedMask & kMaskControl) {
        sendVirtualKey(VK_LCONTROL, false);
    }
    if (savedMask & kMaskShift) {
        sendVirtualKey(VK_LSHIFT, false);
    }
    if (savedMask & kMaskAlt) {
        sendVirtualKey(VK_LMENU, false);
    }

    // Try to signal the PHTV Picker event (custom picker in the C# app).
    // If the event handle is not available (app not running), try to open it.
    if (emojiPickerEvent_ == nullptr) {
        emojiPickerEvent_ = OpenEventW(EVENT_MODIFY_STATE, FALSE, L"Local\\PHTV.Windows.OpenEmojiPicker");
    }

    if (emojiPickerEvent_ != nullptr) {
        if (SetEvent(emojiPickerEvent_)) {
            std::cerr << "[PHTV] Signaled PHTV Picker event\n";
        } else {
            // Handle became invalid (app exited), close and retry next time
            std::cerr << "[PHTV] SetEvent failed, error=" << GetLastError() << "\n";
            CloseHandle(emojiPickerEvent_);
            emojiPickerEvent_ = nullptr;
        }
    } else {
        // Fallback: open system emoji panel via Win+.
        std::cerr << "[PHTV] Picker event not available, falling back to Win+.\n";

#ifdef VK_OEM_PERIOD
        constexpr Uint16 kEmojiTriggerVirtualKey = VK_OEM_PERIOD;
#else
        constexpr Uint16 kEmojiTriggerVirtualKey = 0xBE;
#endif

        sendVirtualKey(VK_LWIN, true);
        sendVirtualKey(kEmojiTriggerVirtualKey, true);
        sendVirtualKey(kEmojiTriggerVirtualKey, false);
        sendVirtualKey(VK_LWIN, false);
    }

    // Re-press modifiers that the user is still physically holding so that
    // the OS modifier state stays consistent with the physical keyboard.
    if (savedMask & kMaskAlt) {
        sendVirtualKey(VK_LMENU, true);
    }
    if (savedMask & kMaskShift) {
        sendVirtualKey(VK_LSHIFT, true);
    }
    if (savedMask & kMaskControl) {
        sendVirtualKey(VK_LCONTROL, true);
    }
}

void LowLevelHookService::persistRuntimeLanguageState() {
    std::string errorMessage;
    if (!phtv::windows_runtime::persistRuntimeLanguage(vLanguage, errorMessage) && !errorMessage.empty()) {
        std::cerr << "[PHTV] Cannot persist runtime language: " << errorMessage << "\n";
    }
}

void LowLevelHookService::updatePauseKeyState(Uint32 previousModifierMask, Uint32 currentModifierMask) {
    if (runtimeConfig_.pauseKeyEnabled == 0) {
        if (pauseKeyPressed_) {
            vLanguage = savedLanguageBeforePause_;
            runtimeConfig_.language = vLanguage;
            pauseKeyPressed_ = false;
            clearSyncState();
            session_.startSession();
        }
        return;
    }

    if (!pauseKeyPressed_ && isPauseModifierHeld(currentModifierMask)) {
        savedLanguageBeforePause_ = vLanguage;
        if (vLanguage != 0) {
            vLanguage = 0;
            runtimeConfig_.language = 0;
            clearSyncState();
            session_.startSession();
        }
        pauseKeyPressed_ = true;
        return;
    }

    if (pauseKeyPressed_ &&
        isPauseModifierHeld(previousModifierMask) &&
        !isPauseModifierHeld(currentModifierMask)) {
        vLanguage = savedLanguageBeforePause_;
        runtimeConfig_.language = vLanguage;
        pauseKeyPressed_ = false;
        clearSyncState();
        session_.startSession();
    }
}

bool LowLevelHookService::isPauseModifierHeld(Uint32 currentModifierMask) const {
    switch (runtimeConfig_.pauseKey) {
        case KEY_LEFT_OPTION:
        case KEY_RIGHT_OPTION:
            return (currentModifierMask & kMaskAlt) != 0;
        case KEY_LEFT_CONTROL:
        case KEY_RIGHT_CONTROL:
            return (currentModifierMask & kMaskControl) != 0;
        case KEY_LEFT_SHIFT:
        case KEY_RIGHT_SHIFT:
            return (currentModifierMask & kMaskShift) != 0;
        case KEY_LEFT_COMMAND:
        case KEY_RIGHT_COMMAND:
            return (currentModifierMask & kMaskWin) != 0;
        default:
            return false;
    }
}

bool LowLevelHookService::handleCustomRestoreOnModifierChange(Uint16 virtualKey,
                                                              bool isKeyDown,
                                                              Uint32 previousModifierMask) {
    if (runtimeConfig_.restoreOnEscape == 0) {
        restoreModifierPressed_ = false;
        keyPressedWithRestoreModifier_ = false;
        return false;
    }

    const int customRestoreKey = runtimeConfig_.customEscapeKey;
    if (customRestoreKey <= 0 || customRestoreKey == KEY_ESC) {
        restoreModifierPressed_ = false;
        keyPressedWithRestoreModifier_ = false;
        return false;
    }

    if (isKeyDown) {
        if (isRestoreModifierVirtualKey(virtualKey)) {
            restoreModifierPressed_ = true;
            keyPressedWithRestoreModifier_ = false;
        }
        return false;
    }

    if (!restoreModifierPressed_) {
        return false;
    }

    const bool shouldRestore = !keyPressedWithRestoreModifier_ &&
                               isRestoreModifierReleased(virtualKey, previousModifierMask, modifierMask_);
    restoreModifierPressed_ = false;
    keyPressedWithRestoreModifier_ = false;
    if (!shouldRestore) {
        return false;
    }

    return tryRestoreCurrentWordWithoutBreakKey(KEY_ESC);
}

bool LowLevelHookService::isRestoreModifierVirtualKey(Uint16 virtualKey) const {
    switch (runtimeConfig_.customEscapeKey) {
        case KEY_LEFT_OPTION:
        case KEY_RIGHT_OPTION:
            return virtualKey == VK_LMENU || virtualKey == VK_RMENU;
        case KEY_LEFT_CONTROL:
        case KEY_RIGHT_CONTROL:
            return virtualKey == VK_LCONTROL || virtualKey == VK_RCONTROL;
        default:
            return false;
    }
}

bool LowLevelHookService::isRestoreModifierReleased(Uint16 virtualKey,
                                                    Uint32 previousModifierMask,
                                                    Uint32 currentModifierMask) const {
    switch (runtimeConfig_.customEscapeKey) {
        case KEY_LEFT_OPTION:
        case KEY_RIGHT_OPTION:
            return (virtualKey == VK_LMENU || virtualKey == VK_RMENU) &&
                   ((previousModifierMask & kMaskAlt) != 0) &&
                   ((currentModifierMask & kMaskAlt) == 0);
        case KEY_LEFT_CONTROL:
        case KEY_RIGHT_CONTROL:
            return (virtualKey == VK_LCONTROL || virtualKey == VK_RCONTROL) &&
                   ((previousModifierMask & kMaskControl) != 0) &&
                   ((currentModifierMask & kMaskControl) == 0);
        default:
            return false;
    }
}

bool LowLevelHookService::tryRestoreCurrentWordWithoutBreakKey(Uint16 fallbackEngineKeyCode) {
    auto output = session_.processKeyDown(
        fallbackEngineKeyCode,
        currentCapsStatus(),
        hasOtherControlKey());

    if (output.code == vDoNothing) {
        return false;
    }

    processEngineOutputWithoutRestoreBreak(output);
    return true;
}

void LowLevelHookService::processEngineOutputWithoutRestoreBreak(
    const phtv::windows_host::EngineOutput& output) {
    const bool useStepByStep = appContext_.useStepByStep;
    int backspaceCount = std::clamp(static_cast<int>(output.backspaceCount), 0, 15);

    const bool isCli = appContext_.isTerminal;
    const int scaledBackspaceDelay = isCli
        ? scaleCliDelay(appContext_.backspaceDelayUs)
        : appContext_.backspaceDelayUs;
    const int scaledWaitAfterBackspace = isCli
        ? scaleCliDelay(appContext_.waitAfterBackspaceUs)
        : appContext_.waitAfterBackspaceUs;
    const int scaledTextDelay = isCli
        ? scaleCliDelay(appContext_.textDelayUs)
        : appContext_.textDelayUs;

    if (backspaceCount > 0) {
        for (int i = 0; i < backspaceCount; ++i) {
            sendBackspace(useStepByStep);
            if (useStepByStep && scaledBackspaceDelay > 0) {
                sleepMicroseconds(scaledBackspaceDelay);
            }
        }

        if (useStepByStep && scaledWaitAfterBackspace > 0) {
            sleepMicroseconds(scaledWaitAfterBackspace);
        }
    }

    if (output.code == vReplaceMaro) {
        sendEngineSequence(output.macroChars, false, useStepByStep, scaledTextDelay);
        return;
    }

    sendEngineSequence(output.committedChars, true, useStepByStep, scaledTextDelay);

    if (output.code == vRestoreAndStartNewSession) {
        session_.startSession();
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
    return (modifierMask_ & (kMaskControl | kMaskAlt | kMaskWin)) != 0;
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
        const bool isEditableControl = controlType == UIA_EditControlTypeId ||
                                       controlType == UIA_ComboBoxControlTypeId;

        if (controlType == UIA_DocumentControlTypeId) {
            hasWebKeyword = true;
        }

        if (hasAddressKeyword) {
            return 1;
        }

        // Prefer editable controls over weak web keywords. Chromium UIA trees can
        // contain document-like ancestors even when focus is in omnibox.
        if (isEditableControl) {
            return 1;
        }

        if (hasWebKeyword) {
            return -1;
        }

        return 0;
    };

    bool foundAddressCandidate = false;
    bool foundWebContent = false;
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
        for (int depth = 0; depth < 12; ++depth) {
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
                foundWebContent = true;
                if (!foundAddressCandidate) {
                    current->Release();
                    walker->Release();
                    focusedElement->Release();
                    outDetermined = true;
                    return false;
                }
                // Once we already have an address candidate, don't let outer
                // document/web ancestors override it.
                break;
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
    if (foundWebContent) {
        outDetermined = true;
        return false;
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
    // Match macOS behavior: browser fix is always-on for browser contexts.
    if (!appContext_.isBrowser) {
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
    std::cerr << "[PHTV Dict] Reload attempted. EN="
              << (status.englishLoaded ? "OK" : "MISSING")
              << " (" << status.englishPath.string() << ")"
              << " VI="
              << (status.vietnameseLoaded ? "OK" : "MISSING")
              << " (" << status.vietnamesePath.string() << ")"
              << "\n";
    if (isBrowserFixDebugEnabled()) {
    }
}

bool LowLevelHookService::refreshRuntimeConfigIfNeeded(bool force) {
    const auto now = std::chrono::steady_clock::now();
    if (!force && now < nextConfigCheckAt_) {
        return false;
    }

    nextConfigCheckAt_ = now + std::chrono::milliseconds(250);

    const auto configPath = phtv::windows_runtime::runtimeConfigPath();
    const auto macrosPath = phtv::windows_runtime::runtimeMacrosPath();

    std::error_code ec;
    const bool hasConfig = std::filesystem::exists(configPath, ec);
    if (ec) {
        return false;
    }

    ec.clear();
    const bool hasMacros = std::filesystem::exists(macrosPath, ec);
    if (ec) {
        return false;
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
        return false;
    }

    phtv::windows_runtime::RuntimeConfig loadedConfig;
    std::string errorMessage;
    if (!phtv::windows_runtime::loadAndApplyRuntimeConfig(loadedConfig, errorMessage)) {
        if (!errorMessage.empty()) {
            std::cerr << "[PHTV] Runtime config load failed: " << errorMessage << "\n";
        }
        return false;
    }

    runtimeConfig_ = std::move(loadedConfig);
    runtimeConfigLoaded_ = true;
    updateRegisteredSystemHotkeys();
    pauseKeyPressed_ = false;
    restoreModifierPressed_ = false;
    keyPressedWithRestoreModifier_ = false;
    switchModifierOnlyArmed_ = false;
    keyPressedWithSwitchModifiers_ = false;
    emojiModifierOnlyArmed_ = false;
    keyPressedWithEmojiModifiers_ = false;
    suppressSwitchHotkeyMessageUntil_ = std::chrono::steady_clock::time_point::min();
    suppressEmojiHotkeyMessageUntil_ = std::chrono::steady_clock::time_point::min();
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

    // Always ensure global vLanguage and vFixRecommendBrowser are perfectly in sync with config
    vLanguage = runtimeConfig_.language == 0 ? 0 : 1;
    vFixRecommendBrowser = runtimeConfig_.fixRecommendBrowser == 0 ? 0 : 1;

    std::cerr << "[PHTV] Config reloaded. lang=" << (vLanguage == 1 ? "VI" : "EN")
              << " switchKey=0x" << std::hex << vSwitchKeyStatus << std::dec
              << " emojiEnabled=" << runtimeConfig_.emojiHotkeyEnabled
              << " emojiKey=0x" << std::hex << runtimeConfig_.emojiHotkeyStatus << std::dec
              << " switchReg=" << switchHotkeyRegistered_
              << " emojiReg=" << emojiHotkeyRegistered_ << "\n";

    if (isBrowserFixDebugEnabled()) {
        std::cerr << "[PHTV] Config reloaded. Language: " << (vLanguage == 1 ? "VI" : "EN")
                  << ", FixBrowser: " << vFixRecommendBrowser << "\n";
    }

    nextAppContextCheckAt_ = std::chrono::steady_clock::time_point::min();
    resetAddressBarCache();
    refreshForegroundAppContext(true);
    clearSyncState();
    session_.startSession();
    return true;
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

    if (newContext.processName.empty()) {
        newContext.processName = queryProcessNameById(processId);
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
    newContext.isChromiumBrowser = kChromiumExecutables.count(processNameLower) > 0;
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
    if (newContext.isIde && !newContext.isTerminal) {
        if (detectIdeTerminalByUiAutomation()) {
            newContext.isTerminal = true;
        }
    }

    std::string matchedExcludedRule;
    for (const auto& appRule : runtimeConfig_.excludedApps) {
        if (matchesRuntimeRule(appRule,
                               processNameLower,
                               processStemLower,
                               processPathLower,
                               titleLower)) {
            newContext.isExcluded = true;
            matchedExcludedRule = appRule;
            break;
        }
    }

    bool matchesStepByStepRule = false;
    std::string matchedStepByStepRule;
    for (const auto& appRule : runtimeConfig_.stepByStepApps) {
        if (matchesRuntimeRule(appRule,
                               processNameLower,
                               processStemLower,
                               processPathLower,
                               titleLower)) {
            matchesStepByStepRule = true;
            matchedStepByStepRule = appRule;
            break;
        }
    }

    newContext.useStepByStep = runtimeConfig_.sendKeyStepByStep != 0 ||
                               matchesStepByStepRule ||
                               newContext.isTerminal;

    if (newContext.useStepByStep) {
        newContext.textDelayUs = kStepByStepDelayDefaultUs;

        if (newContext.isIde && newContext.isTerminal) {
            newContext.backspaceDelayUs = kCliBackspaceDelayIdeUs;
            newContext.waitAfterBackspaceUs = kCliWaitAfterBackspaceIdeUs;
            newContext.textDelayUs = kCliTextDelayIdeUs;
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

    if (appChanged && isAppRuleDebugEnabled()) {
        std::cerr << "[PHTV AppRule] process="
                  << wideToUtf8(processNameLower)
                  << " excluded=" << (newContext.isExcluded ? 1 : 0)
                  << " stepByStep=" << (newContext.useStepByStep ? 1 : 0)
                  << " terminal=" << (newContext.isTerminal ? 1 : 0)
                  << " matchExcluded=\"" << matchedExcludedRule << "\""
                  << " matchStepByStep=\"" << matchedStepByStepRule << "\""
                  << " title=\"" << wideToUtf8(titleLower) << "\""
                  << "\n";
    }

    appContext_ = std::move(newContext);

    if (appChanged) {
        resetAddressBarCache();
        clearSyncState();
        session_.startSession();
        cliSpeedFactor_ = 1.0;
        hasLastKeyDownTime_ = false;
        cliBlockUntil_ = {};
    }
}

void LowLevelHookService::updateCliSpeedFactor() {
    const auto now = std::chrono::steady_clock::now();
    if (!hasLastKeyDownTime_) {
        lastKeyDownTime_ = now;
        hasLastKeyDownTime_ = true;
        cliSpeedFactor_ = 1.0;
        return;
    }

    const int64_t deltaUs = std::chrono::duration_cast<std::chrono::microseconds>(
        now - lastKeyDownTime_).count();
    lastKeyDownTime_ = now;

    double target = 1.0;
    if (deltaUs > 0) {
        if (deltaUs <= kCliSpeedFastThresholdUs) {
            target = kCliSpeedFactorFast;
        } else if (deltaUs <= kCliSpeedMediumThresholdUs) {
            target = kCliSpeedFactorMedium;
        } else if (deltaUs <= kCliSpeedSlowThresholdUs) {
            target = kCliSpeedFactorSlow;
        }
    }

    if (target >= cliSpeedFactor_) {
        cliSpeedFactor_ = target;
    } else {
        cliSpeedFactor_ = (cliSpeedFactor_ * 0.7) + (target * 0.3);
        if (cliSpeedFactor_ < 1.0) {
            cliSpeedFactor_ = 1.0;
        }
    }
}

int LowLevelHookService::scaleCliDelay(int baseDelayUs) const {
    if (baseDelayUs <= 0) {
        return 0;
    }
    if (cliSpeedFactor_ <= 1.05) {
        return baseDelayUs;
    }
    const double scaled = static_cast<double>(baseDelayUs) * cliSpeedFactor_;
    constexpr int kMaxDelayUs = 250000;
    if (scaled > static_cast<double>(kMaxDelayUs)) {
        return kMaxDelayUs;
    }
    return static_cast<int>(scaled);
}

void LowLevelHookService::setCliBlockForMicroseconds(int64_t microseconds) {
    if (microseconds <= 0) {
        return;
    }
    const auto blockUntil = std::chrono::steady_clock::now() +
        std::chrono::microseconds(microseconds);
    if (blockUntil > cliBlockUntil_) {
        cliBlockUntil_ = blockUntil;
    }
}

bool LowLevelHookService::isCliBlocked() const {
    if (!appContext_.isTerminal) {
        return false;
    }
    return std::chrono::steady_clock::now() < cliBlockUntil_;
}

bool LowLevelHookService::detectIdeTerminalByUiAutomation() const {
    if (!uiAutomationReady_ || uiAutomation_ == nullptr) {
        return false;
    }

    IUIAutomationElement* focusedElement = nullptr;
    HRESULT hr = uiAutomation_->GetFocusedElement(&focusedElement);
    if (FAILED(hr) || focusedElement == nullptr) {
        return false;
    }

    bool isTerminalPanel = false;

    auto checkElementForTerminal = [](IUIAutomationElement* element) -> bool {
        if (element == nullptr) {
            return false;
        }

        BSTR nameValue = nullptr;
        BSTR automationIdValue = nullptr;
        BSTR classValue = nullptr;
        BSTR localizedTypeValue = nullptr;

        element->get_CurrentName(&nameValue);
        element->get_CurrentAutomationId(&automationIdValue);
        element->get_CurrentClassName(&classValue);
        element->get_CurrentLocalizedControlType(&localizedTypeValue);

        bool found = false;
        auto checkBstr = [](BSTR value) -> bool {
            if (value == nullptr) {
                return false;
            }
            const std::wstring lower = bstrToLower(value);
            return containsTerminalKeyword(lower);
        };

        found = checkBstr(nameValue) || checkBstr(automationIdValue) ||
                checkBstr(classValue) || checkBstr(localizedTypeValue);

        if (nameValue != nullptr) SysFreeString(nameValue);
        if (automationIdValue != nullptr) SysFreeString(automationIdValue);
        if (classValue != nullptr) SysFreeString(classValue);
        if (localizedTypeValue != nullptr) SysFreeString(localizedTypeValue);

        return found;
    };

    if (checkElementForTerminal(focusedElement)) {
        isTerminalPanel = true;
    }

    if (!isTerminalPanel) {
        IUIAutomationTreeWalker* walker = nullptr;
        if (SUCCEEDED(uiAutomation_->get_ControlViewWalker(&walker)) && walker != nullptr) {
            IUIAutomationElement* current = focusedElement;
            current->AddRef();
            for (int depth = 0; depth < 8 && !isTerminalPanel; ++depth) {
                IUIAutomationElement* parent = nullptr;
                HRESULT parentHr = walker->GetParentElement(current, &parent);
                current->Release();
                current = nullptr;

                if (FAILED(parentHr) || parent == nullptr) {
                    break;
                }

                current = parent;
                if (checkElementForTerminal(parent)) {
                    isTerminalPanel = true;
                }
            }

            if (current != nullptr) {
                current->Release();
            }
            walker->Release();
        }
    }

    focusedElement->Release();
    return isTerminalPanel;
}

void LowLevelHookService::sendAddressBarSelection(int count) {
    if (count <= 0) {
        return;
    }

    // Hold Shift, press Left Arrow N times to select N characters backwards.
    // Sending Shift as a separate event ensures all Left presses are treated as selection.
    sendVirtualKey(VK_LSHIFT, true);

    for (int i = 0; i < count; ++i) {
        sendVirtualKey(VK_LEFT, true, KEYEVENTF_EXTENDEDKEY);
        sendVirtualKey(VK_LEFT, false, KEYEVENTF_EXTENDEDKEY);

        // Handle double-code tables: one engine char may be 2 code points.
        if (IS_DOUBLE_CODE(vCodeTable) && !syncKeyLengths_.empty()) {
            const Uint8 length = syncKeyLengths_.back();
            syncKeyLengths_.pop_back();
            if (length > 1) {
                sendVirtualKey(VK_LEFT, true, KEYEVENTF_EXTENDEDKEY);
                sendVirtualKey(VK_LEFT, false, KEYEVENTF_EXTENDEDKEY);
            }
        }

        if (i + 1 < count) {
            sleepMicroseconds(1500);
        }
    }

    sendVirtualKey(VK_LSHIFT, false);
}

void LowLevelHookService::processAddressBarOutput(
    const phtv::windows_host::EngineOutput& output,
    Uint16 engineKeyCode, int backspaceCount) {
    // Address bar strategy: Empty char → Shift+Left selection → new text replaces selection.
    // This avoids backspace, which re-triggers Chromium autocomplete on Windows.

    const Uint8 capsStatus = currentCapsStatus();
    constexpr int kPostEmptyCharDelayUs = 3000;
    constexpr int kPostSelectionDelayUs = 2000;

    // 1. Wait for Edge to process the empty char that was already sent by caller.
    sleepMicroseconds(kPostEmptyCharDelayUs);

    // 2. Select (backspaceCount) chars backwards using Shift+Left.
    //    backspaceCount already includes +1 for the empty char.
    if (backspaceCount > 0) {
        sendAddressBarSelection(backspaceCount);
        sleepMicroseconds(kPostSelectionDelayUs);
    }

    // 3. Send new text - the first character replaces the selection,
    //    subsequent characters are inserted normally.
    if (output.code == vReplaceMaro) {
        sendEngineSequence(output.macroChars, false, false);

        Uint32 rawKey = engineKeyCode;
        if (capsStatus != 0) {
            rawKey |= CAPS_MASK;
        }
        sendEngineData(rawKey);
        return;
    }

    sendEngineSequence(output.committedChars, true, false);

    if (output.code == vRestore || output.code == vRestoreAndStartNewSession) {
        sendRestoreBreakKey(engineKeyCode, capsStatus);
    }

    if (output.code == vRestoreAndStartNewSession) {
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
                      << " isChromium=" << (appContext_.isChromiumBrowser ? 1 : 0)
                      << "\n";
        }

        if (isAddressBar) {
            // Windows Address Bar Fix: Shift+Left selection strategy.
            // Backspace re-triggers Chromium autocomplete on Windows, causing "dđ" duplication.
            // Instead: send empty char to break autocomplete, then use Shift+Left to SELECT
            // the characters. The new text replaces the selection atomically.
            sendEmptyCharacter();
            int selectionCount = backspaceCount + 1; // +1 for the empty char
            selectionCount = std::clamp(selectionCount, 0, 15);
            processAddressBarOutput(output, engineKeyCode, selectionCount);
            return;
        }

        if (appContext_.isChromiumBrowser && backspaceCount > 0) {
            // Chromium fallback: if address-bar detection misses,
            // pre-select one character then let normal backspace flow continue.
            sendVirtualKey(VK_LSHIFT, true);
            sendVirtualKey(VK_LEFT, true, KEYEVENTF_EXTENDEDKEY);
            sendVirtualKey(VK_LEFT, false, KEYEVENTF_EXTENDEDKEY);
            sendVirtualKey(VK_LSHIFT, false);
            if (backspaceCount == 1) {
                backspaceCount = 0;
            }
            if (isBrowserFixDebugEnabled()) {
                std::cerr << "[PHTV BrowserFix] Chromium fallback selection applied"
                          << " adjustedBackspace=" << backspaceCount << "\n";
            }
        } else if (!appContext_.isChromiumBrowser && backspaceCount > 0) {
            // For non-Chromium browsers (Firefox, etc.), send an empty
            // character (U+202F) to break autocomplete/suggestion selection,
            // then add one extra backspace to remove it.
            sendEmptyCharacter();
            backspaceCount++;
            if (isBrowserFixDebugEnabled()) {
                std::cerr << "[PHTV BrowserFix] Non-Chromium empty char fix applied"
                          << " adjustedBackspace=" << backspaceCount << "\n";
            }
        }
    }

    // Safety guard against accidental mass deletion caused by stale state/race.
    backspaceCount = std::clamp(backspaceCount, 0, 15);

    const bool isCli = appContext_.isTerminal;
    const int scaledBackspaceDelay = isCli
        ? scaleCliDelay(appContext_.backspaceDelayUs)
        : appContext_.backspaceDelayUs;
    const int scaledWaitAfterBackspace = isCli
        ? scaleCliDelay(appContext_.waitAfterBackspaceUs)
        : appContext_.waitAfterBackspaceUs;
    const int scaledTextDelay = isCli
        ? scaleCliDelay(appContext_.textDelayUs)
        : appContext_.textDelayUs;

    if (backspaceCount > 0 && backspaceCount < MAX_BUFF) {
        if (isCli) {
            int64_t totalBlockUs = static_cast<int64_t>(
                std::max(kCliPostSendBlockMinUs, scaledTextDelay * 3));
            if (scaledBackspaceDelay > 0) {
                totalBlockUs += static_cast<int64_t>(scaledBackspaceDelay) * backspaceCount;
            }
            totalBlockUs += static_cast<int64_t>(scaledWaitAfterBackspace);
            setCliBlockForMicroseconds(totalBlockUs);

            if (cliSpeedFactor_ > 1.05) {
                const int preDelay = scaleCliDelay(kCliPreBackspaceDelayUs);
                if (preDelay > 0) {
                    sleepMicroseconds(preDelay);
                }
            }
        }

        for (int i = 0; i < backspaceCount; ++i) {
            sendBackspace(useStepByStep);
            if (useStepByStep && scaledBackspaceDelay > 0) {
                sleepMicroseconds(scaledBackspaceDelay);
            }
        }

        if (useStepByStep && scaledWaitAfterBackspace > 0) {
            sleepMicroseconds(scaledWaitAfterBackspace);
        }
    }

    if (output.code == vReplaceMaro) {
        const size_t charCount = output.macroChars.size() + 1;
        if (isCli && scaledTextDelay > 0) {
            int64_t totalBlockUs = static_cast<int64_t>(
                std::max(kCliPostSendBlockMinUs, scaledTextDelay * 3));
            if (charCount > 1) {
                totalBlockUs += static_cast<int64_t>(scaledTextDelay) *
                    static_cast<int64_t>(charCount - 1);
            }
            setCliBlockForMicroseconds(totalBlockUs);
        }

        sendEngineSequence(output.macroChars, false, useStepByStep, scaledTextDelay);

        Uint32 rawKey = engineKeyCode;
        if (currentCapsStatus() != 0) {
            rawKey |= CAPS_MASK;
        }
        sendEngineData(rawKey);
        if (useStepByStep && scaledTextDelay > 0) {
            sleepMicroseconds(scaledTextDelay);
        }
        return;
    }

    const size_t charCount = output.committedChars.size() +
        ((output.code == vRestore || output.code == vRestoreAndStartNewSession) ? 1 : 0);
    if (isCli && scaledTextDelay > 0 && charCount > 0) {
        int64_t totalBlockUs = static_cast<int64_t>(
            std::max(kCliPostSendBlockMinUs, scaledTextDelay * 3));
        if (charCount > 1) {
            totalBlockUs += static_cast<int64_t>(scaledTextDelay) *
                static_cast<int64_t>(charCount - 1);
        }
        setCliBlockForMicroseconds(totalBlockUs);
    }

    sendEngineSequence(output.committedChars, true, useStepByStep, scaledTextDelay);

    if (output.code == vRestore || output.code == vRestoreAndStartNewSession) {
        sendRestoreBreakKey(engineKeyCode, capsStatus);
        if (useStepByStep && scaledTextDelay > 0) {
            sleepMicroseconds(scaledTextDelay);
        }
    }

    if (output.code == vRestoreAndStartNewSession) {
        session_.startSession();
    }
}

void LowLevelHookService::sendEngineSequence(const std::vector<Uint32>& sequence,
                                             bool reverseOrder,
                                             bool useStepByStep,
                                             int textDelayUs) {
    if (sequence.empty()) {
        return;
    }

    if (reverseOrder) {
        for (auto it = sequence.rbegin(); it != sequence.rend(); ++it) {
            sendEngineData(*it);
            if (useStepByStep && textDelayUs > 0) {
                sleepMicroseconds(textDelayUs);
            }
        }
        return;
    }

    for (const Uint32 value : sequence) {
        sendEngineData(value);
        if (useStepByStep && textDelayUs > 0) {
            sleepMicroseconds(textDelayUs);
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
    // Use NARROW NO-BREAK SPACE (0x202F) like macOS version.
    // This is more effective at interrupting Chromium's autocomplete engine.
    sendUnicode(0x202F);
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
