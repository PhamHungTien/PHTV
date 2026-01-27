#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shellapi.h>
#include <shlwapi.h>
#include <string>
#include <vector>
#include <codecvt>

#pragma comment(lib, "shlwapi.lib")
#pragma comment(lib, "msimg32.lib") // For GradientFill if needed

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
HWND hSettingsWnd = NULL;
HANDLE hMutex;

// Fonts
HFONT hFontTitle;
HFONT hFontNormal;

// Forward Declarations
LRESULT CALLBACK WndProc(HWND, UINT, WPARAM, LPARAM);
LRESULT CALLBACK LowLevelKeyboardProc(int, WPARAM, LPARAM);
LRESULT CALLBACK SettingsWndProc(HWND, UINT, WPARAM, LPARAM);
void InitTrayIcon(HWND hWnd);
void RemoveTrayIcon();
void UpdateTrayIcon();
void ShowSettingsWindow();

// Engine Integration
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

    // Single Instance Check
    hMutex = CreateMutexW(NULL, TRUE, PHTV_MUTEX_NAME);
    if (GetLastError() == ERROR_ALREADY_EXISTS) return 0;

    // Create Fonts
    hFontTitle = CreateFontW(24, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");
    hFontNormal = CreateFontW(18, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");

    // Setup Engine
    wchar_t exePath[MAX_PATH];
    GetModuleFileNameW(NULL, exePath, MAX_PATH);
    PathRemoveFileSpecW(exePath); 
    std::wstring baseDir = exePath;
    std::wstring viDictPath = baseDir + L"\\Resources\\Dictionaries\\vi_dict.bin";
    std::wstring enDictPath = baseDir + L"\\Resources\\Dictionaries\\en_dict.bin";
    initVietnameseDictionary(WStringToString(viDictPath));
    initEnglishDictionary(WStringToString(enDictPath));
    vKeyInit();
    PHTVConfig::Shared().Load();

    // Register Classes
    WNDCLASSEXW wcex = {0};
    wcex.cbSize = sizeof(WNDCLASSEX);
    wcex.lpfnWndProc = WndProc;
    wcex.hInstance = hInstance;
    wcex.lpszClassName = L"PHTVHiddenWindow";
    RegisterClassExW(&wcex);

    WNDCLASSEXW wSettings = {0};
    wSettings.cbSize = sizeof(WNDCLASSEX);
    wSettings.style = CS_HREDRAW | CS_VREDRAW;
    wSettings.lpfnWndProc = SettingsWndProc;
    wSettings.hInstance = hInstance;
    wSettings.hCursor = LoadCursor(nullptr, IDC_ARROW);
    wSettings.hbrBackground = (HBRUSH)(COLOR_WINDOW+1);
    wSettings.lpszClassName = L"PHTVSettingsWindow";
    wSettings.hIcon = LoadIcon(hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
    RegisterClassExW(&wSettings);

    hHiddenWnd = CreateWindowW(L"PHTVHiddenWindow", L"PHTV", 0, 0, 0, 0, 0, nullptr, nullptr, hInstance, nullptr);
    if (!hHiddenWnd) return FALSE;

    InitTrayIcon(hHiddenWnd);

    hKeyboardHook = SetWindowsHookEx(WH_KEYBOARD_LL, LowLevelKeyboardProc, hInstance, 0);
    
    MSG msg;
    while (GetMessage(&msg, nullptr, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    if (hKeyboardHook) UnhookWindowsHookEx(hKeyboardHook);
    RemoveTrayIcon();
    if (hMutex) ReleaseMutex(hMutex);
    DeleteObject(hFontTitle);
    DeleteObject(hFontNormal);

    return (int) msg.wParam;
}

LRESULT CALLBACK LowLevelKeyboardProc(int nCode, WPARAM wParam, LPARAM lParam) {
    if (nCode == HC_ACTION) {
        KBDLLHOOKSTRUCT* pKbd = (KBDLLHOOKSTRUCT*)lParam;
        if (pKbd->dwExtraInfo == PHTV_INJECTED_SIGNATURE) return CallNextHookEx(hKeyboardHook, nCode, wParam, lParam);

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
                Uint8 capsStatus = (isCaps ? 2 : (isShift ? 1 : 0));

                extern vKeyHookState HookState;
                vKeyHandleEvent(vKeyEvent::Keyboard, state, (Uint16)pKbd->vkCode, capsStatus, isCtrl || isAlt);

                if (HookState.code != vDoNothing) {
                    ProcessEngineOutput();
                    return 1;
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
        for (int i = HookState.newCharCount - 1; i >= 0; i--) chars.push_back(HookState.charData[i]);
        SendUnicodeString(chars);
    }
}

void SendBackspace(int count) {
    if (count <= 0) return;
    std::vector<INPUT> inputs;
    for (int i = 0; i < count; ++i) {
        INPUT input = {0};
        input.type = INPUT_KEYBOARD;
        input.ki.wVk = VK_BACK;
        input.ki.dwExtraInfo = PHTV_INJECTED_SIGNATURE;
        inputs.push_back(input);
        input.ki.dwFlags = KEYEVENTF_KEYUP;
        inputs.push_back(input);
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
        if (finalChar >= 'A' && finalChar <= 'Z') {
            if (!isUpperCase) {
                finalChar = tolower(finalChar);
            }
        }
        
        // UNIFIED UNICODE HANDLING (Includes Space 0x0020)
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
    nid.hIcon = LoadIcon(hInst, MAKEINTRESOURCE(IDI_APP_ICON)); 
    if (!nid.hIcon) nid.hIcon = LoadIcon(NULL, IDI_APPLICATION);
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

void ShowSettingsWindow() {
    if (hSettingsWnd) {
        SetForegroundWindow(hSettingsWnd);
        return;
    }
    int width = 450;
    int height = 350;
    int x = (GetSystemMetrics(SM_CXSCREEN) - width) / 2;
    int y = (GetSystemMetrics(SM_CYSCREEN) - height) / 2;
    
    hSettingsWnd = CreateWindowExW(WS_EX_DLGMODALFRAME, L"PHTVSettingsWindow", L"Cài đặt PHTV",
        WS_VISIBLE | WS_SYSMENU | WS_CAPTION | WS_MINIMIZEBOX,
        x, y, width, height, NULL, NULL, hInst, NULL);
}

// UI Helpers
void DrawCheckbox(HDC hdc, int x, int y, const wchar_t* text, bool checked, int id) {
    RECT rc = {x, y, x + 20, y + 20};
    DrawFrameControl(hdc, &rc, DFC_BUTTON, DFCS_BUTTONCHECK | (checked ? DFCS_CHECKED : 0));
    
    SetBkMode(hdc, TRANSPARENT);
    SelectObject(hdc, hFontNormal);
    SetTextColor(hdc, RGB(50, 50, 50));
    TextOutW(hdc, x + 30, y, text, lstrlenW(text));
}

void DrawRadio(HDC hdc, int x, int y, const wchar_t* text, bool checked, int id) {
    RECT rc = {x, y, x + 20, y + 20};
    DrawFrameControl(hdc, &rc, DFC_BUTTON, DFCS_BUTTONRADIO | (checked ? DFCS_CHECKED : 0));
    
    SetBkMode(hdc, TRANSPARENT);
    SelectObject(hdc, hFontNormal);
    SetTextColor(hdc, RGB(50, 50, 50));
    TextOutW(hdc, x + 30, y, text, lstrlenW(text));
}

// Settings Window Procedure
LRESULT CALLBACK SettingsWndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam) {
    switch (message) {
    case WM_PAINT: {
        PAINTSTRUCT ps;
        HDC hdc = BeginPaint(hWnd, &ps);
        
        // Background
        RECT rcClient;
        GetClientRect(hWnd, &rcClient);
        HBRUSH hBrushBg = CreateSolidBrush(RGB(245, 245, 247)); // macOS-like gray
        FillRect(hdc, &rcClient, hBrushBg);
        DeleteObject(hBrushBg);

        // Header
        SetBkMode(hdc, TRANSPARENT);
        SelectObject(hdc, hFontTitle);
        SetTextColor(hdc, RGB(0, 0, 0));
        TextOutW(hdc, 20, 20, L"Kiểu gõ", 7);
        
        // Input Method Group
        DrawRadio(hdc, 30, 60, L"Telex", vInputType == 0, 101);
        DrawRadio(hdc, 150, 60, L"VNI", vInputType == 1, 102);

        // Features Group
        SelectObject(hdc, hFontTitle);
        TextOutW(hdc, 20, 100, L"Tính năng", 9);

        DrawCheckbox(hdc, 30, 140, L"Kiểm tra chính tả", vCheckSpelling, 201);
        DrawCheckbox(hdc, 30, 170, L"Dấu chuẩn (Oà, Uý)", vUseModernOrthography, 202);
        DrawCheckbox(hdc, 30, 200, L"Gõ tắt (Macro)", vUseMacro, 203);
        DrawCheckbox(hdc, 30, 230, L"Khôi phục từ tiếng Anh", vAutoRestoreEnglishWord, 204);

        EndPaint(hWnd, &ps);
        break;
    }
    case WM_LBUTTONUP: {
        int x = LOWORD(lParam);
        int y = HIWORD(lParam);
        
        // Simple Hit Testing (Hardcoded for demo)
        bool changed = false;
        if (y >= 60 && y <= 80) {
            if (x >= 30 && x <= 100) { vInputType = 0; changed = true; }
            else if (x >= 150 && x <= 220) { vInputType = 1; changed = true; }
        }
        else if (x >= 30 && x <= 300) {
            if (y >= 140 && y <= 160) { vCheckSpelling = !vCheckSpelling; changed = true; }
            else if (y >= 170 && y <= 190) { vUseModernOrthography = !vUseModernOrthography; changed = true; }
            else if (y >= 200 && y <= 220) { vUseMacro = !vUseMacro; changed = true; }
            else if (y >= 230 && y <= 250) { vAutoRestoreEnglishWord = !vAutoRestoreEnglishWord; changed = true; }
        }

        if (changed) {
            PHTVConfig::Shared().Save();
            InvalidateRect(hWnd, NULL, TRUE); // Redraw
        }
        break;
    }
    case WM_DESTROY:
        hSettingsWnd = NULL;
        break;
    default:
        return DefWindowProc(hWnd, message, wParam, lParam);
    }
    return 0;
}

LRESULT CALLBACK WndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam) {
    switch (message) {
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
            AppendMenu(hMenu, MF_STRING, IDM_SETTINGS, L"Cài đặt...");
            AppendMenu(hMenu, MF_SEPARATOR, 0, nullptr);
            AppendMenu(hMenu, MF_STRING, IDM_EXIT, L"Thoát");

            SetForegroundWindow(hWnd);
            TrackPopupMenu(hMenu, TPM_BOTTOMALIGN | TPM_LEFTALIGN, curPoint.x, curPoint.y, 0, hWnd, NULL);
            DestroyMenu(hMenu);
        }
        break;
    case WM_COMMAND:
        switch (LOWORD(wParam)) {
        case IDM_EXIT: DestroyWindow(hWnd); break;
        case IDM_TELEX: vInputType = 0; PHTVConfig::Shared().Save(); break;
        case IDM_VNI:   vInputType = 1; PHTVConfig::Shared().Save(); break;
        case IDM_TOGGLE_LANG: 
            vLanguage = !vLanguage; 
            PHTVConfig::Shared().Save(); 
            UpdateTrayIcon(); 
            break;
        case IDM_SETTINGS: ShowSettingsWindow(); break;
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
