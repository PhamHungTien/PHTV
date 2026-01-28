#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shellapi.h>
#include <shlwapi.h>
#include <shlobj.h>
#include <string>
#include <vector>

#pragma comment(lib, "shlwapi.lib")

#include "resource.h"
#include "win32.h"
#include "Engine.h"
#include "EnglishWordDetector.h"
#include "../Config/PHTVConfig.h"

#define PHTV_INJECTED_SIGNATURE 0x99887766
#define WM_TRAYMESSAGE (WM_USER + 1)
#define TRAY_ICON_UID 100
#define TRAY_RETRY_TIMER 1

static HINSTANCE gInstance = NULL;
static HWND gTrayWnd = NULL;
static NOTIFYICONDATA gNid = {0};
static HMENU gTrayMenu = NULL;
static HMENU gMenuTyping = NULL;
static HMENU gMenuInputMethod = NULL;
static HMENU gMenuCodeTable = NULL;
static HMENU gMenuFeatures = NULL;
static UINT gTaskbarCreatedMsg = 0;
static int gTrayRetryCount = 0;

static HHOOK gKeyboardHook = NULL;
static HHOOK gMouseHook = NULL;
static HWINEVENTHOOK gWinEventHook = NULL;
static DWORD gSelfPid = 0;

static std::wstring gAppDataDir;
static std::wstring gSmartSwitchPath;

static void EnsureAppData();
static void LoadSmartSwitchData();
static void SaveSmartSwitchData();
static std::string GetForegroundExeName();
static void UpdateTrayIcon();
static void CreateTrayMenu();
static void UpdateMenuChecks();
static bool AddTrayIcon();
static void RemoveTrayIcon();
static void InitEngine();
static void OpenControlPanel();
static void ProcessEngineOutput();
static void SendBackspace(int count);
static void SendUnicodeString(const std::vector<unsigned int>& charCodes);

LRESULT CALLBACK TrayWndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam);
LRESULT CALLBACK KeyboardProc(int nCode, WPARAM wParam, LPARAM lParam);
LRESULT CALLBACK MouseProc(int nCode, WPARAM wParam, LPARAM lParam);
VOID CALLBACK WinEventProc(HWINEVENTHOOK hWinEventHook, DWORD dwEvent, HWND hwnd, LONG idObject, LONG idChild, DWORD dwEventThread, DWORD dwmsEventTime);

static void EnsureAppData() {
    if (!gAppDataDir.empty()) return;
    wchar_t path[MAX_PATH] = {0};
    if (SHGetFolderPathW(NULL, CSIDL_APPDATA, NULL, SHGFP_TYPE_CURRENT, path) != S_OK) return;
    PathAppendW(path, L"PHTV");
    CreateDirectoryW(path, NULL);
    gAppDataDir = path;
    gSmartSwitchPath = gAppDataDir + L"\\apps.dat";
}

static bool ReadFileBinary(const std::wstring& path, std::vector<Byte>& outData) {
    outData.clear();
    HANDLE hFile = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (hFile == INVALID_HANDLE_VALUE) return false;
    DWORD size = GetFileSize(hFile, NULL);
    if (size == INVALID_FILE_SIZE || size == 0) {
        CloseHandle(hFile);
        return false;
    }
    outData.resize(size);
    DWORD read = 0;
    BOOL ok = ReadFile(hFile, outData.data(), size, &read, NULL);
    CloseHandle(hFile);
    return ok && read == size;
}

