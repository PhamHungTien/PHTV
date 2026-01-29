#include "Bridge.h"
#include <windows.h>
#include <shlwapi.h>
#include <algorithm>
#include <string>
#include <cstring>
#include <vector>
#include <cctype>
#include <fstream>
#include <cstdio>
#include "Engine.h"
#include "Config/PHTVConfig.h"

// Globals for DLL
HINSTANCE hInstDLL;
HHOOK hKeyboardHook = NULL;

// Forward declaration from Engine/main logic logic
#define PHTV_INJECTED_SIGNATURE 0x99887766 

// DLL Entry Point
BOOL APIENTRY DllMain( HMODULE hModule,
                       DWORD  ul_reason_for_call,
                       LPVOID lpReserved
                     )
{
    switch (ul_reason_for_call)
    {
    case DLL_PROCESS_ATTACH:
        hInstDLL = hModule;
        break;
    case DLL_THREAD_ATTACH:
    case DLL_THREAD_DETACH:
    case DLL_PROCESS_DETACH:
        break;
    }
    return TRUE;
}

static std::wstring GetExeDir() {
    wchar_t buffer[MAX_PATH];
    GetModuleFileNameW(NULL, buffer, MAX_PATH);
    PathRemoveFileSpecW(buffer);
    return std::wstring(buffer);
}

static std::string WStringToUtf8(const std::wstring& wstr) {
    if (wstr.empty()) return std::string();
    int size_needed = WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), NULL, 0, NULL, NULL);
    std::string strTo(size_needed, 0);
    WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), &strTo[0], size_needed, NULL, NULL);
    return strTo;
}

static std::wstring Utf8ToWString(const std::string& str) {
    if (str.empty()) return std::wstring();
    int size_needed = MultiByteToWideChar(CP_UTF8, 0, str.c_str(), (int)str.size(), NULL, 0);
    std::wstring wstr(size_needed, 0);
    MultiByteToWideChar(CP_UTF8, 0, str.c_str(), (int)str.size(), &wstr[0], size_needed);
    return wstr;
}

static void CopyWString(const std::wstring& src, wchar_t* outBuf, int outCap) {
    if (!outBuf || outCap <= 0) return;
    wcsncpy_s(outBuf, outCap, src.c_str(), _TRUNCATE);
}

static bool GetClipboardText(std::wstring& outText) {
    outText.clear();
    if (!OpenClipboard(NULL)) return false;
    HANDLE data = GetClipboardData(CF_UNICODETEXT);
    if (!data) {
        CloseClipboard();
        return false;
    }
    const wchar_t* text = static_cast<const wchar_t*>(GlobalLock(data));
    if (!text) {
        CloseClipboard();
        return false;
    }
    outText.assign(text);
    GlobalUnlock(data);
    CloseClipboard();
    return true;
}

static bool SetClipboardText(const std::wstring& text) {
    if (!OpenClipboard(NULL)) return false;
    EmptyClipboard();
    size_t bytes = (text.size() + 1) * sizeof(wchar_t);
    HGLOBAL hMem = GlobalAlloc(GMEM_MOVEABLE, bytes);
    if (!hMem) {
        CloseClipboard();
        return false;
    }
    void* ptr = GlobalLock(hMem);
    if (!ptr) {
        GlobalFree(hMem);
        CloseClipboard();
        return false;
    }
    memcpy(ptr, text.c_str(), bytes);
    GlobalUnlock(hMem);
    SetClipboardData(CF_UNICODETEXT, hMem);
    CloseClipboard();
    return true;
}

static bool ReadFileBinary(const wchar_t* path, std::vector<Byte>& outData) {
    outData.clear();
    if (!path) return false;
    FILE* f = _wfopen(path, L"rb");
    if (!f) return false;
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (size <= 0) {
        fclose(f);
        return false;
    }
    outData.resize((size_t)size);
    fread(outData.data(), 1, (size_t)size, f);
    fclose(f);
    return true;
}

static bool WriteFileBinary(const wchar_t* path, const std::vector<Byte>& data) {
    if (!path) return false;
    FILE* f = _wfopen(path, L"wb");
    if (!f) return false;
    if (!data.empty()) {
        fwrite(data.data(), 1, data.size(), f);
    }
    fclose(f);
    return true;
}

