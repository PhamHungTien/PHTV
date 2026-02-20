//
//  PHTVManager.m
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import "PHTVManager.h"
#import <Sparkle/Sparkle.h>
#import "PHTV-Swift.h"
#import "../Application/PHTVSettingsRuntime.h"
#import "../Core/PHTVHotkey.h"
#import "PHTVCoreBridge.h"

extern void PHTVInit(void);

extern CGEventRef PHTVCallback(CGEventTapProxy proxy,
                                  CGEventType type,
                                  CGEventRef event,
                                  void *refcon);

extern void RequestNewSession(void);
extern void InvalidateLayoutCache(void);
extern void OnInputMethodChanged(void);
extern void OnTableCodeChange(void);
extern void OnActiveAppChanged(void);
extern volatile int vLanguage;
extern volatile int vInputType;
extern int vFreeMark;
extern volatile int vCodeTable;
extern int vShowIconOnDock;
extern volatile int vCheckSpelling;
extern volatile int vAllowConsonantZFWJ;
extern volatile int vUseModernOrthography;
extern volatile int vQuickTelex;
extern volatile int vUseMacro;
extern volatile int vUseMacroInEnglishMode;
extern volatile int vAutoCapsMacro;
extern volatile int vSendKeyStepByStep;
extern volatile int vUseSmartSwitchKey;
extern volatile int vUpperCaseExcludedForCurrentApp;
extern volatile int vFixRecommendBrowser;
extern volatile int vUpperCaseFirstChar;
extern volatile int vTempOffSpelling;
extern volatile int vQuickStartConsonant;
extern volatile int vQuickEndConsonant;
extern volatile int vRememberCode;
extern volatile int vOtherLanguage;
extern volatile int vTempOffPHTV;
extern volatile int vPerformLayoutCompat;
extern volatile int vRestoreOnEscape;
extern volatile int vCustomEscapeKey;
extern volatile int vPauseKeyEnabled;
extern volatile int vPauseKey;
extern volatile int vAutoRestoreEnglishWord;
extern volatile int vSwitchKeyStatus;
extern volatile int vEnableEmojiHotkey;
extern volatile int vEmojiHotkeyModifiers;
extern volatile int vEmojiHotkeyKeyCode;
extern void PHTVSetCheckSpellingCpp(void) __asm("__Z17vSetCheckSpellingv");

static NSString *const PHTVDefaultsKeySpelling = @"Spelling";
static NSString *const PHTVDefaultsKeyAllowConsonantZFWJ = @"vAllowConsonantZFWJ";
static NSString *const PHTVDefaultsKeyModernOrthography = @"ModernOrthography";
static NSString *const PHTVDefaultsKeyQuickTelex = @"QuickTelex";
static NSString *const PHTVDefaultsKeyUpperCaseFirstChar = @"UpperCaseFirstChar";
static NSString *const PHTVDefaultsKeyAutoRestoreEnglishWord = @"vAutoRestoreEnglishWord";

static int PHTVToggleRuntimeIntSetting(volatile int *target,
                                       NSString *key,
                                       BOOL syncSpellingBeforeSessionReset) {
    *target = !(*target);
    __sync_synchronize();

    [[NSUserDefaults standardUserDefaults] setInteger:*target forKey:key];

    if (syncSpellingBeforeSessionReset) {
        PHTVSetCheckSpellingCpp();
    }

    RequestNewSession();
    return *target;
}

@interface PHTVManager (PHTVSystemServicesBridge)

+(BOOL)phtv_isTCCEntryCorrupt;
+(BOOL)phtv_autoFixTCCEntryWithError:(NSError **)error;
+(void)phtv_restartTCCDaemon;
+(void)phtv_startTCCNotificationListener;
+(void)phtv_stopTCCNotificationListener;
+(NSArray *)phtv_getTableCodes;
+(NSString *)phtv_getApplicationSupportFolder;
+(NSString *)phtv_getBinaryArchitectures;
+(NSString *)phtv_getBinaryHash;
+(BOOL)phtv_hasBinaryChangedSinceLastRun;
+(BOOL)phtv_checkBinaryIntegrity;
+(BOOL)phtv_quickConvert;
+(BOOL)phtv_isSafeModeEnabled;
+(void)phtv_setSafeModeEnabled:(BOOL)enabled;
+(void)phtv_clearAXTestFlag;