static bool WriteFileBinary(const std::wstring& path, const std::vector<Byte>& data) {
    HANDLE hFile = CreateFileW(path.c_str(), GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (hFile == INVALID_HANDLE_VALUE) return false;
    DWORD written = 0;
    BOOL ok = TRUE;
    if (!data.empty()) {
        ok = WriteFile(hFile, data.data(), (DWORD)data.size(), &written, NULL);
    }
    CloseHandle(hFile);
    return ok && written == data.size();
}

static void LoadSmartSwitchData() {
    EnsureAppData();
    std::vector<Byte> data;
    if (ReadFileBinary(gSmartSwitchPath, data)) {
        initSmartSwitchKey(data.data(), (int)data.size());
    }
}

static void SaveSmartSwitchData() {
    EnsureAppData();
    std::vector<Byte> data;
    getSmartSwitchKeySaveData(data);
    WriteFileBinary(gSmartSwitchPath, data);
}

static std::string WStringToUtf8(const std::wstring& wstr) {
    if (wstr.empty()) return std::string();
    int size_needed = WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), (int)wstr.size(), NULL, 0, NULL, NULL);
    std::string strTo(size_needed, 0);
    WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), (int)wstr.size(), &strTo[0], size_needed, NULL, NULL);
    return strTo;
}

static std::string GetForegroundExeName() {
    HWND fg = GetForegroundWindow();
    if (!fg) return std::string();
    DWORD pid = 0;
    GetWindowThreadProcessId(fg, &pid);
    if (!pid || pid == gSelfPid) return std::string();
    HANDLE hProc = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
    if (!hProc) return std::string();
    wchar_t path[MAX_PATH];
    DWORD size = MAX_PATH;
    std::string exe;
    if (QueryFullProcessImageNameW(hProc, 0, path, &size)) {
        std::wstring wpath(path);
        size_t pos = wpath.find_last_of(L"\\/");
        std::wstring name = (pos == std::wstring::npos) ? wpath : wpath.substr(pos + 1);
        exe = WStringToUtf8(name);
    }
    CloseHandle(hProc);
    return exe;
}

static void InitEngine() {
    wchar_t exePath[MAX_PATH];
    GetModuleFileNameW(NULL, exePath, MAX_PATH);
    PathRemoveFileSpecW(exePath);
    std::wstring baseDir = exePath;
    std::wstring viDictPath = baseDir + L"\\Resources\\Dictionaries\\vi_dict.bin";
    std::wstring enDictPath = baseDir + L"\\Resources\\Dictionaries\\en_dict.bin";

    initVietnameseDictionary(WStringToUtf8(viDictPath));
    initEnglishDictionary(WStringToUtf8(enDictPath));
    vKeyInit();
    PHTVConfig::Shared().Load();
    LoadSmartSwitchData();
}

static void UpdateTrayIcon() {
    int iconId = vLanguage ? IDI_ICON_VIE : IDI_ICON_ENG;
    int cx = GetSystemMetrics(SM_CXSMICON);
    int cy = GetSystemMetrics(SM_CYSMICON);
    gNid.hIcon = (HICON)LoadImageW(gInstance, MAKEINTRESOURCE(iconId), IMAGE_ICON, cx, cy, LR_DEFAULTCOLOR | LR_SHARED);
    if (!gNid.hIcon) gNid.hIcon = LoadIcon(gInstance, MAKEINTRESOURCE(IDI_APP_ICON));
    if (!gNid.hIcon) gNid.hIcon = LoadIcon(NULL, IDI_APPLICATION);
    wcscpy_s(gNid.szTip, vLanguage ? L"PHTV - VI" : L"PHTV - EN");
    Shell_NotifyIcon(NIM_MODIFY, &gNid);
}

