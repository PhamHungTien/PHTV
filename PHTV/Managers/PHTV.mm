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
#import "../Utils/MJAccessibilityUtils.h"

#define FRONT_APP [[NSWorkspace sharedWorkspace] frontmostApplication].bundleIdentifier

// Performance & Cache Configuration
static const uint64_t SPOTLIGHT_CACHE_DURATION_MS = 50;      // Spotlight detection cache timeout
static const uint64_t PID_CACHE_CLEAN_INTERVAL_MS = 300000;  // 5 minutes - PID cache cleanup
static const NSUInteger MAX_PID_CACHE_SIZE = 100;            // Maximum PID cache entries
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

// Spotlight detection cache (refreshes every 50ms for optimal balance of performance and responsiveness)
// Thread-safe access required since event tap callback may run on different threads
static BOOL _cachedSpotlightActive = NO;
static uint64_t _lastSpotlightCheckTime = 0;
static pid_t _cachedFocusedPID = 0;
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
    return YES;  // Always enabled - matches PHTPApp.swift computed property
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
    os_unfair_lock_unlock(&_spotlightCacheLock);
}

// Thread-safe helper to update Spotlight cache
static inline void UpdateSpotlightCache(BOOL isActive, pid_t pid) {
    os_unfair_lock_lock(&_spotlightCacheLock);
    _cachedSpotlightActive = isActive;
    _lastSpotlightCheckTime = mach_absolute_time();
    if (pid > 0) {
        _cachedFocusedPID = pid;
    }
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

// Check if element is Spotlight by examining its role and subrole
static inline BOOL IsElementSpotlight(AXUIElementRef element) {
    if (element == NULL) return NO;

    CFTypeRef role = NULL;
    CFTypeRef subrole = NULL;
    BOOL isSpotlight = NO;

    // Check role
    if (AXUIElementCopyAttributeValue(element, kAXRoleAttribute, &role) == kAXErrorSuccess) {
        if (role != NULL) {
            // Spotlight search field has specific roles
            if (CFGetTypeID(role) == CFStringGetTypeID()) {
                NSString *roleStr = (__bridge NSString *)role;
                if ([roleStr isEqualToString:@"AXTextField"] ||
                    [roleStr isEqualToString:@"AXSearchField"]) {

                    // Check subrole for confirmation
                    if (AXUIElementCopyAttributeValue(element, kAXSubroleAttribute, &subrole) == kAXErrorSuccess) {
                        if (subrole != NULL && CFGetTypeID(subrole) == CFStringGetTypeID()) {
                            NSString *subroleStr = (__bridge NSString *)subrole;
                            if ([subroleStr containsString:@"Search"]) {
                                isSpotlight = YES;
                            }
                        }
                    }
                }
            }
            CFRelease(role);
        }
    }

    if (subrole != NULL) CFRelease(subrole);
    return isSpotlight;
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

    // Return cached result if recent enough
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
        UpdateSpotlightCache(NO, 0);
        return NO;
    }

    // HEURISTIC CHECK: First try to detect Spotlight by element role/subrole
    // This is more reliable than PID/bundle ID which can be ambiguous
    BOOL elementLooksLikeSpotlight = IsElementSpotlight(focusedElement);

    // Get the PID of the app that owns the focused element
    pid_t focusedPID = 0;
    error = AXUIElementGetPid(focusedElement, &focusedPID);
    CFRelease(focusedElement);

    if (error != kAXErrorSuccess || focusedPID == 0) {
        LogAXError(error, "AXUIElementGetPid");
        // If we couldn't get PID but element looks like Spotlight, trust the heuristic
        if (elementLooksLikeSpotlight) {
            UpdateSpotlightCache(YES, 0);
            return YES;
        }
        UpdateSpotlightCache(NO, 0);
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
        UpdateSpotlightCache(YES, focusedPID);
        return YES;
    }

    // Also check by process path for system processes without bundle ID
    if (bundleId == nil) {
        char pathBuffer[PROC_PIDPATHINFO_MAXSIZE];
        if (proc_pidpath(focusedPID, pathBuffer, sizeof(pathBuffer)) > 0) {
            NSString *path = [NSString stringWithUTF8String:pathBuffer];
            if ([path containsString:@"Spotlight"]) {
                UpdateSpotlightCache(YES, focusedPID);
                return YES;
            }
        }
    }

    // Final fallback: trust the element heuristic if bundle ID check failed
    if (elementLooksLikeSpotlight) {
        UpdateSpotlightCache(YES, focusedPID);
        return YES;
    }

    UpdateSpotlightCache(NO, focusedPID);
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

    // Smart cache cleanup: Limit growth but keep hot entries
    // Check every 5 minutes and only clean if cache grows too large
    uint64_t now = mach_absolute_time();
    uint64_t elapsed_ms = mach_time_to_ms(now - _lastCacheCleanTime);
    if (__builtin_expect(elapsed_ms > PID_CACHE_CLEAN_INTERVAL_MS, 0)) {
        // Only remove half the entries if cache exceeds maximum size
        // This preserves hot entries better than removeAllObjects
        if (_pidBundleCache.count > MAX_PID_CACHE_SIZE) {
            // Remove approximately half by removing every other entry
            NSArray *keys = [_pidBundleCache allKeys];
            for (NSUInteger i = 0; i < keys.count; i += 2) {
                [_pidBundleCache removeObjectForKey:keys[i]];
            }
        }
        _lastCacheCleanTime = now;
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
extern volatile int vFixChromiumBrowser;
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
                                                           @"com.microsoft.edgemac.Dev",
                                                           @"com.microsoft.edgemac.Beta",
                                                           @"com.microsoft.Edge.Dev",
                                                           @"com.microsoft.Edge"]];

    // Apps that need to FORCE Unicode precomposed (not compound) - Using NSSet for O(1) lookup performance
    // These apps don't handle Unicode combining characters properly
    // Note: WhatsApp removed - it needs precomposed but NOT Spotlight-style AX/per-char handling
    NSSet* _forcePrecomposedAppSet = [NSSet setWithArray:@[@"com.apple.Spotlight",
                                                            @"com.apple.systemuiserver",  // Spotlight runs under SystemUIServer
                                                            PHTV_BUNDLE]];  // PHTV itself - SwiftUI TextField needs HID tap posting

    // Apps that need precomposed Unicode but should use normal batched sending (not AX API)
    // These are Electron/web apps that don't support AX text replacement
    NSSet* _precomposedBatchedAppSet = [NSSet setWithArray:@[@"net.whatsapp.WhatsApp"]];

    //app which needs step by step key sending (timing sensitive apps) - Using NSSet for O(1) lookup performance
    NSSet* _stepByStepAppSet = [NSSet setWithArray:@[// Commented out for testing Vietnamese input:
                                                      // @"com.apple.Spotlight",
                                                      // @"com.apple.systemuiserver",  // Spotlight runs under SystemUIServer
                                                      @"com.apple.loginwindow",     // Login window
                                                      @"com.apple.SecurityAgent",   // Security dialogs
                                                      @"com.raycast.macos",
                                                      @"com.alfredapp.Alfred",
                                                      @"com.apple.launchpad"]];     // Launchpad/Ứng dụng
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

        // Read caret position
        CFTypeRef rangeRef = NULL;
        NSInteger caretLocation = (NSInteger)valueStr.length;
        error = AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextRangeAttribute, &rangeRef);
        if (error == kAXErrorSuccess && rangeRef && CFGetTypeID(rangeRef) == AXValueGetTypeID()) {
            CFRange sel;
            if (AXValueGetValue((AXValueRef)rangeRef, PHTV_AXVALUE_CFRANGE_TYPE, &sel)) {
                caretLocation = (NSInteger)sel.location;
            }
        }
        if (rangeRef) CFRelease(rangeRef);

        // Clamp
        if (caretLocation < 0) caretLocation = 0;
        if (caretLocation > (NSInteger)valueStr.length) caretLocation = (NSInteger)valueStr.length;

        // Calculate replacement - handle Unicode composed/decomposed length mismatch
        // The backspaceCount from engine counts logical characters, but Spotlight may have
        // different Unicode representation (composed vs decomposed)
        NSInteger start = caretLocation - backspaceCount;
        if (start < 0) start = 0;

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

        NSInteger len = caretLocation - start;
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

        NSString *bundleId = nil;
        pid_t cachePid = targetPID; // cache key we will use for next lookup

        // Safe Mode: Skip AX API calls entirely, use targetPID from event directly
        // This prevents crashes on unsupported hardware (OCLP Macs)
        if (!vSafeMode) {
            // First, check using Accessibility API to get the actual focused window's app
            AXUIElementRef systemWide = AXUIElementCreateSystemWide();
            AXUIElementRef focusedElement = NULL;
            AXError error = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute, (CFTypeRef *)&focusedElement);
            CFRelease(systemWide);

            if (error == kAXErrorSuccess && focusedElement != NULL) {
                pid_t focusedPID = 0;
                error = AXUIElementGetPid(focusedElement, &focusedPID);
                CFRelease(focusedElement);

                if (error == kAXErrorSuccess && focusedPID != 0) {
                    bundleId = getBundleIdFromPID(focusedPID);
                    cachePid = focusedPID;
                }
            }
        }

        // Fallback to target PID from event if accessibility fails or safe mode
        if (bundleId == nil && targetPID > 0) {
            bundleId = getBundleIdFromPID(targetPID);
        }

        // Last fallback to frontmost app (do not cache frontmost fallback to avoid stale state)
        if (bundleId == nil) {
            bundleId = FRONT_APP;
            cachePid = -1;
        }

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

        LOAD_DATA(vFixChromiumBrowser, vFixChromiumBrowser);

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
    
    void queryFrontMostApp() {
        if ([[[NSWorkspace sharedWorkspace] frontmostApplication].bundleIdentifier compare:PHTV_BUNDLE] != 0) {
            _frontMostApp = [[NSWorkspace sharedWorkspace] frontmostApplication].bundleIdentifier;
            if (_frontMostApp == nil)
                _frontMostApp = [[NSWorkspace sharedWorkspace] frontmostApplication].localizedName != nil ?
                [[NSWorkspace sharedWorkspace] frontmostApplication].localizedName : @"UnknownApp";
        }
    }
    
    NSString* ConvertUtil(NSString* str) {
        return [NSString stringWithUTF8String:convertUtil([str UTF8String]).c_str()];
    }
    
    // Get bundle ID of the actually focused app (not just frontmost)
    // This is important for overlay windows like Spotlight, which aren't the frontmost app
    NSString* getFocusedAppBundleId() {
        // Safe Mode: Skip AX API calls entirely, use frontmost app
        // This prevents crashes on unsupported hardware (OCLP Macs)
        if (vSafeMode) {
            return FRONT_APP;
        }

        AXUIElementRef systemWide = AXUIElementCreateSystemWide();
        AXUIElementRef focusedElement = NULL;
        AXError error = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute, (CFTypeRef *)&focusedElement);
        CFRelease(systemWide);

        if (error != kAXErrorSuccess || focusedElement == NULL) {
            return FRONT_APP;  // Fallback to frontmost app
        }

        pid_t focusedPID = 0;
        error = AXUIElementGetPid(focusedElement, &focusedPID);
        CFRelease(focusedElement);

        if (error != kAXErrorSuccess || focusedPID == 0) {
            return FRONT_APP;
        }

        NSString *bundleId = getBundleIdFromPID(focusedPID);
        return (bundleId != nil) ? bundleId : FRONT_APP;
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

        queryFrontMostApp();
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
        queryFrontMostApp();
        setAppInputMethodStatus(string(_frontMostApp.UTF8String), vLanguage | (vCodeTable << 1));
        saveSmartSwitchKeyData();
    }
    
    void OnInputMethodChanged() {
        if (!vUseSmartSwitchKey) {
            return;  // Skip if disabled
        }

        // PERFORMANCE: Just save the mapping, don't trigger more updates
        queryFrontMostApp();
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
    }
    
    void SendVirtualKey(const Byte& vKey) {
        CGEventRef eventVkeyDown = CGEventCreateKeyboardEvent (myEventSource, vKey, true);
        CGEventRef eventVkeyUp = CGEventCreateKeyboardEvent (myEventSource, vKey, false);
        
        CGEventTapPostEvent(_proxy, eventVkeyDown);
        CGEventTapPostEvent(_proxy, eventVkeyUp);
        
        CFRelease(eventVkeyDown);
        CFRelease(eventVkeyUp);
    }

    void SendBackspace() {
        if (_phtvPostToHIDTap) {
            // Spotlight/SystemUIServer can ignore cached backspace events.
            // Create fresh events and include keyboard type to match real device.
            CGEventRef bsDown = CGEventCreateKeyboardEvent(myEventSource, 51, true);
            CGEventRef bsUp = CGEventCreateKeyboardEvent(myEventSource, 51, false);
            if (_phtvKeyboardType != 0) {
                CGEventSetIntegerValueField(bsDown, kCGKeyboardEventKeyboardType, _phtvKeyboardType);
                CGEventSetIntegerValueField(bsUp, kCGKeyboardEventKeyboardType, _phtvKeyboardType);
            }
            CGEventFlags bsFlags = CGEventGetFlags(bsDown);
            bsFlags |= kCGEventFlagMaskNonCoalesced;
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

        if (IS_DOUBLE_CODE(vCodeTable)) { //VNI or Unicode Compound
            if (_syncKey.back() > 1) {
                NSString *effectiveTarget = _phtvEffectiveTargetBundleId ?: getFocusedAppBundleId();
                if (!(vCodeTable == 3 && containUnicodeCompoundApp(effectiveTarget))) {
                    if (_phtvPostToHIDTap) {
                        CGEventRef bsDown2 = CGEventCreateKeyboardEvent(myEventSource, 51, true);
                        CGEventRef bsUp2 = CGEventCreateKeyboardEvent(myEventSource, 51, false);
                        if (_phtvKeyboardType != 0) {
                            CGEventSetIntegerValueField(bsDown2, kCGKeyboardEventKeyboardType, _phtvKeyboardType);
                            CGEventSetIntegerValueField(bsUp2, kCGKeyboardEventKeyboardType, _phtvKeyboardType);
                        }
                        CGEventFlags bsFlags2 = CGEventGetFlags(bsDown2);
                        bsFlags2 |= kCGEventFlagMaskNonCoalesced;
                        CGEventSetFlags(bsDown2, bsFlags2);
                        CGEventSetFlags(bsUp2, bsFlags2);
                        PostSyntheticEvent(_proxy, bsDown2);
                        PostSyntheticEvent(_proxy, bsUp2);
                        SpotlightTinyDelay();
                        CFRelease(bsDown2);
                        CFRelease(bsUp2);
                    } else {
                        CGEventTapPostEvent(_proxy, eventBackSpaceDown);
                        CGEventTapPostEvent(_proxy, eventBackSpaceUp);
                    }
                }
            }
            _syncKey.pop_back();
        }
    }

    // Consolidated helper function to send multiple backspaces with optional terminal delays
    // This reduces code duplication across the codebase
    void SendBackspaceSequence(int count, BOOL isTerminalApp) {
        if (count <= 0) return;

        for (int i = 0; i < count; i++) {
            SendBackspace();
            if (isTerminalApp) {
                usleep(TERMINAL_KEYSTROKE_DELAY_US);
            }
        }

        // Extra settle time for terminals after all backspaces
        if (isTerminalApp) {
            usleep(TERMINAL_SETTLE_DELAY_US);
        }
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
            // Post typing stats notification for word completion
            [[NSNotificationCenter defaultCenter] postNotificationName:@"TypingStatsWord" object:@YES];
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
    
    void switchLanguage() {
        // Beep is now handled by SwiftUI when LanguageChangedFromBackend notification is posted
        // (removed NSBeep() to avoid duplicate sounds)

        // onImputMethodChanged handles: toggle, save, RequestNewSession, fillData, notify
        // No need to modify vLanguage here or call startNewSession separately
        [appDelegate onImputMethodChanged:YES];
    }
    
    void handleMacro() {
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
        // PERFORMANCE: Use cached bundle ID instead of querying AX API
        NSString *effectiveTarget = _phtvEffectiveTargetBundleId ?: getFocusedAppBundleId();
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
        SendKeyCode(_keycode | (_flag & kCGEventFlagMaskShift ? CAPS_MASK : 0));
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

    // Convert keyboard event to QWERTY-equivalent keycode for layout compatibility
    // This function handles international keyboard layouts by mapping characters to QWERTY keycodes
    CGKeyCode ConvertEventToKeyboadLayoutCompatKeyCode(CGEventRef keyEvent, CGKeyCode fallbackKeyCode) {
        NSEvent *kbLayoutCompatEvent = [NSEvent eventWithCGEvent:keyEvent];
        if (!kbLayoutCompatEvent) {
            return fallbackKeyCode;
        }

        // Strategy 1: Try charactersIgnoringModifiers first (best for most layouts)
        // This gives us the base character without Shift/Option modifications
        NSString *kbLayoutCompatKeyString = kbLayoutCompatEvent.charactersIgnoringModifiers;
        CGKeyCode result = ConvertKeyStringToKeyCode(kbLayoutCompatKeyString, 0xFFFF);
        if (result != 0xFFFF) {
            return result;
        }

        // Strategy 2: If that fails, try the actual characters property
        // This is useful for layouts like AZERTY where Shift+key produces a different character
        // that might be in our mapping (e.g., Shift+& = 1 on AZERTY)
        NSString *actualCharacters = kbLayoutCompatEvent.characters;
        if (actualCharacters && ![actualCharacters isEqualToString:kbLayoutCompatKeyString]) {
            result = ConvertKeyStringToKeyCode(actualCharacters, 0xFFFF);
            if (result != 0xFFFF) {
                return result;
            }
        }

        // Strategy 3: For AZERTY number row handling
        // On AZERTY, the number row produces special characters by default
        // and numbers with Shift. We need to handle the Shift+character -> number case
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
                return [azertyKeycode intValue];
            }
        }

        // Fallback to original keycode
        return fallbackKeyCode;
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
        // Aggressive inline health check every 25 events for near-instant recovery
        // Smart skip: after 1000 healthy checks, reduce frequency to save CPU
        static NSUInteger eventCounter = 0;
        static NSUInteger recoveryCounter = 0;
        static NSUInteger healthyCounter = 0;

        NSUInteger checkInterval = (healthyCounter > 1000) ? 100 : 25;

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
        if (_pauseKeyPressed && (type == kCGEventKeyDown || type == kCGEventKeyUp)) {
            CGEventFlags newFlags = StripPauseModifier(_flag);
            CGEventSetFlags(event, newFlags);
            _flag = newFlags;  // Update local flag as well
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
        } else if (type == kCGEventFlagsChanged) {
            if (_lastFlag == 0 || _lastFlag < _flag) {
                // Pressing more modifiers
                _lastFlag = _flag;

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

                //check switch
                if (checkHotKey(vSwitchKeyStatus, GET_SWITCH_KEY(vSwitchKeyStatus) != 0xFE)) {
                    _lastFlag = 0;
                    switchLanguage();
                    _hasJustUsedHotKey = true;
                    return NULL;
                }
                if (checkHotKey(convertToolHotKey, GET_SWITCH_KEY(convertToolHotKey) != 0xFE)) {
                    _lastFlag = 0;
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
            return event;
        }

        //if "turn off Vietnamese when in other language" mode on
        // PERFORMANCE: Cache language check to avoid expensive TIS calls on every keystroke
        if(vOtherLanguage){
            static NSString *cachedLanguage = nil;
            static uint64_t lastLanguageCheckTime = 0;
            NSString *currentLanguage = nil;

            // Check language at most once every 2 seconds (keyboard layout doesn't change that often)
            uint64_t now = mach_absolute_time();
            uint64_t elapsed_ms = mach_time_to_ms(now - lastLanguageCheckTime);
            if (__builtin_expect(lastLanguageCheckTime == 0 || elapsed_ms > 2000, 0)) {
                TISInputSourceRef isource = TISCopyCurrentKeyboardInputSource();
                if (isource != NULL) {
                    CFArrayRef languages = (CFArrayRef) TISGetInputSourceProperty(isource, kTISPropertyInputSourceLanguages);

                    if (languages != NULL && CFArrayGetCount(languages) > 0) {
                        // MEMORY BUG FIX: CFArrayGetValueAtIndex returns borrowed reference - do NOT CFRelease
                        CFStringRef langRef = (CFStringRef)CFArrayGetValueAtIndex(languages, 0);
                        NSString *newLanguage = [(__bridge NSString *)langRef copy];
                        // Explicitly nil out old value first (ARC will release it), then assign new value
                        // This ensures proper cleanup of static variable across multiple updates
                        cachedLanguage = nil;
                        cachedLanguage = newLanguage;
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
            _phtvPostToHIDTap = spotlightActive || appChars.isSpotlightLike;
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
#endif

            // Post typing stats notification for character (only for printable characters)
            if (!OTHER_CONTROL_KEY && keyCodeToCharacter(_keycode) != 0) {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"TypingStatsCharacter" object:nil];
            }

            if (pData->code == vDoNothing) { //do nothing
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

                // Check if this is a special app (Spotlight-like or WhatsApp-like)
                BOOL isSpecialApp = appChars.isSpotlightLike || appChars.needsPrecomposedBatched;

                //fix autocomplete
                // CRITICAL FIX: NEVER send empty character for SPACE key!
                // This conflicts with macOS Text Replacement feature
                // SendEmptyCharacter is only needed for Vietnamese character keys, NOT for break keys
                if (vFixRecommendBrowser && pData->extCode != 4 && !isSpecialApp && _keycode != KEY_SPACE) {
                    if (vFixChromiumBrowser && [_unicodeCompoundAppSet containsObject:effectiveBundleId]) {
                        if (pData->backspaceCount > 0) {
                            SendShiftAndLeftArrow();
                            if (pData->backspaceCount == 1)
                                pData->backspaceCount--;
                        }
                    } else {
                        SendEmptyCharacter();
                        pData->backspaceCount++;
                    }
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

                // ALWAYS LOG for debugging text replacement issues
                if (IsTextReplacementFixEnabled() && _keycode == KEY_SPACE &&
                    (pData->backspaceCount > 0 || pData->newCharCount > 0)) {
                    NSLog(@"[PHTV TextReplacement] SPACE key: code=%d, backspace=%d, newChar=%d, deleteCount=%d",
                          pData->code, (int)pData->backspaceCount, (int)pData->newCharCount, _externalDeleteCount);
                }

                if (IsTextReplacementFixEnabled() &&
                    _keycode == KEY_SPACE &&
                    (pData->backspaceCount > 0 || pData->newCharCount > 0)) {

                    // Method 1: External DELETE detected (arrow key selection)
                    if (_externalDeleteCount > 0 && _lastExternalDeleteTime != 0) {

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
                    }

                    // Method 2: Mouse click detection (FALLBACK)
                    // When user clicks with mouse, macOS does NOT send DELETE events via CGEventTap
                    // TWO detection patterns:
                    // 2a. Significant char jump: newChar > backspace*2 (e.g., "ko"→"không": 5>4)
                    // 2b. Suspicious restore: (code=vWillProcess OR vRestore) + backspace==newChar + short length
                    //     (macOS already replaced text, engine doesn't know, thinks needs restore)
                    //     Example: "ko"→"không" (macOS), engine sees "ko" buffer, Auto English restore triggers vRestore
                    else if (_externalDeleteCount == 0 &&
                             (pData->newCharCount > pData->backspaceCount * 2 ||
                              ((pData->code == vWillProcess || pData->code == vRestore) &&
                               pData->backspaceCount > 0 &&
                               pData->backspaceCount == pData->newCharCount &&
                               pData->backspaceCount <= 4))) {
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

                //send backspace
                if (!skipProcessing && pData->backspaceCount > 0 && pData->backspaceCount < MAX_BUFF) {
                    if (appChars.isSpotlightLike) {
                        // Defer deletion to AX replacement inside SendNewCharString().
                        _phtvPendingBackspaceCount = (int)pData->backspaceCount;
#ifdef DEBUG
                        PHTVSpotlightDebugLog([NSString stringWithFormat:@"deferBackspace=%d newCharCount=%d", (int)pData->backspaceCount, (int)pData->newCharCount]);
#endif
                    } else {
                        SendBackspaceSequence(pData->backspaceCount, NO);
                    }
                }
                
                //send new character - use step by step for timing sensitive apps like Spotlight
                // IMPORTANT: For Spotlight-like targets we rely on SendNewCharString(), which can
                // perform deterministic replacement (AX) and/or per-character Unicode posting.
                // Forcing step-by-step here would skip deferred deletions and cause duplicated letters.
                // TEXT REPLACEMENT FIX: Skip if already determined we should skip processing
                if (!skipProcessing) {
                    BOOL isSpotlightTarget = spotlightActive || appChars.isSpotlightLike;
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
                            for (int i = pData->newCharCount - 1; i >= 0; i--) {
                                SendKeyCode(pData->charData[i]);
                            }
                        }
                        if (pData->code == vRestore || pData->code == vRestoreAndStartNewSession) {
                            SendKeyCode(_keycode | ((_flag & kCGEventFlagMaskAlphaShift) || (_flag & kCGEventFlagMaskShift) ? CAPS_MASK : 0));
                        }
                        if (pData->code == vRestoreAndStartNewSession) {
                            startNewSession();
                            // Post typing stats notification for word completion
                            [[NSNotificationCenter defaultCenter] postNotificationName:@"TypingStatsWord" object:@YES];
                        }
                    }
                }
            } else if (pData->code == vReplaceMaro) { //MACRO
                handleMacro();
            }

            return NULL;
        }
        
        return event;
        } // @autoreleasepool
    }
}