@end

@implementation PHTVManager {

}

static BOOL _isInited = NO;
static BOOL _permissionLost = NO;  // CRITICAL: Flag to prevent event processing when permission is revoked

static CFMachPortRef      eventTap;
static CGEventMask        eventMask;
static CFRunLoopSourceRef runLoopSource;
static NSUInteger         _tapReenableCount = 0;
static NSUInteger         _tapRecreateCount = 0;

#pragma mark - Core Functionality

+(BOOL)hasPermissionLost {
    return _permissionLost;
}

+(void)markPermissionLost {
    _permissionLost = YES;

    // CRITICAL: INVALIDATE event tap IMMEDIATELY (not just disable)
    // This must happen synchronously in callback thread to prevent kernel deadlock
    if (eventTap != nil) {
        CGEventTapEnable(eventTap, false);
        CFMachPortInvalidate(eventTap);  // Invalidate to stop receiving events completely
        NSLog(@"🛑🛑🛑 EMERGENCY: Event tap INVALIDATED due to permission loss!");
    }
}

// Invalidate permission check cache - forces fresh check on next call
+(void)invalidatePermissionCache {
    [PHTVPermissionService invalidatePermissionCache];
}

// Check if TCC entry is corrupt (app not appearing in System Settings)
+(BOOL)isTCCEntryCorrupt {
    return [self phtv_isTCCEntryCorrupt];
}

// Automatically fix TCC entry corruption by running tccutil reset
// Returns YES if successful, NO if failed or user cancelled
+(BOOL)autoFixTCCEntryWithError:(NSError **)error {
    return [self phtv_autoFixTCCEntryWithError:error];
}

// Restart per-user tccd daemon to force TCC to reload fresh entries
+(void)restartTCCDaemon {
    [self phtv_restartTCCDaemon];
}

#pragma mark - TCC Notification Listener

// Start listening for TCC database changes
+(void)startTCCNotificationListener {
    [self phtv_startTCCNotificationListener];
}

// Stop listening for TCC changes
+(void)stopTCCNotificationListener {
    [self phtv_stopTCCNotificationListener];
}

// SIMPLE permission check using ONLY test event tap (Apple recommended)
// This is the ONLY reliable way to check accessibility permission
// AXIsProcessTrusted() is unreliable - it can return YES even when permission is not effective
+(BOOL)canCreateEventTap {
    return [PHTVPermissionService canCreateEventTap];
}

// Force permission check (bypasses all caching)
+(BOOL)forcePermissionCheck {
    return [PHTVPermissionService forcePermissionCheck];
}

+(BOOL)isInited {
    return _isInited;
}