static void CreateTrayMenu() {
    if (gTrayMenu) return;
    gTrayMenu = CreatePopupMenu();
    AppendMenuW(gTrayMenu, MF_STRING, IDM_TOGGLE_LANG, L"B\u1EADt Ti\u1EBFng Vi\u1EC7t");
    AppendMenuW(gTrayMenu, MF_STRING, IDM_OPEN_CONTROL_PANEL, L"B\u1EA3ng \u0111i\u1EC1u khi\u1EC3n...");
    AppendMenuW(gTrayMenu, MF_SEPARATOR, 0, NULL);

    gMenuTyping = CreatePopupMenu();
    gMenuInputMethod = CreatePopupMenu();
    AppendMenuW(gMenuInputMethod, MF_STRING, IDM_INPUT_TELEX, L"Telex");
    AppendMenuW(gMenuInputMethod, MF_STRING, IDM_INPUT_VNI, L"VNI");
    AppendMenuW(gMenuTyping, MF_POPUP, (UINT_PTR)gMenuInputMethod, L"Ph\u01B0\u01A1ng ph\u00E1p g\u00F5");

    gMenuCodeTable = CreatePopupMenu();
    AppendMenuW(gMenuCodeTable, MF_STRING, IDM_CODE_UNICODE, L"Unicode");
    AppendMenuW(gMenuCodeTable, MF_STRING, IDM_CODE_TCVN3, L"TCVN3 (ABC)");
    AppendMenuW(gMenuCodeTable, MF_STRING, IDM_CODE_VNIWIN, L"VNI Windows");
    AppendMenuW(gMenuTyping, MF_POPUP, (UINT_PTR)gMenuCodeTable, L"B\u1EA3ng m\u00E3");

    AppendMenuW(gMenuTyping, MF_SEPARATOR, 0, NULL);
    AppendMenuW(gMenuTyping, MF_STRING, IDM_OPT_QUICK_TELEX, L"G\u00F5 nhanh (Quick Telex)");
    AppendMenuW(gMenuTyping, MF_STRING, IDM_OPT_UPPER_FIRST, L"Vi\u1EBFt hoa \u0111\u1EA7u c\u00E2u");
    AppendMenuW(gMenuTyping, MF_STRING, IDM_OPT_ALLOW_ZFWJ, L"Ph\u1EE5 \u00E2m Z, F, W, J");
    AppendMenuW(gMenuTyping, MF_STRING, IDM_OPT_QUICK_START, L"Ph\u1EE5 \u00E2m \u0111\u1EA7u nhanh");
    AppendMenuW(gMenuTyping, MF_STRING, IDM_OPT_QUICK_END, L"Ph\u1EE5 \u00E2m cu\u1ED1i nhanh");
    AppendMenuW(gMenuTyping, MF_SEPARATOR, 0, NULL);
    AppendMenuW(gMenuTyping, MF_STRING, IDM_OPT_CHECK_SPELL, L"Ki\u1EC3m tra ch\u00EDnh t\u1EA3");
    AppendMenuW(gMenuTyping, MF_STRING, IDM_OPT_MODERN_ORTHO, L"Ch\u00EDnh t\u1EA3 m\u1EDBi (o\u00E0, u\u00FD)");

    AppendMenuW(gTrayMenu, MF_POPUP, (UINT_PTR)gMenuTyping, L"B\u1ED9 g\u00F5");

    gMenuFeatures = CreatePopupMenu();
    AppendMenuW(gMenuFeatures, MF_STRING, IDM_FEAT_AUTO_RESTORE, L"T\u1EF1 \u0111\u1ED9ng kh\u00F4i ph\u1EE5c ti\u1EBFng Anh");
    AppendMenuW(gMenuFeatures, MF_SEPARATOR, 0, NULL);
    AppendMenuW(gMenuFeatures, MF_STRING, IDM_FEAT_USE_MACRO, L"B\u1EADt g\u00F5 t\u1EAFt");
    AppendMenuW(gMenuFeatures, MF_STRING, IDM_FEAT_MACRO_IN_EN, L"G\u00F5 t\u1EAFt khi \u1EDF ch\u1EBF \u0111\u1ED9 Anh");
    AppendMenuW(gMenuFeatures, MF_STRING, IDM_FEAT_AUTO_CAPS_MACRO, L"T\u1EF1 \u0111\u1ED9ng vi\u1EBFt hoa macro");
    AppendMenuW(gMenuFeatures, MF_SEPARATOR, 0, NULL);
    AppendMenuW(gMenuFeatures, MF_STRING, IDM_FEAT_SMART_SWITCH, L"Chuy\u1EC3n th\u00F4ng minh theo \u1EE9ng d\u1EE5ng");
    AppendMenuW(gMenuFeatures, MF_STRING, IDM_FEAT_REMEMBER_CODE, L"Nh\u1EDB b\u1EA3ng m\u00E3 theo \u1EE9ng d\u1EE5ng");
    AppendMenuW(gMenuFeatures, MF_SEPARATOR, 0, NULL);
    AppendMenuW(gMenuFeatures, MF_STRING, IDM_FEAT_RESTORE_ON_ESC, L"Kh\u00F4i ph\u1EE5c khi nh\u1EA5n Esc");
    AppendMenuW(gMenuFeatures, MF_STRING, IDM_FEAT_PAUSE_KEY, L"T\u1EA1m d\u1EEBng khi gi\u1EEF ph\u00EDm");
    AppendMenuW(gTrayMenu, MF_POPUP, (UINT_PTR)gMenuFeatures, L"T\u00EDnh n\u0103ng");

    AppendMenuW(gTrayMenu, MF_SEPARATOR, 0, NULL);
    AppendMenuW(gTrayMenu, MF_STRING, IDM_EXIT, L"Tho\u00E1t PHTV");

    UpdateMenuChecks();
}