static bool GetForegroundExeName(std::string& outExe) {
    outExe.clear();
    HWND fg = GetForegroundWindow();
    if (!fg) return false;
    DWORD pid = 0;
    GetWindowThreadProcessId(fg, &pid);
    if (pid == 0) return false;
    HANDLE hProc = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_VM_READ, FALSE, pid);
    if (!hProc) return false;
    wchar_t path[MAX_PATH];
    DWORD size = MAX_PATH;
    bool ok = false;
    if (QueryFullProcessImageNameW(hProc, 0, path, &size)) {
        std::wstring wpath(path);
        size_t pos = wpath.find_last_of(L"\\/");
        std::wstring exe = (pos == std::wstring::npos) ? wpath : wpath.substr(pos + 1);
        outExe = WStringToUtf8(exe);
        ok = !outExe.empty();
    }
    CloseHandle(hProc);
    return ok;
}

static bool IsModifierKey(DWORD vk) {
    switch (vk) {
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
        return true;
    default:
        return false;
    }
}

static bool ModifiersMatch(bool reqCtrl, bool reqAlt, bool reqShift, bool reqWin) {
    bool curCtrl = (GetKeyState(VK_CONTROL) & 0x8000) != 0;
    bool curAlt = (GetKeyState(VK_MENU) & 0x8000) != 0;
    bool curShift = (GetKeyState(VK_SHIFT) & 0x8000) != 0;
    bool curWin = (GetKeyState(VK_LWIN) & 0x8000) != 0 || (GetKeyState(VK_RWIN) & 0x8000) != 0;

    if (reqCtrl && !curCtrl) return false;
    if (reqAlt && !curAlt) return false;
    if (reqShift && !curShift) return false;
    if (reqWin && !curWin) return false;

    if (!reqCtrl && curCtrl) return false;
    if (!reqAlt && curAlt) return false;
    if (!reqShift && curShift) return false;
    if (!reqWin && curWin) return false;

    return true;
}

// ---------------------------------------------------------
// INPUT SIMULATION HELPERS
// ---------------------------------------------------------
void SendBackspace(int count) {
    if (count <= 0) return;
    std::vector<INPUT> inputs;
    for (int i = 0; i < count; ++i) {
        INPUT inputDown = {0};
        inputDown.type = INPUT_KEYBOARD;
        inputDown.ki.wVk = VK_BACK;
        inputDown.ki.dwExtraInfo = PHTV_INJECTED_SIGNATURE;
        
        INPUT inputUp = {0};
        inputUp.type = INPUT_KEYBOARD;
        inputUp.ki.wVk = VK_BACK;
        inputUp.ki.dwFlags = KEYEVENTF_KEYUP;
        inputUp.ki.dwExtraInfo = PHTV_INJECTED_SIGNATURE;

        inputs.push_back(inputDown);
        inputs.push_back(inputUp);
    }
    SendInput((UINT)inputs.size(), inputs.data(), sizeof(INPUT));
}

static void SendUnicodeChar(unsigned int finalChar) {
    INPUT inputDown = {0};
    inputDown.type = INPUT_KEYBOARD;
    inputDown.ki.wScan = (WORD)finalChar;
    inputDown.ki.dwFlags = KEYEVENTF_UNICODE;
    inputDown.ki.dwExtraInfo = PHTV_INJECTED_SIGNATURE;

    INPUT inputUp = inputDown;
    inputUp.ki.dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;

    INPUT inputs[2] = {inputDown, inputUp};
    SendInput(2, inputs, sizeof(INPUT));
}

static bool SendCharLayoutCompat(wchar_t ch) {
    SHORT vk = VkKeyScanW(ch);
    if (vk == -1) return false;

    BYTE vkCode = LOBYTE(vk);
    BYTE shiftState = HIBYTE(vk);

    std::vector<INPUT> inputs;
    auto pushKey = [&](WORD key, bool up) {
        INPUT input = {0};
        input.type = INPUT_KEYBOARD;
        input.ki.wVk = key;
        input.ki.dwFlags = up ? KEYEVENTF_KEYUP : 0;
        input.ki.dwExtraInfo = PHTV_INJECTED_SIGNATURE;
        inputs.push_back(input);
    };

    if (shiftState & 0x01) pushKey(VK_SHIFT, false);
    if (shiftState & 0x02) pushKey(VK_CONTROL, false);
    if (shiftState & 0x04) pushKey(VK_MENU, false);

    pushKey(vkCode, false);
    pushKey(vkCode, true);

    if (shiftState & 0x04) pushKey(VK_MENU, true);
    if (shiftState & 0x02) pushKey(VK_CONTROL, true);
    if (shiftState & 0x01) pushKey(VK_SHIFT, true);

    if (!inputs.empty()) {
        SendInput((UINT)inputs.size(), inputs.data(), sizeof(INPUT));
        return true;
    }
    return false;
}

