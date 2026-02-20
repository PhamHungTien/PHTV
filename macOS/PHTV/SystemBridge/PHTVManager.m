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
#import <unistd.h>
#import <math.h>

extern void PHTVInit(void);

extern CGEventRef PHTVCallback(CGEventTapProxy proxy,
                                  CGEventType type,
                                  CGEventRef event,
                                  void *refcon);

extern NSString* ConvertUtil(NSString* str);
extern BOOL vSafeMode;
extern void RequestNewSession(void);
extern void InvalidateLayoutCache(void);
extern void OnInputMethodChanged(void);
extern void OnTableCodeChange(void);
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

// No-op callback used only for permission test tap to satisfy nonnull parameter requirements
static CGEventRef PHTVTestTapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    // Simply pass events through unchanged
    return event;
}

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

@interface PHTVManager ()

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

// Cache for canCreateEventTap to avoid creating test taps too frequently
static BOOL _lastPermissionCheckResult = NO;
static NSTimeInterval _lastPermissionCheckTime = 0;
static NSInteger _permissionFailureCount = 0;
static NSTimeInterval _permissionBackoffUntil = 0;
static BOOL _lastPermissionOutcome = NO;
static BOOL _hasLastPermissionOutcome = NO;

// Dynamic cache TTL: NO CACHE when waiting for permission (immediate detection), long when permission granted
// This ensures instant detection when user grants permission while avoiding excessive test taps when running normally
static const NSTimeInterval kCacheTTLWaitingForPermission = 0.0;  // NO CACHE when waiting - CRITICAL for fast detection
static const NSTimeInterval kCacheTTLPermissionGranted = 5.0;     // 5s when granted (reduced from 10s)

// Retry configuration for test tap creation
static const int kMaxTestTapRetries = 3;           // Number of retry attempts
static const useconds_t kTestTapRetryDelayUs = 50000;  // 50ms between retries

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
    _lastPermissionCheckTime = 0;
    _lastPermissionCheckResult = NO;
    _permissionFailureCount = 0;
    _permissionBackoffUntil = 0;
    _hasLastPermissionOutcome = NO;
    NSLog(@"[Permission] Cache invalidated - next check will be fresh");
}

// Check if TCC entry is corrupt (app not appearing in System Settings)
+(BOOL)isTCCEntryCorrupt {
    // If permission check fails but app is not registered in TCC, entry is corrupt
    BOOL hasPermission = [self canCreateEventTap];
    if (hasPermission) {
        return NO;  // Permission granted - TCC entry is fine
    }

    // Permission denied - check if app is registered in TCC
    BOOL isRegistered = [PHTVTCCMaintenanceService isAppRegisteredInTCC];
    if (!isRegistered) {
        NSLog(@"[TCC] ⚠️ CORRUPT ENTRY DETECTED - App not found in TCC database!");
        return YES;
    }

    return NO;  // App is registered, just waiting for user to grant permission
}

// Automatically fix TCC entry corruption by running tccutil reset
// Returns YES if successful, NO if failed or user cancelled
+(BOOL)autoFixTCCEntryWithError:(NSError **)error {
    return [PHTVTCCMaintenanceService autoFixTCCEntryWithError:error];
}

// Restart per-user tccd daemon to force TCC to reload fresh entries
+(void)restartTCCDaemon {
    [PHTVTCCMaintenanceService restartTCCDaemon];
}

#pragma mark - TCC Notification Listener

// Start listening for TCC database changes
+(void)startTCCNotificationListener {
    [PHTVTCCNotificationService startListening];
}

// Stop listening for TCC changes
+(void)stopTCCNotificationListener {
    [PHTVTCCNotificationService stopListening];
}

// Helper: Try to create test tap with retries
// Returns YES if test tap was successfully created (permission granted)
+(BOOL)tryCreateTestTapWithRetries {
    for (int attempt = 0; attempt < kMaxTestTapRetries; attempt++) {
        CFMachPortRef testTap = CGEventTapCreate(
            kCGSessionEventTap,
            kCGTailAppendEventTap,
            kCGEventTapOptionDefault,
            CGEventMaskBit(kCGEventKeyDown),
            PHTVTestTapCallback,
            NULL
        );

        if (testTap != NULL) {
            // Success - clean up and return
            CFMachPortInvalidate(testTap);
            CFRelease(testTap);
            #ifdef DEBUG
            if (attempt > 0) {
                NSLog(@"[Permission] Test tap SUCCESS on attempt %d", attempt + 1);
            }
            #endif
            return YES;
        }

        // Failed - wait briefly before retry (except on last attempt)
        if (attempt < kMaxTestTapRetries - 1) {
            usleep(kTestTapRetryDelayUs);
        }
    }

    #ifdef DEBUG
    NSLog(@"[Permission] Test tap FAILED after %d attempts", kMaxTestTapRetries);
    #endif
    return NO;
}

