//
//  PHTVManager.m
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import "PHTVManager.h"
#import "PHTVBinaryIntegrity.h"

extern void PHTVInit(void);

extern CGEventRef PHTVCallback(CGEventTapProxy proxy,
                                  CGEventType type,
                                  CGEventRef event,
                                  void *refcon);

extern NSString* ConvertUtil(NSString* str);

// Safe Mode variable from PHTV.mm
extern BOOL vSafeMode;

// No-op callback used only for permission test tap to satisfy nonnull parameter requirements
static CGEventRef PHTVTestTapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    // Simply pass events through unchanged
    return event;
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

// Dynamic cache TTL: NO CACHE when waiting for permission (immediate detection), long when permission granted
// This ensures instant detection when user grants permission while avoiding excessive test taps when running normally
static const NSTimeInterval kCacheTTLWaitingForPermission = 0.0;  // NO CACHE when waiting - CRITICAL for fast detection
static const NSTimeInterval kCacheTTLPermissionGranted = 5.0;     // 5s when granted (reduced from 10s)

// Retry configuration for test tap creation
static const int kMaxTestTapRetries = 3;           // Number of retry attempts
static const useconds_t kTestTapRetryDelayUs = 50000;  // 50ms between retries

// Track if System Settings is currently open (for aggressive polling)
static BOOL _systemSettingsIsOpen = NO;

// Track consecutive AX=YES but Tap=NO states (indicates need for relaunch)
static int _axYesTapNoCount = 0;
static const int kMaxAxYesTapNoBeforeRelaunch = 5;  // After 5 consecutive occurrences, suggest relaunch

// TCC notification observer
static id _tccNotificationObserver = nil;

// Check if app is registered in TCC database for Accessibility
// Returns YES if app is present in TCC (regardless of permission state)
// Returns NO if TCC entry is corrupt/missing (app won't appear in System Settings)
static BOOL IsAppRegisteredInTCC(void) {
    // Try to query TCC database using tccutil
    // This checks if the app has ANY entry in TCC for Accessibility service
    NSTask *task = [[NSTask alloc] init];
    NSPipe *pipe = [NSPipe pipe];

    [task setLaunchPath:@"/usr/bin/tccutil"];
    [task setArguments:@[@"query", @"Accessibility"]];
    [task setStandardOutput:pipe];
    [task setStandardError:[NSPipe pipe]];

    NSError *error = nil;
    if (@available(macOS 10.13, *)) {
        [task launchAndReturnError:&error];
    } else {
        [task launch];
    }

    if (error) {
        NSLog(@"[TCC] Failed to query TCC database: %@", error);
        return YES;  // Assume registered if we can't check
    }

    [task waitUntilExit];

    NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
    NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    // Check if our bundle ID appears in the output
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    BOOL isRegistered = [output containsString:bundleID];

    NSLog(@"[TCC] App registration check: %@ (bundleID: %@)",
          isRegistered ? @"REGISTERED" : @"NOT FOUND", bundleID);

    return isRegistered;
}

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
    BOOL isRegistered = IsAppRegisteredInTCC();
    if (!isRegistered) {
        NSLog(@"[TCC] ⚠️ CORRUPT ENTRY DETECTED - App not found in TCC database!");
        return YES;
    }

    return NO;  // App is registered, just waiting for user to grant permission
}