void SendUnicodeString(const std::vector<unsigned int>& charCodes) {
    if (charCodes.empty()) return;
    std::vector<INPUT> inputs;
    
    // CAPS MASK from Engine (defined in DataType.h)
    const unsigned int CAPS_MASK_VAL = 0x10000;

    for (unsigned int code : charCodes) {
        unsigned int finalChar = code & 0xFFFF; // Extract char
        bool isUpperCase = (code & CAPS_MASK_VAL) != 0;

        // FIX: Handle Capitalization for Raw Keys
        if (finalChar >= 'A' && finalChar <= 'Z') {
            if (!isUpperCase) {
                finalChar = tolower(finalChar);
            }
        }
        
        INPUT inputDown = {0};
        inputDown.type = INPUT_KEYBOARD;
        inputDown.ki.wScan = (WORD)finalChar;
        inputDown.ki.dwFlags = KEYEVENTF_UNICODE;
        inputDown.ki.dwExtraInfo = PHTV_INJECTED_SIGNATURE;
        inputs.push_back(inputDown);

        INPUT inputUp = {0};
        inputUp.type = INPUT_KEYBOARD;
        inputUp.ki.wScan = (WORD)finalChar;
        inputUp.ki.dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;
        inputUp.ki.dwExtraInfo = PHTV_INJECTED_SIGNATURE;
        inputs.push_back(inputUp);
    }
    SendInput((UINT)inputs.size(), inputs.data(), sizeof(INPUT));
}

void ProcessEngineOutput() {
    extern vKeyHookState HookState;
    if (HookState.backspaceCount > 0) SendBackspace(HookState.backspaceCount);
    
    if (HookState.newCharCount > 0) {
        std::vector<unsigned int> chars;
        // FIX: Read buffer in REVERSE order
        for (int i = HookState.newCharCount - 1; i >= 0; i--) {
            chars.push_back(HookState.charData[i]);
        }
        if (vSendKeyStepByStep || vPerformLayoutCompat) {
            const unsigned int CAPS_MASK_VAL = 0x10000;
            for (unsigned int code : chars) {
                unsigned int finalChar = code & 0xFFFF;
                bool isUpperCase = (code & CAPS_MASK_VAL) != 0;
                if (finalChar >= 'A' && finalChar <= 'Z') {
                    if (!isUpperCase) {
                        finalChar = tolower(finalChar);
                    }
                }
                if (vPerformLayoutCompat) {
                    if (SendCharLayoutCompat((wchar_t)finalChar)) {
                        continue;
                    }
                }
                SendUnicodeChar(finalChar);
            }
        } else {
            SendUnicodeString(chars);
        }
    }
}

// ---------------------------------------------------------
// UPPERCASE EXCLUDED APPS
// ---------------------------------------------------------
static std::vector<std::string> g_upperExcludedApps;

// ---------------------------------------------------------
// SWITCH KEY HOTKEY
// ---------------------------------------------------------
static const int SWITCH_KEY_MASK = 0xFF;
static const int SWITCH_KEY_NO = 0xFE;
static const int SWITCH_MASK_CONTROL = 0x100;
static const int SWITCH_MASK_ALT = 0x200;
static const int SWITCH_MASK_WIN = 0x400;
static const int SWITCH_MASK_SHIFT = 0x800;
static const int SWITCH_MASK_FN = 0x1000;
static const int SWITCH_MASK_BEEP = 0x8000;
static bool g_switchHotkeyDown = false;
static bool g_pauseKeyDown = false;

static bool IsSwitchHotkeyEnabled() {
    int status = vSwitchKeyStatus;
    int key = status & SWITCH_KEY_MASK;
    bool hasModifiers = (status & (SWITCH_MASK_CONTROL | SWITCH_MASK_ALT | SWITCH_MASK_WIN | SWITCH_MASK_SHIFT)) != 0;
    return key != 0 || hasModifiers;
}

static bool IsSwitchHotkeyMatch(const KBDLLHOOKSTRUCT* pKbd, bool isKeyDown, bool isKeyUp, bool& shouldConsume) {
    shouldConsume = false;
    if (!IsSwitchHotkeyEnabled()) return false;
    int status = vSwitchKeyStatus;
    int key = status & SWITCH_KEY_MASK;
    bool reqCtrl = (status & SWITCH_MASK_CONTROL) != 0;
    bool reqAlt = (status & SWITCH_MASK_ALT) != 0;
    bool reqWin = (status & SWITCH_MASK_WIN) != 0;
    bool reqShift = (status & SWITCH_MASK_SHIFT) != 0;

    if (!ModifiersMatch(reqCtrl, reqAlt, reqShift, reqWin)) {
        if (isKeyUp) {
            g_switchHotkeyDown = false;
        }
        return false;
    }

    if (key == 0) return false;

    if (key == SWITCH_KEY_NO) {
        if (!(reqCtrl || reqAlt || reqShift || reqWin)) return false;
        if (!IsModifierKey(pKbd->vkCode)) return false;
        shouldConsume = isKeyDown;
        return true;
    }

    if ((int)pKbd->vkCode != key) return false;
    shouldConsume = isKeyDown;
    return true;
}

