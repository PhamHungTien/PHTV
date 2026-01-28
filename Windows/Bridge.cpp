#include "Bridge.h"
#include <windows.h>
#include <shlwapi.h>
#include <string>
#include <vector>
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
        SendUnicodeString(chars);
    }
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

        // Smart switch key per app (optional)
        if (vUseSmartSwitchKey) {
            HWND fg = GetForegroundWindow();
            if (fg) {
                DWORD pid = 0;
                GetWindowThreadProcessId(fg, &pid);
                if (pid != 0) {
                    HANDLE hProc = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_VM_READ, FALSE, pid);
                    if (hProc) {
                        wchar_t path[MAX_PATH];
                        DWORD size = MAX_PATH;
                        if (QueryFullProcessImageNameW(hProc, 0, path, &size)) {
                            std::wstring wpath(path);
                            size_t pos = wpath.find_last_of(L\"\\\\/\");
                            std::wstring exe = (pos == std::wstring::npos) ? wpath : wpath.substr(pos + 1);
                            std::string exeUtf8 = WStringToUtf8(exe);
                            int status = getAppInputMethodStatus(exeUtf8, vLanguage);
                            if (status != -1 && status != vLanguage) {
                                vLanguage = status;
                            }
                        }
                        CloseHandle(hProc);
                    }
                }
            }
        }

        // Access global config directly (vLanguage is extern in Engine)
        if (vLanguage == 1) {
            vKeyEventState state;
            if (wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN) state = vKeyEventState::KeyDown;
            else if (wParam == WM_KEYUP || wParam == WM_SYSKEYUP) state = vKeyEventState::KeyUp;
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
void __cdecl PHTV_Init() {
    vKeyInit();
    PHTVConfig::Shared().Load();

    std::wstring baseDir = GetExeDir();
    std::wstring viDictPath = baseDir + L"\\Resources\\Dictionaries\\vi_dict.bin";
    std::wstring enDictPath = baseDir + L"\\Resources\\Dictionaries\\en_dict.bin";
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
