//
//  PHTVManager.m
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import "PHTVManager.h"

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

// Dynamic cache TTL: Short when waiting for permission, long when permission granted
// This ensures fast detection when user grants permission while avoiding excessive test taps when running normally
static const NSTimeInterval kCacheTTLWaitingForPermission = 0.5;  // 500ms when waiting
static const NSTimeInterval kCacheTTLPermissionGranted = 10.0;    // 10s when granted

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
    NSLog(@"[Permission] Cache invalidated - next check will be fresh");
}

// SAFE permission check via test event tap (Apple recommended)
// This is the ONLY reliable way to check accessibility permission
// Returns YES if we can create event tap (permission granted), NO otherwise
// Cached with DYNAMIC TTL: short when waiting for permission, long when granted
+(BOOL)canCreateEventTap {
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];

    // Use DYNAMIC cache TTL based on current permission state
    // When waiting for permission (NO): use short TTL (0.5s) for fast detection
    // When permission granted (YES): use long TTL (10s) to reduce overhead
    NSTimeInterval cacheTTL = _lastPermissionCheckResult ? kCacheTTLPermissionGranted : kCacheTTLWaitingForPermission;

    if (now - _lastPermissionCheckTime < cacheTTL) {
        #ifdef DEBUG
        NSLog(@"[Permission] Returning CACHED result: %@ (TTL: %.1fs)", _lastPermissionCheckResult ? @"HAS" : @"NO", cacheTTL);
        #endif
        return _lastPermissionCheckResult;
    }

    // Try creating a test event tap (happens every 10s when monitoring is active)
    #ifdef DEBUG
    NSLog(@"[Permission] Creating test event tap to check permission...");
    #endif

    CFMachPortRef testTap = CGEventTapCreate(
        kCGSessionEventTap,
        kCGTailAppendEventTap,
        kCGEventTapOptionDefault,
        CGEventMaskBit(kCGEventKeyDown),
        PHTVTestTapCallback,
        NULL
    );

    BOOL hasPermission = (testTap != NULL);

    #ifdef DEBUG
    NSLog(@"[Permission] Test tap result: %@", hasPermission ? @"SUCCESS (has permission)" : @"FAILED (no permission)");
    #endif

    // Clean up test tap if created successfully
    if (testTap != NULL) {
        CFMachPortInvalidate(testTap);
        CFRelease(testTap);
    }

    // Update cache
    _lastPermissionCheckResult = hasPermission;
    _lastPermissionCheckTime = now;

    return hasPermission;
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

@end