// ---------------------------------------------------------
// HOOK PROCEDURE
// ---------------------------------------------------------
LRESULT CALLBACK LowLevelKeyboardProc(int nCode, WPARAM wParam, LPARAM lParam) {
    if (nCode == HC_ACTION) {
        KBDLLHOOKSTRUCT* pKbd = (KBDLLHOOKSTRUCT*)lParam;

        if (pKbd->dwExtraInfo == PHTV_INJECTED_SIGNATURE) {
            return CallNextHookEx(hKeyboardHook, nCode, wParam, lParam);
        }

        bool isKeyDown = (wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN);
        bool isKeyUp = (wParam == WM_KEYUP || wParam == WM_SYSKEYUP);

        // Pause key handling: temporarily bypass engine while held
        if (vPauseKeyEnabled && vPauseKey > 0 && (int)pKbd->vkCode == vPauseKey) {
            if (isKeyDown) {
                g_pauseKeyDown = true;
                vTempOffEngine(true);
            } else if (isKeyUp) {
                g_pauseKeyDown = false;
                vTempOffEngine(false);
            }
            return CallNextHookEx(hKeyboardHook, nCode, wParam, lParam);
        }

        if (vPauseKeyEnabled && g_pauseKeyDown) {
            return CallNextHookEx(hKeyboardHook, nCode, wParam, lParam);
        }

        // Custom restore key (non-ESC)
        if (vRestoreOnEscape && vCustomEscapeKey > 0 && (int)pKbd->vkCode == vCustomEscapeKey && isKeyDown) {
            if (vRestoreToRawKeys()) {
                ProcessEngineOutput();
                return 1;
            }
        }

        bool shouldConsume = false;
        if (IsSwitchHotkeyMatch(pKbd, isKeyDown, isKeyUp, shouldConsume)) {
            if (isKeyDown && !g_switchHotkeyDown) {
                vLanguage = (vLanguage == 1) ? 0 : 1;
                if ((vSwitchKeyStatus & SWITCH_MASK_BEEP) != 0) {
                    MessageBeep(MB_OK);
                }
                g_switchHotkeyDown = true;
            }
            if (isKeyUp) {
                g_switchHotkeyDown = false;
            }
            if (shouldConsume) {
                return 1;
            }
        }

        // Smart switch key per app (optional)
        std::string exeUtf8;
        bool hasExe = false;
        if (vUseSmartSwitchKey || vUpperCaseExcludedForCurrentApp || !g_upperExcludedApps.empty()) {
            hasExe = GetForegroundExeName(exeUtf8);
        }

        if (vUseSmartSwitchKey && hasExe) {
            int status = getAppInputMethodStatus(exeUtf8, vLanguage);
            if (status != -1 && status != vLanguage) {
                vLanguage = status;
            }
        }

        if (!g_upperExcludedApps.empty() && hasExe) {
            bool excluded = false;
            for (const auto& name : g_upperExcludedApps) {
                if (_stricmp(name.c_str(), exeUtf8.c_str()) == 0) {
                    excluded = true;
                    break;
                }
            }
            vUpperCaseExcludedForCurrentApp = excluded ? 1 : 0;
        } else if (g_upperExcludedApps.empty()) {
            vUpperCaseExcludedForCurrentApp = 0;
        }

        // Access global config directly (vLanguage is extern in Engine)
        if (vLanguage == 1) {
            vKeyEventState state;
            if (isKeyDown) state = vKeyEventState::KeyDown;
            else if (isKeyUp) state = vKeyEventState::KeyUp;
            else return CallNextHookEx(hKeyboardHook, nCode, wParam, lParam);

            if (state == vKeyEventState::KeyDown) {
                bool isShift = (GetKeyState(VK_SHIFT) & 0x8000) != 0;
                bool isCaps = (GetKeyState(VK_CAPITAL) & 0x0001) != 0;
                bool isCtrl = (GetKeyState(VK_CONTROL) & 0x8000) != 0;
                bool isAlt = (GetKeyState(VK_MENU) & 0x8000) != 0;

                Uint8 capsStatus = 0;
                if (isShift) capsStatus = 1;
                if (isCaps) capsStatus = 2; 

                extern vKeyHookState HookState;
                vKeyHandleEvent(vKeyEvent::Keyboard, state, (Uint16)pKbd->vkCode, capsStatus, isCtrl || isAlt);

                if (HookState.code != vDoNothing) {
                    ProcessEngineOutput();
                    return 1; // Block original key
                }
            }
        }
    }
    return CallNextHookEx(hKeyboardHook, nCode, wParam, lParam);
}

