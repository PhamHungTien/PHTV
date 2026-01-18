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
#import <mach/mach_time.h>
#import <libproc.h>
#import <Cocoa/Cocoa.h>

@implementation PHTVSpotlightManager

// Text Replacement detection
static BOOL _externalDeleteDetected = NO;
static uint64_t _lastExternalDeleteTime = 0;
static int _externalDeleteCount = 0;

#pragma mark - Initialization

+ (void)initialize {
    if (self == [PHTVSpotlightManager class]) {
        // Initialize state
        _externalDeleteDetected = NO;
        _lastExternalDeleteTime = 0;
        _externalDeleteCount = 0;
    }
}

#pragma mark - Spotlight Detection

+ (BOOL)containsSearchKeyword:(NSString*)str {
    if (str == nil) return NO;
    NSString *lower = [str lowercaseString];
    return [lower containsString:@"search"] ||
           [lower containsString:@"tìm kiếm"] ||
           [lower containsString:@"tìm"] ||
           [lower containsString:@"filter"] ||
           [lower containsString:@"lọc"];
}

+ (BOOL)isElementSpotlight:(AXUIElementRef)element bundleId:(NSString*)bundleId {
    if (element == NULL) return NO;

    // CRITICAL FIX: Filter out browser address bars
    // Browser address bars have AXSearchField role but they are NOT Spotlight
    // This prevents false positive detection when transitioning between Chromium and Spotlight
    if (bundleId != nil && [PHTVAppDetectionManager isBrowserApp:bundleId]) {
        return NO;  // Browser address bar is NOT Spotlight
    }

    CFTypeRef role = NULL;
    BOOL isSearchField = NO;

    // Check role
    if (AXUIElementCopyAttributeValue(element, kAXRoleAttribute, &role) == kAXErrorSuccess) {
        if (role != NULL && CFGetTypeID(role) == CFStringGetTypeID()) {
            NSString *roleStr = (__bridge NSString *)role;

            // AXSearchField → return YES (standard search field, but already filtered browsers above)
            if ([roleStr isEqualToString:@"AXSearchField"]) {
                isSearchField = YES;
            }
            // AXTextField or AXTextArea → check additional attributes
            else if ([roleStr isEqualToString:@"AXTextField"] || [roleStr isEqualToString:@"AXTextArea"]) {
                CFTypeRef attr = NULL;

                // Check subrole
                if (!isSearchField && AXUIElementCopyAttributeValue(element, kAXSubroleAttribute, &attr) == kAXErrorSuccess) {
                    if (attr != NULL && CFGetTypeID(attr) == CFStringGetTypeID()) {
                        if ([self containsSearchKeyword:(__bridge NSString *)attr]) {
                            isSearchField = YES;
                        }
                    }
                    if (attr) { CFRelease(attr); attr = NULL; }
                }

                // Check AXIdentifier
                if (!isSearchField && AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute, &attr) == kAXErrorSuccess) {
                    if (attr != NULL && CFGetTypeID(attr) == CFStringGetTypeID()) {
                        if ([self containsSearchKeyword:(__bridge NSString *)attr]) {
                            isSearchField = YES;
                        }
                    }
                    if (attr) { CFRelease(attr); attr = NULL; }
                }

                // Check AXDescription
                if (!isSearchField && AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute, &attr) == kAXErrorSuccess) {
                    if (attr != NULL && CFGetTypeID(attr) == CFStringGetTypeID()) {
                        if ([self containsSearchKeyword:(__bridge NSString *)attr]) {
                            isSearchField = YES;
                        }
                    }
                    if (attr) { CFRelease(attr); attr = NULL; }
                }

                // Check AXPlaceholderValue (placeholder text like "Search..." or "Tìm kiếm...")
                if (!isSearchField && AXUIElementCopyAttributeValue(element, kAXPlaceholderValueAttribute, &attr) == kAXErrorSuccess) {
                    if (attr != NULL && CFGetTypeID(attr) == CFStringGetTypeID()) {
                        if ([self containsSearchKeyword:(__bridge NSString *)attr]) {
                            isSearchField = YES;
                        }
                    }
                    if (attr) { CFRelease(attr); attr = NULL; }
                }
            }
            CFRelease(role);
        }
    }

    return isSearchField;
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

    uint64_t elapsed_ms = [PHTVTimingManager machTimeToMs:now - lastCheck];

    // Use cache if it's within 10ms duration (reduced from 30ms for faster Spotlight->App transitions)
    // This ensures when user closes Spotlight and immediately types in another app,
    // we recheck quickly instead of using stale cache
    static const uint64_t SPOTLIGHT_CACHE_DURATION_MS = 10;
    if (elapsed_ms < SPOTLIGHT_CACHE_DURATION_MS && lastCheck > 0) {
        return cachedResult;
    }

    // Get the system-wide focused element with multiple retries
    AXUIElementRef systemWide = AXUIElementCreateSystemWide();
    AXUIElementRef focusedElement = NULL;
    AXError error = kAXErrorFailure;

    // Retry up to 5 times with progressive delays (0ms, 2ms, 5ms, 10ms, 15ms)
    // Increased retries and better delay distribution for more reliable detection
    const int retryDelays[] = {0, 2000, 5000, 10000, 15000};  // microseconds
    for (int attempt = 0; attempt < 5; attempt++) {
        if (attempt > 0) {
            usleep(retryDelays[attempt]);
        }

        error = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute, (CFTypeRef *)&focusedElement);

        if (error == kAXErrorSuccess && focusedElement != NULL) {
            break;  // Success
        }
    }

    // Release systemWide after all retry attempts
    CFRelease(systemWide);

    if (error != kAXErrorSuccess || focusedElement == NULL) {
        // IMPROVED: If AX API completely failed after all retries, return cached result
        // instead of assuming NO. This prevents false negatives when AX API is temporarily unavailable.
        // Only cache NO if we had no previous cached result or it was already NO.
        if (lastCheck > 0 && cachedResult) {
            // We previously detected Spotlight, and AX API is now failing
            // Keep the cached result instead of switching to NO
            return cachedResult;
        }
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

#pragma mark - Text Replacement Detection

+ (void)trackExternalDelete {
    uint64_t now = mach_absolute_time();

    // Reset count if too much time passed (>30000ms = 30 seconds)
    if (_lastExternalDeleteTime != 0) {
        uint64_t elapsed_ms = [PHTVTimingManager machTimeToMs:now - _lastExternalDeleteTime];
        if (elapsed_ms > 30000) {
            _externalDeleteCount = 0;
        }
    }

    _lastExternalDeleteTime = now;
    _externalDeleteCount++;
    _externalDeleteDetected = YES;
}

+ (BOOL)hasRecentExternalDeletes {
    return _externalDeleteDetected;
}

+ (int)getExternalDeleteCount {
    return _externalDeleteCount;
}

+ (void)resetExternalDeleteTracking {
    _externalDeleteDetected = NO;
    _lastExternalDeleteTime = 0;
    _externalDeleteCount = 0;
}

#pragma mark - Cache Invalidation Coordination

+ (void)handleSpotlightCacheInvalidation:(CGEventType)type keycode:(CGKeyCode)keycode flags:(CGEventFlags)flags {
    // Check if Cmd+Space was pressed (Spotlight shortcut)
    if (type == kCGEventKeyDown && keycode == 49 && (flags & kCGEventFlagMaskCommand)) { // Space = 49
        [PHTVCacheManager invalidateSpotlightCache];
    }
}

@end