+(BOOL)initEventTap {
    if (_isInited)
        return true;

    // Reset permission lost flag (fresh start)
    _permissionLost = NO;

    // Invalidate permission check cache on init
    [PHTVPermissionService invalidatePermissionCache];

    // Initialize PHTV engine
    PHTVInit();

    // Create an event tap. We are interested in key presses.
    eventMask = ((1 << kCGEventKeyDown) |
                 (1 << kCGEventKeyUp) |
                 (1 << kCGEventFlagsChanged) |
                 (1 << kCGEventLeftMouseDown) |
                 (1 << kCGEventRightMouseDown));

    // Prefer HID-level event tap for better timing (fixes swallowed keystrokes in terminals)
    eventTap = CGEventTapCreate(kCGHIDEventTap,
                                kCGHeadInsertEventTap,
                                0,
                                eventMask,
                                PHTVCallback,
                                NULL);

    if (!eventTap) {
        NSLog(@"[EventTap] HID tap failed, falling back to session tap");
        eventTap = CGEventTapCreate(kCGSessionEventTap,
                                    kCGHeadInsertEventTap,
                                    0,
                                    eventMask,
                                    PHTVCallback,
                                    NULL);
    }

    if (!eventTap) {
        fprintf(stderr, "Failed to create event tap\n");
        return NO;
    }

    _isInited = YES;
    
    // Create a run loop source.
    runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
    
    // Add to the MAIN run loop (don't create new run loop!)
    CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, kCFRunLoopCommonModes);
    
    // Enable the event tap.
    CGEventTapEnable(eventTap, true);
    
    // IMPORTANT: Do NOT call CFRunLoopRun() here!
    // The main run loop is already running. Calling CFRunLoopRun() would:
    // 1. Block the current thread indefinitely
    // 2. Prevent UI updates and menu bar interactions
    // 3. Make the app unresponsive
    //
    // The event tap will receive events automatically from the main run loop.
    
    NSLog(@"[EventTap] Enabled and added to main run loop");
    
    return YES;
}

+(BOOL)stopEventTap {
    if (_isInited) {
        NSLog(@"[EventTap] Stopping...");

        // Disable the event tap first (safe to call even if already disabled)
        if (eventTap != nil) {
            CGEventTapEnable(eventTap, false);
        }

        // Remove from run loop (MUST be on main thread)
        if (runLoopSource != nil) {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, kCFRunLoopCommonModes);
            CFRelease(runLoopSource);
            runLoopSource = nil;
        }

        // Invalidate and release the event tap (safe even if already invalidated)
        if (eventTap != nil) {
            // Check if port is still valid before invalidating
            if (CFMachPortIsValid(eventTap)) {
                CFMachPortInvalidate(eventTap);
            }
            CFRelease(eventTap);
            eventTap = nil;
        }

        _isInited = false;
        _permissionLost = NO;  // Reset flag when fully stopped

        NSLog(@"[EventTap] Stopped successfully");
    }
    return YES;
}

// Recover when the event tap is disabled by the system (timeout/user input)
+(void)handleEventTapDisabled:(CGEventType)type {
    if (!_isInited) return;

    const char *reason = (type == kCGEventTapDisabledByTimeout) ? "timeout" : "user input";
    NSLog(@"[EventTap] Disabled by %s — attempting to re-enable", reason);

    _tapReenableCount++;
    CGEventTapEnable(eventTap, true);

    // If re-enable failed (tap still disabled), recreate it on the main queue to avoid deadlocks
    if (!CGEventTapIsEnabled(eventTap)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!_isInited) return;
            NSLog(@"[EventTap] Re-enabling failed, recreating event tap");
            _tapRecreateCount++;
            [self stopEventTap];
            [self initEventTap];
        });
    }
}

// Query current state of the tap
+(BOOL)isEventTapEnabled {
    if (!_isInited || eventTap == nil) return NO;
    return CGEventTapIsEnabled(eventTap);
}

// Ensure the tap stays alive for long-running sessions
+(void)ensureEventTapAlive {
    if (!_isInited) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!_isInited) {
                [self initEventTap];
            }
        });
        return;
    }

    if (eventTap == nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self initEventTap];
        });
        return;
    }

    // Check if tap is disabled OR not receiving events properly
    BOOL isEnabled = CGEventTapIsEnabled(eventTap);
    
    if (!isEnabled) {
        _tapReenableCount++;
        NSLog(@"[EventTap] Health check: tap disabled — re-enabling (count=%lu)", (unsigned long)_tapReenableCount);
        CGEventTapEnable(eventTap, true);

        if (!CGEventTapIsEnabled(eventTap)) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!_isInited) return;
                _tapRecreateCount++;
                NSLog(@"[EventTap] Health check: re-enable failed — recreating tap (count=%lu)", (unsigned long)_tapRecreateCount);
                [self stopEventTap];
                [self initEventTap];
            });
        }
    }
}

