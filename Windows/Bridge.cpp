#include "Bridge.h"
#include <windows.h>
#include <vector>
#include "Engine/Engine.h"
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
    // Load config is handled by UI via SetConfig, or we can load defaults
    // PHTVConfig::Shared().Load(); // DLL shouldn't manage file I/O if UI does it, but we can keep it
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

void __cdecl PHTV_SetInputMethod(int type) { vInputType = type; }
void __cdecl PHTV_SetLanguage(int lang) { vLanguage = lang; }
void __cdecl PHTV_SetSpellCheck(bool enable) { vCheckSpelling = enable ? 1 : 0; }
void __cdecl PHTV_SetModernOrthography(bool enable) { vUseModernOrthography = enable ? 1 : 0; }
void __cdecl PHTV_SetMacro(bool enable) { vUseMacro = enable ? 1 : 0; }

bool __cdecl PHTV_IsRunning() {
    return (hKeyboardHook != NULL);
}