// Automatically fix TCC entry corruption by running tccutil reset
// Returns YES if successful, NO if failed or user cancelled
+(BOOL)autoFixTCCEntryWithError:(NSError **)error {
    NSLog(@"[TCC] Auto-fix initiated...");

    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];

    // Create the shell script that will reset TCC
    NSString *script = [NSString stringWithFormat:@"#!/bin/sh\ntccutil reset Accessibility %@\nexit 0", bundleID];

    // Write script to temporary file
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"phtv_tcc_reset.sh"];
    NSError *writeError = nil;
    [script writeToFile:tempPath atomically:YES encoding:NSUTF8StringEncoding error:&writeError];

    if (writeError) {
        NSLog(@"[TCC] Failed to create temp script: %@", writeError);
        if (error) *error = writeError;
        return NO;
    }

    // Make script executable
    [[NSFileManager defaultManager] setAttributes:@{NSFilePosixPermissions: @(0755)}
                                     ofItemAtPath:tempPath
                                            error:nil];

    // Use osascript to run with administrator privileges
    // This will show the native macOS authentication dialog
    NSString *osascript = [NSString stringWithFormat:
        @"do shell script \"sh '%@'\" with administrator privileges", tempPath];

    NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:osascript];
    NSDictionary *errorDict = nil;
    [appleScript executeAndReturnError:&errorDict];

    // Clean up temp file
    [[NSFileManager defaultManager] removeItemAtPath:tempPath error:nil];

    if (errorDict) {
        NSLog(@"[TCC] Auto-fix failed or cancelled: %@", errorDict);
        if (error) {
            *error = [NSError errorWithDomain:@"com.phamhungtien.phtv.tcc"
                                         code:-1
                                     userInfo:errorDict];
        }
        return NO;
    }

    NSLog(@"[TCC] Auto-fix completed successfully");

    // Invalidate cache to trigger fresh check
    [self invalidatePermissionCache];

    // Wait briefly for TCC to update
    usleep(200000);  // 200ms

    return YES;
}

// Forward declaration for AXIsProcessTrusted
extern Boolean AXIsProcessTrusted(void) __attribute__((weak_import));

#pragma mark - TCC Notification Listener

// Start listening for TCC database changes
+(void)startTCCNotificationListener {
    if (_tccNotificationObserver != nil) {
        NSLog(@"[TCC] Notification listener already started");
        return;
    }

    NSLog(@"[TCC] Starting notification listener...");

    // Listen to distributed notification for TCC changes
    // macOS posts this notification when TCC database is modified
    NSDistributedNotificationCenter *center = [NSDistributedNotificationCenter defaultCenter];

    _tccNotificationObserver = [center addObserverForName:@"com.apple.accessibility.api"
                                                   object:nil
                                                    queue:[NSOperationQueue mainQueue]
                                               usingBlock:^(NSNotification *notification) {
        NSLog(@"[TCC] 🔔 TCC notification received: %@", notification.name);
        NSLog(@"[TCC] userInfo: %@", notification.userInfo);

        // Invalidate cache immediately
        [self invalidatePermissionCache];

        // Post internal notification for app to handle
        [[NSNotificationCenter defaultCenter] postNotificationName:@"TCCDatabaseChanged"
                                                            object:nil
                                                          userInfo:notification.userInfo];

        // Check permission after a brief delay to let TCC settle
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)),
                      dispatch_get_main_queue(), ^{
            BOOL hasPermission = [self canCreateEventTap];
            NSLog(@"[TCC] Post-notification check: %@", hasPermission ? @"GRANTED" : @"DENIED");

            // Notify observers about permission change
            [[NSNotificationCenter defaultCenter] postNotificationName:@"AccessibilityStatusChanged"
                                                                object:@(hasPermission)];
        });
    }];

    // Also listen for com.apple.TCC.access.changed
    id observer2 = [center addObserverForName:@"com.apple.TCC.access.changed"
                                       object:nil
                                        queue:[NSOperationQueue mainQueue]
                                   usingBlock:^(NSNotification *notification) {
        NSLog(@"[TCC] 🔔 TCC access changed notification: %@", notification.userInfo);

        [self invalidatePermissionCache];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)),
                      dispatch_get_main_queue(), ^{
            BOOL hasPermission = [self canCreateEventTap];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"AccessibilityStatusChanged"
                                                                object:@(hasPermission)];
        });
    }];

    // Store both observers (we'll use an array)
    if (_tccNotificationObserver == nil) {
        _tccNotificationObserver = observer2;
    }

    NSLog(@"[TCC] Notification listener started successfully");
}