#pragma mark - Table Codes

+(NSArray*)getTableCodes {
    return [self phtv_getTableCodes];
}

#pragma mark - Utilities

+(NSString*)getBuildDate {
    return [NSString stringWithUTF8String:__DATE__];
}

+(void)showMessage:(NSWindow*)window message:(NSString*)msg subMsg:(NSString*)subMsg {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:msg];
    [alert setInformativeText:subMsg];
    [alert addButtonWithTitle:@"OK"];
    if (window) {
        [alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse returnCode) {
        }];
    } else {
        [alert runModal];
    }
}

+(void)requestNewSession {
    RequestNewSession();
}

+(void)invalidateLayoutCache {
    InvalidateLayoutCache();
}

+(int)currentLanguage {
    return vLanguage;
}

+(void)setCurrentLanguage:(int)language {
    vLanguage = language;
    __sync_synchronize();
}

+(int)otherLanguageMode {
    return vOtherLanguage;
}

+(int)currentInputType {
    return vInputType;
}

+(void)setCurrentInputType:(int)inputType {
    vInputType = inputType;
    __sync_synchronize();
}

+(int)currentCodeTable {
    return vCodeTable;
}

+(void)setCurrentCodeTable:(int)codeTable {
    vCodeTable = codeTable;
    __sync_synchronize();
}

+(BOOL)isSmartSwitchKeyEnabled {
    return vUseSmartSwitchKey != 0;
}

+(void)notifyInputMethodChanged {
    OnInputMethodChanged();
}

+(void)notifyTableCodeChanged {
    OnTableCodeChange();
}

+(void)notifyActiveAppChanged {
    OnActiveAppChanged();
}

+(BOOL)isSendKeyStepByStepEnabled {
    return vSendKeyStepByStep != 0;
}

+(void)setSendKeyStepByStepEnabled:(BOOL)enabled {
    vSendKeyStepByStep = enabled ? 1 : 0;
    __sync_synchronize();
}

+(void)setUpperCaseExcludedForCurrentApp:(BOOL)excluded {
    vUpperCaseExcludedForCurrentApp = excluded ? 1 : 0;
}

+(NSDictionary<NSString *, NSNumber *> *)runtimeSettingsSnapshot {
    return @{
        @"checkSpelling": @(vCheckSpelling),
        @"useModernOrthography": @(vUseModernOrthography),
        @"quickTelex": @(vQuickTelex),
        @"switchKeyStatus": @(vSwitchKeyStatus),
        @"useMacro": @(vUseMacro),
        @"useMacroInEnglishMode": @(vUseMacroInEnglishMode),
        @"autoCapsMacro": @(vAutoCapsMacro),
        @"sendKeyStepByStep": @(vSendKeyStepByStep),
        @"useSmartSwitchKey": @(vUseSmartSwitchKey),
        @"upperCaseFirstChar": @(vUpperCaseFirstChar),
        @"allowConsonantZFWJ": @(vAllowConsonantZFWJ),
        @"quickStartConsonant": @(vQuickStartConsonant),
        @"quickEndConsonant": @(vQuickEndConsonant),
        @"rememberCode": @(vRememberCode),
        @"performLayoutCompat": @(vPerformLayoutCompat),
        @"showIconOnDock": @(vShowIconOnDock),
        @"restoreOnEscape": @(vRestoreOnEscape),
        @"customEscapeKey": @(vCustomEscapeKey),
        @"pauseKeyEnabled": @(vPauseKeyEnabled),
        @"pauseKey": @(vPauseKey),
        @"autoRestoreEnglishWord": @(vAutoRestoreEnglishWord),
        @"enableEmojiHotkey": @(vEnableEmojiHotkey),
        @"emojiHotkeyModifiers": @(vEmojiHotkeyModifiers),
        @"emojiHotkeyKeyCode": @(vEmojiHotkeyKeyCode)
    };
}

