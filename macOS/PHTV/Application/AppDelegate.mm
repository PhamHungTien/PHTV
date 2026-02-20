//
//  AppDelegate.m
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import <Carbon/Carbon.h>
#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"
#include "../Core/Engine/Engine.h"

AppDelegate* appDelegate;

extern "C" {
    // Global function to get AppDelegate instance
    AppDelegate* _Nullable GetAppDelegateInstance(void) {
        return appDelegate;
    }

    void SetAppDelegateInstance(AppDelegate* _Nullable instance) {
        appDelegate = instance;
    }

    void OnTableCodeChange(void);
    void initMacroMap(const unsigned char*, const int&);
    void OnInputMethodChanged(void);
    void RequestNewSession(void);
    void OnActiveAppChanged(void);
    void InvalidateLayoutCache(void);
}

//see document in Engine.h
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
}

@implementation AppDelegate

@end