// ---------------------------------------------------------
// EXPORTED FUNCTIONS
// ---------------------------------------------------------
void __cdecl PHTV_Init(const wchar_t* resourceDir) {
    vKeyInit();
    PHTVConfig::Shared().Load();

    std::wstring baseDir = (resourceDir != nullptr) ? std::wstring(resourceDir) : GetExeDir();
    // Remove trailing slash if present
    if (!baseDir.empty() && (baseDir.back() == L'\\' || baseDir.back() == L'/')) {
        baseDir.pop_back();
    }

    std::wstring viDictPath = baseDir + L"\\Dictionaries\\vi_dict.bin";
    std::wstring enDictPath = baseDir + L"\\Dictionaries\\en_dict.bin";
    
    initVietnameseDictionary(WStringToUtf8(viDictPath));
    initEnglishDictionary(WStringToUtf8(enDictPath));
}

void __cdecl PHTV_InstallHook() {
    if (!hKeyboardHook) {
        // Important: NULL for hInstance might work for WH_KEYBOARD_LL in EXE, 
        // but for DLL it usually requires the DLL module handle
        // However, WH_KEYBOARD_LL is a global hook, so hInstance must be set.
        hKeyboardHook = SetWindowsHookEx(WH_KEYBOARD_LL, LowLevelKeyboardProc, hInstDLL, 0);
    }
}

void __cdecl PHTV_UninstallHook() {
    if (hKeyboardHook) {
        UnhookWindowsHookEx(hKeyboardHook);
        hKeyboardHook = NULL;
    }
}

void __cdecl PHTV_LoadConfig() { PHTVConfig::Shared().Load(); }
void __cdecl PHTV_SaveConfig() { PHTVConfig::Shared().Save(); }
void __cdecl PHTV_ResetConfig() { PHTVConfig::Shared().ResetDefaults(); }

void __cdecl PHTV_SetInputMethod(int type) { vInputType = type; }
void __cdecl PHTV_SetLanguage(int lang) { vLanguage = lang; }
void __cdecl PHTV_SetCodeTable(int table) { 
    vCodeTable = table; 
    onTableCodeChange();
}
void __cdecl PHTV_SetSpellCheck(bool enable) { vCheckSpelling = enable ? 1 : 0; }
void __cdecl PHTV_SetModernOrthography(bool enable) { vUseModernOrthography = enable ? 1 : 0; }
void __cdecl PHTV_SetQuickTelex(bool enable) { vQuickTelex = enable ? 1 : 0; }
void __cdecl PHTV_SetAutoRestoreEnglishWord(bool enable) { vAutoRestoreEnglishWord = enable ? 1 : 0; }
void __cdecl PHTV_SetMacro(bool enable) { vUseMacro = enable ? 1 : 0; }
void __cdecl PHTV_SetMacroInEnglishMode(bool enable) { vUseMacroInEnglishMode = enable ? 1 : 0; }
void __cdecl PHTV_SetAutoCapsMacro(bool enable) { vAutoCapsMacro = enable ? 1 : 0; }
void __cdecl PHTV_SetFixRecommendBrowser(bool enable) { vFixRecommendBrowser = enable ? 1 : 0; }
void __cdecl PHTV_SetSmartSwitchKey(bool enable) { vUseSmartSwitchKey = enable ? 1 : 0; }
void __cdecl PHTV_SetUpperCaseFirstChar(bool enable) { vUpperCaseFirstChar = enable ? 1 : 0; }
void __cdecl PHTV_SetUpperCaseExcludedForCurrentApp(bool enable) { vUpperCaseExcludedForCurrentApp = enable ? 1 : 0; }
void __cdecl PHTV_SetAllowConsonantZFWJ(bool enable) { vAllowConsonantZFWJ = enable ? 1 : 0; }
void __cdecl PHTV_SetQuickStartConsonant(bool enable) { vQuickStartConsonant = enable ? 1 : 0; }
void __cdecl PHTV_SetQuickEndConsonant(bool enable) { vQuickEndConsonant = enable ? 1 : 0; }
void __cdecl PHTV_SetFreeMark(bool enable) { vFreeMark = enable ? 1 : 0; }
void __cdecl PHTV_SetRestoreOnEscape(bool enable) { vRestoreOnEscape = enable ? 1 : 0; }
void __cdecl PHTV_SetCustomEscapeKey(int key) { vCustomEscapeKey = key; }
void __cdecl PHTV_SetPauseKeyEnabled(bool enable) { vPauseKeyEnabled = enable ? 1 : 0; }
void __cdecl PHTV_SetPauseKey(int key) { vPauseKey = key; }
void __cdecl PHTV_SetSwitchKeyStatus(int status) { vSwitchKeyStatus = status; }
void __cdecl PHTV_SetOtherLanguage(int lang) { vOtherLanguage = lang; }
void __cdecl PHTV_SetRememberCode(bool enable) { vRememberCode = enable ? 1 : 0; }
void __cdecl PHTV_SetSendKeyStepByStep(bool enable) { vSendKeyStepByStep = enable ? 1 : 0; }
void __cdecl PHTV_SetPerformLayoutCompat(bool enable) { vPerformLayoutCompat = enable ? 1 : 0; }