+(int)currentSwitchKeyStatus {
    return vSwitchKeyStatus;
}

+(void)setSwitchKeyStatus:(int)status {
    vSwitchKeyStatus = status;
    __sync_synchronize();
}

+(void)loadEmojiHotkeySettingsFromDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    PHTVLoadEmojiHotkeySettings(defaults, &vEnableEmojiHotkey, &vEmojiHotkeyModifiers, &vEmojiHotkeyKeyCode);
    __sync_synchronize();
}

+(void)syncSpellingSetting {
    PHTVSetCheckSpellingCpp();
}

+(void)setDockIconRuntimeVisible:(BOOL)visible {
    vShowIconOnDock = visible ? 1 : 0;
}

+(int)toggleSpellCheckSetting {
    return PHTVToggleRuntimeIntSetting(&vCheckSpelling, PHTVDefaultsKeySpelling, YES);
}

+(int)toggleAllowConsonantZFWJSetting {
    return PHTVToggleRuntimeIntSetting(&vAllowConsonantZFWJ, PHTVDefaultsKeyAllowConsonantZFWJ, NO);
}

+(int)toggleModernOrthographySetting {
    return PHTVToggleRuntimeIntSetting(&vUseModernOrthography, PHTVDefaultsKeyModernOrthography, NO);
}

+(int)toggleQuickTelexSetting {
    return PHTVToggleRuntimeIntSetting(&vQuickTelex, PHTVDefaultsKeyQuickTelex, NO);
}

+(int)toggleUpperCaseFirstCharSetting {
    return PHTVToggleRuntimeIntSetting(&vUpperCaseFirstChar, PHTVDefaultsKeyUpperCaseFirstChar, NO);
}

+(int)toggleAutoRestoreEnglishWordSetting {
    return PHTVToggleRuntimeIntSetting(&vAutoRestoreEnglishWord, PHTVDefaultsKeyAutoRestoreEnglishWord, NO);
}

