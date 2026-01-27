#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shellapi.h>
#include <shlwapi.h>
#include <commctrl.h>
#include <string>
#include <vector>
#include <codecvt>

#pragma comment(lib, "shlwapi.lib")
#pragma comment(lib, "comctl32.lib")

// Enable Visual Styles
#pragma comment(linker,"\"/manifestdependency:type='win32' \
name='Microsoft.Windows.Common-Controls' version='6.0.0.0' \
processorArchitecture='*' publicKeyToken='6595b64144ccf1df' language='*'\"")

#include "resource.h"
#include "../Platforms/win32.h"
#include "../Engine/Engine.h"
#include "../Config/PHTVConfig.h"
#include "../Engine/EnglishWordDetector.h"

// Constants
#define PHTV_INJECTED_SIGNATURE 0x99887766 
#define PHTV_MUTEX_NAME L"Local\\PHTV_Instance_Mutex"

// Global Variables
HINSTANCE hInst;
HHOOK hKeyboardHook;
NOTIFYICONDATA nid;
HWND hHiddenWnd;
HANDLE hMutex;

// Forward Declarations
LRESULT CALLBACK WndProc(HWND, UINT, WPARAM, LPARAM);
LRESULT CALLBACK LowLevelKeyboardProc(int, WPARAM, LPARAM);
INT_PTR CALLBACK SettingsDlgProc(HWND hDlg, UINT message, WPARAM wParam, LPARAM lParam);
void InitTrayIcon(HWND hWnd);
void RemoveTrayIcon();
void UpdateTrayIcon();

// Engine Integration Helpers
void ProcessEngineOutput();
void SendUnicodeString(const std::vector<unsigned int>& charCodes);
void SendBackspace(int count);

std::string WStringToString(const std::wstring& wstr) {
    if (wstr.empty()) return std::string();
    int size_needed = WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), NULL, 0, NULL, NULL);
    std::string strTo(size_needed, 0);
    WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), &strTo[0], size_needed, NULL, NULL);
    return strTo;
}

