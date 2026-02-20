//
//  PHTVRuntimeState.mm
//  PHTV
//
//  Global runtime state and C bridge accessors used by Swift/ObjC wrappers.
//

#import <Carbon/Carbon.h>
#import <Cocoa/Cocoa.h>
#include "../Core/Engine/Engine.h"

// see document in Engine.h
// VOLATILE: Ensures thread-safe reads in event tap callback
// These are written on main thread, read on event tap thread
volatile int vLanguage = 1;
volatile int vInputType = 0;
int vFreeMark = 0;
volatile int vCodeTable = 0;
volatile int vCheckSpelling = 1;
volatile int vUseModernOrthography = 1;
volatile int vQuickTelex = 0;
// Default: Ctrl + Shift (no key, modifier only)
// Format: bits 0-7 = keycode (0xFE = no key), bit 8 = Control, bit 11 = Shift
volatile int vSwitchKeyStatus = PHTV_DEFAULT_SWITCH_HOTKEY_STATUS;
volatile int vFixRecommendBrowser = 1;
volatile int vUseMacro = 1;
volatile int vUseMacroInEnglishMode = 0;
volatile int vAutoCapsMacro = 0;
volatile int vSendKeyStepByStep = 0;
volatile int vUseSmartSwitchKey = 1;
volatile int vUpperCaseFirstChar = 0;
volatile int vUpperCaseExcludedForCurrentApp = 0;  // 1 = current app is in uppercase excluded list
volatile int vTempOffSpelling = 0;
volatile int vAllowConsonantZFWJ = 1;
volatile int vQuickStartConsonant = 0;
volatile int vQuickEndConsonant = 0;
volatile int vRememberCode = 1; //new on version 2.0
volatile int vOtherLanguage = 1; //new on version 2.0
volatile int vTempOffPHTV = 0; //new on version 2.0

// Restore to raw keys (customizable key)
volatile int vRestoreOnEscape = 1; //enable restore to raw keys feature (default: ON)
volatile int vCustomEscapeKey = 0; //custom restore key code (0 = default ESC = KEY_ESC)

// Pause Vietnamese input when holding a key
volatile int vPauseKeyEnabled = 0; //enable pause key feature (default: OFF)
volatile int vPauseKey = KEY_LEFT_OPTION; //pause key code (default: Left Option)

// Auto restore English word feature
volatile int vAutoRestoreEnglishWord = 1; //auto restore English words (default: ON)

// Emoji picker hotkey (handled in event tap callback, OpenKey style)
volatile int vEnableEmojiHotkey = 1;
volatile int vEmojiHotkeyModifiers = NSEventModifierFlagCommand;
volatile int vEmojiHotkeyKeyCode = KEY_E; // E key

int vShowIconOnDock = 0; //new on version 2.0

volatile int vPerformLayoutCompat = 0;