int __cdecl PHTV_GetInputMethod() { return vInputType; }
int __cdecl PHTV_GetLanguage() { return vLanguage; }
int __cdecl PHTV_GetCodeTable() { return vCodeTable; }
bool __cdecl PHTV_GetSpellCheck() { return vCheckSpelling != 0; }
bool __cdecl PHTV_GetModernOrthography() { return vUseModernOrthography != 0; }
bool __cdecl PHTV_GetQuickTelex() { return vQuickTelex != 0; }
bool __cdecl PHTV_GetAutoRestoreEnglishWord() { return vAutoRestoreEnglishWord != 0; }
bool __cdecl PHTV_GetMacro() { return vUseMacro != 0; }
bool __cdecl PHTV_GetMacroInEnglishMode() { return vUseMacroInEnglishMode != 0; }
bool __cdecl PHTV_GetAutoCapsMacro() { return vAutoCapsMacro != 0; }
bool __cdecl PHTV_GetFixRecommendBrowser() { return vFixRecommendBrowser != 0; }
bool __cdecl PHTV_GetSmartSwitchKey() { return vUseSmartSwitchKey != 0; }
bool __cdecl PHTV_GetUpperCaseFirstChar() { return vUpperCaseFirstChar != 0; }
bool __cdecl PHTV_GetUpperCaseExcludedForCurrentApp() { return vUpperCaseExcludedForCurrentApp != 0; }
bool __cdecl PHTV_GetAllowConsonantZFWJ() { return vAllowConsonantZFWJ != 0; }
bool __cdecl PHTV_GetQuickStartConsonant() { return vQuickStartConsonant != 0; }
bool __cdecl PHTV_GetQuickEndConsonant() { return vQuickEndConsonant != 0; }
bool __cdecl PHTV_GetFreeMark() { return vFreeMark != 0; }
bool __cdecl PHTV_GetRestoreOnEscape() { return vRestoreOnEscape != 0; }
int __cdecl PHTV_GetCustomEscapeKey() { return vCustomEscapeKey; }
bool __cdecl PHTV_GetPauseKeyEnabled() { return vPauseKeyEnabled != 0; }
int __cdecl PHTV_GetPauseKey() { return vPauseKey; }
int __cdecl PHTV_GetSwitchKeyStatus() { return vSwitchKeyStatus; }
int __cdecl PHTV_GetOtherLanguage() { return vOtherLanguage; }
bool __cdecl PHTV_GetRememberCode() { return vRememberCode != 0; }
bool __cdecl PHTV_GetSendKeyStepByStep() { return vSendKeyStepByStep != 0; }
bool __cdecl PHTV_GetPerformLayoutCompat() { return vPerformLayoutCompat != 0; }

bool __cdecl PHTV_IsRunning() {
    return (hKeyboardHook != NULL);
}

// ---------------------------------------------------------
// MACRO MANAGEMENT
// ---------------------------------------------------------
static std::vector<std::string> g_macroTexts;
static std::vector<std::string> g_macroContents;

static void RefreshMacroCache() {
    std::vector<std::vector<Uint32>> keys;
    std::vector<std::string> texts;
    std::vector<std::string> contents;
    getAllMacro(keys, texts, contents);
    g_macroTexts = texts;
    g_macroContents = contents;
}