int APIENTRY wWinMain(_In_ HINSTANCE hInstance,
                     _In_opt_ HINSTANCE hPrevInstance,
                     _In_ LPWSTR    lpCmdLine,
                     _In_ int       nCmdShow)
{
    UNREFERENCED_PARAMETER(hPrevInstance);
    UNREFERENCED_PARAMETER(lpCmdLine);

    hInst = hInstance;

    // 1. Single Instance Check
    hMutex = CreateMutexW(NULL, TRUE, PHTV_MUTEX_NAME);
    if (GetLastError() == ERROR_ALREADY_EXISTS) {
        // App already running
        return 0;
    }

    // 2. Setup Dictionaries
    wchar_t exePath[MAX_PATH];
    GetModuleFileNameW(NULL, exePath, MAX_PATH);
    PathRemoveFileSpecW(exePath); 

    std::wstring baseDir = exePath;
    std::wstring viDictPath = baseDir + L"\\Resources\\Dictionaries\\vi_dict.bin";
    std::wstring enDictPath = baseDir + L"\\Resources\\Dictionaries\\en_dict.bin";

    initVietnameseDictionary(WStringToString(viDictPath));
    initEnglishDictionary(WStringToString(enDictPath));

    // 3. Initialize Engine & Config
    vKeyInit();
    PHTVConfig::Shared().Load();

    // 4. Create Window
    WNDCLASSEXW wcex = {0};
    wcex.cbSize = sizeof(WNDCLASSEX);
    wcex.style          = CS_HREDRAW | CS_VREDRAW;
    wcex.lpfnWndProc    = WndProc;
    wcex.hInstance      = hInstance;
    wcex.hIcon          = LoadIcon(hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
    wcex.hCursor        = LoadCursor(nullptr, IDC_ARROW);
    wcex.hbrBackground  = (HBRUSH)(COLOR_WINDOW+1);
    wcex.lpszClassName  = L"PHTVHiddenWindow";
    wcex.hIconSm        = LoadIcon(wcex.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));

    RegisterClassExW(&wcex);

    hHiddenWnd = CreateWindowW(L"PHTVHiddenWindow", L"PHTV", WS_OVERLAPPEDWINDOW,
                          CW_USEDEFAULT, 0, CW_USEDEFAULT, 0, nullptr, nullptr, hInstance, nullptr);

    if (!hHiddenWnd) return FALSE;

    InitTrayIcon(hHiddenWnd);

    // 5. Install Hook
    hKeyboardHook = SetWindowsHookEx(WH_KEYBOARD_LL, LowLevelKeyboardProc, hInstance, 0);
    if (!hKeyboardHook) {
        MessageBox(NULL, L"Failed to install keyboard hook!", L"Error", MB_ICONERROR);
        return 1;
    }

    // 6. Loop
    MSG msg;
    while (GetMessage(&msg, nullptr, 0, 0))
    {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    if (hKeyboardHook) UnhookWindowsHookEx(hKeyboardHook);
    RemoveTrayIcon();
    if (hMutex) ReleaseMutex(hMutex);

    return (int) msg.wParam;
}

LRESULT CALLBACK LowLevelKeyboardProc(int nCode, WPARAM wParam, LPARAM lParam) {
    if (nCode == HC_ACTION) {
        KBDLLHOOKSTRUCT* pKbd = (KBDLLHOOKSTRUCT*)lParam;
        
        if (pKbd->dwExtraInfo == PHTV_INJECTED_SIGNATURE) {
            return CallNextHookEx(hKeyboardHook, nCode, wParam, lParam);
        }

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

void ProcessEngineOutput() {
    extern vKeyHookState HookState;
    if (HookState.backspaceCount > 0) SendBackspace(HookState.backspaceCount);
    
    if (HookState.newCharCount > 0) {
        std::vector<unsigned int> chars;
        // FIX 1: Read buffer in REVERSE order (Engine uses LIFO stack logic in hData)
        // hData[0] is the Last entered char, hData[n-1] is the First.
        for (int i = HookState.newCharCount - 1; i >= 0; i--) {
            chars.push_back(HookState.charData[i]);
        }
        SendUnicodeString(chars);
    }
}

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

        // FIX 2: Handle Capitalization for Raw Keys
        // If it's an ASCII letter and CAPS_MASK is NOT set, convert to lowercase
        // (Because Engine stores generic keys like KEY_A as 'A')
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

void InitTrayIcon(HWND hWnd) {
    nid.cbSize = sizeof(NOTIFYICONDATA);
    nid.hWnd = hWnd;
    nid.uID = 1;
    nid.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
    nid.uCallbackMessage = WM_TRAYICON;
    wcscpy_s(nid.szTip, L"PHTV - Bộ gõ Tiếng Việt");
    Shell_NotifyIcon(NIM_ADD, &nid);
    UpdateTrayIcon();
}

void UpdateTrayIcon() {
    int iconId = (vLanguage == 1) ? IDI_ICON_VIE : IDI_ICON_ENG;
    nid.hIcon = LoadIcon(hInst, MAKEINTRESOURCE(iconId));
    if (!nid.hIcon) nid.hIcon = LoadIcon(hInst, MAKEINTRESOURCE(IDI_APP_ICON));
    Shell_NotifyIcon(NIM_MODIFY, &nid);
}

void RemoveTrayIcon() {
    Shell_NotifyIcon(NIM_DELETE, &nid);
}

LRESULT CALLBACK WndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam)
{
    switch (message)
    {
    case WM_TRAYICON:
        if (lParam == WM_RBUTTONUP || lParam == WM_LBUTTONUP) {
            POINT curPoint;
            GetCursorPos(&curPoint);
            HMENU hMenu = CreatePopupMenu();
            
            AppendMenu(hMenu, MF_STRING | (vLanguage == 1 ? MF_CHECKED : 0), IDM_TOGGLE_LANG, L"Chế độ gõ Tiếng Việt");
            AppendMenu(hMenu, MF_SEPARATOR, 0, nullptr);
            AppendMenu(hMenu, MF_STRING | (vInputType == 0 ? MF_CHECKED : 0), IDM_TELEX, L"Telex");
            AppendMenu(hMenu, MF_STRING | (vInputType == 1 ? MF_CHECKED : 0), IDM_VNI, L"VNI");
            AppendMenu(hMenu, MF_SEPARATOR, 0, nullptr);
            AppendMenu(hMenu, MF_STRING | (vUseMacro ? MF_CHECKED : 0), IDM_TOGGLE_MACRO, L"Gõ tắt (Macro)");
            AppendMenu(hMenu, MF_STRING | (vCheckSpelling ? MF_CHECKED : 0), IDM_TOGGLE_SPELL, L"Kiểm tra chính tả");
            AppendMenu(hMenu, MF_STRING | (vUseModernOrthography ? MF_CHECKED : 0), IDM_TOGGLE_MODERN, L"Dấu chuẩn (Oà, Uý)");
            AppendMenu(hMenu, MF_SEPARATOR, 0, nullptr);
            AppendMenu(hMenu, MF_STRING, IDM_SETTINGS, L"Cài đặt...");
            AppendMenu(hMenu, MF_SEPARATOR, 0, nullptr);
            AppendMenu(hMenu, MF_STRING, IDM_EXIT, L"Thoát");

            SetForegroundWindow(hWnd);
            TrackPopupMenu(hMenu, TPM_BOTTOMALIGN | TPM_LEFTALIGN, curPoint.x, curPoint.y, 0, hWnd, NULL);
            DestroyMenu(hMenu);
        }
        break;

    case WM_COMMAND:
        switch (LOWORD(wParam))
        {
        case IDM_EXIT: DestroyWindow(hWnd); break;
        case IDM_TELEX: vInputType = 0; PHTVConfig::Shared().Save(); break;
        case IDM_VNI:   vInputType = 1; PHTVConfig::Shared().Save(); break;
        
        case IDM_TOGGLE_LANG: 
            vLanguage = !vLanguage; 
            PHTVConfig::Shared().Save(); 
            UpdateTrayIcon(); 
            break;

        case IDM_TOGGLE_MACRO: vUseMacro = !vUseMacro; PHTVConfig::Shared().Save(); break;
        case IDM_TOGGLE_SPELL: vCheckSpelling = !vCheckSpelling; PHTVConfig::Shared().Save(); break;
        case IDM_TOGGLE_MODERN: vUseModernOrthography = !vUseModernOrthography; PHTVConfig::Shared().Save(); break;

        case IDM_SETTINGS: 
            DialogBox(hInst, MAKEINTRESOURCE(IDD_SETTINGS), NULL, SettingsDlgProc); 
            UpdateTrayIcon();
            break;
        }
        break;

    case WM_DESTROY:
        PostQuitMessage(0);
        break;
    default:
        return DefWindowProc(hWnd, message, wParam, lParam);
    }
    return 0;
}

INT_PTR CALLBACK SettingsDlgProc(HWND hDlg, UINT message, WPARAM wParam, LPARAM lParam)
{
    UNREFERENCED_PARAMETER(lParam);
    switch (message)
    {
    case WM_INITDIALOG:
        SetDlgItemTextW(hDlg, IDC_GRP_INPUT, L"Kiểu gõ");
        SetDlgItemTextW(hDlg, IDC_GRP_OPTIONS, L"Tính năng");
        SetDlgItemTextW(hDlg, IDC_CHECK_SPELLING, L"Kiểm tra chính tả");
        SetDlgItemTextW(hDlg, IDC_CHECK_MODERN, L"Dùng quy tắc òa, uý (thay vì oà, úy)");
        SetDlgItemTextW(hDlg, IDC_CHECK_QUICKTELEX, L"Bật gõ tắt Telex (cc=ch, gg=gi, ...)");
        SetDlgItemTextW(hDlg, IDC_CHECK_MACRO, L"Cho phép gõ tắt (Macro)");
        SetDlgItemTextW(hDlg, IDC_CHECK_RESTORE_ENG, L"Tự động khôi phục từ tiếng Anh");
        SetDlgItemTextW(hDlg, IDC_BTN_CLOSE, L"Đóng");
        SetWindowTextW(hDlg, L"Cấu hình PHTV");

        if (vInputType == 0) CheckRadioButton(hDlg, IDC_RADIO_TELEX, IDC_RADIO_VNI, IDC_RADIO_TELEX);
        else CheckRadioButton(hDlg, IDC_RADIO_TELEX, IDC_RADIO_VNI, IDC_RADIO_VNI);

        CheckDlgButton(hDlg, IDC_CHECK_SPELLING, vCheckSpelling ? BST_CHECKED : BST_UNCHECKED);
        CheckDlgButton(hDlg, IDC_CHECK_MODERN, vUseModernOrthography ? BST_CHECKED : BST_UNCHECKED);
        CheckDlgButton(hDlg, IDC_CHECK_QUICKTELEX, vQuickTelex ? BST_CHECKED : BST_UNCHECKED);
        CheckDlgButton(hDlg, IDC_CHECK_MACRO, vUseMacro ? BST_CHECKED : BST_UNCHECKED);
        CheckDlgButton(hDlg, IDC_CHECK_RESTORE_ENG, vAutoRestoreEnglishWord ? BST_CHECKED : BST_UNCHECKED);
        
        {
            RECT rc, rcDlg, rcOwner;
            GetWindowRect(hDlg, &rcDlg);
            GetWindowRect(GetDesktopWindow(), &rcOwner);
            CopyRect(&rc, &rcOwner);
            OffsetRect(&rcDlg, -rcDlg.left, -rcDlg.top);
            OffsetRect(&rc, -rc.left, -rc.top);
            OffsetRect(&rc, -rcDlg.right, -rcDlg.bottom);
            SetWindowPos(hDlg, HWND_TOP, rcOwner.left + (rc.right / 2), rcOwner.top + (rc.bottom / 2), 0, 0, SWP_NOSIZE);
        }
        return (INT_PTR)TRUE;

    case WM_COMMAND:
        if (HIWORD(wParam) == BN_CLICKED) {
            switch (LOWORD(wParam)) {
                case IDC_RADIO_TELEX: vInputType = 0; PHTVConfig::Shared().Save(); break;
                case IDC_RADIO_VNI:   vInputType = 1; PHTVConfig::Shared().Save(); break;
                case IDC_CHECK_SPELLING: vCheckSpelling = IsDlgButtonChecked(hDlg, IDC_CHECK_SPELLING); PHTVConfig::Shared().Save(); break;
                case IDC_CHECK_MODERN:   vUseModernOrthography = IsDlgButtonChecked(hDlg, IDC_CHECK_MODERN); PHTVConfig::Shared().Save(); break;
                case IDC_CHECK_QUICKTELEX: vQuickTelex = IsDlgButtonChecked(hDlg, IDC_CHECK_QUICKTELEX); PHTVConfig::Shared().Save(); break;
                case IDC_CHECK_MACRO:      vUseMacro = IsDlgButtonChecked(hDlg, IDC_CHECK_MACRO); PHTVConfig::Shared().Save(); break;
                case IDC_CHECK_RESTORE_ENG: vAutoRestoreEnglishWord = IsDlgButtonChecked(hDlg, IDC_CHECK_RESTORE_ENG); PHTVConfig::Shared().Save(); break;
                case IDC_BTN_CLOSE:
                case IDCANCEL: EndDialog(hDlg, LOWORD(wParam)); return (INT_PTR)TRUE;
            }
        }
        break;
    }
    return (INT_PTR)FALSE;
}