static void UpdateMenuChecks() {
    if (!gTrayMenu) return;
    CheckMenuItem(gTrayMenu, IDM_TOGGLE_LANG, MF_BYCOMMAND | (vLanguage ? MF_CHECKED : MF_UNCHECKED));

    if (gMenuInputMethod) {
        CheckMenuItem(gMenuInputMethod, IDM_INPUT_TELEX, MF_BYCOMMAND | (vInputType == 0 ? MF_CHECKED : MF_UNCHECKED));
        CheckMenuItem(gMenuInputMethod, IDM_INPUT_VNI, MF_BYCOMMAND | (vInputType == 1 ? MF_CHECKED : MF_UNCHECKED));
    }
    if (gMenuCodeTable) {
        CheckMenuItem(gMenuCodeTable, IDM_CODE_UNICODE, MF_BYCOMMAND | (vCodeTable == 0 ? MF_CHECKED : MF_UNCHECKED));
        CheckMenuItem(gMenuCodeTable, IDM_CODE_TCVN3, MF_BYCOMMAND | (vCodeTable == 1 ? MF_CHECKED : MF_UNCHECKED));
        CheckMenuItem(gMenuCodeTable, IDM_CODE_VNIWIN, MF_BYCOMMAND | (vCodeTable == 2 ? MF_CHECKED : MF_UNCHECKED));
    }

    if (gMenuTyping) {
        CheckMenuItem(gMenuTyping, IDM_OPT_QUICK_TELEX, MF_BYCOMMAND | (vQuickTelex ? MF_CHECKED : MF_UNCHECKED));
        CheckMenuItem(gMenuTyping, IDM_OPT_UPPER_FIRST, MF_BYCOMMAND | (vUpperCaseFirstChar ? MF_CHECKED : MF_UNCHECKED));
        CheckMenuItem(gMenuTyping, IDM_OPT_ALLOW_ZFWJ, MF_BYCOMMAND | (vAllowConsonantZFWJ ? MF_CHECKED : MF_UNCHECKED));
        CheckMenuItem(gMenuTyping, IDM_OPT_QUICK_START, MF_BYCOMMAND | (vQuickStartConsonant ? MF_CHECKED : MF_UNCHECKED));
        CheckMenuItem(gMenuTyping, IDM_OPT_QUICK_END, MF_BYCOMMAND | (vQuickEndConsonant ? MF_CHECKED : MF_UNCHECKED));
        CheckMenuItem(gMenuTyping, IDM_OPT_CHECK_SPELL, MF_BYCOMMAND | (vCheckSpelling ? MF_CHECKED : MF_UNCHECKED));
        CheckMenuItem(gMenuTyping, IDM_OPT_MODERN_ORTHO, MF_BYCOMMAND | (vUseModernOrthography ? MF_CHECKED : MF_UNCHECKED));
    }

    if (gMenuFeatures) {
        CheckMenuItem(gMenuFeatures, IDM_FEAT_AUTO_RESTORE, MF_BYCOMMAND | (vAutoRestoreEnglishWord ? MF_CHECKED : MF_UNCHECKED));
        CheckMenuItem(gMenuFeatures, IDM_FEAT_USE_MACRO, MF_BYCOMMAND | (vUseMacro ? MF_CHECKED : MF_UNCHECKED));
        CheckMenuItem(gMenuFeatures, IDM_FEAT_MACRO_IN_EN, MF_BYCOMMAND | (vUseMacroInEnglishMode ? MF_CHECKED : MF_UNCHECKED));
        CheckMenuItem(gMenuFeatures, IDM_FEAT_AUTO_CAPS_MACRO, MF_BYCOMMAND | (vAutoCapsMacro ? MF_CHECKED : MF_UNCHECKED));
        CheckMenuItem(gMenuFeatures, IDM_FEAT_SMART_SWITCH, MF_BYCOMMAND | (vUseSmartSwitchKey ? MF_CHECKED : MF_UNCHECKED));
        CheckMenuItem(gMenuFeatures, IDM_FEAT_REMEMBER_CODE, MF_BYCOMMAND | (vRememberCode ? MF_CHECKED : MF_UNCHECKED));
        CheckMenuItem(gMenuFeatures, IDM_FEAT_RESTORE_ON_ESC, MF_BYCOMMAND | (vRestoreOnEscape ? MF_CHECKED : MF_UNCHECKED));
        CheckMenuItem(gMenuFeatures, IDM_FEAT_PAUSE_KEY, MF_BYCOMMAND | (vPauseKeyEnabled ? MF_CHECKED : MF_UNCHECKED));
    }
}