+(NSUInteger)loadRuntimeSettingsFromUserDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    vLanguage = PHTVReadIntWithFallback(defaults, @"InputMethod", vLanguage);
    vInputType = PHTVReadIntWithFallback(defaults, @"InputType", vInputType);
    vCodeTable = PHTVReadIntWithFallback(defaults, @"CodeTable", vCodeTable);
    NSLog(@"[AppDelegate] Loaded core settings: language=%d, inputType=%d, codeTable=%d",
          vLanguage, vInputType, vCodeTable);

    vUseModernOrthography = PHTVReadIntWithFallback(defaults, @"ModernOrthography", vUseModernOrthography);
    vQuickTelex = PHTVReadIntWithFallback(defaults, @"QuickTelex", vQuickTelex);
    vFreeMark = PHTVReadIntWithFallback(defaults, @"FreeMark", vFreeMark);

    vUseMacro = PHTVReadIntWithFallback(defaults, @"UseMacro", vUseMacro);
    vUseMacroInEnglishMode = PHTVReadIntWithFallback(defaults, @"UseMacroInEnglishMode", vUseMacroInEnglishMode);
    vAutoCapsMacro = PHTVReadIntWithFallback(defaults, @"vAutoCapsMacro", vAutoCapsMacro);

    vSendKeyStepByStep = PHTVReadIntWithFallback(defaults, @"SendKeyStepByStep", vSendKeyStepByStep);
    vUseSmartSwitchKey = PHTVReadIntWithFallback(defaults, @"UseSmartSwitchKey", vUseSmartSwitchKey);
    vUpperCaseFirstChar = PHTVReadIntWithFallback(defaults, @"UpperCaseFirstChar", vUpperCaseFirstChar);
    vAllowConsonantZFWJ = PHTVReadIntWithFallback(defaults, @"vAllowConsonantZFWJ", 1);
    vQuickStartConsonant = PHTVReadIntWithFallback(defaults, @"vQuickStartConsonant", vQuickStartConsonant);
    vQuickEndConsonant = PHTVReadIntWithFallback(defaults, @"vQuickEndConsonant", vQuickEndConsonant);
    vRememberCode = PHTVReadIntWithFallback(defaults, @"vRememberCode", vRememberCode);
    vPerformLayoutCompat = PHTVReadIntWithFallback(defaults, @"vPerformLayoutCompat", vPerformLayoutCompat);

    vRestoreOnEscape = PHTVReadIntWithFallback(defaults, @"vRestoreOnEscape", vRestoreOnEscape);
    vCustomEscapeKey = PHTVReadIntWithFallback(defaults, @"vCustomEscapeKey", vCustomEscapeKey);

    vPauseKeyEnabled = PHTVReadIntWithFallback(defaults, @"vPauseKeyEnabled", vPauseKeyEnabled);
    vPauseKey = PHTVReadIntWithFallback(defaults, @"vPauseKey", vPauseKey);

    vAutoRestoreEnglishWord = PHTVReadIntWithFallback(defaults, @"vAutoRestoreEnglishWord", vAutoRestoreEnglishWord);
    vShowIconOnDock = PHTVReadIntWithFallback(defaults, @"vShowIconOnDock", vShowIconOnDock);

    NSInteger savedHotkey = [defaults integerForKey:@"SwitchKeyStatus"];
    if (savedHotkey != 0) {
        vSwitchKeyStatus = (int)savedHotkey;
        NSLog(@"[AppDelegate] Loaded hotkey from UserDefaults: 0x%X", vSwitchKeyStatus);
    } else {
        NSLog(@"[AppDelegate] No saved hotkey found, using default: 0x%X", vSwitchKeyStatus);
    }

    PHTVLoadEmojiHotkeySettings(defaults, &vEnableEmojiHotkey, &vEmojiHotkeyModifiers, &vEmojiHotkeyKeyCode);

    NSUInteger settingsToken = PHTVComputeSettingsToken(defaults);
    NSLog(@"[AppDelegate] All settings loaded from UserDefaults");

    __sync_synchronize();
    return settingsToken;
}