bool __cdecl PHTV_MacroLoad(const wchar_t* path) {
    if (!path) return false;
    readFromFile(WStringToUtf8(path), false);
    RefreshMacroCache();
    return true;
}

bool __cdecl PHTV_MacroSave(const wchar_t* path) {
    if (!path) return false;
    saveToFile(WStringToUtf8(path));
    return true;
}

void __cdecl PHTV_MacroClear() {
    initMacroMap(nullptr, 0);
    RefreshMacroCache();
}

int __cdecl PHTV_MacroCount() {
    RefreshMacroCache();
    return (int)g_macroTexts.size();
}

bool __cdecl PHTV_MacroGetAt(int index, wchar_t* outKey, int keyCap, wchar_t* outValue, int valueCap) {
    RefreshMacroCache();
    if (index < 0 || index >= (int)g_macroTexts.size()) return false;
    CopyWString(Utf8ToWString(g_macroTexts[index]), outKey, keyCap);
    if (index < (int)g_macroContents.size()) {
        CopyWString(Utf8ToWString(g_macroContents[index]), outValue, valueCap);
    } else {
        CopyWString(L"", outValue, valueCap);
    }
    return true;
}

bool __cdecl PHTV_MacroAdd(const wchar_t* key, const wchar_t* value) {
    if (!key || !value) return false;
    bool ok = addMacro(WStringToUtf8(key), WStringToUtf8(value));
    RefreshMacroCache();
    return ok;
}

bool __cdecl PHTV_MacroDelete(const wchar_t* key) {
    if (!key) return false;
    bool ok = deleteMacro(WStringToUtf8(key));
    RefreshMacroCache();
    return ok;
}

// ---------------------------------------------------------
// APP-SPECIFIC INPUT METHOD MAPPING
// ---------------------------------------------------------
static std::vector<std::pair<std::string, int>> g_appList;

static void RefreshAppList() {
    g_appList.clear();
    std::vector<Byte> data;
    getSmartSwitchKeySaveData(data);
    if (data.size() < 2) return;
    Uint16 count = (Uint16)(data[0] | (data[1] << 8));
    size_t cursor = 2;
    for (Uint16 i = 0; i < count; i++) {
        if (cursor >= data.size()) break;
        Uint8 nameLen = data[cursor++];
        if (cursor + nameLen + 1 > data.size()) break;
        std::string name(reinterpret_cast<char*>(data.data() + cursor), nameLen);
        cursor += nameLen;
        Uint8 lang = data[cursor++];
        g_appList.push_back({name, (int)lang});
    }
}

static void EncodeAppList(const std::vector<std::pair<std::string, int>>& items, std::vector<Byte>& outData) {
    outData.clear();
    Uint16 count = (Uint16)items.size();
    outData.push_back((Byte)(count & 0xFF));
    outData.push_back((Byte)((count >> 8) & 0xFF));
    for (const auto& item : items) {
        std::string name = item.first;
        if (name.size() > 255) name = name.substr(0, 255);
        outData.push_back((Byte)name.size());
        outData.insert(outData.end(), name.begin(), name.end());
        outData.push_back((Byte)item.second);
    }
}

bool __cdecl PHTV_AppListLoad(const wchar_t* path) {
    std::vector<Byte> data;
    if (!ReadFileBinary(path, data)) return false;
    initSmartSwitchKey(data.data(), (int)data.size());
    RefreshAppList();
    return true;
}

bool __cdecl PHTV_AppListSave(const wchar_t* path) {
    std::vector<Byte> data;
    getSmartSwitchKeySaveData(data);
    return WriteFileBinary(path, data);
}

void __cdecl PHTV_AppListClear() {
    initSmartSwitchKey(nullptr, 0);
    RefreshAppList();
}

int __cdecl PHTV_AppListCount() {
    RefreshAppList();
    return (int)g_appList.size();
}

bool __cdecl PHTV_AppListGetAt(int index, wchar_t* outName, int nameCap, int* outLang) {
    RefreshAppList();
    if (index < 0 || index >= (int)g_appList.size()) return false;
    CopyWString(Utf8ToWString(g_appList[index].first), outName, nameCap);
    if (outLang) *outLang = g_appList[index].second;
    return true;
}

void __cdecl PHTV_AppListSet(const wchar_t* name, int lang) {
    if (!name) return;
    setAppInputMethodStatus(WStringToUtf8(name), lang);
    RefreshAppList();
}