static bool AddTrayIcon() {
    CreateTrayMenu();

    gNid.cbSize = sizeof(NOTIFYICONDATA);
    gNid.hWnd = gTrayWnd;
    gNid.uID = TRAY_ICON_UID;
    gNid.uCallbackMessage = WM_TRAYMESSAGE;
    gNid.uVersion = NOTIFYICON_VERSION;
    gNid.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
    UpdateTrayIcon();

    const int maxRetries = 5;
    for (int attempt = 0; attempt < maxRetries; ++attempt) {
        if (Shell_NotifyIcon(NIM_ADD, &gNid)) {
            Shell_NotifyIcon(NIM_SETVERSION, &gNid);
            return true;
        }
        Sleep(1000);
    }
    return false;
}

static void RemoveTrayIcon() {
    Shell_NotifyIcon(NIM_DELETE, &gNid);
}

static void OpenControlPanel() {
    PHTVConfig::Shared().Save();
    wchar_t exePath[MAX_PATH];
    GetModuleFileNameW(NULL, exePath, MAX_PATH);
    PathRemoveFileSpecW(exePath);
    std::wstring baseDir = exePath;

    std::wstring uiExe = baseDir + L"\\PHTV.UI.exe";
    if (GetFileAttributesW(uiExe.c_str()) != INVALID_FILE_ATTRIBUTES) {
        ShellExecuteW(NULL, L"open", uiExe.c_str(), NULL, baseDir.c_str(), SW_SHOWNORMAL);
        return;
    }

    std::wstring iniPath = PHTVConfig::Shared().GetConfigPath();
    ShellExecuteW(NULL, L"open", iniPath.c_str(), NULL, NULL, SW_SHOWNORMAL);
}

static void ProcessEngineOutput() {
    extern vKeyHookState HookState;
    if (HookState.backspaceCount > 0) SendBackspace(HookState.backspaceCount);
    if (HookState.newCharCount > 0) {
        std::vector<unsigned int> chars;
        for (int i = HookState.newCharCount - 1; i >= 0; i--) {
            chars.push_back(HookState.charData[i]);
        }
        SendUnicodeString(chars);
    }
}

static void SendBackspace(int count) {
    if (count <= 0) return;
    std::vector<INPUT> inputs;
    for (int i = 0; i < count; ++i) {
        INPUT down = {0};
        down.type = INPUT_KEYBOARD;
        down.ki.wVk = VK_BACK;
        down.ki.dwExtraInfo = PHTV_INJECTED_SIGNATURE;

        INPUT up = down;
        up.ki.dwFlags = KEYEVENTF_KEYUP;

        inputs.push_back(down);
        inputs.push_back(up);
    }
    SendInput((UINT)inputs.size(), inputs.data(), sizeof(INPUT));
}

