//
//  PHTV Engine
//  PHTV - Bộ gõ Tiếng Việt
//
//  Modified by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//
#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <Foundation/Foundation.h>
#import <libproc.h>
#import <ApplicationServices/ApplicationServices.h>
#import <os/lock.h>
#import <os/log.h>
#import <mach/mach_time.h>
#import <unistd.h>
#import <stdlib.h>
#import <string.h>
#import "Engine.h"
#import "../Application/AppDelegate.h"
#import "PHTVManager.h"
#import "../Core/Legacy/MJAccessibilityUtils.h"

// Forward declarations for functions used before definition (inside extern "C" block)
extern "C" {
    NSString* getBundleIdFromPID(pid_t pid);
    NSString* getFocusedAppBundleId(void);
}

#define FRONT_APP [[NSWorkspace sharedWorkspace] frontmostApplication].bundleIdentifier

// Performance & Cache Configuration
static const uint64_t SPOTLIGHT_CACHE_DURATION_MS = 50;      // Spotlight detection cache timeout
static const uint64_t PID_CACHE_CLEAN_INTERVAL_MS = 60000;   // 60 seconds - PID cache cleanup (Reduced from 5 mins to fix WhatsApp issues)
static const NSUInteger PID_CACHE_INITIAL_CAPACITY = 128;    // Initial PID cache capacity
static const uint64_t DEBUG_LOG_THROTTLE_MS = 500;           // Debug log throttling interval
static const uint64_t APP_SWITCH_CACHE_DURATION_MS = 100;    // App switch detection cache timeout
static const NSUInteger SYNC_KEY_RESERVE_SIZE = 256;         // Pre-allocated buffer size for typing sync

// Terminal/IDE Delay Configuration - conservatively reduced for better performance
// These delays are critical for timing-sensitive apps (terminals, IDEs)
static const uint64_t TERMINAL_KEYSTROKE_DELAY_US = 1500;    // Per-character delay (reduced from 3000us)
static const uint64_t TERMINAL_SETTLE_DELAY_US = 4000;       // After all backspaces (reduced from 8000us)
static const uint64_t TERMINAL_FINAL_SETTLE_US = 10000;      // Final settle after all text (reduced from 20000us)
static const uint64_t SPOTLIGHT_TINY_DELAY_US = 2000;        // Spotlight timing delay (reduced from 3000us)

// Browser Delay Configuration - REMOVED
// Browser delays are no longer needed thanks to Shift+Left strategy (inspired by OpenKey)
// The "Select then Delete" approach eliminates autocomplete race conditions
// This works for all browsers: Chromium, WebKit (Safari), Gecko (Firefox)
// REMOVED: BROWSER_KEYSTROKE_DELAY_BASE_US, BROWSER_KEYSTROKE_DELAY_MAX_US
// REMOVED: BROWSER_SETTLE_DELAY_BASE_US, BROWSER_SETTLE_DELAY_MAX_US
// REMOVED: BROWSER_CHAR_DELAY_BASE_US, BROWSER_CHAR_DELAY_MAX_US
// REMOVED: SAFARI_ADDRESS_BAR_EXTRA_DELAY_US
// REMOVED: AUTO_ENGLISH_KEYSTROKE_DELAY_US, AUTO_ENGLISH_SETTLE_DELAY_US, AUTO_ENGLISH_CHAR_DELAY_US

// Adaptive delay tracking
static uint64_t _lastKeystrokeTimestamp = 0;
static uint64_t _averageResponseTimeUs = 0;
static NSUInteger _responseTimeSamples = 0;
static os_unfair_lock _adaptiveDelayLock = OS_UNFAIR_LOCK_INIT;

// AXValueType constant name differs across SDK versions.
#if defined(kAXValueTypeCFRange)
    #define PHTV_AXVALUE_CFRANGE_TYPE kAXValueTypeCFRange
#elif defined(kAXValueCFRangeType)
    #define PHTV_AXVALUE_CFRANGE_TYPE kAXValueCFRangeType
#else
    // Fallback for older SDKs where the CFRange constant isn't exposed.
    // AXValueType values are stable across macOS; CFRange is typically 4.
    #define PHTV_AXVALUE_CFRANGE_TYPE ((AXValueType)4)
#endif

// Modern logging subsystem
static os_log_t phtv_log;
static dispatch_once_t log_init_token;

// High-resolution timing
static mach_timebase_info_data_t timebase_info;
static dispatch_once_t timebase_init_token;

static inline uint64_t mach_time_to_ms(uint64_t mach_time) {
    return (mach_time * timebase_info.numer) / (timebase_info.denom * 1000000);
}

#ifdef DEBUG
static inline BOOL PHTVSpotlightDebugEnabled(void) {
    // Opt-in logging to avoid noisy Console output.
    // Enable by launching with env var: PHTV_SPOTLIGHT_DEBUG=1
    static int enabled = -1;
    if (enabled < 0) {
        const char *env = getenv("PHTV_SPOTLIGHT_DEBUG");
        enabled = (env != NULL && env[0] != '\0' && strcmp(env, "0") != 0) ? 1 : 0;
    }
    return enabled == 1;
}

static inline void PHTVSpotlightDebugLog(NSString *message) {
    if (!PHTVSpotlightDebugEnabled()) {
        return;
    }
    dispatch_once(&timebase_init_token, ^{
        mach_timebase_info(&timebase_info);
    });
    static uint64_t lastLogTime = 0;
    uint64_t now = mach_absolute_time();
    if (lastLogTime != 0 && mach_time_to_ms(now - lastLogTime) < DEBUG_LOG_THROTTLE_MS) {
        return;
    }
    lastLogTime = now;
    NSLog(@"[PHTV Spotlight] %@", message);
}
#endif

// Cache for PID to bundle ID mapping with modern lock
static NSMutableDictionary<NSNumber*, NSString*> *_pidBundleCache = nil;
static uint64_t _lastCacheCleanTime = 0;
static os_unfair_lock _pidCacheLock = OS_UNFAIR_LOCK_INIT;

// App characteristics cache - cache all app properties to reduce repeated function calls
// This eliminates 5-10 function calls per keystroke down to 1 dictionary lookup
typedef struct {
    BOOL isSpotlightLike;
    BOOL needsPrecomposedBatched;
    BOOL isTerminal;
    BOOL needsStepByStep;
    BOOL containsUnicodeCompound;
} AppCharacteristics;

static NSMutableDictionary<NSString*, NSValue*> *_appCharacteristicsCache = nil;
static os_unfair_lock _appCharCacheLock = OS_UNFAIR_LOCK_INIT;
static NSString* _lastCachedBundleId = nil;  // Track last app to detect switches
static uint64_t _lastCacheInvalidationTime = 0;  // Periodic cache invalidation

// Spotlight detection cache (refreshes every 50ms for optimal balance of performance and responsiveness)
// Thread-safe access required since event tap callback may run on different threads
static BOOL _cachedSpotlightActive = NO;
static uint64_t _lastSpotlightCheckTime = 0;
static pid_t _cachedFocusedPID = 0;
static NSString* _cachedFocusedBundleId = nil;
static os_unfair_lock _spotlightCacheLock = OS_UNFAIR_LOCK_INIT;

// Text Replacement detection (for macOS native text replacement)
// macOS Text Replacement does NOT send delete events via CGEventTap when using mouse!
// We use multiple detection methods:
// 1. External DELETE events (works for arrow key selection)
// 2. Unexpected character count jump (works for mouse click selection)
static BOOL _externalDeleteDetected = NO;
static uint64_t _lastExternalDeleteTime = 0;
static int _externalDeleteCount = 0;

// Check if text replacement fix is enabled via settings (always enabled)
// Note: This feature is always enabled to fix macOS native text replacement conflicts
static inline BOOL IsTextReplacementFixEnabled(void) {
    return YES;  // Always enabled - matches PHTVApp.swift computed property
}

// Safe Mode: Disable all Accessibility API calls for unsupported hardware
// When enabled, the app will use fallback methods that don't rely on AX APIs
// which may crash on Macs running macOS via OpenCore Legacy Patcher (OCLP)
// Note: Not static - exported for PHTVManager access
BOOL vSafeMode = NO;

// Force invalidate Spotlight detection cache
// Call this when Cmd+Space is detected or when modifier keys change
static inline void InvalidateSpotlightCache(void) {
    os_unfair_lock_lock(&_spotlightCacheLock);
    _lastSpotlightCheckTime = 0;
    _cachedFocusedPID = 0;
    _cachedFocusedBundleId = nil;
    os_unfair_lock_unlock(&_spotlightCacheLock);
}

// Thread-safe helper to update Spotlight cache
static inline void UpdateSpotlightCache(BOOL isActive, pid_t pid, NSString* bundleId) {
    os_unfair_lock_lock(&_spotlightCacheLock);
    _cachedSpotlightActive = isActive;
    _lastSpotlightCheckTime = mach_absolute_time();
    _cachedFocusedPID = pid;
    _cachedFocusedBundleId = bundleId;
    os_unfair_lock_unlock(&_spotlightCacheLock);
}

// Track external delete events (not from PHTV) which may indicate text replacement
static inline void TrackExternalDelete(void) {
    dispatch_once(&timebase_init_token, ^{
        mach_timebase_info(&timebase_info);
    });

    uint64_t now = mach_absolute_time();

    // Reset count if too much time passed (>30000ms = 30 seconds)
    // Allow up to 30 seconds for user to select suggestion using mouse or keyboard
    // IMPORTANT: Only check timeout if we have a previous timestamp (not first delete)
    if (_lastExternalDeleteTime != 0) {
        uint64_t elapsed_ms = mach_time_to_ms(now - _lastExternalDeleteTime);
        if (elapsed_ms > 30000) {
            _externalDeleteCount = 0;
        }
    }

    _externalDeleteCount++;
    _lastExternalDeleteTime = now;
    _externalDeleteDetected = YES;
}

// Helper to check if string contains search-related keywords (case insensitive)
static inline BOOL ContainsSearchKeyword(NSString *str) {
    if (str == nil) return NO;
    NSString *lower = [str lowercaseString];
    return [lower containsString:@"search"] ||
           [lower containsString:@"tìm kiếm"] ||
           [lower containsString:@"tìm"] ||
           [lower containsString:@"filter"] ||
           [lower containsString:@"lọc"];
}