// SIMPLE permission check using ONLY test event tap (Apple recommended)
// This is the ONLY reliable way to check accessibility permission
// AXIsProcessTrusted() is unreliable - it can return YES even when permission is not effective
+(BOOL)canCreateEventTap {
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];

    // Honor exponential backoff when permission is repeatedly denied.
    // This prevents CGEventTapCreate hammering the system every 300ms while user hasn't granted permission.
    if (now < _permissionBackoffUntil) {
#ifdef DEBUG
        NSLog(@"[Permission] Backoff active for %.2fs (failures=%ld)", _permissionBackoffUntil - now, (long)_permissionFailureCount);
#endif
        return NO;
    }

    // Use DYNAMIC cache TTL based on current state
    // When waiting for permission (NO): NO CACHE - every check is fresh
    // When permission granted: use 5s TTL to reduce overhead
    NSTimeInterval cacheTTL = _lastPermissionCheckResult ? kCacheTTLPermissionGranted : kCacheTTLWaitingForPermission;

    if (cacheTTL > 0 && (now - _lastPermissionCheckTime < cacheTTL)) {
        return _lastPermissionCheckResult;
    }

    // ONLY trust test event tap creation - this is the ONLY reliable method
    BOOL hasPermission = [self tryCreateTestTapWithRetries];

    if (hasPermission) {
        _permissionFailureCount = 0;
        _permissionBackoffUntil = 0;
        if (!_hasLastPermissionOutcome || !_lastPermissionOutcome) {
            NSLog(@"[Permission] Check: TestTap=SUCCESS");
        }
    } else {
        _permissionFailureCount++;
        // Exponential backoff starting at 0.25s, max 15s
        NSTimeInterval backoff = MIN(15.0, pow(2.0, MIN(_permissionFailureCount, 6)) * 0.25);
        _permissionBackoffUntil = now + backoff;
        if (!_hasLastPermissionOutcome || _lastPermissionOutcome || (_permissionFailureCount % 5 == 1)) {
            NSLog(@"[Permission] Check: TestTap=FAILED (count=%ld) — backing off for %.2fs", (long)_permissionFailureCount, backoff);
        }
    }

    // Update cache
    _lastPermissionCheckResult = hasPermission;
    _lastPermissionCheckTime = now;
    _lastPermissionOutcome = hasPermission;
    _hasLastPermissionOutcome = YES;

    return hasPermission;
}

// Force permission check (bypasses all caching)
+(BOOL)forcePermissionCheck {
    [self invalidatePermissionCache];
    return [self canCreateEventTap];
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
    _lastPermissionCheckTime = 0;
    _lastPermissionCheckResult = NO;

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
    return [[NSArray alloc] initWithObjects:
            @"Unicode",
            @"TCVN3 (ABC)",
            @"VNI Windows",
            @"Unicode tổ hợp",
            @"Vietnamese Locale CP 1258", nil];
}

#pragma mark - Utilities

+(NSString*)getBuildDate {
    return [NSString stringWithUTF8String:__DATE__];
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

#pragma mark - Convert Feature

+(BOOL)quickConvert {
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    NSString *htmlString = [pasteboard stringForType:NSPasteboardTypeHTML];
    NSString *rawString = [pasteboard stringForType:NSPasteboardTypeString];
    bool converted = false;
    
    if (htmlString != nil) {
        htmlString = ConvertUtil(htmlString);
        converted = true;
    }
    if (rawString != nil) {
        rawString = ConvertUtil(rawString);
        converted = true;
    }
    if (converted) {
        [pasteboard clearContents];
        if (htmlString != nil)
            [pasteboard setString:htmlString forType:NSPasteboardTypeHTML];
        if (rawString != nil)
            [pasteboard setString:rawString forType:NSPasteboardTypeString];
        
        return YES;
    }
    return NO;
}

#pragma mark - Application Support

+(NSString*)getApplicationSupportFolder {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *applicationSupportDirectory = [paths firstObject];
    return [NSString stringWithFormat:@"%@/PHTV", applicationSupportDirectory];
}

#pragma mark - Safe Mode

+(BOOL)isSafeModeEnabled {
    return vSafeMode;
}

+(void)setSafeModeEnabled:(BOOL)enabled {
    vSafeMode = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:@"SafeMode"];

    if (enabled) {
        NSLog(@"[SafeMode] ENABLED - Accessibility API calls will be skipped");
    } else {
        NSLog(@"[SafeMode] DISABLED - Normal Accessibility API calls");
    }
}

+(void)clearAXTestFlag {
    // Clear the AX test flag on normal app termination
    // This prevents false positive safe mode activation on next launch
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"AXTestInProgress"];
    NSLog(@"[SafeMode] Cleared AX test flag on normal termination");
}

#pragma mark - Binary Integrity Check
// Implementation delegated directly to Swift service.

+(NSString*)getBinaryArchitectures {
    return [PHTVBinaryIntegrityService getBinaryArchitectures];
}

+(NSString*)getBinaryHash {
    return [PHTVBinaryIntegrityService getBinaryHash];
}

+(BOOL)hasBinaryChangedSinceLastRun {
    return [PHTVBinaryIntegrityService hasBinaryChangedSinceLastRun];
}

+(BOOL)checkBinaryIntegrity {
    return [PHTVBinaryIntegrityService checkBinaryIntegrity];
}

@end
