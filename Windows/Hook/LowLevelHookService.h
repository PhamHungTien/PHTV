#pragma once

#ifdef _WIN32

#include <chrono>
#include <filesystem>
#include <string>
#include <windows.h>
#include <vector>
#include "PHTVEngineSession.h"
#include "RuntimeConfig.h"

struct IUIAutomation;

namespace phtv::windows_hook {

class LowLevelHookService {
public:
    LowLevelHookService();
    ~LowLevelHookService();

    bool start();
    void stop();
    int runMessageLoop();

private:
    static constexpr DWORD kInjectedEventTag = 0x50544856; // "PHTV"

    static LowLevelHookService* instance_;

    static LRESULT CALLBACK KeyboardHookProc(int nCode, WPARAM wParam, LPARAM lParam);
    static LRESULT CALLBACK MouseHookProc(int nCode, WPARAM wParam, LPARAM lParam);

    LRESULT handleKeyboard(WPARAM wParam, LPARAM lParam);
    LRESULT handleMouse(WPARAM wParam, LPARAM lParam);

    void setModifierDown(Uint16 virtualKey);
    void setModifierUp(Uint16 virtualKey);
    bool isModifierKey(Uint16 virtualKey) const;

    Uint8 currentCapsStatus() const;
    bool hasOtherControlKey() const;
    void refreshRuntimeConfigIfNeeded(bool force);
    void refreshForegroundAppContext(bool force);
    void ensureDictionariesLoaded(bool force);
    void initializeUiAutomation();
    void shutdownUiAutomation();
    void resetAddressBarCache();
    bool isFocusedBrowserAddressBar(bool force);
    bool detectAddressBarByFocusedClass(HWND focusedWindow,
                                        std::wstring& outClassNameLower,
                                        bool& outDetermined) const;
    bool detectAddressBarByUiAutomation(HWND focusedWindow, bool& outDetermined) const;
    bool shouldApplyBrowserAddressBarFix(const phtv::windows_host::EngineOutput& output,
                                         Uint16 engineKeyCode) const;

    void processEngineOutput(const phtv::windows_host::EngineOutput& output, Uint16 engineKeyCode);

    void sendEngineSequence(const std::vector<Uint32>& sequence, bool reverseOrder, bool useStepByStep);
    void sendEngineData(Uint32 data);
    void sendRestoreBreakKey(Uint16 engineKeyCode, Uint8 capsStatus);
    void sendEmptyCharacter();
    void sendUnicode(Uint16 unicodeChar);
    void sendVirtualKey(Uint16 virtualKey, bool keyDown, DWORD extraFlags = 0);
    void sleepMicroseconds(int microseconds) const;

    void sendBackspaceRaw();
    void sendBackspace(bool useStepByStep);
    void clearSyncState();
    void pushSyncLength(Uint8 length);

    struct ForegroundAppContext {
        DWORD processId = 0;
        HWND windowHandle = nullptr;
        std::wstring processName;
        std::wstring processPath;
        std::wstring windowTitle;
        bool isBrowser = false;
        bool isTerminal = false;
        bool isIde = false;
        bool isFastTerminal = false;
        bool isMediumTerminal = false;
        bool isSlowTerminal = false;
        bool isExcluded = false;
        bool useStepByStep = false;
        int backspaceDelayUs = 0;
        int waitAfterBackspaceUs = 0;
        int textDelayUs = 0;
    };

    HHOOK keyboardHook_;
    HHOOK mouseHook_;
    bool running_;
    bool hasThreadMessageQueue_;
    bool runtimeConfigLoaded_;
    bool hasConfigFile_;
    bool hasMacrosFile_;
    bool hasConfigWriteTime_;
    bool hasMacrosWriteTime_;
    std::filesystem::file_time_type configWriteTime_;
    std::filesystem::file_time_type macrosWriteTime_;
    std::chrono::steady_clock::time_point nextConfigCheckAt_;
    std::chrono::steady_clock::time_point nextAppContextCheckAt_;

    phtv::windows_host::PHTVEngineSession session_;
    std::vector<Uint8> syncKeyLengths_;
    phtv::windows_runtime::RuntimeConfig runtimeConfig_;
    ForegroundAppContext appContext_;
    IUIAutomation* uiAutomation_;
    bool uiAutomationReady_;
    bool comNeedsUninitialize_;
    std::chrono::steady_clock::time_point nextDictionaryCheckAt_;
    std::chrono::steady_clock::time_point nextAddressBarCheckAt_;
    HWND cachedAddressBarFocusWindow_;
    bool cachedIsAddressBar_;

    Uint32 modifierMask_;
};

} // namespace phtv::windows_hook

#endif // _WIN32