static void SendUnicodeString(const std::vector<unsigned int>& charCodes) {
    if (charCodes.empty()) return;
    std::vector<INPUT> inputs;
    const unsigned int CAPS_MASK_VAL = 0x10000;

    for (unsigned int code : charCodes) {
        unsigned int finalChar = code & 0xFFFF;
        bool isUpperCase = (code & CAPS_MASK_VAL) != 0;

        if (finalChar >= 'A' && finalChar <= 'Z') {
            if (!isUpperCase) finalChar = tolower(finalChar);
        }

        INPUT down = {0};
        down.type = INPUT_KEYBOARD;
        down.ki.wScan = (WORD)finalChar;
        down.ki.dwFlags = KEYEVENTF_UNICODE;
        down.ki.dwExtraInfo = PHTV_INJECTED_SIGNATURE;

        INPUT up = down;
        up.ki.dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;

        inputs.push_back(down);
        inputs.push_back(up);
    }
    SendInput((UINT)inputs.size(), inputs.data(), sizeof(INPUT));
}

LRESULT CALLBACK KeyboardProc(int nCode, WPARAM wParam, LPARAM lParam) {
    if (nCode == HC_ACTION) {
        KBDLLHOOKSTRUCT* pKbd = (KBDLLHOOKSTRUCT*)lParam;
        if (pKbd->dwExtraInfo == PHTV_INJECTED_SIGNATURE) {
            return CallNextHookEx(gKeyboardHook, nCode, wParam, lParam);
        }

        if (vLanguage == 1) {
            vKeyEventState state;
            if (wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN) state = vKeyEventState::KeyDown;
            else if (wParam == WM_KEYUP || wParam == WM_SYSKEYUP) state = vKeyEventState::KeyUp;
            else return CallNextHookEx(gKeyboardHook, nCode, wParam, lParam);

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
                    return 1;
                }
            }
        }
    }
    return CallNextHookEx(gKeyboardHook, nCode, wParam, lParam);
}

LRESULT CALLBACK MouseProc(int nCode, WPARAM wParam, LPARAM lParam) {
    if (nCode == HC_ACTION) {
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
            vKeyHandleEvent(vKeyEvent::Mouse, vKeyEventState::MouseDown, 0);
            break;
        }
    }
    return CallNextHookEx(gMouseHook, nCode, wParam, lParam);
}

VOID CALLBACK WinEventProc(HWINEVENTHOOK hWinEventHook, DWORD dwEvent, HWND hwnd, LONG idObject, LONG idChild, DWORD dwEventThread, DWORD dwmsEventTime) {
    if (!vUseSmartSwitchKey) return;
    std::string exe = GetForegroundExeName();
    if (exe.empty() || _stricmp(exe.c_str(), "explorer.exe") == 0) return;

    int status = getAppInputMethodStatus(exe, vLanguage);
    if (status != -1 && status != vLanguage) {
        vLanguage = status;
        UpdateTrayIcon();
        startNewSession();
    } else if (status == -1) {
        SaveSmartSwitchData();
    }
}