// Stop listening for TCC changes
+(void)stopTCCNotificationListener {
    if (_tccNotificationObserver != nil) {
        NSLog(@"[TCC] Stopping notification listener...");
        [[NSDistributedNotificationCenter defaultCenter] removeObserver:_tccNotificationObserver];
        _tccNotificationObserver = nil;
        NSLog(@"[TCC] Notification listener stopped");
    }
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
            NSLog(@"[Permission] Test tap SUCCESS on attempt %d", attempt + 1);
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

// Check if System Settings (Privacy & Security) is currently open
+(BOOL)isSystemSettingsOpen {
    NSRunningApplication *frontApp = [[NSWorkspace sharedWorkspace] frontmostApplication];
    if (frontApp) {
        NSString *bundleId = frontApp.bundleIdentifier;
        // System Settings on macOS 13+ is "com.apple.systempreferences"
        // System Preferences on older macOS is also "com.apple.systempreferences"
        return [bundleId isEqualToString:@"com.apple.systempreferences"] ||
               [bundleId isEqualToString:@"com.apple.Accessibility-Settings.extension"];
    }
    return NO;
}

// Update System Settings open state
+(void)updateSystemSettingsState {
    _systemSettingsIsOpen = [self isSystemSettingsOpen];
}

// Check if we should suggest app relaunch
+(BOOL)shouldSuggestRelaunch {
    return _axYesTapNoCount >= kMaxAxYesTapNoBeforeRelaunch;
}

// Reset the AX=YES Tap=NO counter
+(void)resetAxYesTapNoCounter {
    _axYesTapNoCount = 0;
}

// SIMPLE permission check using ONLY test event tap (Apple recommended)
// This is the ONLY reliable way to check accessibility permission
// AXIsProcessTrusted() is unreliable - it can return YES even when permission is not effective
+(BOOL)canCreateEventTap {
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];

    // Use DYNAMIC cache TTL based on current state
    // When waiting for permission (NO): NO CACHE - every check is fresh
    // When permission granted: use 5s TTL to reduce overhead
    NSTimeInterval cacheTTL = _lastPermissionCheckResult ? kCacheTTLPermissionGranted : kCacheTTLWaitingForPermission;

    if (cacheTTL > 0 && (now - _lastPermissionCheckTime < cacheTTL)) {
        return _lastPermissionCheckResult;
    }

    // ONLY trust test event tap creation - this is the ONLY reliable method
    BOOL hasPermission = [self tryCreateTestTapWithRetries];

    NSLog(@"[Permission] Check: TestTap=%@", hasPermission ? @"SUCCESS" : @"FAILED");

    // Update cache
    _lastPermissionCheckResult = hasPermission;
    _lastPermissionCheckTime = now;

    return hasPermission;
}

// Force permission check (bypasses all caching)
+(BOOL)forcePermissionCheck {
    [self invalidatePermissionCache];
    _axYesTapNoCount = 0;
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
                 (1 << kCGEventRightMouseDown) |
                 (1 << kCGEventLeftMouseDragged) |
                 (1 << kCGEventRightMouseDragged));

    eventTap = CGEventTapCreate(kCGSessionEventTap,
                                kCGHeadInsertEventTap,
                                0,
                                eventMask,
                                PHTVCallback,
                                NULL);

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
    } else {
        // Proactive: even if enabled, give it a quick re-enable nudge to keep it alive
        // This prevents macOS from silently disabling it
        CGEventTapEnable(eventTap, true);
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
    [[NSUserDefaults standardUserDefaults] synchronize];

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
    [[NSUserDefaults standardUserDefaults] synchronize];
    NSLog(@"[SafeMode] Cleared AX test flag on normal termination");
}

#pragma mark - Binary Integrity Check
// Implementation delegated to PHTVBinaryIntegrity class for better code organization

+(NSString*)getBinaryArchitectures {
    return [PHTVBinaryIntegrity getBinaryArchitectures];
}

+(NSString*)getBinaryHash {
    return [PHTVBinaryIntegrity getBinaryHash];
}

+(BOOL)hasBinaryChangedSinceLastRun {
    return [PHTVBinaryIntegrity hasBinaryChangedSinceLastRun];
}

+(BOOL)checkBinaryIntegrity {
    return [PHTVBinaryIntegrity checkBinaryIntegrity];
}

@end

