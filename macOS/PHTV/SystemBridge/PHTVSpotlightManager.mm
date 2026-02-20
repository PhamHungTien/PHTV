//
//  PHTVSpotlightManager.mm
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import "PHTVSpotlightManager.h"
#import "PHTVCacheManager.h"
#import "PHTVAppDetectionManager.h"
#import "PHTVTimingManager.h"
#import "PHTV-Swift.h"
#import "../Core/phtv_mac_keys.h"
#import <mach/mach_time.h>
#import <libproc.h>
#import <Cocoa/Cocoa.h>

@implementation PHTVSpotlightManager

#pragma mark - Initialization

+ (void)initialize {
    // No-op. State tracking lives in PHTVSpotlightDetectionService.
}

#pragma mark - Spotlight Detection

+ (BOOL)containsSearchKeyword:(NSString*)str {
    return [PHTVSpotlightDetectionService containsSearchKeyword:str];
}

+ (BOOL)isElementSpotlight:(AXUIElementRef)element bundleId:(NSString*)bundleId {
    return [PHTVSpotlightDetectionService isElementSpotlight:element bundleId:bundleId];
}

+ (BOOL)isSpotlightActive {
    // Safe Mode: Skip AX API calls entirely - assume not in Spotlight
    extern BOOL vSafeMode;
    if (vSafeMode) {
        return NO;
    }

    uint64_t now = mach_absolute_time();

    // Thread-safe cache check
    BOOL cachedResult = [PHTVCacheManager getCachedSpotlightActive];
    uint64_t lastCheck = [PHTVCacheManager getLastSpotlightCheckTime];
    uint64_t lastInvalidation = [PHTVCacheManager getLastSpotlightInvalidationTime];

    uint64_t elapsed_ms = [PHTVTimingManager machTimeToMs:now - lastCheck];
    uint64_t elapsed_since_invalidation_ms = lastInvalidation > 0 ? [PHTVTimingManager machTimeToMs:now - lastInvalidation] : UINT64_MAX;

    // CRITICAL FIX 1: Skip cache entirely within 100ms after invalidation
    // This ensures we always recheck immediately after Cmd+Space, ESC, mouse clicks, etc.
    // Prevents using stale cache during Spotlight open/close transitions
    static const uint64_t FORCE_RECHECK_AFTER_INVALIDATION_MS = 100;
    if (elapsed_since_invalidation_ms < FORCE_RECHECK_AFTER_INVALIDATION_MS) {
        // Force full recheck - don't use cache at all
        lastCheck = 0;
        elapsed_ms = UINT64_MAX;
    }

    // CRITICAL FIX 2: Check if cached bundle ID is a browser BEFORE returning cached result
    // This prevents returning stale "YES" if we previously detected browser address bar as Spotlight
    if (lastCheck > 0 && cachedResult) {
        NSString *cachedBundleId = [PHTVCacheManager getCachedFocusedBundleId];
        if (cachedBundleId != nil && [PHTVAppDetectionManager isBrowserApp:cachedBundleId]) {
            // Cached result was for a browser address bar → INVALIDATE and recheck
            [PHTVCacheManager invalidateSpotlightCache];
            lastCheck = 0;  // Force recheck below
            elapsed_ms = UINT64_MAX;
        }
    }

    // Use cache if it's within 150ms duration (balanced to reduce AX calls)
    // This ensures we don't block the event tap with frequent AX calls
    static const uint64_t SPOTLIGHT_CACHE_DURATION_MS = 150;
    if (elapsed_ms < SPOTLIGHT_CACHE_DURATION_MS && lastCheck > 0) {
        return cachedResult;
    }

    // Get the system-wide focused element
    AXUIElementRef systemWide = AXUIElementCreateSystemWide();
    AXUIElementRef focusedElement = NULL;
    AXError error = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute, (CFTypeRef *)&focusedElement);

    // Release systemWide immediately
    CFRelease(systemWide);

    if (error != kAXErrorSuccess || focusedElement == NULL) {
        // If AX API failed, assume NO.
        // Returning stale YES (sticky cache) causes issues when switching apps or closing Spotlight.
        [PHTVCacheManager updateSpotlightCache:NO pid:0 bundleId:nil];
        return NO;
    }

    // Get the PID of the app that owns the focused element FIRST
    // This is needed to filter out browser address bars before checking AXSearchField
    pid_t focusedPID = 0;
    error = AXUIElementGetPid(focusedElement, &focusedPID);

    if (error != kAXErrorSuccess || focusedPID == 0) {
        CFRelease(focusedElement);
        [PHTVCacheManager updateSpotlightCache:NO pid:0 bundleId:nil];
        return NO;
    }

    // Get bundle ID to filter browser address bars
    NSString *bundleId = [PHTVCacheManager getBundleIdFromPID:focusedPID];

    // Ignore PHTV's own UI - search fields inside the app should not trigger Spotlight behavior.
    if (bundleId != nil && [bundleId isEqualToString:PHTV_BUNDLE]) {
        [PHTVCacheManager updateSpotlightCache:NO pid:focusedPID bundleId:bundleId];
        return NO;
    }

    // PRIMARY CHECK: Detect search field by AXRole/AXSubrole
    // Now with bundle ID filtering to exclude browser address bars
    BOOL elementLooksLikeSearchField = [self isElementSpotlight:focusedElement bundleId:bundleId];
    CFRelease(focusedElement);

    // If focused element is a search field (and NOT a browser address bar), return YES
    if (elementLooksLikeSearchField) {
        // Log state change when transitioning TO Spotlight
        if (!cachedResult) {
            NSLog(@"[Spotlight] ✅ DETECTED: bundleId=%@, pid=%d", bundleId ?: @"(nil)", focusedPID);
        }
        [PHTVCacheManager updateSpotlightCache:YES pid:focusedPID bundleId:bundleId];
        return YES;
    }

    // bundle ID was already retrieved above (line 191) - no need to get it again

    // Check if it's Spotlight or similar
    if ([bundleId isEqualToString:@"com.apple.Spotlight"] ||
        [bundleId hasPrefix:@"com.apple.Spotlight"]) {
        // Log state change when transitioning TO Spotlight
        if (!cachedResult) {
            NSLog(@"[Spotlight] ✅ DETECTED (by bundleId): bundleId=%@, pid=%d", bundleId, focusedPID);
        }
        [PHTVCacheManager updateSpotlightCache:YES pid:focusedPID bundleId:bundleId];
        return YES;
    }

    // Also check by process path for system processes without bundle ID
    if (bundleId == nil) {
        char pathBuffer[PROC_PIDPATHINFO_MAXSIZE];
        if (proc_pidpath(focusedPID, pathBuffer, sizeof(pathBuffer)) > 0) {
            NSString *path = [NSString stringWithUTF8String:pathBuffer];
            if ([path containsString:@"Spotlight"]) {
                // Log state change when transitioning TO Spotlight
                if (!cachedResult) {
                    NSLog(@"[Spotlight] ✅ DETECTED (by path): path=%@, pid=%d", path, focusedPID);
                }
                [PHTVCacheManager updateSpotlightCache:YES pid:focusedPID bundleId:@"com.apple.Spotlight"];
                return YES;
            }
        }
    }

    // Log state change when transitioning FROM Spotlight
    if (cachedResult) {
        NSLog(@"[Spotlight] ❌ LOST: now focused on bundleId=%@, pid=%d", bundleId ?: @"(nil)", focusedPID);
    }
    [PHTVCacheManager updateSpotlightCache:NO pid:focusedPID bundleId:bundleId];
    return NO;
}