LRESULT CALLBACK TrayWndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam) {
    switch (message) {
    case WM_CREATE:
        gTaskbarCreatedMsg = RegisterWindowMessageW(L"TaskbarCreated");
        break;
    case WM_TRAYMESSAGE:
        if (lParam == WM_LBUTTONUP) {
            vLanguage = vLanguage ? 0 : 1;
            PHTVConfig::Shared().Save();
            UpdateTrayIcon();
            UpdateMenuChecks();
            startNewSession();
        } else if (lParam == WM_RBUTTONUP) {
            POINT pt;
            GetCursorPos(&pt);
            SetForegroundWindow(hWnd);

            UpdateMenuChecks();

            TrackPopupMenu(gTrayMenu, TPM_RIGHTBUTTON | TPM_BOTTOMALIGN, pt.x, pt.y, 0, hWnd, NULL);
            PostMessage(hWnd, WM_NULL, 0, 0);
        }
        break;
    default:
        if (message == gTaskbarCreatedMsg) {
            AddTrayIcon();
            return 0;
        }
        break;
    case WM_COMMAND:
        switch (LOWORD(wParam)) {
        case IDM_TOGGLE_LANG:
            vLanguage = vLanguage ? 0 : 1;
            PHTVConfig::Shared().Save();
            UpdateTrayIcon();
            UpdateMenuChecks();
            startNewSession();
            break;
        case IDM_OPEN_CONTROL_PANEL:
            OpenControlPanel();
            break;
        case IDM_INPUT_TELEX:
            vInputType = 0;
            PHTVConfig::Shared().Save();
            UpdateMenuChecks();
            startNewSession();
            break;
        case IDM_INPUT_VNI:
            vInputType = 1;
            PHTVConfig::Shared().Save();
            UpdateMenuChecks();
            startNewSession();
            break;
        case IDM_CODE_UNICODE:
            vCodeTable = 0;
            PHTVConfig::Shared().Save();
            UpdateMenuChecks();
            startNewSession();
            break;
        case IDM_CODE_TCVN3:
            vCodeTable = 1;
            PHTVConfig::Shared().Save();
            UpdateMenuChecks();
            startNewSession();
            break;
        case IDM_CODE_VNIWIN:
            vCodeTable = 2;
            PHTVConfig::Shared().Save();
            UpdateMenuChecks();
            startNewSession();
            break;
        case IDM_OPT_QUICK_TELEX:
            vQuickTelex = vQuickTelex ? 0 : 1;
            PHTVConfig::Shared().Save();
            UpdateMenuChecks();
            break;
        case IDM_OPT_UPPER_FIRST:
            vUpperCaseFirstChar = vUpperCaseFirstChar ? 0 : 1;
            PHTVConfig::Shared().Save();
            UpdateMenuChecks();
            break;
        case IDM_OPT_ALLOW_ZFWJ:
            vAllowConsonantZFWJ = vAllowConsonantZFWJ ? 0 : 1;
            PHTVConfig::Shared().Save();
            UpdateMenuChecks();
            break;
        case IDM_OPT_QUICK_START:
            vQuickStartConsonant = vQuickStartConsonant ? 0 : 1;
            PHTVConfig::Shared().Save();
            UpdateMenuChecks();
            break;
        case IDM_OPT_QUICK_END:
            vQuickEndConsonant = vQuickEndConsonant ? 0 : 1;
            PHTVConfig::Shared().Save();
            UpdateMenuChecks();
            break;
        case IDM_OPT_CHECK_SPELL:
            vCheckSpelling = vCheckSpelling ? 0 : 1;
            PHTVConfig::Shared().Save();
            UpdateMenuChecks();
            break;
        case IDM_OPT_MODERN_ORTHO:
            vUseModernOrthography = vUseModernOrthography ? 0 : 1;
            PHTVConfig::Shared().Save();
            UpdateMenuChecks();
            startNewSession();
            break;
        case IDM_FEAT_AUTO_RESTORE:
            vAutoRestoreEnglishWord = vAutoRestoreEnglishWord ? 0 : 1;
            PHTVConfig::Shared().Save();
            UpdateMenuChecks();
            break;
        case IDM_FEAT_USE_MACRO:
            vUseMacro = vUseMacro ? 0 : 1;
            PHTVConfig::Shared().Save();
            UpdateMenuChecks();
            break;
        case IDM_FEAT_MACRO_IN_EN:
            vUseMacroInEnglishMode = vUseMacroInEnglishMode ? 0 : 1;
            PHTVConfig::Shared().Save();
            UpdateMenuChecks();
            break;
        case IDM_FEAT_AUTO_CAPS_MACRO:
            vAutoCapsMacro = vAutoCapsMacro ? 0 : 1;
            PHTVConfig::Shared().Save();
            UpdateMenuChecks();
            break;
        case IDM_FEAT_SMART_SWITCH:
            vUseSmartSwitchKey = vUseSmartSwitchKey ? 0 : 1;
            PHTVConfig::Shared().Save();
            UpdateMenuChecks();
            break;
        case IDM_FEAT_REMEMBER_CODE:
            vRememberCode = vRememberCode ? 0 : 1;
            PHTVConfig::Shared().Save();
            UpdateMenuChecks();
            break;
        case IDM_FEAT_RESTORE_ON_ESC:
            vRestoreOnEscape = vRestoreOnEscape ? 0 : 1;
            PHTVConfig::Shared().Save();
            UpdateMenuChecks();
            break;
        case IDM_FEAT_PAUSE_KEY:
            vPauseKeyEnabled = vPauseKeyEnabled ? 0 : 1;
            PHTVConfig::Shared().Save();
            UpdateMenuChecks();
            break;
        case IDM_EXIT:
            DestroyWindow(hWnd);
            break;
        }
        break;
    case WM_TIMER:
        if (wParam == TRAY_RETRY_TIMER) {
            if (AddTrayIcon() || gTrayRetryCount >= 5) {
                KillTimer(hWnd, TRAY_RETRY_TIMER);
            } else {
                gTrayRetryCount++;
            }
        }
        break;
    case WM_DESTROY:
        RemoveTrayIcon();
        PostQuitMessage(0);
        break;
    }
    return DefWindowProc(hWnd, message, wParam, lParam);
}