// Check if element is a search field by examining its role, subrole, and other attributes
static inline BOOL IsElementSpotlight(AXUIElementRef element) {
    if (element == NULL) return NO;

    CFTypeRef role = NULL;
    BOOL isSearchField = NO;

    // Check role
    if (AXUIElementCopyAttributeValue(element, kAXRoleAttribute, &role) == kAXErrorSuccess) {
        if (role != NULL && CFGetTypeID(role) == CFStringGetTypeID()) {
            NSString *roleStr = (__bridge NSString *)role;

            // AXSearchField → always return YES (standard search field)
            if ([roleStr isEqualToString:@"AXSearchField"]) {
                isSearchField = YES;
            }
            // AXTextField or AXTextArea → check additional attributes
            else if ([roleStr isEqualToString:@"AXTextField"] || [roleStr isEqualToString:@"AXTextArea"]) {
                CFTypeRef attr = NULL;

                // Check subrole
                if (!isSearchField && AXUIElementCopyAttributeValue(element, kAXSubroleAttribute, &attr) == kAXErrorSuccess) {
                    if (attr != NULL && CFGetTypeID(attr) == CFStringGetTypeID()) {
                        if (ContainsSearchKeyword((__bridge NSString *)attr)) {
                            isSearchField = YES;
                        }
                    }
                    if (attr) { CFRelease(attr); attr = NULL; }
                }

                // Check AXIdentifier
                if (!isSearchField && AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute, &attr) == kAXErrorSuccess) {
                    if (attr != NULL && CFGetTypeID(attr) == CFStringGetTypeID()) {
                        if (ContainsSearchKeyword((__bridge NSString *)attr)) {
                            isSearchField = YES;
                        }
                    }
                    if (attr) { CFRelease(attr); attr = NULL; }
                }

                // Check AXDescription
                if (!isSearchField && AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute, &attr) == kAXErrorSuccess) {
                    if (attr != NULL && CFGetTypeID(attr) == CFStringGetTypeID()) {
                        if (ContainsSearchKeyword((__bridge NSString *)attr)) {
                            isSearchField = YES;
                        }
                    }
                    if (attr) { CFRelease(attr); attr = NULL; }
                }

                // Check AXPlaceholderValue (placeholder text like "Search..." or "Tìm kiếm...")
                if (!isSearchField && AXUIElementCopyAttributeValue(element, kAXPlaceholderValueAttribute, &attr) == kAXErrorSuccess) {
                    if (attr != NULL && CFGetTypeID(attr) == CFStringGetTypeID()) {
                        if (ContainsSearchKeyword((__bridge NSString *)attr)) {
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

// Log AX API errors for debugging purposes
// Only logs in debug builds to avoid overhead in production
static inline void LogAXError(AXError error, const char *operation) {
#ifdef DEBUG
    if (error != kAXErrorSuccess) {
        const char *errorStr = "Unknown";
        switch (error) {
            case kAXErrorFailure: errorStr = "Failure"; break;
            case kAXErrorIllegalArgument: errorStr = "IllegalArgument"; break;
            case kAXErrorInvalidUIElement: errorStr = "InvalidUIElement"; break;
            case kAXErrorInvalidUIElementObserver: errorStr = "InvalidUIElementObserver"; break;
            case kAXErrorCannotComplete: errorStr = "CannotComplete"; break;
            case kAXErrorAttributeUnsupported: errorStr = "AttributeUnsupported"; break;
            case kAXErrorActionUnsupported: errorStr = "ActionUnsupported"; break;
            case kAXErrorNotificationUnsupported: errorStr = "NotificationUnsupported"; break;
            case kAXErrorNotImplemented: errorStr = "NotImplemented"; break;
            case kAXErrorNotificationAlreadyRegistered: errorStr = "NotificationAlreadyRegistered"; break;
            case kAXErrorNotificationNotRegistered: errorStr = "NotificationNotRegistered"; break;
            case kAXErrorAPIDisabled: errorStr = "APIDisabled"; break;
            case kAXErrorNoValue: errorStr = "NoValue"; break;
            case kAXErrorParameterizedAttributeUnsupported: errorStr = "ParameterizedAttributeUnsupported"; break;
            case kAXErrorNotEnoughPrecision: errorStr = "NotEnoughPrecision"; break;
            default: break;
        }
        os_log_debug(phtv_log, "[AX] %s failed: %s (code %d)", operation, errorStr, (int)error);
    }
#endif
}

// Check if Spotlight or similar overlay is currently active using Accessibility API
// OPTIMIZED: Results cached for 50ms to avoid repeated AX API calls while remaining responsive
BOOL isSpotlightActive(void) {
    // Safe Mode: Skip AX API calls entirely - assume not in Spotlight
    // This prevents crashes on unsupported hardware (OCLP Macs)
    if (vSafeMode) {
        return NO;
    }

    uint64_t now = mach_absolute_time();

    // Thread-safe cache check
    os_unfair_lock_lock(&_spotlightCacheLock);
    uint64_t lastCheck = _lastSpotlightCheckTime;
    BOOL cachedResult = _cachedSpotlightActive;
    pid_t cachedPID = _cachedFocusedPID;
    os_unfair_lock_unlock(&_spotlightCacheLock);

    uint64_t elapsed_ms = mach_time_to_ms(now - lastCheck);

    // Use cache if it's within the duration, regardless of whether it was TRUE or FALSE.
    // 50ms is responsive enough to detect focus changes while saving thousands of AX calls.
    if (elapsed_ms < SPOTLIGHT_CACHE_DURATION_MS && lastCheck > 0) {
        return cachedResult;
    }

    // Get the system-wide focused element with multiple retries
    // Create systemWide once to avoid unnecessary create/release overhead in retry loop
    AXUIElementRef systemWide = AXUIElementCreateSystemWide();
    AXUIElementRef focusedElement = NULL;
    AXError error = kAXErrorFailure;

    // Retry up to 3 times with progressive delays (0ms, 3ms, 8ms)
    const int retryDelays[] = {0, 3000, 8000};  // microseconds
    for (int attempt = 0; attempt < 3; attempt++) {
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
        LogAXError(error, "AXUIElementCopyAttributeValue(kAXFocusedUIElementAttribute)");
        UpdateSpotlightCache(NO, 0, nil);
        return NO;
    }

    // PRIMARY CHECK: Detect search field by AXRole/AXSubrole
    // This applies to ALL apps with search fields, not just Spotlight
    BOOL elementLooksLikeSearchField = IsElementSpotlight(focusedElement);

    // Get the PID of the app that owns the focused element
    pid_t focusedPID = 0;
    error = AXUIElementGetPid(focusedElement, &focusedPID);
    CFRelease(focusedElement);

    // If focused element is a search field, return YES immediately (for any app)
    if (elementLooksLikeSearchField) {
        NSString *bundleId = (focusedPID > 0) ? getBundleIdFromPID(focusedPID) : nil;
        UpdateSpotlightCache(YES, focusedPID > 0 ? focusedPID : 0, bundleId);
        return YES;
    }

    if (error != kAXErrorSuccess || focusedPID == 0) {
        LogAXError(error, "AXUIElementGetPid");
        UpdateSpotlightCache(NO, 0, nil);
        return NO;
    }

    // Quick path: if PID unchanged and we already checked, return cached
    if (focusedPID == cachedPID && cachedPID > 0) {
        return cachedResult;
    }

    // Get the bundle ID from the PID (uses internal cache)
    NSRunningApplication *app = [NSRunningApplication runningApplicationWithProcessIdentifier:focusedPID];
    NSString *bundleId = app.bundleIdentifier;

    // Check if it's Spotlight or similar
    if ([bundleId isEqualToString:@"com.apple.Spotlight"] ||
        [bundleId hasPrefix:@"com.apple.Spotlight"]) {
        UpdateSpotlightCache(YES, focusedPID, bundleId);
        return YES;
    }

    // Also check by process path for system processes without bundle ID
    if (bundleId == nil) {
        char pathBuffer[PROC_PIDPATHINFO_MAXSIZE];
        if (proc_pidpath(focusedPID, pathBuffer, sizeof(pathBuffer)) > 0) {
            NSString *path = [NSString stringWithUTF8String:pathBuffer];
            if ([path containsString:@"Spotlight"]) {
                UpdateSpotlightCache(YES, focusedPID, @"com.apple.Spotlight");
                return YES;
            }
        }
    }

    UpdateSpotlightCache(NO, focusedPID, bundleId);
    return NO;
}

// Get bundle ID from process ID
NSString* getBundleIdFromPID(pid_t pid) {
    if (__builtin_expect(pid <= 0, 0)) return nil;
    
    // Initialize infrastructure once
    dispatch_once(&log_init_token, ^{
        phtv_log = os_log_create("com.phamhungtien.phtv", "Engine");
    });
    dispatch_once(&timebase_init_token, ^{
        mach_timebase_info(&timebase_info);
    });
    
    // Fast path: check cache with modern lock
    NSNumber *pidKey = @(pid);
    os_unfair_lock_lock(&_pidCacheLock);
    
    // Initialize cache on first use
    if (__builtin_expect(_pidBundleCache == nil, 0)) {
        _pidBundleCache = [NSMutableDictionary dictionaryWithCapacity:PID_CACHE_INITIAL_CAPACITY];
        _lastCacheCleanTime = mach_absolute_time();
    }

    NSString *cached = _pidBundleCache[pidKey];

    // Smart cache cleanup: Check every 60 seconds
    // Force clean ALL entries to ensure we handle app restarts/updates (like WhatsApp)
    // Re-populating cache is cheap (NSRunningApplication is fast) vs user facing bugs
    uint64_t now = mach_absolute_time();
    uint64_t elapsed_ms = mach_time_to_ms(now - _lastCacheCleanTime);
    if (__builtin_expect(elapsed_ms > PID_CACHE_CLEAN_INTERVAL_MS, 0)) {
        [_pidBundleCache removeAllObjects];
        _lastCacheCleanTime = now;
        #ifdef DEBUG
        NSLog(@"[Cache] PID cache cleared (interval expired)");
        #endif
    }
    
    os_unfair_lock_unlock(&_pidCacheLock);
    
    if (cached) {
        return [cached isEqualToString:@""] ? nil : cached;
    }
    
    // Try to get bundle ID from running application - O(1) lookup instead of O(n) iteration
    NSRunningApplication *app = [NSRunningApplication runningApplicationWithProcessIdentifier:pid];
    if (app) {
        NSString *bundleId = app.bundleIdentifier ?: @"";
        os_unfair_lock_lock(&_pidCacheLock);
        _pidBundleCache[pidKey] = bundleId;
        os_unfair_lock_unlock(&_pidCacheLock);
        return bundleId.length > 0 ? bundleId : nil;
    }
    
    // Safe Mode: Skip proc_pidpath entirely for system processes to prevent crashes
    // This fixes "Unable to obtain a task name port right" crash on macOS 15+ (Issue #80)
    if (vSafeMode) {
        os_unfair_lock_lock(&_pidCacheLock);
        _pidBundleCache[pidKey] = @"";
        os_unfair_lock_unlock(&_pidCacheLock);
        return nil;
    }
    
    // Fallback: get process path and try to find bundle
    char pathBuffer[PROC_PIDPATHINFO_MAXSIZE];
    if (proc_pidpath(pid, pathBuffer, sizeof(pathBuffer)) > 0) {
        NSString *path = [NSString stringWithUTF8String:pathBuffer];
        // Debug logging disabled in release builds for performance
        #ifdef DEBUG
        NSLog(@"PHTV DEBUG: PID=%d path=%@", pid, path);
        #endif
        // Check for known system processes
        if ([path containsString:@"Spotlight"]) {
            os_unfair_lock_lock(&_pidCacheLock);
            _pidBundleCache[pidKey] = @"com.apple.Spotlight";
            os_unfair_lock_unlock(&_pidCacheLock);
            return @"com.apple.Spotlight";
        }
        if ([path containsString:@"SystemUIServer"]) {
            os_unfair_lock_lock(&_pidCacheLock);
            _pidBundleCache[pidKey] = @"com.apple.systemuiserver";
            os_unfair_lock_unlock(&_pidCacheLock);
            return @"com.apple.systemuiserver";
        }
        if ([path containsString:@"Launchpad"]) {
            os_unfair_lock_lock(&_pidCacheLock);
            _pidBundleCache[pidKey] = @"com.apple.launchpad.launcher";
            os_unfair_lock_unlock(&_pidCacheLock);
            return @"com.apple.launchpad.launcher";
        }
    }
    
    // Cache negative result
    os_unfair_lock_lock(&_pidCacheLock);
    _pidBundleCache[pidKey] = @"";
    os_unfair_lock_unlock(&_pidCacheLock);
    return nil;
}
#define OTHER_CONTROL_KEY (_flag & kCGEventFlagMaskCommand) || (_flag & kCGEventFlagMaskControl) || \
                            (_flag & kCGEventFlagMaskAlternate) || (_flag & kCGEventFlagMaskSecondaryFn) || \
                            (_flag & kCGEventFlagMaskNumericPad) || (_flag & kCGEventFlagMaskHelp)

#define DYNA_DATA(macro, pos) (macro ? pData->macroData[pos] : pData->charData[pos])
#define MAX_UNICODE_STRING  20
#define EMPTY_HOTKEY 0xFE0000FE
#define LOAD_DATA(VAR, KEY) VAR = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@#KEY]

// Ignore code for Modifier keys and numpad
// Reference: https://eastmanreference.com/complete-list-of-applescript-key-codes
// Maps characters to their QWERTY keycode equivalents for layout compatibility
// This comprehensive map supports multiple international keyboard layouts
NSDictionary *keyStringToKeyCodeMap = @{
    // ===== STANDARD QWERTY CHARACTERS =====
    // Number row
    @"`": @50, @"~": @50, @"1": @18, @"!": @18, @"2": @19, @"@": @19, @"3": @20, @"#": @20, @"4": @21, @"$": @21,
    @"5": @23, @"%": @23, @"6": @22, @"^": @22, @"7": @26, @"&": @26, @"8": @28, @"*": @28, @"9": @25, @"(": @25,
    @"0": @29, @")": @29, @"-": @27, @"_": @27, @"=": @24, @"+": @24,
    // First row (QWERTY)
    @"q": @12, @"w": @13, @"e": @14, @"r": @15, @"t": @17, @"y": @16, @"u": @32, @"i": @34, @"o": @31, @"p": @35,
    @"[": @33, @"{": @33, @"]": @30, @"}": @30, @"\\": @42, @"|": @42,
    // Second row (home row)
    @"a": @0, @"s": @1, @"d": @2, @"f": @3, @"g": @5, @"h": @4, @"j": @38, @"k": @40, @"l": @37,
    @";": @41, @":": @41, @"'": @39, @"\"": @39,
    // Third row
    @"z": @6, @"x": @7, @"c": @8, @"v": @9, @"b": @11, @"n": @45, @"m": @46,
    @",": @43, @"<": @43, @".": @47, @">": @47, @"/": @44, @"?": @44,

    // ===== INTERNATIONAL KEYBOARD LAYOUT CHARACTERS =====
    // Maps special characters from various keyboard layouts to their physical key positions
    // Note: When a character appears on multiple layouts at different positions,
    // we use the most common position. The layout compatibility feature will
    // find the correct mapping at runtime.

    // German QWERTZ specific
    @"ß": @27,  // ß at - position

    // Umlauts (German, Nordic, Turkish, Hungarian)
    @"ü": @33,  // ü at [ position (German/Nordic)
    @"ö": @41,  // ö at ; position (German/Nordic)
    @"ä": @39,  // ä at ' position (German/Nordic)

    // French AZERTY specific
    @"é": @19,  // é at 2 position
    @"è": @26,  // è at 7 position
    @"ù": @39,  // ù at ' position
    @"²": @50,  // ² at ` position
    @"«": @30,  // « guillemet
    @"»": @42,  // » guillemet
    @"µ": @42,  // µ (micro)

    // Spanish
    @"ñ": @41,  // ñ at ; position
    @"¡": @24,  // ¡ at = position
    @"¿": @27,  // ¿ at - position
    @"¬": @50,  // ¬ at ` position

    // Italian
    @"ò": @41,  // ò at ; position
    @"ì": @24,  // ì at = position

    // Portuguese
    @"ç": @41,  // ç at ; position (most common)
    @"º": @50,  // º at ` position
    @"ª": @50,  // ª at ` position

    // Nordic (Swedish, Norwegian, Danish, Finnish)
    @"å": @33,  // å at [ position
    @"æ": @39,  // æ at ' position
    @"ø": @41,  // ø at ; position
    @"§": @50,  // § at ` position
    @"½": @50,  // ½ at ` position
    @"¤": @21,  // ¤ currency at 4 position

    // Polish
    @"ą": @0, @"ć": @8, @"ę": @14, @"ł": @37, @"ń": @45,
    @"ó": @31, @"ś": @1, @"ź": @7, @"ż": @6,

    // Czech/Slovak
    @"ě": @19, @"š": @20, @"č": @21, @"ř": @23, @"ž": @22,
    @"ý": @26, @"á": @28, @"í": @25, @"ú": @41, @"ů": @33,
    @"ď": @30, @"ť": @39, @"ň": @42,

    // Hungarian
    @"ő": @27, @"ű": @42,

    // Turkish
    @"ğ": @33, @"ş": @41, @"ı": @34,

    // Dead keys and accents (excluding ^ which is already defined in QWERTY section)
    @"´": @24,  // acute accent
    @"¨": @33,  // diaeresis
    @"à": @29,  // à at 0 position (AZERTY)

    // Currency and special symbols
    @"€": @14,  // € Euro
    @"£": @20,  // £ Pound
    @"¥": @16,  // ¥ Yen
    @"¢": @8,   // ¢ Cent
    @"©": @8,   // © Copyright
    @"®": @15,  // ® Registered
    @"™": @17,  // ™ Trademark
    @"°": @28,  // ° Degree
    @"±": @24,  // ± Plus-minus
    @"×": @7,   // × Multiplication
    @"÷": @44,  // ÷ Division
    @"≠": @24,  // ≠ Not equal
    @"≤": @43,  // ≤ Less/equal
    @"≥": @47,  // ≥ Greater/equal
    @"∞": @23,  // ∞ Infinity
    @"…": @41,  // … Ellipsis
    @"–": @27,  // – En dash
    @"—": @27,  // — Em dash
    @"\u2018": @39,  // ' Left single quote
    @"\u2019": @39,  // ' Right single quote
    @"\u201C": @39,  // " Left double quote
    @"\u201D": @39   // " Right double quote
};

extern AppDelegate* appDelegate;
extern volatile int vSendKeyStepByStep;
extern volatile int vPerformLayoutCompat;
extern volatile int vTempOffPHTV;

extern "C" {
    //app which must sent special empty character - Using NSSet for O(1) lookup performance
    NSSet* _niceSpaceAppSet = [NSSet setWithArray:@[@"com.sublimetext.3",
                                                     @"com.sublimetext.2"]];

    //app which error with unicode Compound - Using NSSet for O(1) lookup performance
    NSSet* _unicodeCompoundAppSet = [NSSet setWithArray:@[@"com.apple.",
                                                           @"com.google.Chrome",
                                                           @"com.brave.Browser",
                                                           @"com.microsoft.edgemac",  // Edge Stable
                                                           @"com.microsoft.edgemac.Dev",
                                                           @"com.microsoft.edgemac.Beta",
                                                           @"com.microsoft.Edge",  // Edge Stable (alternate)
                                                           @"com.microsoft.Edge.Dev",
                                                           @"com.thebrowser.Browser",  // Arc Browser
                                                           @"company.thebrowser.dia",  // Dia Browser
                                                           @"org.chromium.Chromium",  // Chromium
                                                           @"com.vivaldi.Vivaldi",  // Vivaldi
                                                           @"com.operasoftware.Opera"]];  // Opera

    // Browsers (Chromium, Safari, Firefox, etc.)
    // These apps have their own address bar autocomplete/prediction that conflicts 
    // with Spotlight-style HID tap posting or AX API replacement.
    // They should be treated as normal apps (using CGEventTapPostEvent and SendEmptyCharacter).
    // BROWSER SET: All major browsers including Chromium-based variants
    // This ensures browser input fixes (adaptive delays, empty character timing, etc.) apply universally
    NSSet* _browserAppSet = [NSSet setWithArray:@[
        // Safari (WebKit)
        @"com.apple.Safari",
        @"com.apple.SafariTechnologyPreview",  // Safari Technology Preview

        // Firefox (Gecko)
        @"org.mozilla.firefox",
        @"org.mozilla.firefoxdeveloperedition",  // Firefox Developer Edition
        @"org.mozilla.nightly",  // Firefox Nightly
        @"app.zen-browser.zen",  // Zen Browser (Firefox-based)

        // Chrome (all variants)
        @"com.google.Chrome",
        @"com.google.Chrome.canary",  // Chrome Canary
        @"com.google.Chrome.dev",     // Chrome Dev
        @"com.google.Chrome.beta",    // Chrome Beta

        // Chromium-based browsers
        @"org.chromium.Chromium",     // Pure Chromium
        @"com.brave.Browser",         // Brave
        @"com.brave.Browser.beta",    // Brave Beta
        @"com.brave.Browser.nightly", // Brave Nightly

        // Microsoft Edge (all variants)
        @"com.microsoft.edgemac",      // Edge Stable
        @"com.microsoft.edgemac.Dev",  // Edge Dev
        @"com.microsoft.edgemac.Beta", // Edge Beta
        @"com.microsoft.edgemac.Canary", // Edge Canary
        @"com.microsoft.Edge",         // Edge Stable (alternate ID)
        @"com.microsoft.Edge.Dev",     // Edge Dev (alternate ID)

        // Arc Browser family
        @"com.thebrowser.Browser",     // Arc Browser

        // Vietnamese browsers
        @"com.visualkit.browser",      // Cốc Cốc (old)
        @"com.coccoc.browser",         // Cốc Cốc (new)

        // Other Chromium-based browsers
        @"com.vivaldi.Vivaldi",        // Vivaldi
        @"com.operasoftware.Opera",    // Opera
        @"com.operasoftware.OperaGX",  // Opera GX
        @"com.kagi.kagimacOS",         // Orion (WebKit + partial Chromium compat)
        @"com.duckduckgo.macos.browser", // DuckDuckGo
        @"com.sigmaos.sigmaos.macos",  // SigmaOS
        @"com.pushplaylabs.sidekick",  // Sidekick Browser
        @"com.bookry.wavebox",         // Wavebox
        @"com.mighty.app",             // Mighty Browser
        @"com.collovos.naver.whale",   // Naver Whale
        @"ru.yandex.desktop.yandex-browser", // Yandex Browser

        // Electron-based apps (Chromium engine)
        // These apps use Chromium's text input system and need browser fixes
        @"com.tinyspeck.slackmacgap",  // Slack
        @"com.hnc.Discord",            // Discord
        @"com.electron.discord",       // Discord (alternate)
        // NOTE: VSCode removed from this list - terminal needs Layout Compatibility enabled
        @"com.github.GitHubClient",    // GitHub Desktop
        @"com.figma.Desktop",          // Figma
        @"notion.id",                  // Notion
        @"com.linear",                 // Linear
        @"com.logseq.logseq",          // Logseq
        @"md.obsidian",                // Obsidian
    ]];

    // Apps that need to FORCE Unicode precomposed (not compound) - Using NSSet for O(1) lookup performance
    // These apps don't handle Unicode combining characters properly
    // Note: Most apps are now auto-detected via search field detection (IsElementSpotlight)
    // Only apps that ALWAYS need precomposed (not just in search fields) should be listed here
    NSSet* _forcePrecomposedAppSet = [NSSet setWithArray:@[@"com.apple.Spotlight",
                                                            @"com.apple.systemuiserver"]];  // Spotlight runs under SystemUIServer

    // Apps that need precomposed Unicode but should use normal batched sending (not AX API)
    // These are Electron/web apps that don't support AX text replacement
    // NOTE: Microsoft Office apps support Vietnamese compound Unicode properly in documents
    // Template search may have minor issues but prioritizing document editing experience
    NSSet* _precomposedBatchedAppSet = [NSSet setWithArray:@[@"net.whatsapp.WhatsApp",
                                                              @"notion.id"]];  // Notion - Electron app

    //app which needs step by step key sending (timing sensitive apps) - Using NSSet for O(1) lookup performance
    NSSet* _stepByStepAppSet = [NSSet setWithArray:@[// Commented out for testing Vietnamese input:
                                                      // @"com.apple.Spotlight",
                                                      // @"com.apple.systemuiserver",  // Spotlight runs under SystemUIServer
                                                      @"com.apple.loginwindow",     // Login window
                                                      @"com.apple.SecurityAgent",   // Security dialogs
                                                      @"com.raycast.macos",
                                                      @"com.alfredapp.Alfred",
                                                      @"com.apple.launchpad",       // Launchpad/Ứng dụng
                                                      @"notion.id"]];               // Notion - needs step-by-step for stability
                                                      // Removed WhatsApp - step-by-step causes more issues

    // Apps where Vietnamese input should be disabled (search/launcher apps) - Using NSSet for O(1) lookup performance
    NSSet* _disableVietnameseAppSet = [NSSet setWithArray:@[
        @"com.apple.apps.launcher",       // Apps.app (Applications)
        @"com.apple.ScreenContinuity",    // iPhone Mirroring
        // WhatsApp is handled separately (force precomposed Unicode like Spotlight)
    ]];
    
    // Optimized helper to check if bundleId matches any app in the set (exact match or prefix)
    // PERFORMANCE: inline + always_inline attribute for hot path optimization
    __attribute__((always_inline)) static inline BOOL bundleIdMatchesAppSet(NSString* bundleId, NSSet* appSet) {
        if (bundleId == nil) return NO;

        // Fast path: exact match using O(1) NSSet lookup
        if ([appSet containsObject:bundleId]) {
            return YES;
        }

        // Slower path: check for prefix matches (needed for "com.apple." pattern)
        for (NSString* app in appSet) {
            if ([bundleId hasPrefix:app]) {
                return YES;
            }
        }
        return NO;
    }

    // Forward declaration
    BOOL isTerminalApp(NSString *bundleId);

    // Get cached app characteristics or compute and cache them
    // This reduces 5-10 function calls per keystroke to 1 dictionary lookup
    // PERFORMANCE: Critical hot path optimization - ~15ms savings per keystroke
    static inline AppCharacteristics getAppCharacteristics(NSString* bundleId) {
        if (!bundleId) {
            AppCharacteristics empty = {NO, NO, NO, NO, NO};
            return empty;
        }

        // Fast path: check cache with lock
        os_unfair_lock_lock(&_appCharCacheLock);

        // Initialize cache on first use
        if (__builtin_expect(_appCharacteristicsCache == nil, 0)) {
            _appCharacteristicsCache = [NSMutableDictionary dictionaryWithCapacity:32];
        }

        // CRITICAL FIX: Invalidate cache on app switch or periodically
        // Reduced from 30s to 10s for better browser detection responsiveness
        // This fixes WhatsApp and browser issues where behavior changes dynamically
        uint64_t now = mach_absolute_time();
        static mach_timebase_info_data_t timebase;
        if (timebase.denom == 0) {
            mach_timebase_info(&timebase);
        }
        uint64_t nowMs = (now * timebase.numer) / (timebase.denom * 1000000);

        BOOL shouldInvalidate = NO;

        // Invalidate on app switch (different bundle ID)
        if (_lastCachedBundleId != nil && ![_lastCachedBundleId isEqualToString:bundleId]) {
            shouldInvalidate = YES;
            #ifdef DEBUG
            NSLog(@"[Cache] App switched: %@ -> %@, invalidating cache", _lastCachedBundleId, bundleId);
            #endif
        }

        // BROWSER FIX: Invalidate every 10 seconds (reduced from 30s)
        // Browsers change behavior dynamically (search bar vs page content, tab switches)
        // Faster invalidation ensures adaptive delays respond to current context
        if (nowMs - _lastCacheInvalidationTime > 10000) {
            shouldInvalidate = YES;
            _lastCacheInvalidationTime = nowMs;
            #ifdef DEBUG
            NSLog(@"[Cache] 10s elapsed, invalidating cache for browser responsiveness");
            #endif
        }

        if (shouldInvalidate) {
            [_appCharacteristicsCache removeAllObjects];
            _lastCachedBundleId = bundleId;
        }

        NSValue *cached = _appCharacteristicsCache[bundleId];
        if (cached) {
            AppCharacteristics chars;
            [cached getValue:&chars];
            os_unfair_lock_unlock(&_appCharCacheLock);
            return chars;
        }
        os_unfair_lock_unlock(&_appCharCacheLock);

        // Compute characteristics (slow path - only once per app)
        AppCharacteristics chars;
        chars.isSpotlightLike = bundleIdMatchesAppSet(bundleId, _forcePrecomposedAppSet);
        chars.needsPrecomposedBatched = bundleIdMatchesAppSet(bundleId, _precomposedBatchedAppSet);
        chars.isTerminal = isTerminalApp(bundleId);
        chars.needsStepByStep = bundleIdMatchesAppSet(bundleId, _stepByStepAppSet);
        chars.containsUnicodeCompound = [_unicodeCompoundAppSet containsObject:bundleId];

        // Cache for future use
        os_unfair_lock_lock(&_appCharCacheLock);
        _appCharacteristicsCache[bundleId] = [NSValue valueWithBytes:&chars objCType:@encode(AppCharacteristics)];
        os_unfair_lock_unlock(&_appCharCacheLock);

        return chars;
    }

    __attribute__((always_inline)) static inline BOOL isSpotlightLikeApp(NSString* bundleId) {
        return bundleIdMatchesAppSet(bundleId, _forcePrecomposedAppSet);
    }

    // Check if app needs precomposed Unicode but with batched sending (not AX API)
    __attribute__((always_inline)) static inline BOOL needsPrecomposedBatched(NSString* bundleId) {
        return bundleIdMatchesAppSet(bundleId, _precomposedBatchedAppSet);
    }

    // Cache the effective target bundle id for the current event tap callback.
    // This avoids re-querying AX focus inside hot-path send routines.
    static NSString* _phtvEffectiveTargetBundleId = nil;
    static BOOL _phtvPostToHIDTap = NO;
    static int64_t _phtvKeyboardType = 0;
    static int _phtvPendingBackspaceCount = 0;

    __attribute__((always_inline)) static inline void SpotlightTinyDelay(void) {
        usleep(SPOTLIGHT_TINY_DELAY_US);
    }

    // Simple and reliable: always read fresh from AX, no tracking
    static BOOL ReplaceFocusedTextViaAX(NSInteger backspaceCount, NSString* insertText) {
        // Safe Mode: Skip AX API calls entirely
        // This prevents crashes on unsupported hardware (OCLP Macs)
        if (vSafeMode) {
            return NO;
        }

        if (backspaceCount < 0) backspaceCount = 0;
        if (insertText == nil) insertText = @"";

        AXUIElementRef systemWide = AXUIElementCreateSystemWide();
        AXUIElementRef focusedElement = NULL;
        AXError error = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute, (CFTypeRef *)&focusedElement);
        CFRelease(systemWide);
        if (error != kAXErrorSuccess || focusedElement == NULL) {
            return NO;
        }

        // Read current value
        CFTypeRef valueRef = NULL;
        error = AXUIElementCopyAttributeValue(focusedElement, kAXValueAttribute, &valueRef);
        if (error != kAXErrorSuccess) {
            CFRelease(focusedElement);
            return NO;
        }
        NSString *valueStr = (valueRef && CFGetTypeID(valueRef) == CFStringGetTypeID()) ? (__bridge NSString *)valueRef : @"";

        // Read caret position and selected text range
        CFTypeRef rangeRef = NULL;
        NSInteger caretLocation = (NSInteger)valueStr.length;
        NSInteger selectedLength = 0;
        error = AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextRangeAttribute, &rangeRef);
        if (error == kAXErrorSuccess && rangeRef && CFGetTypeID(rangeRef) == AXValueGetTypeID()) {
            CFRange sel;
            if (AXValueGetValue((AXValueRef)rangeRef, PHTV_AXVALUE_CFRANGE_TYPE, &sel)) {
                caretLocation = (NSInteger)sel.location;
                selectedLength = (NSInteger)sel.length;
            }
        }
        if (rangeRef) CFRelease(rangeRef);

        // Clamp
        if (caretLocation < 0) caretLocation = 0;
        if (caretLocation > (NSInteger)valueStr.length) caretLocation = (NSInteger)valueStr.length;

        // Calculate replacement position
        NSInteger start;

        // If there's selected text, replace it instead of using backspaceCount
        if (selectedLength > 0) {
            // User has highlighted text - replace the selected range
            start = caretLocation;
        } else {
            // No selection - use backspaceCount to calculate how much to delete
            // Handle Unicode composed/decomposed length mismatch
            // The backspaceCount from engine counts logical characters, but Spotlight may have
            // different Unicode representation (composed vs decomposed)
            start = caretLocation - backspaceCount;
        }

        if (start < 0) start = 0;

        // Calculate replacement length
        NSInteger len;

        if (selectedLength > 0) {
            // User has selected text - use the selected length
            len = selectedLength;
        } else {
            // No selection - use backspaceCount to calculate deletion length
            // If we're replacing text, verify the length matches what we expect
            // Vietnamese text may have combining characters that increase length
            if (backspaceCount > 0 && start < caretLocation) {
                NSString *textToDelete = [valueStr substringWithRange:NSMakeRange(start, caretLocation - start)];
                // Get composed form length - this is what engine expects
                NSString *composedText = [textToDelete precomposedStringWithCanonicalMapping];
                NSInteger composedLen = (NSInteger)composedText.length;

                // If composed length differs from backspaceCount, the text in Spotlight
                // may be in decomposed form - recalculate start position
                if (composedLen != backspaceCount && composedLen > 0) {
                    // Try to find correct start by counting composed characters backwards
                    NSInteger actualStart = caretLocation;
                    NSInteger composedCount = 0;
                    while (actualStart > 0 && composedCount < backspaceCount) {
                        actualStart--;
                        // Check if this is a base character (not combining mark)
                        unichar c = [valueStr characterAtIndex:actualStart];
                        // Skip combining marks (0x0300-0x036F, 0x1DC0-0x1DFF, etc.)
                        if (!(c >= 0x0300 && c <= 0x036F) &&
                            !(c >= 0x1DC0 && c <= 0x1DFF) &&
                            !(c >= 0x20D0 && c <= 0x20FF) &&
                            !(c >= 0xFE20 && c <= 0xFE2F)) {
                            composedCount++;
                        }
                    }
                    start = actualStart;
                }
            }

            len = caretLocation - start;
        }

        // Clamp length to valid range
        if (start + len > (NSInteger)valueStr.length) len = (NSInteger)valueStr.length - start;
        if (len < 0) len = 0;

        NSString *newValue = [valueStr stringByReplacingCharactersInRange:NSMakeRange(start, len) withString:insertText];

        // Write new value
        AXError writeError = AXUIElementSetAttributeValue(focusedElement, kAXValueAttribute, (__bridge CFTypeRef)newValue);
        if (writeError != kAXErrorSuccess) {
            LogAXError(writeError, "AXUIElementSetAttributeValue(kAXValueAttribute)");
            if (valueRef) CFRelease(valueRef);
            CFRelease(focusedElement);
            return NO;
        }

        // Set caret position
        NSInteger newCaret = start + (NSInteger)insertText.length;
        CFRange newSel = CFRangeMake(newCaret, 0);
        AXValueRef newRange = AXValueCreate(PHTV_AXVALUE_CFRANGE_TYPE, &newSel);
        if (newRange) {
            AXUIElementSetAttributeValue(focusedElement, kAXSelectedTextRangeAttribute, newRange);
            CFRelease(newRange);
        }

        if (valueRef) CFRelease(valueRef);
        CFRelease(focusedElement);
        return YES;
    }

    __attribute__((always_inline)) static inline void PostSyntheticEvent(CGEventTapProxy proxy, CGEventRef e) {
        if (_phtvPostToHIDTap) {
            CGEventPost(kCGHIDEventTap, e);
        } else {
            CGEventTapPostEvent(proxy, e);
        }
    }

    __attribute__((always_inline)) static inline void ApplyKeyboardTypeAndFlags(CGEventRef down, CGEventRef up) {
        if (_phtvKeyboardType != 0) {
            CGEventSetIntegerValueField(down, kCGKeyboardEventKeyboardType, _phtvKeyboardType);
            CGEventSetIntegerValueField(up, kCGKeyboardEventKeyboardType, _phtvKeyboardType);
        }
        if (_phtvPostToHIDTap) {
            // Spotlight/SystemUIServer is sensitive to coalescing.
            CGEventFlags flags = CGEventGetFlags(down);
            flags |= kCGEventFlagMaskNonCoalesced;
            // CRITICAL FIX: Clear Fn/Globe flag to prevent triggering system hotkeys
            // (e.g., Fn+E opens Character Viewer/Emoji picker on macOS)
            flags &= ~kCGEventFlagMaskSecondaryFn;
            CGEventSetFlags(down, flags);
            CGEventSetFlags(up, flags);
        }
    }

    // Check if Vietnamese input should be disabled for current app (using PID)
    // PERFORMANCE: inline for hot path (called on every keystroke)
    __attribute__((always_inline)) static inline BOOL shouldDisableVietnameseForEvent(CGEventRef event) {
        static pid_t lastPid = -1;
        static uint64_t lastCheckTime = 0;
        static BOOL lastResult = NO;

        uint64_t now = mach_absolute_time();
        pid_t targetPID = (pid_t)CGEventGetIntegerValueField(event, kCGEventTargetUnixProcessID);

        // Fast path: reuse last decision if same PID and checked recently
        // Very short cache for immediate app-switch response
        uint64_t elapsed_ms = mach_time_to_ms(now - lastCheckTime);
        if (__builtin_expect(targetPID > 0 && targetPID == lastPid && elapsed_ms < APP_SWITCH_CACHE_DURATION_MS, 1)) {
            return lastResult;
        }

        // Use getFocusedAppBundleId() which is now optimized with focus cache
        NSString *bundleId = getFocusedAppBundleId();
        pid_t cachePid = targetPID;

        BOOL shouldDisable = bundleIdMatchesAppSet(bundleId, _disableVietnameseAppSet);

        // Update cache only when we have a valid PID, to avoid cross-app leakage
        lastResult = shouldDisable;
        lastCheckTime = now;
        lastPid = (cachePid > 0) ? cachePid : -1;

        return shouldDisable;
    }

    // Legacy check (for backward compatibility)
    BOOL shouldDisableVietnamese(NSString* bundleId) {
        return bundleIdMatchesAppSet(bundleId, _disableVietnameseAppSet);
    }

    // Legacy check (for backward compatibility)
    BOOL needsStepByStep(NSString* bundleId) {
        return bundleIdMatchesAppSet(bundleId, _stepByStepAppSet);
    }
    
    CGEventSourceRef myEventSource = NULL;
    vKeyHookState* pData;
    CGEventRef eventBackSpaceDown;
    CGEventRef eventBackSpaceUp;
    UniChar _newChar, _newCharHi;
    CGEventRef _newEventDown, _newEventUp;
    CGKeyCode _keycode;
    CGEventFlags _flag, _lastFlag = 0, _privateFlag;
    CGEventTapProxy _proxy;
    
    Uint16 _newCharString[MAX_UNICODE_STRING];
    Uint16 _newCharSize;
    bool _willContinuteSending = false;
    bool _willSendControlKey = false;
    
    vector<Uint16> _syncKey;
    
    Uint16 _uniChar[2];
    int _i, _j, _k;
    Uint32 _tempChar;
    bool _hasJustUsedHotKey = false;

    // For restore key detection with modifier keys
    bool _restoreModifierPressed = false;
    bool _keyPressedWithRestoreModifier = false;

    // For switch hotkey exact match - prevent prefix matching
    // (e.g., Cmd+Shift should NOT trigger when user presses Cmd+Shift+S)
    bool _keyPressedWhileSwitchModifiersHeld = false;

    // For pause key detection - temporarily disable Vietnamese when holding key
    bool _pauseKeyPressed = false;
    int _savedLanguageBeforePause = 1; // Save language state before pause (1 = Vietnamese, 0 = English)

    int _languageTemp = 0; //use for smart switch key
    vector<Byte> savedSmartSwitchKeyData; ////use for smart switch key
    
    NSString* _frontMostApp = @"UnknownApp";
    
    void PHTVInit() {
        // Initialize logging infrastructure first
        dispatch_once(&log_init_token, ^{
            phtv_log = os_log_create("com.phamhungtien.phtv", "Engine");
        });
        dispatch_once(&timebase_init_token, ^{
            mach_timebase_info(&timebase_info);
        });

        //load saved data
        LOAD_DATA(vLanguage, InputMethod); if (vLanguage < 0) vLanguage = 1;
        LOAD_DATA(vInputType, InputType); if (vInputType < 0) vInputType = 0;
        vFreeMark = 0;//(int)[[NSUserDefaults standardUserDefaults] integerForKey:@"FreeMark"];
        LOAD_DATA(vCodeTable, CodeTable); if (vCodeTable < 0) vCodeTable = 0;
        LOAD_DATA(vCheckSpelling, Spelling);
        LOAD_DATA(vQuickTelex, QuickTelex);
        LOAD_DATA(vUseModernOrthography, ModernOrthography);
        LOAD_DATA(vRestoreIfWrongSpelling, RestoreIfInvalidWord);
        LOAD_DATA(vFixRecommendBrowser, FixRecommendBrowser);
        LOAD_DATA(vUseMacro, UseMacro);
        LOAD_DATA(vUseMacroInEnglishMode, UseMacroInEnglishMode);
        LOAD_DATA(vAutoCapsMacro, vAutoCapsMacro);
        LOAD_DATA(vSendKeyStepByStep, SendKeyStepByStep);
        LOAD_DATA(vUseSmartSwitchKey, UseSmartSwitchKey);
        LOAD_DATA(vUpperCaseFirstChar, UpperCaseFirstChar);

        LOAD_DATA(vTempOffSpelling, vTempOffSpelling);
        LOAD_DATA(vAllowConsonantZFWJ, vAllowConsonantZFWJ);
        LOAD_DATA(vQuickEndConsonant, vQuickEndConsonant);
        LOAD_DATA(vQuickStartConsonant, vQuickStartConsonant);
        LOAD_DATA(vRememberCode, vRememberCode);
        LOAD_DATA(vOtherLanguage, vOtherLanguage);
        LOAD_DATA(vTempOffPHTV, vTempOffPHTV);

        LOAD_DATA(vPerformLayoutCompat, vPerformLayoutCompat);
        LOAD_DATA(vSafeMode, SafeMode);

        // Auto-detect AX crash: Check if previous AX test caused crash
        // If AXTestInProgress flag is still set, previous launch crashed during AX test
        NSUserDefaults *axDefaults = [NSUserDefaults standardUserDefaults];
        if ([axDefaults boolForKey:@"AXTestInProgress"]) {
            // Previous launch crashed during AX API call - auto-enable safe mode
            vSafeMode = YES;
            [axDefaults setBool:YES forKey:@"SafeMode"];
            [axDefaults setBool:NO forKey:@"AXTestInProgress"];
            [axDefaults synchronize];
            os_log_error(phtv_log, "[PHTV] ⚠️ Auto-enabled Safe Mode: Previous AX API call crashed");
            NSLog(@"[PHTV] ⚠️ Auto-enabled Safe Mode due to previous AX crash");
        }

        // Test AX API if not in safe mode
        if (!vSafeMode) {
            // Set flag before attempting AX call
            [axDefaults setBool:YES forKey:@"AXTestInProgress"];
            [axDefaults synchronize];

            // Attempt a simple AX API call
            @try {
                AXUIElementRef testSystemWide = AXUIElementCreateSystemWide();
                if (testSystemWide != NULL) {
                    CFRelease(testSystemWide);
                }
                // AX test passed - clear the flag
                [axDefaults setBool:NO forKey:@"AXTestInProgress"];
                [axDefaults synchronize];
                os_log_info(phtv_log, "[PHTV] AX API test passed");
            }
            @catch (NSException *exception) {
                // AX test threw exception - enable safe mode
                vSafeMode = YES;
                [axDefaults setBool:YES forKey:@"SafeMode"];
                [axDefaults setBool:NO forKey:@"AXTestInProgress"];
                [axDefaults synchronize];
                os_log_error(phtv_log, "[PHTV] ⚠️ AX API test failed with exception, enabling Safe Mode");
            }
        }

        // Auto-enable layout compatibility for non-US keyboard layouts
        // Check if user has never set this preference (key doesn't exist)
        NSUserDefaults *layoutDefaults = [NSUserDefaults standardUserDefaults];
        if ([layoutDefaults objectForKey:@"vPerformLayoutCompat"] == nil) {
            // First run - auto-detect keyboard layout
            TISInputSourceRef currentKeyboard = TISCopyCurrentKeyboardInputSource();
            if (currentKeyboard != NULL) {
                CFStringRef sourceID = (CFStringRef)TISGetInputSourceProperty(currentKeyboard, kTISPropertyInputSourceID);
                if (sourceID != NULL) {
                    NSString *keyboardID = (__bridge NSString *)sourceID;
                    // Check if NOT a standard US keyboard layout
                    // US layouts typically contain "US" or "ABC" in their ID
                    BOOL isUSLayout = [keyboardID containsString:@".US"] ||
                                      [keyboardID containsString:@".ABC"] ||
                                      [keyboardID isEqualToString:@"com.apple.keylayout.US"];
                    if (!isUSLayout) {
                        // Auto-enable layout compatibility for non-US keyboards (QWERTZ, AZERTY, etc.)
                        vPerformLayoutCompat = 1;
                        [layoutDefaults setInteger:vPerformLayoutCompat forKey:@"vPerformLayoutCompat"];
                        os_log_info(phtv_log, "[PHTV] Auto-enabled layout compatibility for non-US keyboard: %{public}@", keyboardID);
                    }
                }
                CFRelease(currentKeyboard);
            }
        }

        myEventSource = CGEventSourceCreate(kCGEventSourceStatePrivate);
        pData = (vKeyHookState*)vKeyInit();

        // Performance optimization: Pre-allocate _syncKey vector to avoid reallocations
        // Typical typing buffer is ~50 chars, reserve for safety margin
        _syncKey.reserve(SYNC_KEY_RESERVE_SIZE);

        eventBackSpaceDown = CGEventCreateKeyboardEvent (myEventSource, 51, true);
        eventBackSpaceUp = CGEventCreateKeyboardEvent (myEventSource, 51, false);
        
        //init and load macro data
        NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
        NSData *data = [prefs objectForKey:@"macroData"];
        initMacroMap((Byte*)data.bytes, (int)data.length);
        
        //init and load smart switch key data
        data = [prefs objectForKey:@"smartSwitchKey"];
        initSmartSwitchKey((Byte*)data.bytes, (int)data.length);
        
        //init convert tool
        convertToolDontAlertWhenCompleted = ![prefs boolForKey:@"convertToolDontAlertWhenCompleted"];
        convertToolToAllCaps = [prefs boolForKey:@"convertToolToAllCaps"];
        convertToolToAllNonCaps = [prefs boolForKey:@"convertToolToAllNonCaps"];
        convertToolToCapsFirstLetter = [prefs boolForKey:@"convertToolToCapsFirstLetter"];
        convertToolToCapsEachWord = [prefs boolForKey:@"convertToolToCapsEachWord"];
        convertToolRemoveMark = [prefs boolForKey:@"convertToolRemoveMark"];
        convertToolFromCode = [prefs integerForKey:@"convertToolFromCode"];
        convertToolToCode = [prefs integerForKey:@"convertToolToCode"];
        convertToolHotKey = (int)[prefs integerForKey:@"convertToolHotKey"];
        if (convertToolHotKey == 0) {
            convertToolHotKey = EMPTY_HOTKEY;
        }
    }
    
    void RequestNewSession() {
        // Acquire barrier: ensure we see latest config changes before processing
        __atomic_thread_fence(__ATOMIC_ACQUIRE);

        #ifdef DEBUG
        // Use atomic loads for thread-safe debug logging
        int dbg_inputType = __atomic_load_n(&vInputType, __ATOMIC_RELAXED);
        int dbg_codeTable = __atomic_load_n(&vCodeTable, __ATOMIC_RELAXED);
        int dbg_language = __atomic_load_n(&vLanguage, __ATOMIC_RELAXED);
        NSLog(@"[RequestNewSession] vInputType=%d, vCodeTable=%d, vLanguage=%d",
              dbg_inputType, dbg_codeTable, dbg_language);
        #endif

        // Must use vKeyHandleEvent with Mouse event, NOT startNewSession directly!
        // The Mouse event triggers proper word-break handling which clears:
        // - hMacroKey (critical for macro state)
        // - _specialChar and _typingStates (critical for typing state)
        // - vCheckSpelling restoration
        // - _willTempOffEngine flag
        vKeyHandleEvent(vKeyEvent::Mouse, vKeyEventState::MouseDown, 0);

        // Clear VNI/Unicode Compound sync tracking
        int currentCodeTable = __atomic_load_n(&vCodeTable, __ATOMIC_RELAXED);
        if (IS_DOUBLE_CODE(currentCodeTable)) {
            _syncKey.clear();
        }

        // Reset additional state variables
        _lastFlag = 0;
        _willContinuteSending = false;
        _willSendControlKey = false;
        _hasJustUsedHotKey = false;

        // Release barrier: ensure state reset is visible to all threads
        __atomic_thread_fence(__ATOMIC_RELEASE);

        #ifdef DEBUG
        NSLog(@"[RequestNewSession] Session reset complete");
        #endif
    }

    NSString* ConvertUtil(NSString* str) {
        return [NSString stringWithUTF8String:convertUtil([str UTF8String]).c_str()];
    }
    
    // Get bundle ID of the actually focused app (not just frontmost)
    // This is important for overlay windows like Spotlight, which aren't the frontmost app
    // OPTIMIZED: Uses the cache populated by isSpotlightActive()
    NSString* getFocusedAppBundleId() {
        // Safe Mode: Skip AX API calls entirely, use frontmost app
        // This prevents crashes on unsupported hardware (OCLP Macs)
        if (vSafeMode) {
            return FRONT_APP;
        }
    
        // Ensure cache is reasonably fresh (within 50ms)
        // isSpotlightActive() is always called before getFocusedAppBundleId() in the hot path
        uint64_t now = mach_absolute_time();
        os_unfair_lock_lock(&_spotlightCacheLock);
        uint64_t lastCheck = _lastSpotlightCheckTime;
        NSString *cachedBundleId = [_cachedFocusedBundleId copy];
        os_unfair_lock_unlock(&_spotlightCacheLock);
    
        uint64_t elapsed_ms = mach_time_to_ms(now - lastCheck);
        if (elapsed_ms < SPOTLIGHT_CACHE_DURATION_MS && lastCheck > 0 && cachedBundleId != nil) {
            return cachedBundleId;
        }
    
        // Cache miss or too old - trigger a fresh check via isSpotlightActive
        isSpotlightActive();
    
        os_unfair_lock_lock(&_spotlightCacheLock);
        NSString *result = [_cachedFocusedBundleId copy];
        os_unfair_lock_unlock(&_spotlightCacheLock);
    
        return (result != nil) ? result : FRONT_APP;
    }    
    BOOL containUnicodeCompoundApp(NSString* topApp) {
        // Optimized to use NSSet for O(1) lookup instead of O(n) array iteration
        return bundleIdMatchesAppSet(topApp, _unicodeCompoundAppSet);
    }
    
    BOOL needsForcePrecomposed(NSString* bundleId) {
        return bundleIdMatchesAppSet(bundleId, _forcePrecomposedAppSet);
    }
    
    void saveSmartSwitchKeyData() {
        getSmartSwitchKeySaveData(savedSmartSwitchKeyData);
        NSData* _data = [NSData dataWithBytes:savedSmartSwitchKeyData.data() length:savedSmartSwitchKeyData.size()];
        NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
        [prefs setObject:_data forKey:@"smartSwitchKey"];
    }
    
    void OnActiveAppChanged() { //use for smart switch key; improved on Sep 28th, 2019
        if (!vUseSmartSwitchKey && !vRememberCode) {
            return;  // Skip if features disabled - performance optimization
        }

        // Use the optimized focused app bundle ID
        _frontMostApp = getFocusedAppBundleId();
        
        _languageTemp = getAppInputMethodStatus(string(_frontMostApp.UTF8String), vLanguage | (vCodeTable << 1));

        if ((_languageTemp & 0x01) != vLanguage) { //for input method
            if (_languageTemp != -1) {
                // PERFORMANCE: Update state directly without triggering callbacks
                // onImputMethodChanged would cause cascading updates
                vLanguage = _languageTemp;
                [[NSUserDefaults standardUserDefaults] setInteger:vLanguage forKey:@"InputMethod"];
                RequestNewSession();  // Direct call, no cascading
                [appDelegate fillData];  // Update UI only

                // Notify SwiftUI (use separate notification for smart switch to avoid sound)
                [[NSNotificationCenter defaultCenter] postNotificationName:@"LanguageChangedFromSmartSwitch"
                                                                    object:@(vLanguage)];
            } else {
                saveSmartSwitchKeyData();
            }
        }
        if (vRememberCode && (_languageTemp >> 1) != vCodeTable) { //for remember table code feature
            if (_languageTemp != -1) {
                // PERFORMANCE: Update state directly
                vCodeTable = (_languageTemp >> 1);
                [[NSUserDefaults standardUserDefaults] setInteger:vCodeTable forKey:@"CodeTable"];
                RequestNewSession();
                [appDelegate fillData];
            } else {
                saveSmartSwitchKeyData();
            }
        }
    }
    
    void OnTableCodeChange() {
        onTableCodeChange();  // Update macro state
        if (!vRememberCode) {
            return;  // Skip if disabled
        }

        // PERFORMANCE: Just save the mapping, don't trigger more updates
        _frontMostApp = getFocusedAppBundleId();
        setAppInputMethodStatus(string(_frontMostApp.UTF8String), vLanguage | (vCodeTable << 1));
        saveSmartSwitchKeyData();
    }
    
    void OnInputMethodChanged() {
        if (!vUseSmartSwitchKey) {
            return;  // Skip if disabled
        }

        // PERFORMANCE: Just save the mapping, don't trigger more updates
        _frontMostApp = getFocusedAppBundleId();
        setAppInputMethodStatus(string(_frontMostApp.UTF8String), vLanguage | (vCodeTable << 1));
        saveSmartSwitchKeyData();
    }
    
    void OnSpellCheckingChanged() {
        vSetCheckSpelling();
    }
    
    void InsertKeyLength(const Uint8& len) {
        _syncKey.push_back(len);
    }
    
    void SendPureCharacter(const Uint16& ch) {
        _newEventDown = CGEventCreateKeyboardEvent(myEventSource, 0, true);
        _newEventUp = CGEventCreateKeyboardEvent(myEventSource, 0, false);
        ApplyKeyboardTypeAndFlags(_newEventDown, _newEventUp);
        CGEventKeyboardSetUnicodeString(_newEventDown, 1, &ch);
        CGEventKeyboardSetUnicodeString(_newEventUp, 1, &ch);
        PostSyntheticEvent(_proxy, _newEventDown);
        PostSyntheticEvent(_proxy, _newEventUp);
        if (_phtvPostToHIDTap) SpotlightTinyDelay();
        CFRelease(_newEventDown);
        CFRelease(_newEventUp);
        if (IS_DOUBLE_CODE(vCodeTable)) {
            InsertKeyLength(1);
        }
    }
    
    void SendKeyCode(Uint32 data) {
        _newChar = (Uint16)data;
        if (!(data & CHAR_CODE_MASK)) {
            if (IS_DOUBLE_CODE(vCodeTable)) //VNI
                InsertKeyLength(1);
            
            _newEventDown = CGEventCreateKeyboardEvent(myEventSource, _newChar, true);
            _newEventUp = CGEventCreateKeyboardEvent(myEventSource, _newChar, false);
            _privateFlag = CGEventGetFlags(_newEventDown);
            
            if (data & CAPS_MASK) {
                _privateFlag |= kCGEventFlagMaskShift;
            } else {
                _privateFlag &= ~kCGEventFlagMaskShift;
            }
            _privateFlag |= kCGEventFlagMaskNonCoalesced;
            
            // CRITICAL FIX: Clear Fn/Globe flag to prevent triggering system hotkeys
            // (e.g., Fn+E opens Character Viewer/Emoji picker on macOS)
            // This prevents the bug where typing 'eee' triggers the emoji picker
            _privateFlag &= ~kCGEventFlagMaskSecondaryFn;
            
            CGEventSetFlags(_newEventDown, _privateFlag);
            CGEventSetFlags(_newEventUp, _privateFlag);
            ApplyKeyboardTypeAndFlags(_newEventDown, _newEventUp);
            PostSyntheticEvent(_proxy, _newEventDown);
            PostSyntheticEvent(_proxy, _newEventUp);
            if (_phtvPostToHIDTap) SpotlightTinyDelay();
        } else {
            if (vCodeTable == 0) { //unicode 2 bytes code
                _newEventDown = CGEventCreateKeyboardEvent(myEventSource, 0, true);
                _newEventUp = CGEventCreateKeyboardEvent(myEventSource, 0, false);
                ApplyKeyboardTypeAndFlags(_newEventDown, _newEventUp);
                CGEventKeyboardSetUnicodeString(_newEventDown, 1, &_newChar);
                CGEventKeyboardSetUnicodeString(_newEventUp, 1, &_newChar);
                PostSyntheticEvent(_proxy, _newEventDown);
                PostSyntheticEvent(_proxy, _newEventUp);
                if (_phtvPostToHIDTap) SpotlightTinyDelay();
            } else if (vCodeTable == 1 || vCodeTable == 2 || vCodeTable == 4) { //others such as VNI Windows, TCVN3: 1 byte code
                _newCharHi = HIBYTE(_newChar);
                _newChar = LOBYTE(_newChar);
                
                _newEventDown = CGEventCreateKeyboardEvent(myEventSource, 0, true);
                _newEventUp = CGEventCreateKeyboardEvent(myEventSource, 0, false);
                ApplyKeyboardTypeAndFlags(_newEventDown, _newEventUp);
                CGEventKeyboardSetUnicodeString(_newEventDown, 1, &_newChar);
                CGEventKeyboardSetUnicodeString(_newEventUp, 1, &_newChar);
                PostSyntheticEvent(_proxy, _newEventDown);
                PostSyntheticEvent(_proxy, _newEventUp);
                if (_phtvPostToHIDTap) SpotlightTinyDelay();
                if (_newCharHi > 32) {
                    if (vCodeTable == 2) //VNI
                        InsertKeyLength(2);
                    CFRelease(_newEventDown);
                    CFRelease(_newEventUp);
                    _newEventDown = CGEventCreateKeyboardEvent(myEventSource, 0, true);
                    _newEventUp = CGEventCreateKeyboardEvent(myEventSource, 0, false);
                    ApplyKeyboardTypeAndFlags(_newEventDown, _newEventUp);
                    CGEventKeyboardSetUnicodeString(_newEventDown, 1, &_newCharHi);
                    CGEventKeyboardSetUnicodeString(_newEventUp, 1, &_newCharHi);
                    PostSyntheticEvent(_proxy, _newEventDown);
                    PostSyntheticEvent(_proxy, _newEventUp);
                    if (_phtvPostToHIDTap) SpotlightTinyDelay();
                } else {
                    if (vCodeTable == 2) //VNI
                        InsertKeyLength(1);
                }
            } else if (vCodeTable == 3) { //Unicode Compound
                _newCharHi = (_newChar >> 13);
                _newChar &= 0x1FFF;
                _uniChar[0] = _newChar;
                _uniChar[1] = _newCharHi > 0 ? (_unicodeCompoundMark[_newCharHi - 1]) : 0;
                InsertKeyLength(_newCharHi > 0 ? 2 : 1);
                _newEventDown = CGEventCreateKeyboardEvent(myEventSource, 0, true);
                _newEventUp = CGEventCreateKeyboardEvent(myEventSource, 0, false);
                ApplyKeyboardTypeAndFlags(_newEventDown, _newEventUp);
                CGEventKeyboardSetUnicodeString(_newEventDown, (_newCharHi > 0 ? 2 : 1), _uniChar);
                CGEventKeyboardSetUnicodeString(_newEventUp, (_newCharHi > 0 ? 2 : 1), _uniChar);
                PostSyntheticEvent(_proxy, _newEventDown);
                PostSyntheticEvent(_proxy, _newEventUp);
                if (_phtvPostToHIDTap) SpotlightTinyDelay();
            }
        }
        CFRelease(_newEventDown);
        CFRelease(_newEventUp);
    }

    // Forward declarations for adaptive delay functions
    uint64_t getAdaptiveDelay(uint64_t baseDelay, uint64_t maxDelay);

    void SendEmptyCharacter() {
        if (IS_DOUBLE_CODE(vCodeTable)) //VNI or Unicode Compound
            InsertKeyLength(1);

        _newChar = 0x202F; //empty char
        if ([_niceSpaceAppSet containsObject:FRONT_APP]) {
            _newChar = 0x200C; //Unicode character with empty space
        }

        _newEventDown = CGEventCreateKeyboardEvent(myEventSource, 0, true);
        _newEventUp = CGEventCreateKeyboardEvent(myEventSource, 0, false);
        ApplyKeyboardTypeAndFlags(_newEventDown, _newEventUp);
        CGEventKeyboardSetUnicodeString(_newEventDown, 1, &_newChar);
        CGEventKeyboardSetUnicodeString(_newEventUp, 1, &_newChar);
        PostSyntheticEvent(_proxy, _newEventDown);
        PostSyntheticEvent(_proxy, _newEventUp);
        if (_phtvPostToHIDTap) SpotlightTinyDelay();
        CFRelease(_newEventDown);
        CFRelease(_newEventUp);

        // BROWSER FIX REMOVED: Shift+Left strategy eliminates need for delays
        // No delay needed after empty character - the select-then-delete approach handles it
    }
    
    void SendVirtualKey(const Byte& vKey) {
        CGEventRef eventVkeyDown = CGEventCreateKeyboardEvent (myEventSource, vKey, true);
        CGEventRef eventVkeyUp = CGEventCreateKeyboardEvent (myEventSource, vKey, false);
        
        CGEventTapPostEvent(_proxy, eventVkeyDown);
        CGEventTapPostEvent(_proxy, eventVkeyUp);
        
        CFRelease(eventVkeyDown);
        CFRelease(eventVkeyUp);
    }

    void SendPhysicalBackspace() {
        if (_phtvPostToHIDTap) {
            CGEventRef bsDown = CGEventCreateKeyboardEvent(myEventSource, 51, true);
            CGEventRef bsUp = CGEventCreateKeyboardEvent(myEventSource, 51, false);
            if (_phtvKeyboardType != 0) {
                CGEventSetIntegerValueField(bsDown, kCGKeyboardEventKeyboardType, _phtvKeyboardType);
                CGEventSetIntegerValueField(bsUp, kCGKeyboardEventKeyboardType, _phtvKeyboardType);
            }
            CGEventFlags bsFlags = CGEventGetFlags(bsDown);
            bsFlags |= kCGEventFlagMaskNonCoalesced;
            bsFlags &= ~kCGEventFlagMaskSecondaryFn;
            CGEventSetFlags(bsDown, bsFlags);
            CGEventSetFlags(bsUp, bsFlags);
            PostSyntheticEvent(_proxy, bsDown);
            PostSyntheticEvent(_proxy, bsUp);
            SpotlightTinyDelay();
            CFRelease(bsDown);
            CFRelease(bsUp);
        } else {
            CGEventTapPostEvent(_proxy, eventBackSpaceDown);
            CGEventTapPostEvent(_proxy, eventBackSpaceUp);
        }
    }

    void SendBackspace() {
        SendPhysicalBackspace();

        if (IS_DOUBLE_CODE(vCodeTable)) { //VNI or Unicode Compound
            if (!_syncKey.empty()) {
                if (_syncKey.back() > 1) {
                    NSString *effectiveTarget = _phtvEffectiveTargetBundleId ?: getFocusedAppBundleId();
                    if (!(vCodeTable == 3 && containUnicodeCompoundApp(effectiveTarget))) {
                        SendPhysicalBackspace();
                    }
                }
                _syncKey.pop_back();
            }
        }
    }

    // Delay type enum for different app categories
    typedef enum {
        DelayTypeNone = 0,
        DelayTypeTerminal = 1,
        // Browser delays removed - Shift+Left strategy eliminates need for delays:
        // DelayTypeBrowser = 2,          // REMOVED - no longer needed
        // DelayTypeSafariBrowser = 3,    // REMOVED - no longer needed
        // DelayTypeAutoEnglish = 4       // REMOVED - no longer needed
    } DelayType;

    // Update response time tracking for adaptive delays
    // Call this after each keystroke to measure system responsiveness
    void UpdateResponseTimeTracking() {
        uint64_t now = mach_absolute_time();

        os_unfair_lock_lock(&_adaptiveDelayLock);

        if (_lastKeystrokeTimestamp > 0) {
            uint64_t responseTime = mach_time_to_ms(now - _lastKeystrokeTimestamp) * 1000; // Convert to microseconds

            // Exponential moving average: 80% old + 20% new
            if (_responseTimeSamples == 0) {
                _averageResponseTimeUs = responseTime;
            } else {
                _averageResponseTimeUs = (_averageResponseTimeUs * 4 + responseTime) / 5;
            }

            _responseTimeSamples++;

            // Cap at 100 samples to prevent overflow
            if (_responseTimeSamples > 100) {
                _responseTimeSamples = 50; // Reset but keep some history
            }
        }

        _lastKeystrokeTimestamp = now;

        os_unfair_lock_unlock(&_adaptiveDelayLock);
    }

    // Calculate adaptive delay based on system load
    // Returns value between base and max based on measured response time
    uint64_t getAdaptiveDelay(uint64_t baseDelay, uint64_t maxDelay) {
        os_unfair_lock_lock(&_adaptiveDelayLock);

        uint64_t avgResponse = _averageResponseTimeUs;
        NSUInteger samples = _responseTimeSamples;

        os_unfair_lock_unlock(&_adaptiveDelayLock);

        // Need at least 3 samples for adaptive behavior
        if (samples < 3) {
            return baseDelay;
        }

        // Adaptive scaling: if response time > 2x base delay, scale up
        // Example: If avgResponse=8ms and base=4ms, scale factor = 2.0
        double scaleFactor = 1.0;
        if (avgResponse > baseDelay * 2) {
            scaleFactor = (double)avgResponse / (double)baseDelay;
            scaleFactor = fmin(scaleFactor, 2.0); // Cap at 2x
        }

        uint64_t adaptiveDelay = (uint64_t)(baseDelay * scaleFactor);

        // Clamp between base and max
        if (adaptiveDelay < baseDelay) {
            return baseDelay;
        }
        if (adaptiveDelay > maxDelay) {
            return maxDelay;
        }

        return adaptiveDelay;
    }

    void SendShiftAndLeftArrow() {
        CGEventRef eventVkeyDown = CGEventCreateKeyboardEvent (myEventSource, KEY_LEFT, true);
        CGEventRef eventVkeyUp = CGEventCreateKeyboardEvent (myEventSource, KEY_LEFT, false);
        _privateFlag = CGEventGetFlags(eventVkeyDown);
        _privateFlag |= kCGEventFlagMaskShift;
        CGEventSetFlags(eventVkeyDown, _privateFlag);
        CGEventSetFlags(eventVkeyUp, _privateFlag);
        
        CGEventTapPostEvent(_proxy, eventVkeyDown);
        CGEventTapPostEvent(_proxy, eventVkeyUp);
        
        if (IS_DOUBLE_CODE(vCodeTable)) { //VNI or Unicode Compound
            if (_syncKey.back() > 1) {
                // PERFORMANCE: Use cached bundle ID instead of querying AX API on every backspace
                NSString *effectiveTarget = _phtvEffectiveTargetBundleId ?: getFocusedAppBundleId();
                if (!(vCodeTable == 3 && containUnicodeCompoundApp(effectiveTarget))) {
                    CGEventTapPostEvent(_proxy, eventVkeyDown);
                    CGEventTapPostEvent(_proxy, eventVkeyUp);
                }
            }
            _syncKey.pop_back();
        }
        CFRelease(eventVkeyDown);
        CFRelease(eventVkeyUp);
    }

    // Consolidated helper function to send multiple backspaces with app-specific delays
    // IMPROVED: Now supports adaptive delays and Safari-specific handling
    void SendBackspaceSequenceWithDelay(int count, DelayType delayType) {
        if (count <= 0) return;

        uint64_t keystrokeDelay = 0;
        uint64_t settleDelay = 0;
        BOOL useShiftLeftStrategy = NO;

        switch (delayType) {
            case DelayTypeTerminal:
                keystrokeDelay = TERMINAL_KEYSTROKE_DELAY_US;
                settleDelay = TERMINAL_SETTLE_DELAY_US;
                break;
            // Browser delay cases removed - no longer needed with Shift+Left strategy
            // DelayTypeBrowser, DelayTypeSafariBrowser, DelayTypeAutoEnglish are now unused
            default:
                break;
        }

        if (useShiftLeftStrategy) {
            // OPENKEY REFERENCED FIX: Use Shift+Left to select text then Delete
            // This is more robust against browser address bar autocomplete
            // where a single Backspace might just dismiss the autocomplete suggestion
            // but fail to delete the actual character.
            for (int i = 0; i < count; i++) {
                SendShiftAndLeftArrow(); // Selects char (and handles syncKey)
                if (keystrokeDelay > 0) {
                    usleep((useconds_t)keystrokeDelay);
                }
            }
            // Send one physical backspace to delete the selection
            SendPhysicalBackspace();
        } else {
            // Standard backspace method for non-browser apps
            for (int i = 0; i < count; i++) {
                SendBackspace();
                if (keystrokeDelay > 0) {
                    usleep((useconds_t)keystrokeDelay);
                }
            }
        }

        // Extra settle time after all backspaces
        if (settleDelay > 0) {
            usleep((useconds_t)settleDelay);
        }
    }

    // Backwards compatible wrapper
    void SendBackspaceSequence(int count, BOOL isTerminalApp) {
        // Terminal apps no longer need special delay handling
        SendBackspaceSequenceWithDelay(count, DelayTypeNone);
    }

    /**
     * Check if app is a terminal/IDE that needs special handling
     * These apps are extremely timing-sensitive and need higher delays
     * Uses backspace method with step-by-step character sending
     */
    BOOL isTerminalApp(NSString *bundleId) {
        if (!bundleId) return NO;

        // JetBrains IDEs (IntelliJ, PyCharm, WebStorm, GoLand, CLion, Fleet, etc.)
        if ([bundleId hasPrefix:@"com.jetbrains"]) {
            return YES;
        }

        static NSSet<NSString*> *terminalApps = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            terminalApps = [NSSet setWithArray:@[
                // Terminals
                @"com.apple.Terminal",              // macOS Terminal (used by Claude Code)
                @"com.googlecode.iterm2",           // iTerm2
                @"io.alacritty",                    // Alacritty
                @"com.github.wez.wezterm",          // WezTerm
                @"com.mitchellh.ghostty",           // Ghostty
                @"dev.warp.Warp-Stable",            // Warp
                @"net.kovidgoyal.kitty",            // Kitty
                @"co.zeit.hyper",                   // Hyper
                @"org.tabby",                       // Tabby
                @"com.raphaelamorim.rio",           // Rio
                @"com.termius-dmg.mac",             // Termius
                // IDEs/Editors
                @"com.microsoft.VSCode",            // VS Code
                @"com.microsoft.VSCodeInsiders",    // VS Code Insiders
                @"com.google.antigravity",          // Android Studio
                @"dev.zed.Zed",                     // Zed
                @"com.sublimetext.4",               // Sublime Text 4
                @"com.sublimetext.3",               // Sublime Text 3
                @"com.panic.Nova"                   // Nova
            ]];
        });
        return [terminalApps containsObject:bundleId];
    }

    void SendCutKey() {
        CGEventRef eventVkeyDown = CGEventCreateKeyboardEvent (myEventSource, KEY_X, true);
        CGEventRef eventVkeyUp = CGEventCreateKeyboardEvent (myEventSource, KEY_X, false);
        _privateFlag = CGEventGetFlags(eventVkeyDown);
        _privateFlag |= NX_COMMANDMASK;
        CGEventSetFlags(eventVkeyDown, _privateFlag);
        CGEventSetFlags(eventVkeyUp, _privateFlag);
        
        CGEventTapPostEvent(_proxy, eventVkeyDown);
        CGEventTapPostEvent(_proxy, eventVkeyUp);
        
        CFRelease(eventVkeyDown);
        CFRelease(eventVkeyUp);
    }
    
    void SendNewCharString(const bool& dataFromMacro=false, const Uint16& offset=0) {
        _j = 0;
        _newCharSize = dataFromMacro ? pData->macroData.size() : pData->newCharCount;
        _willContinuteSending = false;
        _willSendControlKey = false;
        
        // Prefer the effective target bundle id cached by the callback.
        // Fallback to focused app only if cache isn't available.
        NSString *effectiveTarget = _phtvEffectiveTargetBundleId ?: getFocusedAppBundleId();
        // Treat as Spotlight target if the callback decided to use HID/Spotlight-safe path.
        // This covers cases where Spotlight is active but bundle-id matching is imperfect.
        BOOL isSpotlightTarget = _phtvPostToHIDTap || isSpotlightLikeApp(effectiveTarget);
        // WhatsApp and similar apps need precomposed Unicode but with batched sending (not AX API)
        BOOL isPrecomposedBatched = needsPrecomposedBatched(effectiveTarget);
        // Force precomposed for: Unicode Compound (code 3) on Spotlight, OR any Unicode on WhatsApp-like apps
        BOOL forcePrecomposed = ((vCodeTable == 3) && isSpotlightTarget) ||
                                 ((vCodeTable == 0 || vCodeTable == 3) && isPrecomposedBatched);
        
        if (_newCharSize > 0) {
            for (_k = dataFromMacro ? offset : pData->newCharCount - 1 - offset;
                 dataFromMacro ? _k < pData->macroData.size() : _k >= 0;
                 dataFromMacro ? _k++ : _k--) {
                
                if (_j >= 16) {
                    _willContinuteSending = true;
                    break;
                }
                
                _tempChar = DYNA_DATA(dataFromMacro, _k);
                if (_tempChar & PURE_CHARACTER_MASK) {
                    _newCharString[_j++] = _tempChar;
                    if (IS_DOUBLE_CODE(vCodeTable)) {
                        InsertKeyLength(1);
                    }
                } else if (!(_tempChar & CHAR_CODE_MASK)) {
                    if (IS_DOUBLE_CODE(vCodeTable)) //VNI
                        InsertKeyLength(1);
                    _newCharString[_j++] = keyCodeToCharacter(_tempChar);
                } else {
                    if (vCodeTable == 0) {  //unicode 2 bytes code
                        _newCharString[_j++] = _tempChar;
                    } else if (vCodeTable == 1 || vCodeTable == 2 || vCodeTable == 4) { //others such as VNI Windows, TCVN3: 1 byte code
                        _newChar = _tempChar;
                        _newCharHi = HIBYTE(_newChar);
                        _newChar = LOBYTE(_newChar);
                        _newCharString[_j++] = _newChar;
                        
                        if (_newCharHi > 32) {
                            if (vCodeTable == 2) //VNI
                                InsertKeyLength(2);
                            _newCharString[_j++] = _newCharHi;
                            _newCharSize++;
                        } else {
                            if (vCodeTable == 2) //VNI
                                InsertKeyLength(1);
                        }
                    } else if (vCodeTable == 3) { //Unicode Compound
                        _newChar = _tempChar;
                        _newCharHi = (_newChar >> 13);
                        _newChar &= 0x1FFF;
                        
                        // Always build compound form first (will be converted to precomposed later if needed)
                        InsertKeyLength(_newCharHi > 0 ? 2 : 1);
                        _newCharString[_j++] = _newChar;
                        if (_newCharHi > 0) {
                            _newCharSize++;
                            _newCharString[_j++] = _unicodeCompoundMark[_newCharHi - 1];
                        }
                        
                    }
                }
            }//end for
        }
        
        if (!_willContinuteSending && (pData->code == vRestore || pData->code == vRestoreAndStartNewSession)) { //if is restore
            if (keyCodeToCharacter(_keycode) != 0) {
                _newCharSize++;
                _newCharString[_j++] = keyCodeToCharacter(_keycode | ((_flag & kCGEventFlagMaskAlphaShift) || (_flag & kCGEventFlagMaskShift) ? CAPS_MASK : 0));
            } else {
                _willSendControlKey = true;
            }
        }
        if (!_willContinuteSending && pData->code == vRestoreAndStartNewSession) {
            startNewSession();
        }
        
        // If we need to force precomposed Unicode (for apps like Spotlight), 
        // convert the entire string from compound to precomposed form
        Uint16 _finalCharString[MAX_UNICODE_STRING];
        int _finalCharSize = _willContinuteSending ? 16 : _newCharSize - offset;
        
        if (forcePrecomposed && _finalCharSize > 0) {
            // Create NSString from Unicode characters and get precomposed version
            NSString *tempStr = [NSString stringWithCharacters:(const unichar *)_newCharString length:_finalCharSize];
            NSString *precomposed = [tempStr precomposedStringWithCanonicalMapping];
            _finalCharSize = (int)[precomposed length];
            [precomposed getCharacters:(unichar *)_finalCharString range:NSMakeRange(0, _finalCharSize)];
        } else {
            // Use original string
            memcpy(_finalCharString, _newCharString, _finalCharSize * sizeof(Uint16));
        }

        if (isSpotlightTarget) {
            // Try AX API first - it's atomic and most reliable when it works
            NSString *insertStr = [NSString stringWithCharacters:(const unichar *)_finalCharString length:_finalCharSize];
            int backspaceCount = _phtvPendingBackspaceCount;
            _phtvPendingBackspaceCount = 0;

            BOOL axSucceeded = ReplaceFocusedTextViaAX(backspaceCount, insertStr);
            if (axSucceeded) {
                // Small delay after AX replacement to let Spotlight update its internal state
                // This prevents race conditions when typing quickly
                usleep(5000); // 5ms
                return;
            }

            // AX failed - fallback to synthetic events
            SendBackspaceSequence(backspaceCount, NO);

            _newEventDown = CGEventCreateKeyboardEvent(myEventSource, 0, true);
            _newEventUp = CGEventCreateKeyboardEvent(myEventSource, 0, false);
            if (_phtvKeyboardType != 0) {
                CGEventSetIntegerValueField(_newEventDown, kCGKeyboardEventKeyboardType, _phtvKeyboardType);
                CGEventSetIntegerValueField(_newEventUp, kCGKeyboardEventKeyboardType, _phtvKeyboardType);
            }
            CGEventFlags uFlags = CGEventGetFlags(_newEventDown) | kCGEventFlagMaskNonCoalesced;
            // Clear Fn/Globe flag to prevent triggering system hotkeys
            uFlags &= ~kCGEventFlagMaskSecondaryFn;
            CGEventSetFlags(_newEventDown, uFlags);
            CGEventSetFlags(_newEventUp, uFlags);
            CGEventKeyboardSetUnicodeString(_newEventDown, _finalCharSize, _finalCharString);
            CGEventKeyboardSetUnicodeString(_newEventUp, _finalCharSize, _finalCharString);
            PostSyntheticEvent(_proxy, _newEventDown);
            PostSyntheticEvent(_proxy, _newEventUp);
            CFRelease(_newEventDown);
            CFRelease(_newEventUp);
            return;
        } else {
            _newEventDown = CGEventCreateKeyboardEvent(myEventSource, 0, true);
            _newEventUp = CGEventCreateKeyboardEvent(myEventSource, 0, false);
            if (_phtvKeyboardType != 0) {
                CGEventSetIntegerValueField(_newEventDown, kCGKeyboardEventKeyboardType, _phtvKeyboardType);
                CGEventSetIntegerValueField(_newEventUp, kCGKeyboardEventKeyboardType, _phtvKeyboardType);
            }
            CGEventKeyboardSetUnicodeString(_newEventDown, _finalCharSize, _finalCharString);
            CGEventKeyboardSetUnicodeString(_newEventUp, _finalCharSize, _finalCharString);
            PostSyntheticEvent(_proxy, _newEventDown);
            PostSyntheticEvent(_proxy, _newEventUp);
            CFRelease(_newEventDown);
            CFRelease(_newEventUp);
        }

        if (_willContinuteSending) {
            SendNewCharString(dataFromMacro, dataFromMacro ? _k : 16);
        }
        
        //the case when hCode is vRestore or vRestoreAndStartNewSession, the word is invalid and last key is control key such as TAB, LEFT ARROW, RIGHT ARROW,...
        if (_willSendControlKey) {
            SendKeyCode(_keycode);
        }
    }
            
    bool checkHotKey(int hotKeyData, bool checkKeyCode=true) {
        if ((hotKeyData & (~0x8000)) == EMPTY_HOTKEY)
            return false;
        if (HAS_CONTROL(hotKeyData) ^ GET_BOOL(_lastFlag & kCGEventFlagMaskControl))
            return false;
        if (HAS_OPTION(hotKeyData) ^ GET_BOOL(_lastFlag & kCGEventFlagMaskAlternate))
            return false;
        if (HAS_COMMAND(hotKeyData) ^ GET_BOOL(_lastFlag & kCGEventFlagMaskCommand))
            return false;
        if (HAS_SHIFT(hotKeyData) ^ GET_BOOL(_lastFlag & kCGEventFlagMaskShift))
            return false;
        if (HAS_FN(hotKeyData) ^ GET_BOOL(_lastFlag & kCGEventFlagMaskSecondaryFn))
            return false;
        if (checkKeyCode) {
            if (GET_SWITCH_KEY(hotKeyData) != _keycode)
                return false;
        }
        return true;
    }

    // Check if ALL modifier keys required by a hotkey are currently held
    // This is used to detect if user is in the process of pressing a modifier combo
    // Returns true if current flags CONTAIN all required modifiers (may have extra modifiers)
    bool hotkeyModifiersAreHeld(int hotKeyData, CGEventFlags currentFlags) {
        if ((hotKeyData & (~0x8000)) == EMPTY_HOTKEY)
            return false;

        // Check if all required modifiers are present in current flags
        if (HAS_CONTROL(hotKeyData) && !(currentFlags & kCGEventFlagMaskControl))
            return false;
        if (HAS_OPTION(hotKeyData) && !(currentFlags & kCGEventFlagMaskAlternate))
            return false;
        if (HAS_COMMAND(hotKeyData) && !(currentFlags & kCGEventFlagMaskCommand))
            return false;
        if (HAS_SHIFT(hotKeyData) && !(currentFlags & kCGEventFlagMaskShift))
            return false;
        if (HAS_FN(hotKeyData) && !(currentFlags & kCGEventFlagMaskSecondaryFn))
            return false;

        return true;
    }

    // Check if this is a modifier-only hotkey (no specific key required, keycode = 0xFE)
    bool isModifierOnlyHotkey(int hotKeyData) {
        return GET_SWITCH_KEY(hotKeyData) == 0xFE;
    }

    void switchLanguage() {
        // Beep is now handled by SwiftUI when LanguageChangedFromBackend notification is posted
        // (removed NSBeep() to avoid duplicate sounds)

        // onImputMethodChanged handles: toggle, save, RequestNewSession, fillData, notify
        // No need to modify vLanguage here or call startNewSession separately
        [appDelegate onImputMethodChanged:YES];
    }
    
    void handleMacro() {
        // PERFORMANCE: Use cached bundle ID instead of querying AX API
        NSString *effectiveTarget = _phtvEffectiveTargetBundleId ?: getFocusedAppBundleId();
        // Use _phtvPostToHIDTap which includes spotlightActive (search field detected via AX)
        BOOL isSpotlightLike = _phtvPostToHIDTap || isSpotlightLikeApp(effectiveTarget);

        #ifdef DEBUG
        NSLog(@"[Macro] handleMacro: target='%@', isSpotlight=%d (postToHID=%d), backspaceCount=%d, macroSize=%zu",
              effectiveTarget, isSpotlightLike, _phtvPostToHIDTap, (int)pData->backspaceCount, pData->macroData.size());
        #endif

        // CRITICAL FIX: Spotlight requires AX API for macro replacement
        // Synthetic backspace events don't work reliably in Spotlight
        if (isSpotlightLike) {
            // Convert macro data to NSString
            // Macro data can contain: PURE_CHARACTER_MASK, CHAR_CODE_MASK (Vietnamese), or normal keycodes
            NSMutableString *macroString = [NSMutableString string];
            for (int i = 0; i < pData->macroData.size(); i++) {
                Uint32 data = pData->macroData[i];
                Uint16 ch;

                if (data & PURE_CHARACTER_MASK) {
                    // Pure Unicode character (special chars) - use directly, remove CAPS_MASK
                    ch = data & ~CAPS_MASK;
                    #ifdef DEBUG
                    NSLog(@"[Macro] [%d] PURE_CHAR: 0x%X → '%C'", i, data, (unichar)ch);
                    #endif
                } else if (!(data & CHAR_CODE_MASK)) {
                    // Normal keycode (a-z, 0-9, etc.) - convert using keyCodeToCharacter()
                    ch = keyCodeToCharacter(data);
                    if (ch == 0) {
                        // Keycode cannot be converted (e.g., function keys)
                        #ifdef DEBUG
                        NSLog(@"[Macro] [%d] KEYCODE: 0x%X → SKIP (no conversion)", i, data);
                        #endif
                        continue; // Skip this keycode
                    }
                    #ifdef DEBUG
                    NSLog(@"[Macro] [%d] KEYCODE: 0x%X → '%C'", i, data, (unichar)ch);
                    #endif
                } else {
                    // CHAR_CODE_MASK (Vietnamese diacritics)
                    if (vCodeTable == 0) {
                        // Unicode mode - use directly (ạ, ù, ế, etc.)
                        ch = data & 0xFFFF;
                        #ifdef DEBUG
                        NSLog(@"[Macro] [%d] CHAR_CODE (Unicode): 0x%X → '%C'", i, data, (unichar)ch);
                        #endif
                    } else {
                        // VNI/TCVN mode - extract low byte
                        ch = LOBYTE(data);
                        #ifdef DEBUG
                        NSLog(@"[Macro] [%d] CHAR_CODE (VNI/TCVN): 0x%X → '%C'", i, data, (unichar)ch);
                        #endif
                        // High byte handling would go here for VNI if needed
                    }
                }
                [macroString appendFormat:@"%C", (unichar)ch];
            }

            // Try AX API first - atomic and most reliable for Spotlight
            BOOL axSucceeded = ReplaceFocusedTextViaAX(pData->backspaceCount, macroString);
            if (axSucceeded) {
                #ifdef DEBUG
                NSLog(@"[Macro] Spotlight: AX API succeeded, macro='%@'", macroString);
                #endif
                usleep(5000); // 5ms delay for Spotlight
                return;
            }

            #ifdef DEBUG
            NSLog(@"[Macro] Spotlight: AX API failed, falling back to synthetic events");
            #endif
            // AX failed - fallback to synthetic events below
        }

        //fix autocomplete
        if (vFixRecommendBrowser) {
            SendEmptyCharacter();
            pData->backspaceCount++;
        }

        //send backspace
        if (pData->backspaceCount > 0) {
            SendBackspaceSequence(pData->backspaceCount, NO);
        }

        //send real data - use step by step for timing sensitive apps like Spotlight
        BOOL useStepByStep = vSendKeyStepByStep || needsStepByStep(effectiveTarget);
        if (!useStepByStep) {
            SendNewCharString(true);
        } else {
            for (int i = 0; i < pData->macroData.size(); i++) {
                if (pData->macroData[i] & PURE_CHARACTER_MASK) {
                    SendPureCharacter(pData->macroData[i]);
                } else {
                    SendKeyCode(pData->macroData[i]);
                }
            }
        }

        // Send trigger key for non-Spotlight apps
        if (!isSpotlightLike) {
            SendKeyCode(_keycode | (_flag & kCGEventFlagMaskShift ? CAPS_MASK : 0));
        }
    }

    // Convert character string to QWERTY keycode
    // This function maps a character to its equivalent QWERTY keycode for layout compatibility
    int ConvertKeyStringToKeyCode(NSString *keyString, CGKeyCode fallback) {
        if (!keyString || keyString.length == 0) {
            return fallback;
        }

        // First try exact match (for special characters like ß, ü, etc.)
        NSNumber *keycode = [keyStringToKeyCodeMap objectForKey:keyString];
        if (keycode) {
            return [keycode intValue];
        }

        // Then try lowercase version for letters
        NSString *lowercasedKeyString = [keyString lowercaseString];
        if (lowercasedKeyString && ![lowercasedKeyString isEqualToString:keyString]) {
            keycode = [keyStringToKeyCodeMap objectForKey:lowercasedKeyString];
            if (keycode) {
                return [keycode intValue];
            }
        }

        return fallback;
    }

    // Layout compatibility cache to avoid expensive NSEvent creation on every keystroke
    static CGKeyCode _layoutCache[256];
    static BOOL _layoutCacheValid = NO;

    // Invalidate layout cache (call when keyboard layout changes)
    extern "C" void InvalidateLayoutCache() {
        _layoutCacheValid = NO;
    }

    // Convert keyboard event to QWERTY-equivalent keycode for layout compatibility
    // This function handles international keyboard layouts by mapping characters to QWERTY keycodes
    CGKeyCode ConvertEventToKeyboadLayoutCompatKeyCode(CGEventRef keyEvent, CGKeyCode fallbackKeyCode) {
        // Fast path: check cache first
        CGKeyCode rawKeyCode = (CGKeyCode)CGEventGetIntegerValueField(keyEvent, kCGKeyboardEventKeycode);
        if (_layoutCacheValid && rawKeyCode < 256 && _layoutCache[rawKeyCode] != 0xFFFF) {
            return _layoutCache[rawKeyCode];
        }

        // Initialize cache if needed
        if (!_layoutCacheValid) {
            for (int i = 0; i < 256; i++) _layoutCache[i] = 0xFFFF;
            _layoutCacheValid = YES;
        }

        NSEvent *kbLayoutCompatEvent = [NSEvent eventWithCGEvent:keyEvent];
        if (!kbLayoutCompatEvent) {
            return fallbackKeyCode;
        }

        CGKeyCode result = fallbackKeyCode;

        // Strategy 1: Try charactersIgnoringModifiers first (best for most layouts)
        // This gives us the base character without Shift/Option modifications
        NSString *kbLayoutCompatKeyString = kbLayoutCompatEvent.charactersIgnoringModifiers;
        CGKeyCode converted = ConvertKeyStringToKeyCode(kbLayoutCompatKeyString, 0xFFFF);
        if (converted != 0xFFFF) {
            result = converted;
        } else {
            // Strategy 2: If that fails, try the actual characters property
            // This is useful for layouts like AZERTY where Shift+key produces a different character
            // that might be in our mapping (e.g., Shift+& = 1 on AZERTY)
            NSString *actualCharacters = kbLayoutCompatEvent.characters;
            if (actualCharacters && ![actualCharacters isEqualToString:kbLayoutCompatKeyString]) {
                converted = ConvertKeyStringToKeyCode(actualCharacters, 0xFFFF);
                if (converted != 0xFFFF) {
                    result = converted;
                }
            }
        }

        // Strategy 3: For AZERTY number row handling
        // On AZERTY, the number row produces special characters by default
        // and numbers with Shift. We need to handle the Shift+character -> number case
        if (result == fallbackKeyCode) {
            static NSDictionary *azertyShiftedToNumber = nil;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                azertyShiftedToNumber = @{
                    @"&": @18,  // & (Shift=1) -> KEY_1
                    @"é": @19,  // é (Shift=2) -> KEY_2 (note: on some AZERTY, 2 is direct)
                    @"\"": @20, // " (Shift=3) -> KEY_3
                    @"'": @21,  // ' (Shift=4) -> KEY_4
                    @"(": @23,  // ( (Shift=5) -> KEY_5
                    @"-": @22,  // - (but this is complex, may not be 6)
                    @"è": @26,  // è (Shift=7) -> KEY_7
                    @"_": @28,  // _ (Shift=8) -> KEY_8
                    @"ç": @25,  // ç (Shift=9) -> KEY_9
                    @"à": @29,  // à (Shift=0) -> KEY_0
                };
            });

            // Check if the base character is an AZERTY special char that maps to number row
            if (kbLayoutCompatKeyString.length == 1) {
                NSNumber *azertyKeycode = [azertyShiftedToNumber objectForKey:kbLayoutCompatKeyString];
                if (azertyKeycode) {
                    result = [azertyKeycode intValue];
                }
            }
        }

        // Cache result
        if (rawKeyCode < 256) {
            _layoutCache[rawKeyCode] = result;
        }

        return result;
    }

    // Handle hotkey press (switch language or convert tool)
    // Returns NULL if hotkey was triggered (consuming the event), otherwise returns the original event
    static inline CGEventRef HandleHotkeyPress(CGEventType type, CGKeyCode keycode) {
        if (type != kCGEventKeyDown) return NULL;

        // Check switch language hotkey
        if (GET_SWITCH_KEY(vSwitchKeyStatus) == keycode &&
            checkHotKey(vSwitchKeyStatus, GET_SWITCH_KEY(vSwitchKeyStatus) != 0xFE)) {
            switchLanguage();
            _lastFlag = 0;
            _hasJustUsedHotKey = true;
            return (CGEventRef)-1;  // Special marker to indicate "consume event"
        }

        // Check convert tool hotkey
        if (GET_SWITCH_KEY(convertToolHotKey) == keycode &&
            checkHotKey(convertToolHotKey, GET_SWITCH_KEY(convertToolHotKey) != 0xFE)) {
            [appDelegate onQuickConvert];
            _lastFlag = 0;
            _hasJustUsedHotKey = true;
            return (CGEventRef)-1;  // Special marker to indicate "consume event"
        }

        // Only mark as used hotkey if we had modifiers pressed
        _hasJustUsedHotKey = _lastFlag != 0;
        return NULL;
    }

    // Check if a given key matches the pause key configuration
    static inline BOOL IsPauseKeyPressed(CGEventFlags flags) {
        if (!vPauseKeyEnabled || vPauseKey <= 0) return NO;

        if (vPauseKey == KEY_LEFT_OPTION || vPauseKey == KEY_RIGHT_OPTION) {
            return (flags & kCGEventFlagMaskAlternate) != 0;
        } else if (vPauseKey == KEY_LEFT_CONTROL || vPauseKey == KEY_RIGHT_CONTROL) {
            return (flags & kCGEventFlagMaskControl) != 0;
        } else if (vPauseKey == KEY_LEFT_SHIFT || vPauseKey == KEY_RIGHT_SHIFT) {
            return (flags & kCGEventFlagMaskShift) != 0;
        } else if (vPauseKey == KEY_LEFT_COMMAND || vPauseKey == KEY_RIGHT_COMMAND) {
            return (flags & kCGEventFlagMaskCommand) != 0;
        } else if (vPauseKey == 63) {  // Fn key
            return (flags & kCGEventFlagMaskSecondaryFn) != 0;
        }
        return NO;
    }

    // Strip pause modifier from event flags to prevent special characters
    static inline CGEventFlags StripPauseModifier(CGEventFlags flags) {
        if (vPauseKey == KEY_LEFT_OPTION || vPauseKey == KEY_RIGHT_OPTION) {
            return flags & ~kCGEventFlagMaskAlternate;
        } else if (vPauseKey == KEY_LEFT_CONTROL || vPauseKey == KEY_RIGHT_CONTROL) {
            return flags & ~kCGEventFlagMaskControl;
        } else if (vPauseKey == KEY_LEFT_COMMAND || vPauseKey == KEY_RIGHT_COMMAND) {
            return flags & ~kCGEventFlagMaskCommand;
        } else if (vPauseKey == 63) {  // Fn key
            return flags & ~kCGEventFlagMaskSecondaryFn;
        }
        return flags;
    }

    // Handle pause key press - temporarily disable Vietnamese input
    static inline void HandlePauseKeyPress(CGEventFlags flags) {
        if (_pauseKeyPressed) return;  // Already pressed

        if (IsPauseKeyPressed(flags)) {
            // Save current language state and temporarily switch to English
            _savedLanguageBeforePause = vLanguage;
            if (vLanguage == 1) {
                // Only switch if currently in Vietnamese mode
                vLanguage = 0;  // Switch to English
            }
            _pauseKeyPressed = true;
        }
    }

    // Handle pause key release - restore Vietnamese input
    static inline void HandlePauseKeyRelease(CGEventFlags oldFlags, CGEventFlags newFlags) {
        if (!_pauseKeyPressed) return;  // Not pressed

        // Check if pause key was released
        if (!IsPauseKeyPressed(newFlags) && IsPauseKeyPressed(oldFlags)) {
            // Restore saved language state
            vLanguage = _savedLanguageBeforePause;
            _pauseKeyPressed = false;
        }
    }

    // Handle Spotlight cache invalidation on Cmd+Space and modifier changes
    // This ensures fast Spotlight detection
    static inline void HandleSpotlightCacheInvalidation(CGEventType type, CGKeyCode keycode, CGEventFlags flag) {
        // Detect Cmd+Space hotkey and invalidate cache immediately
        if (type == kCGEventKeyDown && keycode == 49 && (flag & kCGEventFlagMaskCommand)) {
            InvalidateSpotlightCache();
            return;
        }

        // Track modifier flag changes to invalidate cache on significant changes
        static CGEventFlags _lastEventFlags = 0;
        CGEventFlags flagChangeMask = kCGEventFlagMaskCommand | kCGEventFlagMaskAlternate | kCGEventFlagMaskControl;
        if ((type == kCGEventFlagsChanged) && ((flag ^ _lastEventFlags) & flagChangeMask)) {
            InvalidateSpotlightCache();
        }
        _lastEventFlags = flag;
    }

    // Event tap health monitoring - checks tap status and recovers if needed
    // Returns YES if tap is healthy, NO if recovery was attempted
    static inline BOOL CheckAndRecoverEventTap(void) {
        // BROWSER FIX: More aggressive health check for faster recovery
        // Reduced intervals to catch tap disable within 5-10 keystrokes instead of 15-50
        // Smart skip: after 1000 healthy checks, reduce frequency to save CPU
        static NSUInteger eventCounter = 0;
        static NSUInteger recoveryCounter = 0;
        static NSUInteger healthyCounter = 0;

        // IMPROVED: Much more aggressive checking for browser responsiveness
        // 10 events when healthy and established (was 50)
        // 5 events when recovering or initial state (was 15)
        // This reduces detection latency from 50 keystrokes to 5-10
        NSUInteger checkInterval = (healthyCounter > 1000) ? 10 : 5;

        if (__builtin_expect(++eventCounter % checkInterval == 0, 0)) {
            if (__builtin_expect(![PHTVManager isEventTapEnabled], 0)) {
                healthyCounter = 0; // Reset healthy counter on failure
                // Throttle log: only log every 10th recovery to reduce overhead
                if (++recoveryCounter % 10 == 1) {
                    os_log_error(phtv_log, "[EventTap] Detected disabled tap — recovering (occurrence #%lu)", (unsigned long)recoveryCounter);
                }
                [PHTVManager ensureEventTapAlive];
                return NO;
            } else {
                // Tap is healthy, increment counter
                if (__builtin_expect(healthyCounter < 2000, 1)) healthyCounter++;
            }
        }
        return YES;
    }

    /**
     * MAIN HOOK entry, very important function.
     * MAIN Callback.
     */
    void TryToRestoreSessionFromAX() {
        return; // Disabled to prevent malware false positive
    }

    CGEventRef PHTVCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
        @autoreleasepool {
        // CRITICAL: If permission was lost, reject ALL events immediately
        // This prevents ANY processing after permission revocation
        if (__builtin_expect([PHTVManager hasPermissionLost], 0)) {
            return event;  // Pass through without processing
        }

        // Auto-recover when macOS temporarily disables the event tap
        if (__builtin_expect(type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput, 0)) {
            [PHTVManager handleEventTapDisabled:type];
            return event;
        }

        // REMOVED: Permission checking in callback - causes kernel deadlock
        // Permission is now checked ONLY via test event tap creation in timer (safe approach)

        // Perform periodic health check and recovery
        CheckAndRecoverEventTap();

        //dont handle my event
        if (CGEventGetIntegerValueField(event, kCGEventSourceStateID) == CGEventSourceGetSourceStateID(myEventSource)) {
            return event;
        }

        _flag = CGEventGetFlags(event);
        _keycode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);

        // TEXT REPLACEMENT DETECTION: Track external delete events (only if fix enabled)
        // When macOS Text Replacement is triggered (e.g., "ko" -> "không"),
        // macOS sends synthetic delete events that we didn't generate
        // We track these to avoid duplicate characters when SendEmptyCharacter() is called
        if (IsTextReplacementFixEnabled() && type == kCGEventKeyDown && _keycode == KEY_DELETE) {
            // This is an external delete event (not from PHTV since we already filtered myEventSource)
            TrackExternalDelete();
#ifdef DEBUG
            NSLog(@"[TextReplacement] External DELETE detected");
#endif
        }

        // Also track space after deletes to detect text replacement pattern (only if fix enabled)
        if (IsTextReplacementFixEnabled() && type == kCGEventKeyDown && _keycode == KEY_SPACE) {
#ifdef DEBUG
            dispatch_once(&timebase_init_token, ^{
                mach_timebase_info(&timebase_info);
            });
            uint64_t now = mach_absolute_time();
            uint64_t elapsed_ms = (_lastExternalDeleteTime != 0) ? mach_time_to_ms(now - _lastExternalDeleteTime) : 0;
            NSLog(@"[TextReplacement] SPACE key pressed: deleteCount=%d, elapsedMs=%llu, sourceID=%lld",
                  _externalDeleteCount, elapsed_ms,
                  CGEventGetIntegerValueField(event, kCGEventSourceStateID));
#endif
        }

        // Handle Spotlight detection optimization
        HandleSpotlightCacheInvalidation(type, _keycode, _flag);

        // If pause key is being held, strip pause modifier from events to prevent special characters
        // BUT only if no other modifiers are pressed (to preserve system shortcuts like Option+Cmd+V)
        if (_pauseKeyPressed && (type == kCGEventKeyDown || type == kCGEventKeyUp)) {
            // Check if other modifiers are pressed (excluding the pause key modifier)
            CGEventFlags otherModifiers = _flag & ~kCGEventFlagMaskNonCoalesced;
            
            // Remove the pause key's modifier from the check
            if (vPauseKey == KEY_LEFT_OPTION || vPauseKey == KEY_RIGHT_OPTION) {
                otherModifiers &= ~kCGEventFlagMaskAlternate;
            } else if (vPauseKey == KEY_LEFT_CONTROL || vPauseKey == KEY_RIGHT_CONTROL) {
                otherModifiers &= ~kCGEventFlagMaskControl;
            } else if (vPauseKey == KEY_LEFT_COMMAND || vPauseKey == KEY_RIGHT_COMMAND) {
                otherModifiers &= ~kCGEventFlagMaskCommand;
            } else if (vPauseKey == KEY_LEFT_SHIFT || vPauseKey == KEY_RIGHT_SHIFT) {
                otherModifiers &= ~kCGEventFlagMaskShift;
            } else if (vPauseKey == 63) {  // Fn key
                otherModifiers &= ~kCGEventFlagMaskSecondaryFn;
            }
            
            // Only strip if no other significant modifiers are pressed
            // This preserves system shortcuts like Option+Cmd+V (move file)
            BOOL hasOtherModifiers = (otherModifiers & (kCGEventFlagMaskCommand | kCGEventFlagMaskControl | 
                                                         kCGEventFlagMaskAlternate | kCGEventFlagMaskShift)) != 0;
            
            if (!hasOtherModifiers) {
                CGEventFlags newFlags = StripPauseModifier(_flag);
                CGEventSetFlags(event, newFlags);
                _flag = newFlags;  // Update local flag as well
            }
        }

        if (type == kCGEventKeyDown && vPerformLayoutCompat) {
            // If conversion fail, use current keycode
           _keycode = ConvertEventToKeyboadLayoutCompatKeyCode(event, _keycode);
        }
        
        //switch language shortcut; convert hotkey
        CGEventRef hotkeyResult = HandleHotkeyPress(type, _keycode);
        if (hotkeyResult == (CGEventRef)-1) {
            return NULL;  // Hotkey was triggered, consume event
        }

        if (type == kCGEventKeyDown) {
            // Track if any key is pressed while restore modifier is held
            // Only track if custom restore key is actually set (Option or Control)
            if (vRestoreOnEscape && vCustomEscapeKey > 0 && _restoreModifierPressed) {
                _keyPressedWithRestoreModifier = true;
            }

            // Track if any key is pressed while switch hotkey modifiers are held
            // This prevents modifier-only hotkeys (like Cmd+Shift) from triggering
            // when user presses a key combo like Cmd+Shift+S
            bool switchIsModifierOnly = isModifierOnlyHotkey(vSwitchKeyStatus);
            bool convertIsModifierOnly = isModifierOnlyHotkey(convertToolHotKey);
            if (switchIsModifierOnly || convertIsModifierOnly) {
                bool switchModifiersHeld = switchIsModifierOnly && hotkeyModifiersAreHeld(vSwitchKeyStatus, _flag);
                bool convertModifiersHeld = convertIsModifierOnly && hotkeyModifiersAreHeld(convertToolHotKey, _flag);
                if (switchModifiersHeld || convertModifiersHeld) {
                    _keyPressedWhileSwitchModifiersHeld = true;
                }
            }
        } else if (type == kCGEventFlagsChanged) {
            if (_lastFlag == 0 || _lastFlag < _flag) {
                // Pressing more modifiers
                _lastFlag = _flag;

                // Reset switch modifier tracking when modifiers change (user starting a new combo)
                _keyPressedWhileSwitchModifiersHeld = false;

                // Check if restore modifier key is being pressed
                if (vRestoreOnEscape && vCustomEscapeKey > 0) {
                    bool isOptionKey = (vCustomEscapeKey == KEY_LEFT_OPTION || vCustomEscapeKey == KEY_RIGHT_OPTION);
                    bool isControlKey = (vCustomEscapeKey == KEY_LEFT_CONTROL || vCustomEscapeKey == KEY_RIGHT_CONTROL);

                    if ((isOptionKey && (_flag & kCGEventFlagMaskAlternate)) ||
                        (isControlKey && (_flag & kCGEventFlagMaskControl))) {
                        _restoreModifierPressed = true;
                        _keyPressedWithRestoreModifier = false;
                    }
                }

                // Check if pause key is being pressed - temporarily disable Vietnamese
                HandlePauseKeyPress(_flag);
            } else if (_lastFlag > _flag)  {
                // Releasing modifiers - check for restore modifier key first
                if (vRestoreOnEscape && _restoreModifierPressed && !_keyPressedWithRestoreModifier) {
                    bool isOptionKey = (vCustomEscapeKey == KEY_LEFT_OPTION || vCustomEscapeKey == KEY_RIGHT_OPTION);
                    bool isControlKey = (vCustomEscapeKey == KEY_LEFT_CONTROL || vCustomEscapeKey == KEY_RIGHT_CONTROL);

                    bool optionReleased = isOptionKey && (_lastFlag & kCGEventFlagMaskAlternate) && !(_flag & kCGEventFlagMaskAlternate);
                    bool controlReleased = isControlKey && (_lastFlag & kCGEventFlagMaskControl) && !(_flag & kCGEventFlagMaskControl);

                    if (optionReleased || controlReleased) {
                        // Restore modifier released without any other key press - trigger restore
                        if (vRestoreToRawKeys()) {
                            // Successfully restored - pData now contains restore info
                            NSString *effectiveBundleId = _phtvEffectiveTargetBundleId ?: getFocusedAppBundleId();
                            BOOL isTerminal = isTerminalApp(effectiveBundleId);

                            // Send backspaces to delete Vietnamese characters
                            if (pData->backspaceCount > 0 && pData->backspaceCount < MAX_BUFF) {
                                SendBackspaceSequence(pData->backspaceCount, isTerminal);
                            }

                            // Send the raw ASCII characters
                            SendNewCharString();

                            // Final settle time for terminals after all text is sent
                            if (isTerminal) {
                                usleep(TERMINAL_FINAL_SETTLE_US);
                            }

                            _lastFlag = 0;
                            _restoreModifierPressed = false;
                            _keyPressedWithRestoreModifier = false;
                            return NULL;
                        }
                        _restoreModifierPressed = false;
                        _keyPressedWithRestoreModifier = false;
                    }
                }

                // Reset restore modifier state when releasing any modifier
                if (_restoreModifierPressed) {
                    bool isOptionKey = (vCustomEscapeKey == KEY_LEFT_OPTION || vCustomEscapeKey == KEY_RIGHT_OPTION);
                    bool isControlKey = (vCustomEscapeKey == KEY_LEFT_CONTROL || vCustomEscapeKey == KEY_RIGHT_CONTROL);

                    bool optionReleased = isOptionKey && (_lastFlag & kCGEventFlagMaskAlternate) && !(_flag & kCGEventFlagMaskAlternate);
                    bool controlReleased = isControlKey && (_lastFlag & kCGEventFlagMaskControl) && !(_flag & kCGEventFlagMaskControl);

                    if (optionReleased || controlReleased) {
                        _restoreModifierPressed = false;
                        _keyPressedWithRestoreModifier = false;
                    }
                }

                // Check if pause key is being released - restore Vietnamese mode
                HandlePauseKeyRelease(_lastFlag, _flag);

                // Check switch hotkey - only trigger if no other key was pressed
                // while the modifier combination was held (exact match requirement)
                // This prevents Cmd+Shift from triggering when user presses Cmd+Shift+S
                bool switchIsModifierOnly = isModifierOnlyHotkey(vSwitchKeyStatus);
                bool canTriggerSwitch = !switchIsModifierOnly || !_keyPressedWhileSwitchModifiersHeld;
                if (canTriggerSwitch && checkHotKey(vSwitchKeyStatus, GET_SWITCH_KEY(vSwitchKeyStatus) != 0xFE)) {
                    _lastFlag = 0;
                    _keyPressedWhileSwitchModifiersHeld = false;
                    switchLanguage();
                    _hasJustUsedHotKey = true;
                    return NULL;
                }

                // Check convert tool hotkey with same exact match logic
                bool convertIsModifierOnly = isModifierOnlyHotkey(convertToolHotKey);
                bool canTriggerConvert = !convertIsModifierOnly || !_keyPressedWhileSwitchModifiersHeld;
                if (canTriggerConvert && checkHotKey(convertToolHotKey, GET_SWITCH_KEY(convertToolHotKey) != 0xFE)) {
                    _lastFlag = 0;
                    _keyPressedWhileSwitchModifiersHeld = false;
                    [appDelegate onQuickConvert];
                    _hasJustUsedHotKey = true;
                    return NULL;
                }

                //check temporarily turn off spell checking
                if (vTempOffSpelling && !_hasJustUsedHotKey && _lastFlag & kCGEventFlagMaskControl) {
                    vTempOffSpellChecking();
                }
                if (vTempOffPHTV && !_hasJustUsedHotKey && _lastFlag & kCGEventFlagMaskCommand) {
                    vTempOffEngine();
                }
                _lastFlag = 0;
                _keyPressedWhileSwitchModifiersHeld = false;
                _hasJustUsedHotKey = false;
            }
        }

        // Also check correct event hooked
        if ((type != kCGEventKeyDown) && (type != kCGEventKeyUp) &&
            (type != kCGEventLeftMouseDown) && (type != kCGEventRightMouseDown) &&
            (type != kCGEventLeftMouseDragged) && (type != kCGEventRightMouseDragged))
            return event;
        
        _proxy = proxy;
        
        // Skip Vietnamese processing for Spotlight and similar launcher apps
        // Use PID-based detection to properly detect overlay windows like Spotlight
        if (shouldDisableVietnameseForEvent(event)) {
            return event;
        }
        
        //If is in english mode
        // Use atomic read to ensure thread-safe access from event tap thread
        int currentLanguage = __atomic_load_n(&vLanguage, __ATOMIC_RELAXED);
        if (currentLanguage == 0) {
            if (vUseMacro && vUseMacroInEnglishMode && type == kCGEventKeyDown) {
                vEnglishMode((type == kCGEventKeyDown ? vKeyEventState::KeyDown : vKeyEventState::MouseDown),
                             _keycode,
                             (_flag & kCGEventFlagMaskShift) || (_flag & kCGEventFlagMaskAlphaShift),
                             OTHER_CONTROL_KEY);

                if (pData->code == vReplaceMaro) { //handle macro in english mode
                    handleMacro();
                    return NULL;
                }
            }

            return event;
        }
        
        //handle mouse - reset session to avoid stale typing state
        if (type == kCGEventLeftMouseDown || type == kCGEventRightMouseDown || type == kCGEventLeftMouseDragged || type == kCGEventRightMouseDragged) {
            RequestNewSession();
            
            // Try to restore session if clicked on a word (Left Mouse Down only)
            if (type == kCGEventLeftMouseDown) {
                // TryToRestoreSessionFromAX();
            }
            
            return event;
        }

        //if "turn off Vietnamese when in other language" mode on
        // PERFORMANCE: Cache language check to avoid expensive TIS calls on every keystroke
        if(vOtherLanguage){
            static NSString *cachedLanguage = nil;
            static uint64_t lastLanguageCheckTime = 0;
            NSString *currentLanguage = nil;

            // Check language at most once every 1 second (keyboard layout doesn't change that often)
            uint64_t now = mach_absolute_time();
            uint64_t elapsed_ms = mach_time_to_ms(now - lastLanguageCheckTime);
            if (__builtin_expect(lastLanguageCheckTime == 0 || elapsed_ms > 1000, 0)) {
                TISInputSourceRef isource = TISCopyCurrentKeyboardInputSource();
                if (isource != NULL) {
                    CFArrayRef languages = (CFArrayRef) TISGetInputSourceProperty(isource, kTISPropertyInputSourceLanguages);

                    if (languages != NULL && CFArrayGetCount(languages) > 0) {
                        // MEMORY BUG FIX: CFArrayGetValueAtIndex returns borrowed reference - do NOT CFRelease
                        CFStringRef langRef = (CFStringRef)CFArrayGetValueAtIndex(languages, 0);
                        cachedLanguage = [(__bridge NSString *)langRef copy];
                    }
                    CFRelease(isource);  // Only release isource (we copied it)
                    lastLanguageCheckTime = now;
                }
            }

            currentLanguage = cachedLanguage;
            // Allow Latin-based keyboard layouts that can type Vietnamese
            // This includes: en (English), de (German), fr (French), es (Spanish),
            // it (Italian), pt (Portuguese), nl (Dutch), da (Danish), sv (Swedish),
            // Only block non-Latin keyboards like Chinese, Japanese, Korean, Arabic, Hebrew, etc.
            // All Latin-script based keyboards are allowed for Vietnamese input
            static NSSet *latinLanguages = nil;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                latinLanguages = [[NSSet alloc] initWithArray:@[
                    // Western European
                    @"en", @"de", @"fr", @"es", @"it", @"pt", @"nl", @"ca",  // English, German, French, Spanish, Italian, Portuguese, Dutch, Catalan
                    // Nordic
                    @"da", @"sv", @"no", @"nb", @"nn", @"fi", @"is", @"fo",  // Danish, Swedish, Norwegian, Finnish, Icelandic, Faroese
                    // Eastern European (Latin script)
                    @"pl", @"cs", @"sk", @"hu", @"ro", @"hr", @"sl", @"sr-Latn",  // Polish, Czech, Slovak, Hungarian, Romanian, Croatian, Slovenian, Serbian Latin
                    // Baltic
                    @"et", @"lv", @"lt",  // Estonian, Latvian, Lithuanian
                    // Other European
                    @"sq", @"bs", @"mt",  // Albanian, Bosnian, Maltese
                    // Turkish & Turkic (Latin script)
                    @"tr", @"az", @"uz", @"tk",  // Turkish, Azerbaijani, Uzbek, Turkmen
                    // Southeast Asian (Latin script)
                    @"id", @"ms", @"vi", @"tl", @"jv", @"su",  // Indonesian, Malay, Vietnamese, Tagalog, Javanese, Sundanese
                    // African (Latin script)
                    @"sw", @"ha", @"yo", @"ig", @"zu", @"xh", @"af",  // Swahili, Hausa, Yoruba, Igbo, Zulu, Xhosa, Afrikaans
                    // Pacific
                    @"mi", @"sm", @"to", @"haw",  // Maori, Samoan, Tongan, Hawaiian
                    // Celtic
                    @"ga", @"gd", @"cy", @"br",  // Irish, Scottish Gaelic, Welsh, Breton
                    // Other
                    @"eo", @"la",  // Esperanto, Latin
                    // Romanizations (Pinyin, Romaji often report base language but use Latin)
                    @"mul"  // Multiple languages (generic Latin)
                ]];
            });
            if (currentLanguage && ![latinLanguages containsObject:currentLanguage]) {
                return event;
            }
        }
        
        //handle keyboard
        if (type == kCGEventKeyDown) {
            // Determine the effective target app.
            // NOTE: In some cases (observed while Spotlight is focused), kCGEventTargetUnixProcessID may
            // resolve to an unrelated foreground app (e.g. Console). When Spotlight is AX-focused, prefer
            // the AX-focused owner.
            pid_t eventTargetPID = (pid_t)CGEventGetIntegerValueField(event, kCGEventTargetUnixProcessID);
            NSString *eventTargetBundleId = (eventTargetPID > 0) ? getBundleIdFromPID(eventTargetPID) : nil;
            NSString *focusedBundleId = getFocusedAppBundleId();
            BOOL spotlightActive = isSpotlightActive();
            NSString *effectiveBundleId = (spotlightActive && focusedBundleId != nil) ? focusedBundleId : (eventTargetBundleId ?: focusedBundleId);

            // PERFORMANCE: Cache app characteristics once per callback
            // This eliminates 5-10 function calls throughout the callback
            AppCharacteristics appChars = getAppCharacteristics(effectiveBundleId);

            // Cache for send routines called later in this callback.
            _phtvEffectiveTargetBundleId = effectiveBundleId;
            
            // BROWSER FIX: Browsers (Chromium, Safari, Firefox, etc.) don't support 
            // HID tap posting or AX API for their address bar autocomplete.
            // When spotlightActive=true on a browser address bar, we should NOT use Spotlight-style handling.
            BOOL isBrowser = [_browserAppSet containsObject:effectiveBundleId];
            _phtvPostToHIDTap = (!isBrowser && spotlightActive) || appChars.isSpotlightLike;
            
            _phtvKeyboardType = CGEventGetIntegerValueField(event, kCGKeyboardEventKeyboardType);
            _phtvPendingBackspaceCount = 0;

#ifdef DEBUG
            // Diagnostic logs: either we believe the target is Spotlight-like, or AX says Spotlight is active.
            // This helps detect bundle-id mismatches (e.g. Spotlight field hosted by another process).
            if (_phtvPostToHIDTap || spotlightActive) {
                int currentCodeTable = __atomic_load_n(&vCodeTable, __ATOMIC_RELAXED);
                PHTVSpotlightDebugLog([NSString stringWithFormat:@"spotlightActive=%d targetPID=%d eventTarget=%@ focused=%@ effective=%@ codeTable=%d keycode=%d",
                                      (int)spotlightActive,
                                      (int)eventTargetPID,
                                      eventTargetBundleId,
                                      focusedBundleId,
                                      effectiveBundleId,
                                      currentCodeTable,
                                      (int)_keycode]);
            }
#endif

            struct CodeTableOverrideGuard {
                bool active = false;
                int saved = 0;
                ~CodeTableOverrideGuard() {
                    if (active) {
                        __atomic_store_n(&vCodeTable, saved, __ATOMIC_RELAXED);
                    }
                }
            } codeTableGuard;

            int currentCodeTable = __atomic_load_n(&vCodeTable, __ATOMIC_RELAXED);
            if (currentCodeTable == 3 && (spotlightActive || appChars.isSpotlightLike)) {
                codeTableGuard.active = true;
                codeTableGuard.saved = currentCodeTable;
                __atomic_store_n(&vCodeTable, 0, __ATOMIC_RELAXED);
            }

            //send event signal to Engine
            vKeyHandleEvent(vKeyEvent::Keyboard,
                            vKeyEventState::KeyDown,
                            _keycode,
                            _flag & kCGEventFlagMaskShift ? 1 : (_flag & kCGEventFlagMaskAlphaShift ? 2 : 0),
                            OTHER_CONTROL_KEY);

#ifdef DEBUG
            // Log engine result for space key
            if (_keycode == KEY_SPACE) {
                NSLog(@"[TextReplacement] Engine result for SPACE: code=%d, extCode=%d, backspace=%d, newChar=%d",
                      pData->code, pData->extCode, pData->backspaceCount, pData->newCharCount);
            }

            // AUTO ENGLISH DEBUG LOGGING
            // Log when Auto English should trigger (extCode=5)
            if (pData->extCode == 5) {
                if (pData->code == vRestore || pData->code == vRestoreAndStartNewSession) {
                    NSLog(@"[AutoEnglish] ✓ RESTORE TRIGGERED: code=%d, backspace=%d, newChar=%d, keycode=%d (0x%X)",
                          pData->code, (int)pData->backspaceCount, (int)pData->newCharCount, _keycode, _keycode);
                } else {
                    NSLog(@"[AutoEnglish] ⚠️ WARNING: extCode=5 but code=%d (not restore!)", pData->code);
                }
            }
            // Log when Auto English might have failed (SPACE key with no restore)
            else if (_keycode == KEY_SPACE && pData->code == vDoNothing) {
                NSLog(@"[AutoEnglish] ✗ NO RESTORE on SPACE: code=%d, extCode=%d",
                      pData->code, pData->extCode);
            }
#endif

            if (pData->code == vDoNothing) { //do nothing
                // Navigation keys: trigger session restore to support keyboard-based edit-in-place
                if (_keycode == KEY_LEFT || _keycode == KEY_RIGHT || _keycode == KEY_UP || _keycode == KEY_DOWN ||
                    _keycode == 115 || _keycode == 119 || _keycode == 116 || _keycode == 121) { // Home, End, PgUp, PgDown
                    // TryToRestoreSessionFromAX();
                }

                // Use atomic read for thread safety
                int currentCodeTable = __atomic_load_n(&vCodeTable, __ATOMIC_RELAXED);
                if (IS_DOUBLE_CODE(currentCodeTable)) { //VNI
                    if (pData->extCode == 1) { //break key
                        _syncKey.clear();
                    } else if (pData->extCode == 2) { //delete key
                        if (_syncKey.size() > 0) {
                            if (_syncKey.back() > 1 && (vCodeTable == 2 || !containUnicodeCompoundApp(effectiveBundleId))) {
                                //send one more backspace
                                CGEventTapPostEvent(_proxy, eventBackSpaceDown);
                                CGEventTapPostEvent(_proxy, eventBackSpaceUp);
                            }
                            _syncKey.pop_back();
                        }
                       
                    } else if (pData->extCode == 3) { //normal key
                        InsertKeyLength(1);
                    }
                }
                return event;
            } else if (pData->code == vWillProcess || pData->code == vRestore || pData->code == vRestoreAndStartNewSession) { //handle result signal
                #ifdef DEBUG
                if (pData->code == vRestoreAndStartNewSession) {
                    fprintf(stderr, "[AutoEnglish] vRestoreAndStartNewSession START: backspace=%d, newChar=%d, keycode=%d\n",
                           (int)pData->backspaceCount, (int)pData->newCharCount, _keycode);
                    fflush(stderr);
                }
                #endif

                // BROWSER FIX: Browsers (Chromium, Safari, Firefox, etc.) don't support AX API properly
                // for their address bar autocomplete. When spotlightActive=true on a browser, 
                // we should NOT use Spotlight-style handling.
                BOOL isBrowserApp = [_browserAppSet containsObject:effectiveBundleId];
                
                // Check if this is a special app (Spotlight-like or WhatsApp-like)
                // Also treat as special when spotlightActive (search field detected via AX API)
                // EXCEPT for browsers - they don't support AX API for autocomplete, so ignore spotlightActive for them
                BOOL isSpecialApp = (!isBrowserApp && spotlightActive) || appChars.isSpotlightLike || appChars.needsPrecomposedBatched;

                // BROWSER SHORTCUT FIX: Avoid sending empty character for common shortcut prefixes (like /)
                // or when a new session just started without any previous context.
                // This prevents browsers from deleting the shortcut token (e.g., "/p") 
                // when PHTV tries to break the autocomplete.
                BOOL isPotentialShortcut = (_keycode == KEY_SLASH);
                
                // fix autocomplete
                // CRITICAL FIX: NEVER send empty character for SPACE key!
                // This conflicts with macOS Text Replacement feature
                // SendEmptyCharacter is only needed for Vietnamese character keys, NOT for break keys
                if (vFixRecommendBrowser && pData->extCode != 4 && !isSpecialApp && _keycode != KEY_SPACE && !isPotentialShortcut) {
                    SendEmptyCharacter();
                    pData->backspaceCount++;
                }
#ifdef DEBUG
                if (_keycode == KEY_SPACE && vFixRecommendBrowser && pData->extCode != 4 && !isSpecialApp) {
                    NSLog(@"[TextReplacement] SKIPPED SendEmptyCharacter for SPACE to avoid Text Replacement conflict");
                }
#endif

                // TEXT REPLACEMENT FIX: Skip backspace/newChar if this is SPACE after text replacement
                // Detection methods:
                // 1. External DELETE detected (arrow key selection) - HIGH CONFIDENCE
                // 2. Short backspace + code=3 without DELETE (mouse click selection) - FALLBACK
                // Can be enabled via Settings > Compatibility > "Sửa lỗi Text Replacement"
                BOOL skipProcessing = NO;

                // Log for debugging text replacement issues (only in Debug builds)
                #ifdef DEBUG
                if (IsTextReplacementFixEnabled() &&
                    (pData->backspaceCount > 0 || pData->newCharCount > 0)) {
                    NSLog(@"[PHTV TextReplacement] Key=%d: code=%d, extCode=%d, backspace=%d, newChar=%d, deleteCount=%d",
                          _keycode, pData->code, pData->extCode, (int)pData->backspaceCount, (int)pData->newCharCount, _externalDeleteCount);
                }
                #endif

                if (IsTextReplacementFixEnabled() &&
                    _keycode == KEY_SPACE &&
                    (pData->backspaceCount > 0 || pData->newCharCount > 0)) {

                    // Method 1: External DELETE detected (arrow key selection)
                    if (_externalDeleteCount > 0 && _lastExternalDeleteTime != 0) {

                    // CRITICAL FIX: Exclude Auto English from Text Replacement detection
                    // Auto English uses extCode=5 and vRestoreAndStartNewSession
                    // Without this exclusion, Auto English restore gets skipped!
                    if (pData->extCode != 5 && pData->code != vRestoreAndStartNewSession) {

                    // Check how long ago the delete happened
                    dispatch_once(&timebase_init_token, ^{
                        mach_timebase_info(&timebase_info);
                    });
                    uint64_t now = mach_absolute_time();
                    uint64_t elapsed_since_delete = mach_time_to_ms(now - _lastExternalDeleteTime);

                    // Text replacement pattern: delete + space within 30 seconds (allow slow menu selection)
                    if (elapsed_since_delete < 30000) {
                        // This is macOS Text Replacement, skip processing
                        skipProcessing = YES;
#ifdef DEBUG
                        NSLog(@"[TextReplacement] Text replacement detected - passing through event (code=%d, backspace=%d, newChar=%d, deleteCount=%d, elapsedMs=%llu)",
                              pData->code, (int)pData->backspaceCount, (int)pData->newCharCount, _externalDeleteCount, elapsed_since_delete);
#endif
                        // Reset detection for next time
                        _externalDeleteCount = 0;
                        _externalDeleteDetected = NO;
                        _lastExternalDeleteTime = 0;

                        // CRITICAL: Return event to let macOS insert Space
                        return event;
                    } else {
                        // Too old, reset the counter
                        _externalDeleteCount = 0;
                        _externalDeleteDetected = NO;
                        _lastExternalDeleteTime = 0;
                    }
                    }  // End of Auto English exclusion check
                    }  // End of _externalDeleteCount check

                    // Method 2: Mouse click detection (FALLBACK)
                    // When user clicks with mouse, macOS does NOT send DELETE events via CGEventTap
                    // Detection patterns (with Auto English exclusions):
                    // 2a. Significant char jump: newChar >= backspace*2 (e.g., "dc"→"được": 4>=2*2, "ko"→"không": 5>=2*2)
                    // 2b. Equal counts pattern: backspace==newChar + short length (e.g., some Text Replacements don't expand)
                    // EXCLUSIONS: Auto English has extCode=5, vRestoreAndStartNewSession - skip these
                    else if (_externalDeleteCount == 0 &&
                             pData->extCode != 5 &&  // EXCLUDE: Auto English restore (extCode=5)
                             pData->code != vRestoreAndStartNewSession) {  // EXCLUDE: Auto English word break
                        BOOL pattern2a = (pData->newCharCount >= pData->backspaceCount * 2);  // Text expanded 2x or more
                        BOOL pattern2b = ((pData->code == vWillProcess || pData->code == vRestore) &&
                                         pData->backspaceCount > 0 &&
                                         pData->backspaceCount == pData->newCharCount &&
                                         pData->backspaceCount <= 10);  // Equal counts, short word

                        if (pattern2a || pattern2b) {
                        #ifdef DEBUG
                        NSLog(@"[PHTV TextReplacement] Pattern %@ matched: code=%d, backspace=%d, newChar=%d, keycode=%d",
                              pattern2a ? @"2a" : @"2b",
                              pData->code, (int)pData->backspaceCount, (int)pData->newCharCount, _keycode);
                        #endif
                        // Text replacement detected
                        skipProcessing = YES;
                        NSLog(@"[PHTV TextReplacement] ✅ DETECTED - Skipping processing (code=%d, backspace=%d, newChar=%d)",
                              pData->code, (int)pData->backspaceCount, (int)pData->newCharCount);
                        // CRITICAL: Return event to let macOS insert Space
                        return event;
                        } else {
                            // Detection FAILED - will process normally (potential bug!)
                            NSLog(@"[PHTV TextReplacement] ❌ NOT DETECTED - Will process normally (code=%d, backspace=%d, newChar=%d) - MAY CAUSE DUPLICATE!",
                                  pData->code, (int)pData->backspaceCount, (int)pData->newCharCount);
                        }
                    }
                }

                // Auto-English browser fix removed - Shift+Left strategy handles it
                // No need for HID tap forcing or aggressive delays anymore

                //send backspace
                if (!skipProcessing && pData->backspaceCount > 0 && pData->backspaceCount < MAX_BUFF) {
                    // Use Spotlight-style deferred backspace when in search field (spotlightActive) or Spotlight-like app
                    // EXCEPT for Chromium apps - they don't support AX API properly
                    if ((!isBrowserApp && spotlightActive) || appChars.isSpotlightLike) {
                        // Defer deletion to AX replacement inside SendNewCharString().
                        _phtvPendingBackspaceCount = (int)pData->backspaceCount;
#ifdef DEBUG
                        PHTVSpotlightDebugLog([NSString stringWithFormat:@"deferBackspace=%d newCharCount=%d", (int)pData->backspaceCount, (int)pData->newCharCount]);
#endif
                    } else {
                        // NEW STRATEGY: Use "Select then Delete" (Shift + Left Arrow) approach
                        // This strategy (inspired by OpenKey) works well for all browsers:
                        // - Chromium-based (Chrome, Edge, Brave, etc.)
                        // - WebKit (Safari)
                        // - Gecko (Firefox)
                        // No more delays needed thanks to this approach

                        if (appChars.needsStepByStep) {
                            // Only step-by-step apps need special timing
                            SendBackspaceSequenceWithDelay(pData->backspaceCount, DelayTypeTerminal);
                        } else {
                            // Browsers, terminals, and normal apps all use no delay
                            // The Shift+Left strategy handles browser autocomplete issues
                            SendBackspaceSequence(pData->backspaceCount, NO);
                        }
                    }
                }

                //send new character - use step by step for timing sensitive apps like Spotlight
                // IMPORTANT: For Spotlight-like targets we rely on SendNewCharString(), which can
                // perform deterministic replacement (AX) and/or per-character Unicode posting.
                // Forcing step-by-step here would skip deferred deletions and cause duplicated letters.
                // TEXT REPLACEMENT FIX: Skip if already determined we should skip processing
                // EXCEPTION: Auto English restore (extCode=5) on Chromium apps should use step-by-step
                // because Chromium's autocomplete interferes with AX API and Unicode string posting
                if (!skipProcessing) {
                    // For Spotlight-like targets we rely on SendNewCharString(), which can
                    // perform deterministic replacement (AX) and/or per-character Unicode posting.
                    // EXCEPT for browsers - they don't support AX API properly
                    BOOL isSpotlightTarget = (!isBrowserApp && spotlightActive) || appChars.isSpotlightLike;
                    // Browser step-by-step removed - Shift+Left strategy handles browsers well with batch posting
                    // Only use step-by-step for explicitly configured apps
                    BOOL useStepByStep = (!isSpotlightTarget) && (vSendKeyStepByStep || appChars.needsStepByStep);
#ifdef DEBUG
                    if (isSpotlightTarget) {
                        PHTVSpotlightDebugLog([NSString stringWithFormat:@"willSend stepByStep=%d backspaceCount=%d newCharCount=%d", (int)useStepByStep, (int)pData->backspaceCount, (int)pData->newCharCount]);
                    }
#endif
                    if (!useStepByStep) {
                        SendNewCharString();
                    } else {
                        if (pData->newCharCount > 0 && pData->newCharCount <= MAX_BUFF) {
                            // Browser delays removed - Shift+Left strategy handles autocomplete
                            for (int i = pData->newCharCount - 1; i >= 0; i--) {
                                SendKeyCode(pData->charData[i]);
                                // No delay needed between characters - Shift+Left handles it
                            }
                        }
                        if (pData->code == vRestore || pData->code == vRestoreAndStartNewSession) {
                            #ifdef DEBUG
                            if (pData->code == vRestoreAndStartNewSession) {
                                fprintf(stderr, "[AutoEnglish] PROCESSING RESTORE: backspace=%d, newChar=%d, skipProcessing=%d\n",
                                       (int)pData->backspaceCount, (int)pData->newCharCount, skipProcessing);
                                fflush(stderr);
                            }
                            #endif
                            // Browser delay removed - Shift+Left strategy handles autocomplete
                            // No delay needed before final key
                            SendKeyCode(_keycode | ((_flag & kCGEventFlagMaskAlphaShift) || (_flag & kCGEventFlagMaskShift) ? CAPS_MASK : 0));
                        }
                        if (pData->code == vRestoreAndStartNewSession) {
                            startNewSession();
                        }
                    }
                }
            } else if (pData->code == vReplaceMaro) { //MACRO
                handleMacro();
            }

            // Update response time tracking for adaptive delays
            // Measure how long it takes for system to process keystrokes
            UpdateResponseTimeTracking();

            return NULL;
        }
        
        return event;
        } // @autoreleasepool
    }
}
