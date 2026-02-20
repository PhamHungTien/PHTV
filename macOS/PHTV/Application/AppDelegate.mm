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
#import "AppDelegate+Private.h"
#import "AppDelegate+Accessibility.h"
#import "AppDelegate+AppMonitoring.h"
#import "AppDelegate+Defaults.h"
#import "AppDelegate+DockVisibility.h"
#import "AppDelegate+InputState.h"
#import "AppDelegate+InputSourceMonitoring.h"
#import "AppDelegate+LoginItem.h"
#import "AppDelegate+MacroData.h"
#import "AppDelegate+PermissionFlow.h"
#import "AppDelegate+RuntimeSettings.h"
#import "AppDelegate+SettingsBridge.h"
#import "AppDelegate+SettingsActions.h"
#import "AppDelegate+Sparkle.h"
#import "AppDelegate+StatusBarMenu.h"
#import "AppDelegate+UIActions.h"
#import "../SystemBridge/PHTVManager.h"
#import <Sparkle/Sparkle.h>
#import "PHTV-Swift.h"
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

@implementation AppDelegate

- (void)dealloc {
    [self stopInputSourceMonitoring];
    
    [self stopAccessibilityMonitoring];
    [self stopHealthCheckMonitoring];
}

@end