extern "C" {
    int PHTVGetCurrentLanguage(void) {
        return vLanguage;
    }

    void PHTVSetCurrentLanguage(int language) {
        vLanguage = language;
        __sync_synchronize();
    }

    int PHTVGetCurrentInputType(void) {
        return vInputType;
    }

    void PHTVSetCurrentInputType(int inputType) {
        vInputType = inputType;
        __sync_synchronize();
    }

    int PHTVGetCurrentCodeTable(void) {
        return vCodeTable;
    }

    void PHTVSetCurrentCodeTable(int codeTable) {
        vCodeTable = codeTable;
        __sync_synchronize();
    }

    BOOL PHTVIsSmartSwitchKeyEnabled(void) {
        return vUseSmartSwitchKey != 0;
    }

    BOOL PHTVIsSendKeyStepByStepEnabled(void) {
        return vSendKeyStepByStep != 0;
    }

    void PHTVSetSendKeyStepByStepEnabled(BOOL enabled) {
        vSendKeyStepByStep = enabled ? 1 : 0;
        __sync_synchronize();
    }

    void PHTVSetUpperCaseExcludedForCurrentApp(BOOL excluded) {
        vUpperCaseExcludedForCurrentApp = excluded ? 1 : 0;
    }

    int PHTVGetSwitchKeyStatus(void) {
        return vSwitchKeyStatus;
    }

    void PHTVSetSwitchKeyStatus(int status) {
        vSwitchKeyStatus = status;
        __sync_synchronize();
    }

    int PHTVGetCheckSpelling(void) {
        return vCheckSpelling;
    }

    void PHTVSetCheckSpelling(int value) {
        vCheckSpelling = value;
        __sync_synchronize();
    }

    int PHTVGetAllowConsonantZFWJ(void) {
        return vAllowConsonantZFWJ;
    }

    void PHTVSetAllowConsonantZFWJ(int value) {
        vAllowConsonantZFWJ = value;
        __sync_synchronize();
    }

    int PHTVGetUseModernOrthography(void) {
        return vUseModernOrthography;
    }

    void PHTVSetUseModernOrthography(int value) {
        vUseModernOrthography = value;
        __sync_synchronize();
    }

    int PHTVGetQuickTelex(void) {
        return vQuickTelex;
    }

    void PHTVSetQuickTelex(int value) {
        vQuickTelex = value;
        __sync_synchronize();
    }

    int PHTVGetUpperCaseFirstChar(void) {
        return vUpperCaseFirstChar;
    }

    void PHTVSetUpperCaseFirstChar(int value) {
        vUpperCaseFirstChar = value;
        __sync_synchronize();
    }

    int PHTVGetAutoRestoreEnglishWord(void) {
        return vAutoRestoreEnglishWord;
    }

    void PHTVSetAutoRestoreEnglishWord(int value) {
        vAutoRestoreEnglishWord = value;
        __sync_synchronize();
    }

    void PHTVSetShowIconOnDock(BOOL visible) {
        vShowIconOnDock = visible ? 1 : 0;
        __sync_synchronize();
    }

    int PHTVGetUseMacro(void) {
        return vUseMacro;
    }

    int PHTVGetUseMacroInEnglishMode(void) {
        return vUseMacroInEnglishMode;
    }

    int PHTVGetAutoCapsMacro(void) {
        return vAutoCapsMacro;
    }

    int PHTVGetQuickStartConsonant(void) {
        return vQuickStartConsonant;
    }

    int PHTVGetQuickEndConsonant(void) {
        return vQuickEndConsonant;
    }

    int PHTVGetRememberCode(void) {
        return vRememberCode;
    }

    int PHTVGetPerformLayoutCompat(void) {
        return vPerformLayoutCompat;
    }

    int PHTVGetShowIconOnDock(void) {
        return vShowIconOnDock;
    }

    int PHTVGetRestoreOnEscape(void) {
        return vRestoreOnEscape;
    }

    int PHTVGetCustomEscapeKey(void) {
        return vCustomEscapeKey;
    }

    int PHTVGetPauseKeyEnabled(void) {
        return vPauseKeyEnabled;
    }

    int PHTVGetPauseKey(void) {
        return vPauseKey;
    }

    int PHTVGetEnableEmojiHotkey(void) {
        return vEnableEmojiHotkey;
    }

    int PHTVGetEmojiHotkeyModifiers(void) {
        return vEmojiHotkeyModifiers;
    }

    int PHTVGetEmojiHotkeyKeyCode(void) {
        return vEmojiHotkeyKeyCode;
    }

    void PHTVSetEmojiHotkeySettings(int enabled, int modifiers, int keyCode) {
        vEnableEmojiHotkey = enabled;
        vEmojiHotkeyModifiers = modifiers;
        vEmojiHotkeyKeyCode = keyCode;
        __sync_synchronize();
    }

    int PHTVGetFreeMark(void) {
        return vFreeMark;
    }

    void PHTVSetFreeMark(int value) {
        vFreeMark = value;
        __sync_synchronize();
    }

    void PHTVSetUseMacro(int value) {
        vUseMacro = value;
        __sync_synchronize();
    }

    void PHTVSetUseMacroInEnglishMode(int value) {
        vUseMacroInEnglishMode = value;
        __sync_synchronize();
    }

    void PHTVSetAutoCapsMacro(int value) {
        vAutoCapsMacro = value;
        __sync_synchronize();
    }

    void PHTVSetUseSmartSwitchKey(BOOL enabled) {
        vUseSmartSwitchKey = enabled ? 1 : 0;
        __sync_synchronize();
    }

    void PHTVSetQuickStartConsonant(int value) {
        vQuickStartConsonant = value;
        __sync_synchronize();
    }

    void PHTVSetQuickEndConsonant(int value) {
        vQuickEndConsonant = value;
        __sync_synchronize();
    }

    void PHTVSetRememberCode(int value) {
        vRememberCode = value;
        __sync_synchronize();
    }

    void PHTVSetPerformLayoutCompat(int value) {
        vPerformLayoutCompat = value;
        __sync_synchronize();
    }

    void PHTVSetRestoreOnEscape(int value) {
        vRestoreOnEscape = value;
        __sync_synchronize();
    }

    void PHTVSetCustomEscapeKey(int value) {
        vCustomEscapeKey = value;
        __sync_synchronize();
    }

    void PHTVSetPauseKeyEnabled(int value) {
        vPauseKeyEnabled = value;
        __sync_synchronize();
    }

    void PHTVSetPauseKey(int value) {
        vPauseKey = value;
        __sync_synchronize();
    }

    void PHTVSetFixRecommendBrowser(int value) {
        vFixRecommendBrowser = value;
        __sync_synchronize();
    }

    void PHTVSetTempOffSpelling(int value) {
        vTempOffSpelling = value;
        __sync_synchronize();
    }

    void PHTVSetOtherLanguage(int value) {
        vOtherLanguage = value;
        __sync_synchronize();
    }

    void PHTVSetTempOffPHTV(int value) {
        vTempOffPHTV = value;
        __sync_synchronize();
    }

    int PHTVDefaultSwitchHotkeyStatus(void) {
        return PHTV_DEFAULT_SWITCH_HOTKEY_STATUS;
    }

    int PHTVDefaultPauseKey(void) {
        return KEY_LEFT_OPTION;
    }

    int PHTVGetOtherLanguage(void) {
        return vOtherLanguage;
    }
}