static HWND CreateTrayWindow(const HINSTANCE& hInst) {
    const wchar_t* className = L"PHTVTrayWindow";
    WNDCLASSEXW wcex = {0};
    wcex.cbSize = sizeof(WNDCLASSEX);
    wcex.lpfnWndProc = TrayWndProc;
    wcex.hInstance = hInst;
    wcex.lpszClassName = className;
    wcex.hIcon = LoadIcon(hInst, MAKEINTRESOURCE(IDI_APP_ICON));

    RegisterClassExW(&wcex);
    HWND hWnd = CreateWindowW(className, L"PHTV", WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, 0, CW_USEDEFAULT, 0, NULL, NULL, hInst, NULL);
    if (!hWnd) return NULL;
    ShowWindow(hWnd, SW_HIDE);
    UpdateWindow(hWnd);
    return hWnd;
}

int APIENTRY wWinMain(_In_ HINSTANCE hInstance,
                     _In_opt_ HINSTANCE hPrevInstance,
                     _In_ LPWSTR    lpCmdLine,
                     _In_ int       nCmdShow) {
    UNREFERENCED_PARAMETER(hPrevInstance);
    UNREFERENCED_PARAMETER(lpCmdLine);
    UNREFERENCED_PARAMETER(nCmdShow);

    gInstance = hInstance;
    gSelfPid = GetCurrentProcessId();

    InitEngine();

    gTrayWnd = CreateTrayWindow(hInstance);
    if (!gTrayWnd) return 1;

    if (!AddTrayIcon()) {
        SetTimer(gTrayWnd, TRAY_RETRY_TIMER, 3000, NULL);
    }

    gKeyboardHook = SetWindowsHookEx(WH_KEYBOARD_LL, KeyboardProc, hInstance, 0);
    gMouseHook = SetWindowsHookEx(WH_MOUSE_LL, MouseProc, hInstance, 0);
    gWinEventHook = SetWinEventHook(EVENT_SYSTEM_FOREGROUND, EVENT_SYSTEM_FOREGROUND, NULL, WinEventProc, 0, 0, WINEVENT_OUTOFCONTEXT | WINEVENT_SKIPOWNPROCESS);

    MSG msg;
    while (GetMessage(&msg, NULL, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    if (gWinEventHook) UnhookWinEvent(gWinEventHook);
    if (gMouseHook) UnhookWindowsHookEx(gMouseHook);
    if (gKeyboardHook) UnhookWindowsHookEx(gKeyboardHook);
    return (int)msg.wParam;
}
