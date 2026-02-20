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
#import "PHTVCoreBridge.h"

extern void PHTVInit(void);

extern CGEventRef PHTVCallback(CGEventTapProxy proxy,
                                  CGEventType type,
                                  CGEventRef event,
                                  void *refcon);

extern void PHTVSetCheckSpellingCpp(void) __asm("__Z17vSetCheckSpellingv");

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
+(void)phtv_requestNewSession;
+(void)phtv_invalidateLayoutCache;
+(void)phtv_notifyInputMethodChanged;
+(void)phtv_notifyTableCodeChanged;
+(void)phtv_notifyActiveAppChanged;
+(int)phtv_currentLanguage;
+(void)phtv_setCurrentLanguage:(int)language;
+(int)phtv_otherLanguageMode;
+(int)phtv_currentInputType;
+(void)phtv_setCurrentInputType:(int)inputType;
+(int)phtv_currentCodeTable;
+(void)phtv_setCurrentCodeTable:(int)codeTable;
+(BOOL)phtv_isSmartSwitchKeyEnabled;
+(BOOL)phtv_isSendKeyStepByStepEnabled;
+(void)phtv_setSendKeyStepByStepEnabled:(BOOL)enabled;
+(void)phtv_setUpperCaseExcludedForCurrentApp:(BOOL)excluded;
+(int)phtv_currentSwitchKeyStatus;
+(void)phtv_setSwitchKeyStatus:(int)status;
+(void)phtv_setDockIconRuntimeVisible:(BOOL)visible;
+(int)phtv_toggleSpellCheckSetting;
+(int)phtv_toggleAllowConsonantZFWJSetting;
+(int)phtv_toggleModernOrthographySetting;
+(int)phtv_toggleQuickTelexSetting;
+(int)phtv_toggleUpperCaseFirstCharSetting;
+(int)phtv_toggleAutoRestoreEnglishWordSetting;
+(NSDictionary<NSString *, NSNumber *> *)phtv_runtimeSettingsSnapshot;
+(void)phtv_loadEmojiHotkeySettingsFromDefaults;
+(NSUInteger)phtv_loadRuntimeSettingsFromUserDefaults;
+(void)phtv_loadDefaultConfig;

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
    [self phtv_requestNewSession];
}

+(void)invalidateLayoutCache {
    [self phtv_invalidateLayoutCache];
}

+(int)currentLanguage {
    return [self phtv_currentLanguage];
}

+(void)setCurrentLanguage:(int)language {
    [self phtv_setCurrentLanguage:language];
}

+(int)otherLanguageMode {
    return [self phtv_otherLanguageMode];
}

+(int)currentInputType {
    return [self phtv_currentInputType];
}

+(void)setCurrentInputType:(int)inputType {
    [self phtv_setCurrentInputType:inputType];
}

+(int)currentCodeTable {
    return [self phtv_currentCodeTable];
}

+(void)setCurrentCodeTable:(int)codeTable {
    [self phtv_setCurrentCodeTable:codeTable];
}

+(BOOL)isSmartSwitchKeyEnabled {
    return [self phtv_isSmartSwitchKeyEnabled];
}

+(void)notifyInputMethodChanged {
    [self phtv_notifyInputMethodChanged];
}

+(void)notifyTableCodeChanged {
    [self phtv_notifyTableCodeChanged];
}

+(void)notifyActiveAppChanged {
    [self phtv_notifyActiveAppChanged];
}

+(BOOL)isSendKeyStepByStepEnabled {
    return [self phtv_isSendKeyStepByStepEnabled];
}

+(void)setSendKeyStepByStepEnabled:(BOOL)enabled {
    [self phtv_setSendKeyStepByStepEnabled:enabled];
}

+(void)setUpperCaseExcludedForCurrentApp:(BOOL)excluded {
    [self phtv_setUpperCaseExcludedForCurrentApp:excluded];
}

+(NSDictionary<NSString *, NSNumber *> *)runtimeSettingsSnapshot {
    return [self phtv_runtimeSettingsSnapshot];
}

+(int)currentSwitchKeyStatus {
    return [self phtv_currentSwitchKeyStatus];
}

+(void)setSwitchKeyStatus:(int)status {
    [self phtv_setSwitchKeyStatus:status];
}

+(void)loadEmojiHotkeySettingsFromDefaults {
    [self phtv_loadEmojiHotkeySettingsFromDefaults];
}

+(void)syncSpellingSetting {
    PHTVSetCheckSpellingCpp();
}

+(void)setDockIconRuntimeVisible:(BOOL)visible {
    [self phtv_setDockIconRuntimeVisible:visible];
}

+(int)toggleSpellCheckSetting {
    return [self phtv_toggleSpellCheckSetting];
}

+(int)toggleAllowConsonantZFWJSetting {
    return [self phtv_toggleAllowConsonantZFWJSetting];
}

+(int)toggleModernOrthographySetting {
    return [self phtv_toggleModernOrthographySetting];
}

+(int)toggleQuickTelexSetting {
    return [self phtv_toggleQuickTelexSetting];
}

+(int)toggleUpperCaseFirstCharSetting {
    return [self phtv_toggleUpperCaseFirstCharSetting];
}

+(int)toggleAutoRestoreEnglishWordSetting {
    return [self phtv_toggleAutoRestoreEnglishWordSetting];
}

+(NSUInteger)loadRuntimeSettingsFromUserDefaults {
    return [self phtv_loadRuntimeSettingsFromUserDefaults];
}

+(void)loadDefaultConfig {
    [self phtv_loadDefaultConfig];
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
