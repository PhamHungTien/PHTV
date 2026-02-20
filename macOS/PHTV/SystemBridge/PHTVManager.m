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
#import "PHTVManager+SwiftBridgePrivate.h"

extern void PHTVSetCheckSpellingCpp(void) __asm("__Z17vSetCheckSpellingv");

@implementation PHTVManager

#pragma mark - Core Functionality

+(BOOL)hasPermissionLost {
    return [PHTVEventTapService hasPermissionLost];
}

+(void)markPermissionLost {
    [PHTVEventTapService markPermissionLost];
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
    return [PHTVEventTapService isEventTapInited];
}

+(BOOL)initEventTap {
    return [PHTVEventTapService initEventTap];
}

+(BOOL)stopEventTap {
    return [PHTVEventTapService stopEventTap];
}

// Recover when the event tap is disabled by the system (timeout/user input)
+(void)handleEventTapDisabled:(CGEventType)type {
    [PHTVEventTapService handleEventTapDisabled:type];
}

// Query current state of the tap
+(BOOL)isEventTapEnabled {
    return [PHTVEventTapService isEventTapEnabled];
}

// Ensure the tap stays alive for long-running sessions
+(void)ensureEventTapAlive {
    [PHTVEventTapService ensureEventTapAlive];
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