#pragma mark - Safari Detection

+ (BOOL)isSafariAddressBar {
    return [PHTVSpotlightDetectionService isSafariAddressBar];
}

+ (BOOL)isSafariGoogleDocsOrSheets {
    return [PHTVSpotlightDetectionService isSafariGoogleDocsOrSheets];
}

#pragma mark - Text Replacement Detection

+ (void)trackExternalDelete {
    [PHTVSpotlightDetectionService trackExternalDelete];
}

+ (BOOL)hasRecentExternalDeletes {
    return [PHTVSpotlightDetectionService hasRecentExternalDeletes];
}

+ (int)getExternalDeleteCount {
    return (int)[PHTVSpotlightDetectionService externalDeleteCountValue];
}

+ (void)resetExternalDeleteTracking {
    [PHTVSpotlightDetectionService resetExternalDeleteTracking];
}

#pragma mark - Cache Invalidation Coordination

+ (void)handleSpotlightCacheInvalidation:(CGEventType)type keycode:(CGKeyCode)keycode flags:(CGEventFlags)flags {
    // Check if Cmd+Space was pressed (Spotlight shortcut)
    // ALSO: Invalidate on ANY Command key press to support Apple Intelligence (Double Cmd) and other overlays
    BOOL isCommandKey = (keycode == KEY_LEFT_COMMAND || keycode == KEY_RIGHT_COMMAND);
    BOOL isCmdSpace = (keycode == KEY_SPACE && (flags & kCGEventFlagMaskCommand));

    if (type == kCGEventKeyDown && (isCmdSpace || isCommandKey)) {
        [PHTVCacheManager invalidateSpotlightCache];
    }
}

@end