bool __cdecl PHTV_AppListRemove(const wchar_t* name) {
    if (!name) return false;
    RefreshAppList();
    std::string target = WStringToUtf8(name);
    std::vector<std::pair<std::string, int>> filtered;
    for (const auto& item : g_appList) {
        if (item.first != target) {
            filtered.push_back(item);
        }
    }
    std::vector<Byte> data;
    EncodeAppList(filtered, data);
    if (data.empty()) {
        initSmartSwitchKey(nullptr, 0);
    } else {
        initSmartSwitchKey(data.data(), (int)data.size());
    }
    RefreshAppList();
    return true;
}

// ---------------------------------------------------------
// UPPERCASE EXCLUDED APPS (LOCAL LIST)
// ---------------------------------------------------------
static void EncodeUpperExcludedList(const std::vector<std::string>& items, std::vector<Byte>& outData) {
    outData.clear();
    Uint16 count = (Uint16)items.size();
    outData.push_back((Byte)(count & 0xFF));
    outData.push_back((Byte)((count >> 8) & 0xFF));
    for (const auto& nameRaw : items) {
        std::string name = nameRaw;
        if (name.size() > 255) name = name.substr(0, 255);
        outData.push_back((Byte)name.size());
        outData.insert(outData.end(), name.begin(), name.end());
    }
}

static void DecodeUpperExcludedList(const std::vector<Byte>& data, std::vector<std::string>& outItems) {
    outItems.clear();
    if (data.size() < 2) return;
    Uint16 count = (Uint16)(data[0] | (data[1] << 8));
    size_t cursor = 2;
    for (Uint16 i = 0; i < count; i++) {
        if (cursor >= data.size()) break;
        Uint8 nameLen = data[cursor++];
        if (cursor + nameLen > data.size()) break;
        std::string name(reinterpret_cast<const char*>(data.data() + cursor), nameLen);
        cursor += nameLen;
        if (!name.empty()) {
            outItems.push_back(name);
        }
    }
}

bool __cdecl PHTV_UpperExcludedLoad(const wchar_t* path) {
    std::vector<Byte> data;
    if (!ReadFileBinary(path, data)) return false;
    DecodeUpperExcludedList(data, g_upperExcludedApps);
    return true;
}

bool __cdecl PHTV_UpperExcludedSave(const wchar_t* path) {
    std::vector<Byte> data;
    EncodeUpperExcludedList(g_upperExcludedApps, data);
    return WriteFileBinary(path, data);
}

void __cdecl PHTV_UpperExcludedClear() {
    g_upperExcludedApps.clear();
    vUpperCaseExcludedForCurrentApp = 0;
}

int __cdecl PHTV_UpperExcludedCount() {
    return (int)g_upperExcludedApps.size();
}

bool __cdecl PHTV_UpperExcludedGetAt(int index, wchar_t* outName, int nameCap) {
    if (index < 0 || index >= (int)g_upperExcludedApps.size()) return false;
    CopyWString(Utf8ToWString(g_upperExcludedApps[index]), outName, nameCap);
    return true;
}

void __cdecl PHTV_UpperExcludedAdd(const wchar_t* name) {
    if (!name) return;
    std::string target = WStringToUtf8(name);
    if (target.empty()) return;
    for (const auto& existing : g_upperExcludedApps) {
        if (_stricmp(existing.c_str(), target.c_str()) == 0) {
            return;
        }
    }
    g_upperExcludedApps.push_back(target);
}

bool __cdecl PHTV_UpperExcludedRemove(const wchar_t* name) {
    if (!name) return false;
    std::string target = WStringToUtf8(name);
    auto it = std::remove_if(g_upperExcludedApps.begin(), g_upperExcludedApps.end(), [&](const std::string& item) {
        return _stricmp(item.c_str(), target.c_str()) == 0;
    });
    if (it != g_upperExcludedApps.end()) {
        g_upperExcludedApps.erase(it, g_upperExcludedApps.end());
        return true;
    }
    return false;
}

bool __cdecl PHTV_QuickConvertClipboard(int fromCode, int toCode) {
    if (fromCode < 0 || fromCode > 4 || toCode < 0 || toCode > 4) return false;
    std::wstring text;
    if (!GetClipboardText(text)) return false;
    Uint8 oldFrom = convertToolFromCode;
    Uint8 oldTo = convertToolToCode;
    convertToolFromCode = (Uint8)fromCode;
    convertToolToCode = (Uint8)toCode;
    std::string converted = convertUtil(WStringToUtf8(text));
    convertToolFromCode = oldFrom;
    convertToolToCode = oldTo;
    return SetClipboardText(Utf8ToWString(converted));
}
