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
#import "../Application/AppDelegate.h"
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

    // Use cache if it's within 50ms duration (increased from 10ms to prevent event tap timeouts)
    // This ensures we don't block the event tap with frequent AX calls
    static const uint64_t SPOTLIGHT_CACHE_DURATION_MS = 50;
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
    // Detect if focused element is Safari address bar (NOT web content)
    // Strategy 1: Check if focused element is AXTextField/AXComboBox (address bar)
    // Strategy 2: Check if element or its parent is AXWebArea (web content)
    // If in AXTextField/AXComboBox OR NOT in web content, it's address bar
    AXUIElementRef systemWide = AXUIElementCreateSystemWide();
    AXUIElementRef focusedElement = NULL;
    BOOL isWebContent = NO;
    BOOL isAddressBarElement = NO;

    AXError error = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute, (CFTypeRef *)&focusedElement);
    CFRelease(systemWide);

    if (error != kAXErrorSuccess || focusedElement == NULL) {
        return YES;  // If can't detect, assume address bar (use Shift+Left)
    }

    // First, check the focused element's role directly
    CFTypeRef focusedRole = NULL;
    if (AXUIElementCopyAttributeValue(focusedElement, kAXRoleAttribute, &focusedRole) == kAXErrorSuccess) {
        if (focusedRole != NULL && CFGetTypeID(focusedRole) == CFStringGetTypeID()) {
            NSString *roleStr = (__bridge NSString *)focusedRole;
            // Safari address bar is typically AXTextField or AXComboBox
            if ([roleStr isEqualToString:@"AXTextField"] ||
                [roleStr isEqualToString:@"AXComboBox"] ||
                [roleStr isEqualToString:@"AXSearchField"]) {
                isAddressBarElement = YES;
            }
        }
        if (focusedRole) CFRelease(focusedRole);
    }

    // If it's an address bar element, return YES immediately
    if (isAddressBarElement) {
        CFRelease(focusedElement);
        return YES;
    }

    // Otherwise, check if current element or any parent is AXWebArea
    AXUIElementRef currentElement = focusedElement;
    CFRetain(currentElement);

    for (int i = 0; i < 10; i++) {  // Check up to 10 levels of parents
        CFTypeRef role = NULL;
        if (AXUIElementCopyAttributeValue(currentElement, kAXRoleAttribute, &role) == kAXErrorSuccess) {
            if (role != NULL && CFGetTypeID(role) == CFStringGetTypeID()) {
                NSString *roleStr = (__bridge NSString *)role;
                if ([roleStr isEqualToString:@"AXWebArea"]) {
                    isWebContent = YES;
                    CFRelease(role);
                    break;
                }
            }
            if (role) CFRelease(role);
        }

        // Get parent
        AXUIElementRef parent = NULL;
        if (AXUIElementCopyAttributeValue(currentElement, kAXParentAttribute, (CFTypeRef *)&parent) != kAXErrorSuccess || parent == NULL) {
            break;
        }
        CFRelease(currentElement);
        currentElement = parent;
    }

    CFRelease(currentElement);
    CFRelease(focusedElement);

    // Return YES if NOT in web content (address bar, search field, etc.)
    return !isWebContent;
}

+ (BOOL)isSafariGoogleDocsOrSheets {
    // Detect if Safari is currently on Google Docs or Google Sheets
    // by checking the URL via Accessibility API
    // Google Docs URL patterns:
    // - docs.google.com/document
    // - docs.google.com/spreadsheets
    // - docs.google.com/presentation

    AXUIElementRef systemWide = AXUIElementCreateSystemWide();
    AXUIElementRef focusedElement = NULL;
    BOOL isGoogleDocs = NO;

    AXError error = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute, (CFTypeRef *)&focusedElement);
    CFRelease(systemWide);

    if (error != kAXErrorSuccess || focusedElement == NULL) {
        return NO;  // If can't detect, assume NOT Google Docs
    }

    // Get PID and create app element
    pid_t pid = 0;
    error = AXUIElementGetPid(focusedElement, &pid);
    CFRelease(focusedElement);

    if (error != kAXErrorSuccess || pid == 0) {
        return NO;
    }

    // Create app element to get window info
    AXUIElementRef appElement = AXUIElementCreateApplication(pid);
    if (appElement == NULL) {
        return NO;
    }

    // Get focused window
    AXUIElementRef focusedWindow = NULL;
    error = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute, (CFTypeRef *)&focusedWindow);
    CFRelease(appElement);

    if (error != kAXErrorSuccess || focusedWindow == NULL) {
        return NO;
    }

    // Try to get document URL (Safari exposes this for web pages)
    CFTypeRef documentURL = NULL;
    error = AXUIElementCopyAttributeValue(focusedWindow, kAXDocumentAttribute, &documentURL);

    if (error == kAXErrorSuccess && documentURL != NULL) {
        if (CFGetTypeID(documentURL) == CFStringGetTypeID()) {
            NSString *urlStr = (__bridge NSString *)documentURL;
            // Check for Google Docs/Sheets/Slides patterns
            if ([urlStr containsString:@"docs.google.com/document"] ||
                [urlStr containsString:@"docs.google.com/spreadsheets"] ||
                [urlStr containsString:@"docs.google.com/presentation"] ||
                [urlStr containsString:@"docs.google.com/forms"]) {
                isGoogleDocs = YES;
            }
        }
        CFRelease(documentURL);
    }

    // Fallback: Check window title for Google Docs indicators
    if (!isGoogleDocs) {
        CFTypeRef title = NULL;
        error = AXUIElementCopyAttributeValue(focusedWindow, kAXTitleAttribute, &title);
        if (error == kAXErrorSuccess && title != NULL) {
            if (CFGetTypeID(title) == CFStringGetTypeID()) {
                NSString *titleStr = (__bridge NSString *)title;
                // Google Docs typically has " - Google Docs" or " - Google Sheets" in title
                if ([titleStr containsString:@" - Google Docs"] ||
                    [titleStr containsString:@" - Google Sheets"] ||
                    [titleStr containsString:@" - Google Slides"] ||
                    [titleStr containsString:@" - Google Tài liệu"] ||
                    [titleStr containsString:@" - Google Trang tính"] ||
                    [titleStr containsString:@" - Google Biểu mẫu"]) {
                    isGoogleDocs = YES;
                }
            }
            CFRelease(title);
        }
    }

    CFRelease(focusedWindow);
    return isGoogleDocs;
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
    // ALSO: Invalidate on ANY Command key press to support Apple Intelligence (Double Cmd) and other overlays
    // 55 = kVK_Command (Left Command), 54 = kVK_RightCommand (Right Command), 49 = kVK_Space
    BOOL isCommandKey = (keycode == 55 || keycode == 54);
    BOOL isCmdSpace = (keycode == 49 && (flags & kCGEventFlagMaskCommand));

    if (type == kCGEventKeyDown && (isCmdSpace || isCommandKey)) {
        [PHTVCacheManager invalidateSpotlightCache];
    }
}

@end
