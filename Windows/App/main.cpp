//
//  main.cpp
//  PHTV - Windows Entry Point
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shellapi.h>
#include <string>
#include <vector>

#include "resource.h"
#include "../Platforms/win32.h"
#include "../Engine/Engine.h"
#include "../Config/PHTVConfig.h"

// Global Variables
HINSTANCE hInst;
HHOOK hKeyboardHook;
NOTIFYICONDATA nid;
HWND hHiddenWnd;

// Forward Declarations
LRESULT CALLBACK WndProc(HWND, UINT, WPARAM, LPARAM);
LRESULT CALLBACK LowLevelKeyboardProc(int, WPARAM, LPARAM);
void InitTrayIcon(HWND hWnd);
void RemoveTrayIcon();
void UpdateMenuState(HMENU hMenu);

// Engine Integration Helpers
void ProcessEngineOutput();
void SendUnicodeString(const std::vector<unsigned int>& charCodes);
void SendBackspace(int count);

// Main Entry Point
int APIENTRY wWinMain(_In_ HINSTANCE hInstance,
                     _In_opt_ HINSTANCE hPrevInstance,
                     _In_ LPWSTR    lpCmdLine,
                     _In_ int       nCmdShow)
{
    UNREFERENCED_PARAMETER(hPrevInstance);
    UNREFERENCED_PARAMETER(lpCmdLine);

    hInst = hInstance;

    // 1. Initialize PHTV Engine & Config
    vKeyInit();
    PHTVConfig::Shared().Load();

    // 2. Create a hidden window for message processing (Tray Icon requires a window)
    WNDCLASSEXW wcex;
    wcex.cbSize = sizeof(WNDCLASSEX);
    wcex.style          = CS_HREDRAW | CS_VREDRAW;
    wcex.lpfnWndProc    = WndProc;
    wcex.cbClsExtra     = 0;
    wcex.cbWndExtra     = 0;
    wcex.hInstance      = hInstance;
    wcex.hIcon          = LoadIcon(hInstance, IDI_APPLICATION);
    wcex.hCursor        = LoadCursor(nullptr, IDC_ARROW);
    wcex.hbrBackground  = (HBRUSH)(COLOR_WINDOW+1);
    wcex.lpszMenuName   = nullptr;
    wcex.lpszClassName  = L"PHTVHiddenWindow";
    wcex.hIconSm        = LoadIcon(wcex.hInstance, IDI_APPLICATION);

    RegisterClassExW(&wcex);

    hHiddenWnd = CreateWindowW(L"PHTVHiddenWindow", L"PHTV", WS_OVERLAPPEDWINDOW,
                          CW_USEDEFAULT, 0, CW_USEDEFAULT, 0, nullptr, nullptr, hInstance, nullptr);

    if (!hHiddenWnd) return FALSE;

    // 3. Initialize Tray Icon
    InitTrayIcon(hHiddenWnd);

    // 4. Install Keyboard Hook
    hKeyboardHook = SetWindowsHookEx(WH_KEYBOARD_LL, LowLevelKeyboardProc, hInstance, 0);
    if (!hKeyboardHook) {
        MessageBox(NULL, L"Failed to install keyboard hook!", L"Error", MB_ICONERROR);
        return 1;
    }

    // 5. Main Message Loop
    MSG msg;
    while (GetMessage(&msg, nullptr, 0, 0))
    {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    // Cleanup
    if (hKeyboardHook) UnhookWindowsHookEx(hKeyboardHook);
    RemoveTrayIcon();

    return (int) msg.wParam;
}

// Keyboard Hook Procedure
LRESULT CALLBACK LowLevelKeyboardProc(int nCode, WPARAM wParam, LPARAM lParam) {
    if (nCode == HC_ACTION) {
        KBDLLHOOKSTRUCT* pKbd = (KBDLLHOOKSTRUCT*)lParam;
        
        // Only process if PHTV is enabled (Vietnamese mode)
        if (vLanguage == 1) {
            // Map Windows Event to Engine Event
            vKeyEvent event = (wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN) ? vKeyEvent::Keyboard : vKeyEvent::Keyboard; // Engine doesn't distinguish much
            vKeyEventState state = (wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN) ? vKeyEventState::KeyDown : vKeyEventState::KeyUp;

            // Filter: Only process KeyDown for logic usually, unless engine needs KeyUp
            if (state == vKeyEventState::KeyDown) {
                // Check modifiers
                bool isShift = (GetKeyState(VK_SHIFT) & 0x8000) != 0;
                bool isCaps = (GetKeyState(VK_CAPITAL) & 0x0001) != 0;
                bool isCtrl = (GetKeyState(VK_CONTROL) & 0x8000) != 0;
                bool isAlt = (GetKeyState(VK_MENU) & 0x8000) != 0;

                // Engine input requires basic mapping. 
                // Note: pKbd->vkCode maps directly to our definitions in win32.h for the most part
                
                // Pass to Engine
                // capsStatus: 1 for Shift, 2 for CapsLock (as per Engine.h comments)
                Uint8 capsStatus = 0;
                if (isShift) capsStatus = 1;
                if (isCaps) capsStatus = 2; 

                // We need to access the HookState structure which is global in Engine.cpp
                // Accessing via vKeyInit return pointer or extern declaration
                extern vKeyHookState HookState;

                // Call Engine
                vKeyHandleEvent(event, state, (Uint16)pKbd->vkCode, capsStatus, isCtrl || isAlt);

                // Check Engine Result in HookState
                if (HookState.code != vDoNothing) {
                    // Engine has processed this key.
                    // We must BLOCK the original key and simulate the output.
                    
                    ProcessEngineOutput();

                    // Reset Engine State for next key if needed, or Engine does it.
                    // IMPORTANT: If we processed it, return 1 to block original key
                    return 1; 
                }
            }
        }
    }
    return CallNextHookEx(hKeyboardHook, nCode, wParam, lParam);
}

// Helper to convert Engine output to Windows Input
void ProcessEngineOutput() {
    extern vKeyHookState HookState;

    // 1. Handle Backspace (Delete old characters)
    if (HookState.backspaceCount > 0) {
        SendBackspace(HookState.backspaceCount);
    }

    // 2. Handle New Characters
    if (HookState.newCharCount > 0) {
        std::vector<unsigned int> chars;
        for (int i = 0; i < HookState.newCharCount; i++) {
            chars.push_back(HookState.charData[i]);
        }
        SendUnicodeString(chars);
    }
    
    // 3. Special handling for Macro replacement if needed
    // (Similar logic: backspace old macro trigger -> send new content)
}

void SendBackspace(int count) {
    std::vector<INPUT> inputs;
    for (int i = 0; i < count; ++i) {
        INPUT input = {0};
        input.type = INPUT_KEYBOARD;
        input.ki.wVk = VK_BACK;
        inputs.push_back(input);

        input.ki.dwFlags = KEYEVENTF_KEYUP;
        inputs.push_back(input);
    }
    SendInput((UINT)inputs.size(), inputs.data(), sizeof(INPUT));
}

void SendUnicodeString(const std::vector<unsigned int>& charCodes) {
    std::vector<INPUT> inputs;
    for (unsigned int code : charCodes) {
        // Extract pure character code (remove internal engine flags)
        // See DataType.h: CHAR_MASK 0xFFFF
        // Also handle Upper/Lower case logic if Engine passes generic chars
        
        unsigned int finalChar = code & 0xFFFF; // Simple extraction
        
        INPUT input = {0};
        input.type = INPUT_KEYBOARD;
        input.ki.wScan = (WORD)finalChar;
        input.ki.dwFlags = KEYEVENTF_UNICODE;
        inputs.push_back(input);

        input.ki.dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;
        inputs.push_back(input);
    }
    SendInput((UINT)inputs.size(), inputs.data(), sizeof(INPUT));
}


// Window Procedure (For Tray Icon)
LRESULT CALLBACK WndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam)
{
    switch (message)
    {
    case WM_TRAYICON:
        if (lParam == WM_RBUTTONUP) {
            POINT curPoint;
            GetCursorPos(&curPoint);
            HMENU hMenu = CreatePopupMenu();
            
            // Create Menu Items
            AppendMenu(hMenu, MF_STRING | (vLanguage == 1 ? MF_CHECKED : 0), IDM_VNI, L"Vietnamese Mode");
            AppendMenu(hMenu, MF_SEPARATOR, 0, nullptr);
            AppendMenu(hMenu, MF_STRING | (vInputType == 0 ? MF_CHECKED : 0), IDM_TELEX, L"Telex");
            AppendMenu(hMenu, MF_STRING | (vInputType == 1 ? MF_CHECKED : 0), IDM_VNI, L"VNI");
            AppendMenu(hMenu, MF_SEPARATOR, 0, nullptr);
            AppendMenu(hMenu, MF_STRING, IDM_EXIT, L"Exit");

            SetForegroundWindow(hWnd);
            TrackPopupMenu(hMenu, TPM_BOTTOMALIGN | TPM_LEFTALIGN, curPoint.x, curPoint.y, 0, hWnd, NULL);
        }
        break;

    case WM_COMMAND:
        switch (LOWORD(wParam))
        {
        case IDM_EXIT:
            DestroyWindow(hWnd);
            break;
        case IDM_TELEX:
            vInputType = 0;
            PHTVConfig::Shared().Save();
            break;
        case IDM_VNI:
            vInputType = 1;
            PHTVConfig::Shared().Save();
            break;
        // Toggle Language
        case 1005: // Custom ID for language toggle if implemented
            vLanguage = (vLanguage == 0) ? 1 : 0;
            PHTVConfig::Shared().Save();
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

void InitTrayIcon(HWND hWnd) {
    nid.cbSize = sizeof(NOTIFYICONDATA);
    nid.hWnd = hWnd;
    nid.uID = 1;
    nid.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
    nid.uCallbackMessage = WM_TRAYICON;
    nid.hIcon = LoadIcon(NULL, IDI_APPLICATION); // Placeholder Icon
    wcscpy_s(nid.szTip, L"PHTV - Vietnamese Input Method");
    Shell_NotifyIcon(NIM_ADD, &nid);
}

void RemoveTrayIcon() {
    Shell_NotifyIcon(NIM_DELETE, &nid);
}