+(void)loadDefaultConfig {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    vLanguage = 1;
    [defaults setInteger:vLanguage forKey:@"InputMethod"];

    vInputType = 0;
    [defaults setInteger:vInputType forKey:@"InputType"];

    vFreeMark = 0;
    [defaults setInteger:vFreeMark forKey:@"FreeMark"];

    vCheckSpelling = 1;
    [defaults setInteger:vCheckSpelling forKey:@"Spelling"];

    vCodeTable = 0;
    [defaults setInteger:vCodeTable forKey:@"CodeTable"];

    vSwitchKeyStatus = PHTV_DEFAULT_SWITCH_HOTKEY_STATUS;
    [defaults setInteger:vSwitchKeyStatus forKey:@"SwitchKeyStatus"];

    vQuickTelex = 0;
    [defaults setInteger:vQuickTelex forKey:@"QuickTelex"];

    vUseModernOrthography = 1;
    [defaults setInteger:vUseModernOrthography forKey:@"ModernOrthography"];

    vFixRecommendBrowser = 1;
    [defaults setInteger:vFixRecommendBrowser forKey:@"FixRecommendBrowser"];

    vUseMacro = 1;
    [defaults setInteger:vUseMacro forKey:@"UseMacro"];

    vUseMacroInEnglishMode = 0;
    [defaults setInteger:vUseMacroInEnglishMode forKey:@"UseMacroInEnglishMode"];

    vSendKeyStepByStep = 0;
    [defaults setInteger:vSendKeyStepByStep forKey:@"SendKeyStepByStep"];

    vUseSmartSwitchKey = 1;
    [defaults setInteger:vUseSmartSwitchKey forKey:@"UseSmartSwitchKey"];

    vUpperCaseFirstChar = 0;
    [defaults setInteger:vUpperCaseFirstChar forKey:@"UpperCaseFirstChar"];

    vTempOffSpelling = 0;
    [defaults setInteger:vTempOffSpelling forKey:@"vTempOffSpelling"];

    vAllowConsonantZFWJ = 1;
    [defaults setInteger:vAllowConsonantZFWJ forKey:@"vAllowConsonantZFWJ"];

    vQuickStartConsonant = 0;
    [defaults setInteger:vQuickStartConsonant forKey:@"vQuickStartConsonant"];

    vQuickEndConsonant = 0;
    [defaults setInteger:vQuickEndConsonant forKey:@"vQuickEndConsonant"];

    vRememberCode = 1;
    [defaults setInteger:vRememberCode forKey:@"vRememberCode"];

    vOtherLanguage = 1;
    [defaults setInteger:vOtherLanguage forKey:@"vOtherLanguage"];

    vTempOffPHTV = 0;
    [defaults setInteger:vTempOffPHTV forKey:@"vTempOffPHTV"];

    vAutoRestoreEnglishWord = 1;
    [defaults setInteger:vAutoRestoreEnglishWord forKey:@"vAutoRestoreEnglishWord"];

    vRestoreOnEscape = 1;
    [defaults setInteger:vRestoreOnEscape forKey:@"vRestoreOnEscape"];

    vCustomEscapeKey = 0;
    [defaults setInteger:vCustomEscapeKey forKey:@"vCustomEscapeKey"];

    vShowIconOnDock = 0;
    [defaults setInteger:vShowIconOnDock forKey:@"vShowIconOnDock"];

    vPerformLayoutCompat = 0;
    [defaults setInteger:vPerformLayoutCompat forKey:@"vPerformLayoutCompat"];

    [defaults setInteger:1 forKey:@"GrayIcon"];
    [defaults setBool:NO forKey:@"PHTV_RunOnStartup"];
    [defaults setInteger:0 forKey:@"RunOnStartup"];
    [defaults setInteger:1 forKey:@"vSettingsWindowAlwaysOnTop"];
    [defaults setInteger:0 forKey:@"vBeepOnModeSwitch"];
    [defaults setDouble:0.5 forKey:@"vBeepVolume"];
    [defaults setDouble:18.0 forKey:@"vMenuBarIconSize"];
    [defaults setInteger:0 forKey:@"vUseVietnameseMenubarIcon"];

    [defaults setInteger:86400 forKey:@"SUScheduledCheckInterval"];
    [defaults setBool:YES forKey:@"vAutoInstallUpdates"];

    [defaults setBool:YES forKey:@"vIncludeSystemInfo"];
    [defaults setBool:NO forKey:@"vIncludeLogs"];
    [defaults setBool:YES forKey:@"vIncludeCrashLogs"];

    __sync_synchronize();
}

#pragma mark - Convert Feature

+(BOOL)quickConvert {
    return [self phtv_quickConvert];
}

#pragma mark - Application Support

+(NSString*)getApplicationSupportFolder {
    return [self phtv_getApplicationSupportFolder];
}

#pragma mark - Safe Mode

+(BOOL)isSafeModeEnabled {
    return [self phtv_isSafeModeEnabled];
}

+(void)setSafeModeEnabled:(BOOL)enabled {
    [self phtv_setSafeModeEnabled:enabled];
}

+(void)clearAXTestFlag {
    [self phtv_clearAXTestFlag];
}

#pragma mark - Binary Integrity Check
// Public API wrappers delegate to Swift service helpers.

+(NSString*)getBinaryArchitectures {
    return [self phtv_getBinaryArchitectures];
}

+(NSString*)getBinaryHash {
    return [self phtv_getBinaryHash];
}

+(BOOL)hasBinaryChangedSinceLastRun {
    return [self phtv_hasBinaryChangedSinceLastRun];
}

+(BOOL)checkBinaryIntegrity {
    return [self phtv_checkBinaryIntegrity];
}

@end
