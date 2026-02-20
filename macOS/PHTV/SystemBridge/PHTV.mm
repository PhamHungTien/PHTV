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
#import <os/log.h>
#import <mach/mach_time.h>
#import <unistd.h>
#import <stdlib.h>
#import <string.h>
#include <limits>
#import "Engine.h"
#include "../Core/PHTVConstants.h"
#import "../Application/AppDelegate.h"
#import "../Application/AppDelegate+InputState.h"
#import "../Application/AppDelegate+StatusBarMenu.h"
#import "../Application/AppDelegate+UIActions.h"
#import "PHTVManager.h"
#import <Sparkle/Sparkle.h>
#import "PHTV-Swift.h"

// Forward declarations for functions used before definition (inside extern "C" block)
extern "C" {
    NSString* getBundleIdFromPID(pid_t pid);
    NSString* getFocusedAppBundleId(void);
}

#define FRONT_APP [[NSWorkspace sharedWorkspace] frontmostApplication].bundleIdentifier

typedef NS_ENUM(NSInteger, DelayType) {
    DelayTypeNone = 0,
    DelayTypeSpotlight = 2
};

typedef NS_ENUM(NSInteger, PHTVTextReplacementDecision) {
    PHTVTextReplacementDecisionNone = 0,
    PHTVTextReplacementDecisionExternalDelete = 1,
    PHTVTextReplacementDecisionPattern2A = 2,
    PHTVTextReplacementDecisionPattern2B = 3,
    PHTVTextReplacementDecisionFallbackNoMatch = 4
};

// Cached app behavior used across the event callback.
typedef struct {
    BOOL isSpotlightLike;
    BOOL needsPrecomposedBatched;
    BOOL needsStepByStep;
    BOOL containsUnicodeCompound;
    BOOL isSafari;
} AppCharacteristics;

// Performance & Cache Configuration
static const uint64_t SPOTLIGHT_CACHE_DURATION_MS = 150;     // Spotlight detection cache timeout (balanced for lower CPU)
#ifdef DEBUG
static const uint64_t DEBUG_LOG_THROTTLE_MS = 500;           // Debug log throttling interval
#endif
static const uint64_t APP_SWITCH_CACHE_DURATION_MS = 100;    // App switch detection cache timeout
static const uint64_t TEXT_REPLACEMENT_DELETE_WINDOW_MS = 30000;  // Max gap from external delete to replacement space
static const NSUInteger SYNC_KEY_RESERVE_SIZE = 256;         // Pre-allocated buffer size for typing sync

// Timing delay constants (all in microseconds)
static const int64_t kPHTVEventMarker = 0x50485456; // "PHTV"
static const useconds_t CLI_BACKSPACE_DELAY_FAST_US = 6000;
static const useconds_t CLI_WAIT_AFTER_BACKSPACE_FAST_US = 18000;
static const useconds_t CLI_TEXT_DELAY_FAST_US = 5000;
static const useconds_t CLI_BACKSPACE_DELAY_MEDIUM_US = 9000;
static const useconds_t CLI_WAIT_AFTER_BACKSPACE_MEDIUM_US = 27000;
static const useconds_t CLI_TEXT_DELAY_MEDIUM_US = 7000;
static const useconds_t CLI_BACKSPACE_DELAY_SLOW_US = 12000;
static const useconds_t CLI_WAIT_AFTER_BACKSPACE_SLOW_US = 36000;
static const useconds_t CLI_TEXT_DELAY_SLOW_US = 9000;
static const useconds_t CLI_BACKSPACE_DELAY_DEFAULT_US = 8000;
static const useconds_t CLI_WAIT_AFTER_BACKSPACE_DEFAULT_US = 24000;
static const useconds_t CLI_TEXT_DELAY_DEFAULT_US = 6000;
static const int CLI_TEXT_CHUNK_SIZE_DEFAULT = 20;
static const int CLI_TEXT_CHUNK_SIZE_ONE_BY_ONE = 1;
static const useconds_t CLI_BACKSPACE_DELAY_IDE_US = 8000;
static const useconds_t CLI_WAIT_AFTER_BACKSPACE_IDE_US = 25000;
static const useconds_t CLI_TEXT_DELAY_IDE_US = 8000;
static const useconds_t CLI_POST_SEND_BLOCK_MIN_US = 20000;
static const useconds_t CLI_PRE_BACKSPACE_DELAY_US = 4000;
static const uint64_t CLI_SPEED_FAST_THRESHOLD_US = 20000;
static const uint64_t CLI_SPEED_MEDIUM_THRESHOLD_US = 32000;
static const uint64_t CLI_SPEED_SLOW_THRESHOLD_US = 48000;
static const double CLI_SPEED_FACTOR_FAST = 2.1;
static const double CLI_SPEED_FACTOR_MEDIUM = 1.6;
static const double CLI_SPEED_FACTOR_SLOW = 1.3;

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

static inline uint64_t mach_time_to_us(uint64_t mach_time) {
    return (mach_time * timebase_info.numer) / (timebase_info.denom * 1000);
}

static inline uint64_t us_to_mach_time(uint64_t microseconds) {
    // Convert microseconds to mach absolute time units
    return (microseconds * timebase_info.denom * 1000) / timebase_info.numer;
}

static inline useconds_t PHTVClampUseconds(uint64_t microseconds) {
    if (microseconds > static_cast<uint64_t>(std::numeric_limits<useconds_t>::max())) {
        return std::numeric_limits<useconds_t>::max();
    }
    return static_cast<useconds_t>(microseconds);
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

extern "C" BOOL PHTVGetSafeMode(void) {
    return vSafeMode;
}

extern "C" void PHTVSetSafeMode(BOOL enabled) {
    vSafeMode = enabled;
}

// Check if Spotlight or similar overlay is currently active using Accessibility API
// OPTIMIZED: Results cached for 50ms to avoid repeated AX API calls while remaining responsive
BOOL isSpotlightActive(void) {
    if (vSafeMode) {
        return NO;
    }
    return [PHTVSpotlightDetectionService isSpotlightActive];
}

// Get bundle ID from process ID
NSString* getBundleIdFromPID(pid_t pid) {
    return [PHTVCacheStateService bundleIdFromPID:(int32_t)pid safeMode:vSafeMode];
}
#define OTHER_CONTROL_KEY (_flag & kCGEventFlagMaskCommand) || (_flag & kCGEventFlagMaskControl) || \
                            (_flag & kCGEventFlagMaskAlternate) || (_flag & kCGEventFlagMaskSecondaryFn) || \
                            (_flag & kCGEventFlagMaskNumericPad) || (_flag & kCGEventFlagMaskHelp)

#define DYNA_DATA(macro, pos) (macro ? pData->macroData[pos] : pData->charData[pos])
#define MAX_UNICODE_STRING  20

extern AppDelegate* appDelegate;
extern volatile int vSendKeyStepByStep;
extern volatile int vPerformLayoutCompat;
extern volatile int vTempOffPHTV;
extern volatile int vEnableEmojiHotkey;
extern volatile int vEmojiHotkeyModifiers;
extern volatile int vEmojiHotkeyKeyCode;
extern volatile int vPauseKeyEnabled;
extern volatile int vPauseKey;

extern "C" {

    // Get cached app characteristics or compute and cache them.
    // Cache state and computation are centralized in Swift services.
    static inline AppCharacteristics getAppCharacteristics(NSString* bundleId) {
        const uint64_t kAppCharacteristicsCacheMaxAgeMs = 10000;
        AppCharacteristics chars = {NO, NO, NO, NO, NO};
        if (!bundleId || bundleId.length == 0) {
            return chars;
        }

        int invalidationReason = (int)[PHTVCacheStateService prepareAppCharacteristicsCacheForBundleId:bundleId
                                                                                              maxAgeMs:kAppCharacteristicsCacheMaxAgeMs];
#ifdef DEBUG
        if (invalidationReason == 1) {
            NSLog(@"[Cache] App switched to %@, invalidating app characteristics cache", bundleId);
        } else if (invalidationReason == 2) {
            NSLog(@"[Cache] 10s elapsed, invalidating cache for browser responsiveness");
        }
#endif

        PHTVAppCharacteristicsBox *box = [PHTVCacheStateService appCharacteristicsForBundleId:bundleId];
        if (box) {
            chars.isSpotlightLike = box.isSpotlightLike;
            chars.needsPrecomposedBatched = box.needsPrecomposedBatched;
            chars.needsStepByStep = box.needsStepByStep;
            chars.containsUnicodeCompound = box.containsUnicodeCompound;
            chars.isSafari = box.isSafari;
            return chars;
        }

        chars.isSpotlightLike = [PHTVAppDetectionService isSpotlightLikeApp:bundleId];
        chars.needsPrecomposedBatched = [PHTVAppDetectionService needsPrecomposedBatched:bundleId];
        chars.needsStepByStep = [PHTVAppDetectionService needsStepByStep:bundleId];
        chars.containsUnicodeCompound = [PHTVAppDetectionService containsUnicodeCompound:bundleId];
        chars.isSafari = [PHTVAppDetectionService isSafariApp:bundleId];

        [PHTVCacheStateService setAppCharacteristicsForBundleId:bundleId
                                                isSpotlightLike:chars.isSpotlightLike
                                         needsPrecomposedBatched:chars.needsPrecomposedBatched
                                                 needsStepByStep:chars.needsStepByStep
                                         containsUnicodeCompound:chars.containsUnicodeCompound
                                                        isSafari:chars.isSafari];
        return chars;
    }

    __attribute__((always_inline)) static inline BOOL isSpotlightLikeApp(NSString* bundleId) {
        return [PHTVAppDetectionService isSpotlightLikeApp:bundleId];
    }

    // Check if app needs precomposed Unicode but with batched sending (not AX API)
    __attribute__((always_inline)) static inline BOOL needsPrecomposedBatched(NSString* bundleId) {
        return [PHTVAppDetectionService needsPrecomposedBatched:bundleId];
    }

    // Cache the effective target bundle id for the current event tap callback.
    // This avoids re-querying AX focus inside hot-path send routines.
static NSString* _phtvEffectiveTargetBundleId = nil;
static BOOL _phtvPostToHIDTap = NO;
static BOOL _phtvPostToSessionForCli = NO;
static BOOL _phtvIsCliTarget = NO;
static double _phtvCliSpeedFactor = 1.0;
static int _phtvCliPendingBackspaceCount = 0;
static useconds_t _phtvCliBackspaceDelayUs = 0;
static useconds_t _phtvCliWaitAfterBackspaceUs = 0;
static useconds_t _phtvCliTextDelayUs = 0;
static int _phtvCliTextChunkSize = CLI_TEXT_CHUNK_SIZE_DEFAULT;
static int64_t _phtvKeyboardType = 0;
static int _phtvPendingBackspaceCount = 0;
static uint64_t _phtvCliBlockUntil = 0;
static useconds_t _phtvCliPostSendBlockUs = CLI_POST_SEND_BLOCK_MIN_US;
static uint64_t _phtvCliLastKeyDownTime = 0;

    __attribute__((always_inline)) static inline void SpotlightTinyDelay(void) {
    }

    static inline void SetCliBlockForMicroseconds(uint64_t microseconds) {
        if (microseconds == 0) return;
        dispatch_once(&timebase_init_token, ^{
            mach_timebase_info(&timebase_info);
        });
        uint64_t now = mach_absolute_time();
        uint64_t until = now + us_to_mach_time(microseconds);
        if (until > _phtvCliBlockUntil) {
            _phtvCliBlockUntil = until;
        }
    }

    static inline double PHTVComputeCliSpeedFactor(uint64_t deltaUs) {
        if (deltaUs == 0) {
            return 1.0;
        }
        if (deltaUs <= CLI_SPEED_FAST_THRESHOLD_US) {
            return CLI_SPEED_FACTOR_FAST;
        }
        if (deltaUs <= CLI_SPEED_MEDIUM_THRESHOLD_US) {
            return CLI_SPEED_FACTOR_MEDIUM;
        }
        if (deltaUs <= CLI_SPEED_SLOW_THRESHOLD_US) {
            return CLI_SPEED_FACTOR_SLOW;
        }
        return 1.0;
    }

    static inline void UpdateCliSpeedFactor(uint64_t now) {
        dispatch_once(&timebase_init_token, ^{
            mach_timebase_info(&timebase_info);
        });
        if (_phtvCliLastKeyDownTime == 0) {
            _phtvCliLastKeyDownTime = now;
            _phtvCliSpeedFactor = 1.0;
            return;
        }
        uint64_t deltaUs = mach_time_to_us(now - _phtvCliLastKeyDownTime);
        _phtvCliLastKeyDownTime = now;
        double target = PHTVComputeCliSpeedFactor(deltaUs);
        if (target >= _phtvCliSpeedFactor) {
            _phtvCliSpeedFactor = target;
        } else {
            _phtvCliSpeedFactor = (_phtvCliSpeedFactor * 0.7) + (target * 0.3);
            if (_phtvCliSpeedFactor < 1.0) {
                _phtvCliSpeedFactor = 1.0;
            }
        }
    }

    static inline useconds_t PHTVScaleCliDelay(useconds_t baseDelay) {
        if (baseDelay == 0) {
            return 0;
        }
        if (_phtvCliSpeedFactor <= 1.05) {
            return baseDelay;
        }
        double scaled = (double)baseDelay * _phtvCliSpeedFactor;
        return PHTVClampUseconds((uint64_t)scaled);
    }

    static inline uint64_t PHTVScaleCliDelay64(uint64_t baseDelay) {
        if (baseDelay == 0) {
            return 0;
        }
        if (_phtvCliSpeedFactor <= 1.05) {
            return baseDelay;
        }
        return (uint64_t)((double)baseDelay * _phtvCliSpeedFactor);
    }

    struct PHTVCliProfile {
        useconds_t backspaceDelayUs;
        useconds_t waitAfterBackspaceUs;
        useconds_t textDelayUs;
        int textChunkSize;
    };

    static const PHTVCliProfile kPHTVCliProfileIDE = {
        CLI_BACKSPACE_DELAY_IDE_US,
        CLI_WAIT_AFTER_BACKSPACE_IDE_US,
        CLI_TEXT_DELAY_IDE_US,
        CLI_TEXT_CHUNK_SIZE_ONE_BY_ONE
    };

    static const PHTVCliProfile kPHTVCliProfileFast = {
        CLI_BACKSPACE_DELAY_FAST_US,
        CLI_WAIT_AFTER_BACKSPACE_FAST_US,
        CLI_TEXT_DELAY_FAST_US,
        CLI_TEXT_CHUNK_SIZE_ONE_BY_ONE
    };

    static const PHTVCliProfile kPHTVCliProfileMedium = {
        CLI_BACKSPACE_DELAY_MEDIUM_US,
        CLI_WAIT_AFTER_BACKSPACE_MEDIUM_US,
        CLI_TEXT_DELAY_MEDIUM_US,
        CLI_TEXT_CHUNK_SIZE_ONE_BY_ONE
    };

    static const PHTVCliProfile kPHTVCliProfileSlow = {
        CLI_BACKSPACE_DELAY_SLOW_US,
        CLI_WAIT_AFTER_BACKSPACE_SLOW_US,
        CLI_TEXT_DELAY_SLOW_US,
        CLI_TEXT_CHUNK_SIZE_ONE_BY_ONE
    };

    static const PHTVCliProfile kPHTVCliProfileDefault = {
        CLI_BACKSPACE_DELAY_DEFAULT_US,
        CLI_WAIT_AFTER_BACKSPACE_DEFAULT_US,
        CLI_TEXT_DELAY_DEFAULT_US,
        CLI_TEXT_CHUNK_SIZE_ONE_BY_ONE
    };

    static inline void ApplyCliProfile(const PHTVCliProfile &profile) {
        _phtvCliBackspaceDelayUs = profile.backspaceDelayUs;
        _phtvCliWaitAfterBackspaceUs = profile.waitAfterBackspaceUs;
        _phtvCliTextDelayUs = profile.textDelayUs;
        _phtvCliTextChunkSize = profile.textChunkSize;
        _phtvCliPostSendBlockUs = (useconds_t)MAX((uint64_t)CLI_POST_SEND_BLOCK_MIN_US,
                                                  (uint64_t)_phtvCliTextDelayUs * 3);
    }

    static inline void ConfigureCliProfile(NSString *bundleId) {
        if ([PHTVAppDetectionService isVSCodeFamilyApp:bundleId] ||
            [PHTVAppDetectionService isJetBrainsApp:bundleId]) {
            ApplyCliProfile(kPHTVCliProfileIDE);
            return;
        }
        if ([PHTVAppDetectionService isFastTerminalApp:bundleId]) {
            ApplyCliProfile(kPHTVCliProfileFast);
            return;
        }
        if ([PHTVAppDetectionService isMediumTerminalApp:bundleId]) {
            ApplyCliProfile(kPHTVCliProfileMedium);
            return;
        }
        if ([PHTVAppDetectionService isSlowTerminalApp:bundleId]) {
            ApplyCliProfile(kPHTVCliProfileSlow);
            return;
        }

        // Default terminal profile
        ApplyCliProfile(kPHTVCliProfileDefault);
    }

    static inline BOOL IsAsciiWhitespace(unichar c) {
        return c == ' ' || c == '\t' || c == '\n' || c == '\r';
    }

    static inline BOOL IsAsciiLetter(unichar c) {
        return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z');
    }

    static inline BOOL IsAsciiDigit(unichar c) {
        return (c >= '0' && c <= '9');
    }

    static inline BOOL IsAsciiClosingPunct(unichar c) {
        return c == '"' || c == '\'' || c == ')' || c == ']' || c == '}';
    }

    static inline BOOL IsAsciiSentenceTerminator(unichar c) {
        return c == '.' || c == '!' || c == '?';
    }

    static inline BOOL IsUppercasePrimeCandidateKey(CGKeyCode keycode, CGEventFlags flags) {
        if ((flags & kCGEventFlagMaskCommand) ||
            (flags & kCGEventFlagMaskControl) ||
            (flags & kCGEventFlagMaskAlternate) ||
            (flags & kCGEventFlagMaskSecondaryFn) ||
            (flags & kCGEventFlagMaskNumericPad) ||
            (flags & kCGEventFlagMaskHelp)) {
            return NO;
        }
        Uint32 keyWithCaps = keycode | (((flags & kCGEventFlagMaskShift) || (flags & kCGEventFlagMaskAlphaShift)) ? CAPS_MASK : 0);
        Uint16 ch = keyCodeToCharacter(keyWithCaps);
        if (ch == 0) {
            return NO;
        }
        if (ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r') {
            return NO;
        }
        return YES;
    }

    static NSSet<NSString *> *UppercaseAbbreviationSet(void) {
        static NSSet<NSString *> *set = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            set = [NSSet setWithArray:@[
                @"mr", @"mrs", @"ms", @"dr", @"prof", @"sr", @"jr", @"st",
                @"vs", @"etc", @"eg", @"ie",
                @"tp", @"q", @"p", @"ths", @"ts", @"gs", @"pgs"
            ]];
        });
        return set;
    }

    static BOOL ShouldPrimeUppercaseFromAX(BOOL *outReliable) {
        if (outReliable) {
            *outReliable = NO;
        }
        if (!vUpperCaseFirstChar || vUpperCaseExcludedForCurrentApp || vSafeMode) {
            return NO;
        }

        AXUIElementRef systemWide = AXUIElementCreateSystemWide();
        AXUIElementRef focusedElement = NULL;
        AXError error = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute, (CFTypeRef *)&focusedElement);
        CFRelease(systemWide);
        if (error != kAXErrorSuccess || focusedElement == NULL) {
            return NO;
        }

        CFTypeRef valueRef = NULL;
        error = AXUIElementCopyAttributeValue(focusedElement, kAXValueAttribute, &valueRef);
        if (error != kAXErrorSuccess) {
            CFRelease(focusedElement);
            return NO;
        }

        if (outReliable) {
            *outReliable = YES;
        }

        NSString *valueStr = @"";
        if (valueRef && CFGetTypeID(valueRef) == CFStringGetTypeID()) {
            valueStr = [(__bridge NSString *)valueRef copy];
        }

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
        if (valueRef) CFRelease(valueRef);
        CFRelease(focusedElement);

        if (caretLocation <= 0) {
            return YES;
        }
        if (caretLocation > (NSInteger)valueStr.length) {
            caretLocation = (NSInteger)valueStr.length;
        }

        NSInteger idx = caretLocation - 1;

        // Skip trailing whitespace
        while (idx >= 0 && IsAsciiWhitespace([valueStr characterAtIndex:idx])) {
            idx--;
        }
        if (idx < 0) {
            return YES;
        }

        // Skip closing punctuation and any whitespace before it
        BOOL progressed = YES;
        while (progressed) {
            progressed = NO;
            while (idx >= 0 && IsAsciiClosingPunct([valueStr characterAtIndex:idx])) {
                idx--;
                progressed = YES;
            }
            while (idx >= 0 && IsAsciiWhitespace([valueStr characterAtIndex:idx])) {
                idx--;
                progressed = YES;
            }
        }
        if (idx < 0) {
            return YES;
        }

        unichar lastChar = [valueStr characterAtIndex:idx];
        if (!IsAsciiSentenceTerminator(lastChar)) {
            return NO;
        }

        if (lastChar != '.') {
            return YES;
        }

        // Dot: check previous token to avoid abbreviations like "Dr." or "tp."
        NSInteger end = idx - 1;
        while (end >= 0 && IsAsciiWhitespace([valueStr characterAtIndex:end])) {
            end--;
        }
        if (end < 0) {
            return NO;
        }

        NSInteger start = end;
        while (start >= 0) {
            unichar c = [valueStr characterAtIndex:start];
            if (IsAsciiLetter(c) || IsAsciiDigit(c)) {
                start--;
                continue;
            }
            break;
        }

        NSRange tokenRange = NSMakeRange(start + 1, end - start);
        if (tokenRange.length == 0) {
            return NO;
        }

        NSString *token = [[valueStr substringWithRange:tokenRange] lowercaseString];

        // Numeric token like "3."
        BOOL allDigits = YES;
        for (NSUInteger i = 0; i < token.length; i++) {
            if (!IsAsciiDigit([token characterAtIndex:i])) {
                allDigits = NO;
                break;
            }
        }
        if (allDigits) {
            return NO;
        }

        if (token.length == 1) {
            return NO;
        }

        if ([UppercaseAbbreviationSet() containsObject:token]) {
            return NO;
        }

        return YES;
    }

    static bool _pendingUppercasePrimeCheck = true;

    __attribute__((always_inline)) static inline void PostSyntheticEvent(CGEventTapProxy proxy, CGEventRef e) {
        CGEventSetIntegerValueField(e, kCGEventSourceUserData, kPHTVEventMarker);
        if (_phtvPostToHIDTap) {
            CGEventPost(kCGHIDEventTap, e);
        } else if (_phtvPostToSessionForCli) {
            CGEventPost(kCGSessionEventTap, e);
        } else {
            CGEventTapPostEvent(proxy, e);
        }
    }

    void ThrottleCliInjection() {
    }

    __attribute__((always_inline)) static inline void ApplyKeyboardTypeAndFlags(CGEventRef down, CGEventRef up) {
        if (_phtvKeyboardType != 0) {
            CGEventSetIntegerValueField(down, kCGKeyboardEventKeyboardType, _phtvKeyboardType);
            CGEventSetIntegerValueField(up, kCGKeyboardEventKeyboardType, _phtvKeyboardType);
        }
        
        // Apply NonCoalesced flag to ALL synthetic events to prevent macOS event merging
        // This is critical for maintaining correct sequence of [Backspace, Text]
        CGEventFlags flags = CGEventGetFlags(down);
        flags |= kCGEventFlagMaskNonCoalesced;
        
        // CRITICAL FIX: Clear Fn/Globe flag to prevent triggering system hotkeys
        flags &= ~kCGEventFlagMaskSecondaryFn;
        
        CGEventSetFlags(down, flags);
        CGEventSetFlags(up, flags);
        CGEventSetIntegerValueField(down, kCGEventSourceUserData, kPHTVEventMarker);
        CGEventSetIntegerValueField(up, kCGEventSourceUserData, kPHTVEventMarker);
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

        BOOL shouldDisable = [PHTVAppDetectionService shouldDisableVietnamese:bundleId];

        // Update cache only when we have a valid PID, to avoid cross-app leakage
        lastResult = shouldDisable;
        lastCheckTime = now;
        lastPid = (cachePid > 0) ? cachePid : -1;

        return shouldDisable;
    }

    // Legacy check (for backward compatibility)
    BOOL shouldDisableVietnamese(NSString* bundleId) {
        return [PHTVAppDetectionService shouldDisableVietnamese:bundleId];
    }

    // Legacy check (for backward compatibility)
    BOOL needsStepByStep(NSString* bundleId) {
        return [PHTVAppDetectionService needsStepByStep:bundleId];
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
    
    std::vector<Uint16> _syncKey;
    
    Uint16 _uniChar[2];
    int _i, _j, _k;
    Uint32 _tempChar;
    bool _hasJustUsedHotKey = false;
    bool _pauseKeyPressed = false;
    int _savedLanguageBeforePause = 1;

    // For restore key detection with modifier keys
    bool _restoreModifierPressed = false;
    bool _keyPressedWithRestoreModifier = false;

    // For switch hotkey exact match - prevent prefix matching
    // (e.g., Cmd+Shift should NOT trigger when user presses Cmd+Shift+S)
    bool _keyPressedWhileSwitchModifiersHeld = false;

    // For emoji hotkey modifier-only mode - prevent prefix matching
    bool _keyPressedWhileEmojiModifiersHeld = false;

    int _languageTemp = 0; //use for smart switch key
    std::vector<Byte> savedSmartSwitchKeyData; ////use for smart switch key
    
    NSString* _frontMostApp = @"UnknownApp";
    
    void PHTVInit() {
        // Initialize logging infrastructure first
        dispatch_once(&log_init_token, ^{
            phtv_log = os_log_create("com.phamhungtien.phtv", "Engine");
        });
        dispatch_once(&timebase_init_token, ^{
            mach_timebase_info(&timebase_info);
        });

        [PHTVCoreSettingsBootstrapService loadFromUserDefaults];

        [PHTVSafeModeStartupService recoverAndValidateAccessibilityState];

        [PHTVLayoutCompatibilityService autoEnableIfNeeded];

        myEventSource = CGEventSourceCreate(kCGEventSourceStatePrivate);
        pData = (vKeyHookState*)vKeyInit();

        // Performance optimization: Pre-allocate _syncKey vector to avoid reallocations
        // Typical typing buffer is ~50 chars, reserve for safety margin
        _syncKey.reserve(SYNC_KEY_RESERVE_SIZE);

        eventBackSpaceDown = CGEventCreateKeyboardEvent (myEventSource, KEY_DELETE, true);
        eventBackSpaceUp = CGEventCreateKeyboardEvent (myEventSource, KEY_DELETE, false);
        
        // Apply NonCoalesced flag to global backspace events
        CGEventSetFlags(eventBackSpaceDown, CGEventGetFlags(eventBackSpaceDown) | kCGEventFlagMaskNonCoalesced);
        CGEventSetFlags(eventBackSpaceUp, CGEventGetFlags(eventBackSpaceUp) | kCGEventFlagMaskNonCoalesced);
        
        [PHTVEngineStartupDataService loadFromUserDefaults];
        [PHTVConvertToolSettingsService loadFromUserDefaults];
    }
    
    static void RequestNewSessionInternal(bool allowUppercasePrime) {
        // Reset AX context caches on new session (often triggered by mouse click/focus change).
        [PHTVAccessibilityService invalidateContextDetectionCaches];

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

        _pendingUppercasePrimeCheck = true;
        if (allowUppercasePrime) {
            BOOL axReliable = NO;
            BOOL shouldPrime = ShouldPrimeUppercaseFromAX(&axReliable);
            if (shouldPrime) {
                vPrimeUpperCaseFirstChar();
                _pendingUppercasePrimeCheck = false;
            }
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

    void RequestNewSession() {
        RequestNewSessionInternal(true);
    }

    NSString* PHTVBuildDateString() {
        return [NSString stringWithUTF8String:__DATE__];
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
    
        // Ensure cache is reasonably fresh (within 10ms - matches Spotlight detection cache policy)
        // isSpotlightActive() is always called before getFocusedAppBundleId() in the hot path
        uint64_t now = mach_absolute_time();
        
        uint64_t lastCheck = [PHTVCacheStateService lastSpotlightCheckTime];
        NSString *cachedBundleId = [PHTVCacheStateService cachedFocusedBundleId];
    
        uint64_t elapsed_ms = mach_time_to_ms(now - lastCheck);
        if (elapsed_ms < SPOTLIGHT_CACHE_DURATION_MS && lastCheck > 0 && cachedBundleId != nil) {
            return cachedBundleId;
        }
    
        // Cache miss or too old - trigger a fresh check via isSpotlightActive.
        isSpotlightActive();
    
        NSString *result = [PHTVCacheStateService cachedFocusedBundleId];
    
        return (result != nil) ? result : FRONT_APP;
    }    
    BOOL containUnicodeCompoundApp(NSString* topApp) {
        // Optimized to use NSSet for O(1) lookup instead of O(n) array iteration
        return [PHTVAppDetectionService containsUnicodeCompound:topApp];
    }
    
    BOOL needsForcePrecomposed(NSString* bundleId) {
        return [PHTVAppDetectionService isSpotlightLikeApp:bundleId];
    }
    
    void saveSmartSwitchKeyData() {
        getSmartSwitchKeySaveData(savedSmartSwitchKeyData);
        NSData* _data = [NSData dataWithBytes:savedSmartSwitchKeyData.data() length:savedSmartSwitchKeyData.size()];
        [PHTVSmartSwitchPersistenceService saveSmartSwitchData:_data];
    }
    
    void OnActiveAppChanged() { //use for smart switch key; improved on Sep 28th, 2019
        if (!vUseSmartSwitchKey && !vRememberCode) {
            return;  // Skip if features disabled - performance optimization
        }

        // Use the optimized focused app bundle ID
        _frontMostApp = getFocusedAppBundleId();

        // CRITICAL: Guard against nil bundleIdentifier during app switching transitions
        if (_frontMostApp == nil) {
            return;  // Skip if no frontmost app - prevents crash on NULL UTF8String
        }

        // CRITICAL FIX: Ignore PHTV's own settings window in smart switch logic
        // This prevents the settings window (which is often excluded/English) from polluting the global language state
        // or overwriting the saved state of the previous app.
        if ([_frontMostApp isEqualToString:PHTV_BUNDLE]) {
            _languageTemp = SMART_SWITCH_NOT_FOUND; // Reset temp value to avoid using state from previous app switch
            return;
        }

        _languageTemp = getAppInputMethodStatus(std::string(_frontMostApp.UTF8String),
                                               encodeSmartSwitchInputState(vLanguage, vCodeTable));

        if (_languageTemp == SMART_SWITCH_NOT_FOUND) {
            saveSmartSwitchKeyData();
            return;
        }

        if (decodeSmartSwitchInputMethod(_languageTemp) != vLanguage) { //for input method
            // PERFORMANCE: Update state directly without triggering callbacks
            // onImputMethodChanged would cause cascading updates
            vLanguage = decodeSmartSwitchInputMethod(_languageTemp);
            [PHTVSmartSwitchPersistenceService saveInputMethod:vLanguage];
            RequestNewSession();  // Direct call, no cascading
            [appDelegate fillData];  // Update UI only

            // Notify SwiftUI (use separate notification for smart switch to avoid sound)
            [[NSNotificationCenter defaultCenter] postNotificationName:@"LanguageChangedFromSmartSwitch"
                                                                object:@(vLanguage)];
        }
        if (vRememberCode && decodeSmartSwitchCodeTable(_languageTemp) != vCodeTable) { //for remember table code feature
            // PERFORMANCE: Update state directly
            vCodeTable = decodeSmartSwitchCodeTable(_languageTemp);
            [PHTVSmartSwitchPersistenceService saveCodeTable:vCodeTable];
            RequestNewSession();
            [appDelegate fillData];
        }
    }
    
    void OnTableCodeChange() {
        onTableCodeChange();  // Update macro state
        if (!vRememberCode) {
            return;  // Skip if disabled
        }

        // PERFORMANCE: Just save the mapping, don't trigger more updates
        _frontMostApp = getFocusedAppBundleId();

        // CRITICAL: Guard against nil bundleIdentifier
        if (_frontMostApp == nil) {
            return;  // Skip if no frontmost app - prevents crash
        }

        // CRITICAL FIX: Ignore PHTV's own settings window.
        // Changing settings shouldn't save the new language for PHTV itself.
        if ([_frontMostApp isEqualToString:PHTV_BUNDLE]) {
            return;
        }

        setAppInputMethodStatus(std::string(_frontMostApp.UTF8String),
                                encodeSmartSwitchInputState(vLanguage, vCodeTable));
        saveSmartSwitchKeyData();
    }
    
    void OnInputMethodChanged() {
        if (!vUseSmartSwitchKey) {
            return;  // Skip if disabled
        }

        // PERFORMANCE: Just save the mapping, don't trigger more updates
        _frontMostApp = getFocusedAppBundleId();

        // CRITICAL: Guard against nil bundleIdentifier
        if (_frontMostApp == nil) {
            return;  // Skip if no frontmost app - prevents crash
        }

        // CRITICAL FIX: Ignore PHTV's own settings window.
        if ([_frontMostApp isEqualToString:PHTV_BUNDLE]) {
            return;
        }

        setAppInputMethodStatus(std::string(_frontMostApp.UTF8String),
                                encodeSmartSwitchInputState(vLanguage, vCodeTable));
        saveSmartSwitchKeyData();
    }
    
    void OnSpellCheckingChanged() {
        vSetCheckSpelling();
    }

    void PHTVSyncSpellCheckingState() {
        OnSpellCheckingChanged();
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
        if ([PHTVAppDetectionService needsNiceSpace:FRONT_APP]) {
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
        
        PostSyntheticEvent(_proxy, eventVkeyDown);
        PostSyntheticEvent(_proxy, eventVkeyUp);
        
        CFRelease(eventVkeyDown);
        CFRelease(eventVkeyUp);
    }

    void SendPhysicalBackspace() {
        if (_phtvPostToHIDTap) {
            CGEventRef bsDown = CGEventCreateKeyboardEvent(myEventSource, KEY_DELETE, true);
            CGEventRef bsUp = CGEventCreateKeyboardEvent(myEventSource, KEY_DELETE, false);
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
            PostSyntheticEvent(_proxy, eventBackSpaceDown);
            PostSyntheticEvent(_proxy, eventBackSpaceUp);
        }
    }

    static inline void ConsumeSyncKeyOnBackspace() {
        if (!IS_DOUBLE_CODE(vCodeTable)) {
            return;
        }
        if (_syncKey.empty()) {
            return;
        }
        if (_syncKey.back() > 1) {
            _syncKey.back()--;
        } else {
            _syncKey.pop_back();
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


    void SendShiftAndLeftArrow() {
        CGEventRef eventVkeyDown = CGEventCreateKeyboardEvent (myEventSource, KEY_LEFT, true);
        CGEventRef eventVkeyUp = CGEventCreateKeyboardEvent (myEventSource, KEY_LEFT, false);
        _privateFlag = CGEventGetFlags(eventVkeyDown);
        _privateFlag |= kCGEventFlagMaskShift;
        CGEventSetFlags(eventVkeyDown, _privateFlag);
        CGEventSetFlags(eventVkeyUp, _privateFlag);
        
        PostSyntheticEvent(_proxy, eventVkeyDown);
        PostSyntheticEvent(_proxy, eventVkeyUp);
        
        if (IS_DOUBLE_CODE(vCodeTable)) { //VNI or Unicode Compound
            if (_syncKey.back() > 1) {
                // PERFORMANCE: Use cached bundle ID instead of querying AX API on every backspace
                NSString *effectiveTarget = _phtvEffectiveTargetBundleId ?: getFocusedAppBundleId();
                if (!(vCodeTable == 3 && containUnicodeCompoundApp(effectiveTarget))) {
                    PostSyntheticEvent(_proxy, eventVkeyDown);
                    PostSyntheticEvent(_proxy, eventVkeyUp);
                }
            }
            _syncKey.pop_back();
        }
        CFRelease(eventVkeyDown);
        CFRelease(eventVkeyUp);
    }

    void SendUnicodeStringChunked(const Uint16* chars, int len, int chunkSize, uint64_t interDelayUs) {
        if (len <= 0 || chars == nullptr) {
            return;
        }
        if (chunkSize < 1) {
            chunkSize = 1;
        }
        uint64_t effectiveDelayUs = interDelayUs;
        if (_phtvIsCliTarget && interDelayUs > 0) {
            effectiveDelayUs = PHTVScaleCliDelay64(interDelayUs);
        }
        if (_phtvIsCliTarget) {
            uint64_t totalBlockUs = PHTVScaleCliDelay64(_phtvCliPostSendBlockUs);
            if (effectiveDelayUs > 0 && len > 1) {
                totalBlockUs += effectiveDelayUs * (uint64_t)(len - 1);
            }
            SetCliBlockForMicroseconds(totalBlockUs);
        }

        for (int i = 0; i < len; i += chunkSize) {
            int chunkLen = len - i;
            if (chunkLen > chunkSize) {
                chunkLen = chunkSize;
            }

            _newEventDown = CGEventCreateKeyboardEvent(myEventSource, 0, true);
            _newEventUp = CGEventCreateKeyboardEvent(myEventSource, 0, false);
            if (_phtvKeyboardType != 0) {
                CGEventSetIntegerValueField(_newEventDown, kCGKeyboardEventKeyboardType, _phtvKeyboardType);
                CGEventSetIntegerValueField(_newEventUp, kCGKeyboardEventKeyboardType, _phtvKeyboardType);
            }
            CGEventFlags flags = CGEventGetFlags(_newEventDown) | kCGEventFlagMaskNonCoalesced;
            flags &= ~kCGEventFlagMaskSecondaryFn;
            CGEventSetFlags(_newEventDown, flags);
            CGEventSetFlags(_newEventUp, flags);
            CGEventKeyboardSetUnicodeString(_newEventDown, chunkLen, chars + i);
            CGEventKeyboardSetUnicodeString(_newEventUp, chunkLen, chars + i);
            PostSyntheticEvent(_proxy, _newEventDown);
            PostSyntheticEvent(_proxy, _newEventUp);
            CFRelease(_newEventDown);
            CFRelease(_newEventUp);
            if (effectiveDelayUs > 0 && (i + chunkSize) < len) {
                useconds_t sleepUs = PHTVClampUseconds(effectiveDelayUs);
                usleep(sleepUs);
            }
        }

        if (_phtvIsCliTarget) {
            uint64_t totalBlockUs = PHTVScaleCliDelay64(_phtvCliPostSendBlockUs);
            if (effectiveDelayUs > 0 && len > 1) {
                totalBlockUs += effectiveDelayUs * (uint64_t)(len - 1);
            }
            SetCliBlockForMicroseconds(totalBlockUs);
        }
    }

    // Consolidated helper function to send multiple backspaces
    // Delays and throttling removed for standard application behavior
    void SendBackspaceSequenceWithDelay(int count, DelayType delayType) {
        if (count <= 0) return;

        if (_phtvIsCliTarget) {
            useconds_t backspaceDelay = PHTVScaleCliDelay(_phtvCliBackspaceDelayUs);
            useconds_t waitDelay = PHTVScaleCliDelay(_phtvCliWaitAfterBackspaceUs);
            uint64_t totalBlockUs = PHTVScaleCliDelay64(_phtvCliPostSendBlockUs);
            if (backspaceDelay > 0 && count > 0) {
                totalBlockUs += (uint64_t)backspaceDelay * (uint64_t)count;
            }
            totalBlockUs += (uint64_t)waitDelay;
            SetCliBlockForMicroseconds(totalBlockUs);
            if (_phtvCliSpeedFactor > 1.05) {
                useconds_t preDelay = PHTVScaleCliDelay(CLI_PRE_BACKSPACE_DELAY_US);
                if (preDelay > 0) {
                    usleep(preDelay);
                }
            }
            for (int i = 0; i < count; i++) {
                SendPhysicalBackspace();
                ConsumeSyncKeyOnBackspace();
                if (backspaceDelay > 0) {
                    usleep(backspaceDelay);
                }
            }
            if (waitDelay > 0) {
                usleep(waitDelay);
            }
            SetCliBlockForMicroseconds(totalBlockUs);
            return;
        }

        // Always use standard backspace method
        for (int i = 0; i < count; i++) {
            SendBackspace();
        }
    }

    void SendCutKey() {
        CGEventRef eventVkeyDown = CGEventCreateKeyboardEvent (myEventSource, KEY_X, true);
        CGEventRef eventVkeyUp = CGEventCreateKeyboardEvent (myEventSource, KEY_X, false);
        _privateFlag = CGEventGetFlags(eventVkeyDown);
        _privateFlag |= NX_COMMANDMASK;
        CGEventSetFlags(eventVkeyDown, _privateFlag);
        CGEventSetFlags(eventVkeyUp, _privateFlag);
        
        PostSyntheticEvent(_proxy, eventVkeyDown);
        PostSyntheticEvent(_proxy, eventVkeyUp);
        
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

            BOOL shouldVerify = (backspaceCount > 0);
            BOOL axSucceeded = vSafeMode ? NO : [PHTVAccessibilityService replaceFocusedTextViaAX:backspaceCount
                                                                                        insertText:insertStr
                                                                                            verify:shouldVerify];
            if (axSucceeded) {
                goto FinalizeSend;
            }

            // AX failed - fallback to synthetic events
            SendBackspaceSequenceWithDelay(backspaceCount, DelayTypeNone);

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
            goto FinalizeSend;
        } else {
            if (_phtvIsCliTarget) {
                int chunkSize = (_phtvCliTextChunkSize > 0) ? _phtvCliTextChunkSize : CLI_TEXT_CHUNK_SIZE_ONE_BY_ONE;
                SendUnicodeStringChunked(_finalCharString, _finalCharSize, chunkSize, _phtvCliTextDelayUs);
                goto FinalizeSend;
            }
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

    FinalizeSend:
        if (_willContinuteSending) {
            SendNewCharString(dataFromMacro, dataFromMacro ? _k : 16);
        }
        
        //the case when hCode is vRestore or vRestoreAndStartNewSession, the word is invalid and last key is control key such as TAB, LEFT ARROW, RIGHT ARROW,...
        if (_willSendControlKey) {
            SendKeyCode(_keycode);
        }
    }
            
    static inline bool checkHotKeyWithFlags(int hotKeyData, bool checkKeyCode, CGEventFlags flags, CGKeyCode keycode) {
        return [PHTVHotkeyService checkHotKey:(int32_t)hotKeyData
                                 checkKeyCode:checkKeyCode
                               currentKeycode:(uint16_t)keycode
                                  currentFlags:(uint64_t)flags];
    }

    bool checkHotKey(int hotKeyData, bool checkKeyCode=true) {
        return checkHotKeyWithFlags(hotKeyData, checkKeyCode, _lastFlag, _keycode);
    }

    // Check if ALL modifier keys required by a hotkey are currently held
    // This is used to detect if user is in the process of pressing a modifier combo
    // Returns true if current flags CONTAIN all required modifiers (may have extra modifiers)
    bool hotkeyModifiersAreHeld(int hotKeyData, CGEventFlags currentFlags) {
        return [PHTVHotkeyService hotkeyModifiersAreHeld:(int32_t)hotKeyData
                                            currentFlags:(uint64_t)currentFlags];
    }

    // Check if this is a modifier-only hotkey (no specific key required, keycode = 0xFE)
    bool isModifierOnlyHotkey(int hotKeyData) {
        return [PHTVHotkeyService isModifierOnlyHotkey:(int32_t)hotKeyData];
    }

    void switchLanguage() {
        // Beep is now handled by SwiftUI when LanguageChangedFromBackend notification is posted

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
            BOOL shouldVerify = (pData->backspaceCount > 0);
            BOOL axSucceeded = vSafeMode ? NO : [PHTVAccessibilityService replaceFocusedTextViaAX:pData->backspaceCount
                                                                                        insertText:macroString
                                                                                            verify:shouldVerify];
            if (axSucceeded) {
                #ifdef DEBUG
                NSLog(@"[Macro] Spotlight: AX API succeeded, macro='%@'", macroString);
                #endif
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

        // Send backspace if needed
        if (pData->backspaceCount > 0) {
            SendBackspaceSequenceWithDelay(pData->backspaceCount, DelayTypeNone);
        }

        //send real data - use step by step for timing sensitive apps like Spotlight
        BOOL useStepByStep = _phtvIsCliTarget || vSendKeyStepByStep || needsStepByStep(effectiveTarget);
        if (!useStepByStep) {
            SendNewCharString(true);
        } else {
            useconds_t cliTextDelay = 0;
            if (_phtvIsCliTarget) {
                cliTextDelay = PHTVScaleCliDelay(_phtvCliTextDelayUs);
            }
            for (int i = 0; i < pData->macroData.size(); i++) {
                if (pData->macroData[i] & PURE_CHARACTER_MASK) {
                    SendPureCharacter(pData->macroData[i]);
                } else {
                    SendKeyCode(pData->macroData[i]);
                }
                if (cliTextDelay > 0 && i + 1 < pData->macroData.size()) {
                    usleep(cliTextDelay);
                }
            }
            if (_phtvIsCliTarget && pData->macroData.size() > 0) {
                uint64_t totalBlockUs = PHTVScaleCliDelay64(_phtvCliPostSendBlockUs);
                if (cliTextDelay > 0 && pData->macroData.size() > 1) {
                    totalBlockUs += (uint64_t)cliTextDelay * (uint64_t)(pData->macroData.size() - 1);
                }
                SetCliBlockForMicroseconds(totalBlockUs);
            }
        }

        // Send trigger key for non-Spotlight apps
        if (!isSpotlightLike) {
            SendKeyCode(_keycode | (_flag & kCGEventFlagMaskShift ? CAPS_MASK : 0));
        }
    }

    extern "C" void InvalidateLayoutCache() {
        [PHTVHotkeyService invalidateLayoutCache];
    }

    CGKeyCode ConvertEventToKeyboardLayoutCompatKeyCode(CGEventRef keyEvent, CGKeyCode fallbackKeyCode) {
        return (CGKeyCode)[PHTVHotkeyService convertEventToKeyboardLayoutCompatKeyCode:keyEvent
                                                                               fallback:(uint16_t)fallbackKeyCode];
    }

    static inline CGEventFlags RelevantEmojiModifierFlags(CGEventFlags flags) {
        return flags & (kCGEventFlagMaskCommand |
                        kCGEventFlagMaskAlternate |
                        kCGEventFlagMaskControl |
                        kCGEventFlagMaskShift |
                        kCGEventFlagMaskSecondaryFn);
    }

    static inline bool isEmojiModifierOnlyHotkey() {
        return !HOTKEY_RAW_KEY_HAS_KEY(vEmojiHotkeyKeyCode);
    }

    // Check if ALL emoji hotkey modifiers are currently held
    static inline bool emojiHotkeyModifiersAreHeld(CGEventFlags currentFlags) {
        CGEventFlags expected = RelevantEmojiModifierFlags((CGEventFlags)vEmojiHotkeyModifiers);
        if (expected == 0) return false;
        CGEventFlags current = RelevantEmojiModifierFlags(currentFlags);
        return (current & expected) == expected;
    }

    static inline BOOL CheckEmojiHotkey(CGKeyCode keycode, CGEventFlags flags) {
        if (!vEnableEmojiHotkey) return NO;
        // Skip modifier-only emoji hotkeys here (handled in flagsChanged)
        if (isEmojiModifierOnlyHotkey()) return NO;
        if ((CGKeyCode)vEmojiHotkeyKeyCode != keycode) return NO;

        // Require at least one modifier for key+modifier combos
        CGEventFlags expectedModifiers = RelevantEmojiModifierFlags((CGEventFlags)vEmojiHotkeyModifiers);
        if (expectedModifiers == 0) return NO;
        return RelevantEmojiModifierFlags(flags) == expectedModifiers;
    }

    // Handle hotkey press (switch language / convert tool / emoji picker)
    // Returns NULL if hotkey was triggered (consuming the event), otherwise returns the original event
    static inline CGEventRef HandleHotkeyPress(CGEventType type, CGKeyCode keycode) {
        if (type != kCGEventKeyDown) return NULL;

        BOOL switchHotkeyHasKey = HOTKEY_HAS_KEY(vSwitchKeyStatus);
        BOOL convertHotkeyHasKey = HOTKEY_HAS_KEY(gConvertToolOptions.hotKey);
        BOOL isSwitchHotkeyKey = switchHotkeyHasKey && HOTKEY_KEY_MATCHES(vSwitchKeyStatus, keycode);
        BOOL isConvertHotkeyKey = convertHotkeyHasKey && HOTKEY_KEY_MATCHES(gConvertToolOptions.hotKey, keycode);
        BOOL isEmojiHotkeyKey = vEnableEmojiHotkey && ((CGKeyCode)vEmojiHotkeyKeyCode == keycode);

        // OpenKey style: clear stale modifier tracking on unrelated key presses.
        if (!isSwitchHotkeyKey && !isConvertHotkeyKey && !isEmojiHotkeyKey) {
            _lastFlag = 0;
            _hasJustUsedHotKey = false;
            return NULL;
        }

        // Check switch language hotkey
        if (isSwitchHotkeyKey &&
            (checkHotKey(vSwitchKeyStatus, true) ||
             checkHotKeyWithFlags(vSwitchKeyStatus, true, _flag, keycode))) {
            switchLanguage();
            _lastFlag = 0;
            _hasJustUsedHotKey = true;
            return (CGEventRef)-1;  // Special marker to indicate "consume event"
        }

        // Check convert tool hotkey
        if (isConvertHotkeyKey &&
            (checkHotKey(gConvertToolOptions.hotKey, true) ||
             checkHotKeyWithFlags(gConvertToolOptions.hotKey, true, _flag, keycode))) {
            [appDelegate onQuickConvert];
            _lastFlag = 0;
            _hasJustUsedHotKey = true;
            return (CGEventRef)-1;  // Special marker to indicate "consume event"
        }

        // Check emoji picker hotkey
        if (isEmojiHotkeyKey && CheckEmojiHotkey(keycode, _flag)) {
            [appDelegate onEmojiHotkeyTriggered];
            _lastFlag = 0;
            _hasJustUsedHotKey = true;
            return (CGEventRef)-1;  // Special marker to indicate "consume event"
        }

        // Only mark as used hotkey if we had modifiers pressed
        _hasJustUsedHotKey = _lastFlag != 0;
        return NULL;
    }

    static inline CGEventFlags PauseModifierMaskForKeyCode(int pauseKey) {
        switch (pauseKey) {
            case KEY_LEFT_OPTION:
            case KEY_RIGHT_OPTION:
                return kCGEventFlagMaskAlternate;
            case KEY_LEFT_CONTROL:
            case KEY_RIGHT_CONTROL:
                return kCGEventFlagMaskControl;
            case KEY_LEFT_SHIFT:
            case KEY_RIGHT_SHIFT:
                return kCGEventFlagMaskShift;
            case KEY_LEFT_COMMAND:
            case KEY_RIGHT_COMMAND:
                return kCGEventFlagMaskCommand;
            case KEY_FUNCTION:
                return kCGEventFlagMaskSecondaryFn;
            default:
                return 0;
        }
    }

    static inline CGEventFlags PauseKeyModifierMask(void) {
        return PauseModifierMaskForKeyCode(vPauseKey);
    }

    // Strip pause modifier from event flags to prevent special characters
    static inline CGEventFlags StripPauseModifier(CGEventFlags flags) {
        CGEventFlags pauseMask = PauseKeyModifierMask();
        if (pauseMask == 0) {
            return flags;
        }
        return flags & ~pauseMask;
    }

    // Handle pause key press - temporarily disable Vietnamese input
    static inline void HandlePauseKeyPress(CGEventFlags flags) {
        if (_pauseKeyPressed || !vPauseKeyEnabled || vPauseKey <= 0) {
            return;
        }

        CGEventFlags pauseMask = PauseKeyModifierMask();
        if (pauseMask == 0 || (flags & pauseMask) == 0) {
            return;
        }

        _savedLanguageBeforePause = vLanguage;
        if (vLanguage == 1) {
            vLanguage = 0;
        }
        _pauseKeyPressed = true;
    }

    // Handle pause key release - restore Vietnamese input
    static inline void HandlePauseKeyRelease(CGEventFlags oldFlags, CGEventFlags newFlags) {
        if (!_pauseKeyPressed) {
            return;
        }

        CGEventFlags pauseMask = PauseKeyModifierMask();
        if (pauseMask == 0) {
            return;
        }

        BOOL wasPressed = (oldFlags & pauseMask) != 0;
        BOOL isPressed = (newFlags & pauseMask) != 0;
        if (!isPressed && wasPressed) {
            vLanguage = _savedLanguageBeforePause;
            _pauseKeyPressed = false;
        }
    }

    // Handle Spotlight cache invalidation on Cmd+Space and modifier changes
    // This ensures fast Spotlight detection
    static inline void HandleSpotlightCacheInvalidation(CGEventType type, CGKeyCode keycode, CGEventFlags flag) {
        [PHTVSpotlightDetectionService handleSpotlightCacheInvalidation:type keycode:keycode flags:flag];
    }

    // Event tap health monitoring - checks tap status and recovers if needed
    // Returns YES if tap is healthy, NO if recovery was attempted
    static inline BOOL CheckAndRecoverEventTap(CGEventType type) {
        if (__builtin_expect(type != kCGEventKeyDown, 1)) {
            return YES;
        }
        // BROWSER FIX: More aggressive health check for faster recovery
        // Reduced intervals to catch tap disable within 5-10 keystrokes instead of 15-50
        // Smart skip: after 1000 healthy checks, reduce frequency to save CPU
        static NSUInteger eventCounter = 0;
        static NSUInteger recoveryCounter = 0;
        static NSUInteger healthyCounter = 0;

        // Balanced checking for responsiveness vs CPU usage
        // 25 events when recovering/initial, 50 when stable
        NSUInteger checkInterval = (healthyCounter > 2000) ? 50 : 25;

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

        // CLI stabilization: block briefly after synthetic injection to avoid interleaving
        if (type == kCGEventKeyDown && _phtvCliBlockUntil != 0) {
            dispatch_once(&timebase_init_token, ^{
                mach_timebase_info(&timebase_info);
            });
            uint64_t now = mach_absolute_time();
            if (now < _phtvCliBlockUntil) {
                uint64_t remainUs = mach_time_to_us(_phtvCliBlockUntil - now);
                if (remainUs > 0) {
                    usleep(PHTVClampUseconds(remainUs));
                }
            }
        }

        // Auto-recover when macOS temporarily disables the event tap
        if (__builtin_expect(type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput, 0)) {
            [PHTVManager handleEventTapDisabled:type];
            return event;
        }

        // REMOVED: Permission checking in callback - causes kernel deadlock
        // Permission is now checked ONLY via test event tap creation in timer (safe approach)

        // Perform periodic health check and recovery
        CheckAndRecoverEventTap(type);

        // Skip events injected by PHTV itself (marker-based)
        if (CGEventGetIntegerValueField(event, kCGEventSourceUserData) == kPHTVEventMarker) {
            return event;
        }

        //dont handle my event
        if (CGEventGetIntegerValueField(event, kCGEventSourceStateID) == CGEventSourceGetSourceStateID(myEventSource)) {
            return event;
        }

        _phtvPostToSessionForCli = NO;
        _phtvIsCliTarget = NO;
        _flag = CGEventGetFlags(event);
        _keycode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);

        // TEXT REPLACEMENT DETECTION: Track external delete events (only if fix enabled)
        // When macOS Text Replacement is triggered (e.g., "ko" -> "không"),
        // macOS sends synthetic delete events that we didn't generate
        // We track these to avoid duplicate characters when SendEmptyCharacter() is called
        if (IsTextReplacementFixEnabled() && type == kCGEventKeyDown && _keycode == KEY_DELETE) {
            // This is an external delete event (not from PHTV since we already filtered myEventSource)
            [PHTVSpotlightDetectionService trackExternalDelete];
#ifdef DEBUG
            NSLog(@"[TextReplacement] External DELETE detected");
#endif
        }

        // Also track space after deletes to detect text replacement pattern (only if fix enabled)
        if (IsTextReplacementFixEnabled() && type == kCGEventKeyDown && _keycode == KEY_SPACE) {
#ifdef DEBUG
            int externalDeleteCount = (int)[PHTVSpotlightDetectionService externalDeleteCountValue];
            unsigned long long elapsed_ms = [PHTVSpotlightDetectionService elapsedSinceLastExternalDeleteMs];
            NSLog(@"[TextReplacement] SPACE key pressed: deleteCount=%d, elapsedMs=%llu, sourceID=%lld",
                  externalDeleteCount, elapsed_ms,
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
            const CGEventFlags pauseModifierMask = PauseKeyModifierMask();
            if (pauseModifierMask != 0) {
                otherModifiers &= ~pauseModifierMask;
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
           _keycode = ConvertEventToKeyboardLayoutCompatKeyCode(event, _keycode);
        }
        
        //switch language shortcut; convert hotkey
        CGEventRef hotkeyResult = HandleHotkeyPress(type, _keycode);
        if (hotkeyResult == (CGEventRef)-1) {
            return NULL;  // Hotkey was triggered, consume event
        }

        if (type == kCGEventKeyDown) {
            if (vUpperCaseFirstChar && !vUpperCaseExcludedForCurrentApp) {
                bool hasFocusModifiers = (_flag & (kCGEventFlagMaskCommand |
                                                   kCGEventFlagMaskControl |
                                                   kCGEventFlagMaskAlternate |
                                                   kCGEventFlagMaskSecondaryFn |
                                                   kCGEventFlagMaskNumericPad |
                                                   kCGEventFlagMaskHelp)) != 0;
                if (hasFocusModifiers ||
                    _keycode == KEY_TAB ||
                    phtv_mac_key_is_navigation(_keycode)) {
                    _pendingUppercasePrimeCheck = true;
                }
                if (_pendingUppercasePrimeCheck && IsUppercasePrimeCandidateKey(_keycode, _flag)) {
                    BOOL axReliable = NO;
                    BOOL shouldPrime = ShouldPrimeUppercaseFromAX(&axReliable);
                    if (shouldPrime) {
                        vPrimeUpperCaseFirstChar();
                    }
                    _pendingUppercasePrimeCheck = false;
                }
            }

            // Track if any key is pressed while restore modifier is held
            // Only track if custom restore key is actually set (Option or Control)
            if (vRestoreOnEscape && vCustomEscapeKey > 0 && _restoreModifierPressed) {
                _keyPressedWithRestoreModifier = true;
            }

            // Track if any key is pressed while switch hotkey modifiers are held
            // This prevents modifier-only hotkeys (like Cmd+Shift) from triggering
            // when user presses a key combo like Cmd+Shift+S
            bool switchIsModifierOnly = isModifierOnlyHotkey(vSwitchKeyStatus);
            bool convertIsModifierOnly = isModifierOnlyHotkey(gConvertToolOptions.hotKey);
            if (switchIsModifierOnly || convertIsModifierOnly) {
                bool switchModifiersHeld = switchIsModifierOnly && hotkeyModifiersAreHeld(vSwitchKeyStatus, _flag);
                bool convertModifiersHeld = convertIsModifierOnly && hotkeyModifiersAreHeld(gConvertToolOptions.hotKey, _flag);
                if (switchModifiersHeld || convertModifiersHeld) {
                    _keyPressedWhileSwitchModifiersHeld = true;
                }
            }

            // Track key presses for emoji modifier-only hotkey
            if (vEnableEmojiHotkey && isEmojiModifierOnlyHotkey() && emojiHotkeyModifiersAreHeld(_flag)) {
                _keyPressedWhileEmojiModifiersHeld = true;
            }
        } else if (type == kCGEventFlagsChanged) {
            if (_lastFlag == 0 || _lastFlag < _flag) {
                // Pressing more modifiers
                _lastFlag = _flag;

                // Reset modifier tracking when modifiers change (user starting a new combo)
                _keyPressedWhileSwitchModifiersHeld = false;
                _keyPressedWhileEmojiModifiersHeld = false;

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
                                                // Send backspaces to delete Vietnamese characters
                                                if (pData->backspaceCount > 0 && pData->backspaceCount < MAX_BUFF) {
                                                    SendBackspaceSequenceWithDelay(pData->backspaceCount, DelayTypeNone);
                                                }
                        
                                                // Send the raw ASCII characters
                                                SendNewCharString();
                        
                                                _lastFlag = 0;
                                                _restoreModifierPressed = false;
                                                _keyPressedWithRestoreModifier = false;
                                                return NULL;
                                            }                        _restoreModifierPressed = false;
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
                if (canTriggerSwitch && checkHotKey(vSwitchKeyStatus, HOTKEY_HAS_KEY(vSwitchKeyStatus))) {
                    _lastFlag = 0;
                    _keyPressedWhileSwitchModifiersHeld = false;
                    switchLanguage();
                    _hasJustUsedHotKey = true;
                    return NULL;
                }

                // Check convert tool hotkey with same exact match logic
                bool convertIsModifierOnly = isModifierOnlyHotkey(gConvertToolOptions.hotKey);
                bool canTriggerConvert = !convertIsModifierOnly || !_keyPressedWhileSwitchModifiersHeld;
                if (canTriggerConvert && checkHotKey(gConvertToolOptions.hotKey, HOTKEY_HAS_KEY(gConvertToolOptions.hotKey))) {
                    _lastFlag = 0;
                    _keyPressedWhileSwitchModifiersHeld = false;
                    [appDelegate onQuickConvert];
                    _hasJustUsedHotKey = true;
                    return NULL;
                }

                // Check emoji picker modifier-only hotkey
                if (vEnableEmojiHotkey && isEmojiModifierOnlyHotkey() && !_keyPressedWhileEmojiModifiersHeld) {
                    CGEventFlags expectedEmoji = RelevantEmojiModifierFlags((CGEventFlags)vEmojiHotkeyModifiers);
                    CGEventFlags lastEmoji = RelevantEmojiModifierFlags(_lastFlag);
                    if (expectedEmoji != 0 && lastEmoji == expectedEmoji) {
                        _lastFlag = 0;
                        _keyPressedWhileEmojiModifiersHeld = false;
                        [appDelegate onEmojiHotkeyTriggered];
                        _hasJustUsedHotKey = true;
                        return NULL;
                    }
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
                _keyPressedWhileEmojiModifiersHeld = false;
                _hasJustUsedHotKey = false;
            }
        }

        // Also check correct event hooked
        if ((type != kCGEventKeyDown) && (type != kCGEventKeyUp) &&
            (type != kCGEventLeftMouseDown) && (type != kCGEventRightMouseDown))
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
        if (type == kCGEventLeftMouseDown || type == kCGEventRightMouseDown) {
            RequestNewSessionInternal(true);
            
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
            
            // Determine if target is a browser for later logic
            BOOL isTargetBrowser = (eventTargetBundleId != nil && [PHTVAppDetectionService isBrowserApp:eventTargetBundleId]);
            
            // Check if Spotlight is active.
            // Note: We MUST check this even if target is a browser, because Spotlight can be invoked OVER a browser.
            // Spotlight detection service handles performance/caching to avoid lag.
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
            BOOL isBrowser = isTargetBrowser || [PHTVAppDetectionService isBrowserApp:effectiveBundleId];
            _phtvPostToHIDTap = (!isBrowser && spotlightActive) || appChars.isSpotlightLike;
            BOOL isTerminalApp = [PHTVAppDetectionService isTerminalApp:effectiveBundleId];
            BOOL isJetBrainsApp = [PHTVAppDetectionService isJetBrainsApp:effectiveBundleId];
            BOOL isTerminalPanel = NO;
            if (!isTerminalApp && !isJetBrainsApp) {
                isTerminalPanel = vSafeMode ? NO : [PHTVAccessibilityService isTerminalPanelFocused];
            }
            // Best-effort: Force CLI mode for all JetBrains apps to avoid terminal swallowing
            _phtvIsCliTarget = (isTerminalApp || isTerminalPanel || isJetBrainsApp);
            _phtvPostToSessionForCli = _phtvIsCliTarget;
            if (_phtvIsCliTarget) {
                ConfigureCliProfile(effectiveBundleId);
            } else {
                _phtvCliBackspaceDelayUs = 0;
                _phtvCliWaitAfterBackspaceUs = 0;
                _phtvCliTextDelayUs = 0;
                _phtvCliTextChunkSize = CLI_TEXT_CHUNK_SIZE_DEFAULT;
            }
            if (_phtvIsCliTarget) {
                uint64_t now = mach_absolute_time();
                UpdateCliSpeedFactor(now);
            } else {
                _phtvCliSpeedFactor = 1.0;
                _phtvCliLastKeyDownTime = 0;
            }

            _phtvKeyboardType = CGEventGetIntegerValueField(event, kCGKeyboardEventKeyboardType);
            _phtvPendingBackspaceCount = 0;
            _phtvCliPendingBackspaceCount = 0;

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
            if (currentCodeTable == 3 &&
                (spotlightActive || appChars.isSpotlightLike)) {
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
                if (phtv_mac_key_is_navigation(_keycode)) {
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
                                PostSyntheticEvent(_proxy, eventBackSpaceDown);
                                PostSyntheticEvent(_proxy, eventBackSpaceUp);
                            }
                            _syncKey.pop_back();
                        }
                       
                    } else if (pData->extCode == 3) { //normal key
                        InsertKeyLength(1);
                    }
                }
                return event;
            } else if (pData->code == vWillProcess || pData->code == vRestore || pData->code == vRestoreAndStartNewSession) { //handle result signal
                // FIGMA FIX: Force pass-through for Space key to support "Hand tool" (Hold Space)
                // When PHTV consumes Space and sends a synthetic one, it breaks the "hold" state.
                if (_keycode == KEY_SPACE && pData->backspaceCount == 0 && pData->newCharCount == 1 && [effectiveBundleId isEqualToString:@"com.figma.Desktop"]) {
                    return event;
                }

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
                BOOL isBrowserApp = [PHTVAppDetectionService isBrowserApp:effectiveBundleId];
                
                // Check if this is a special app (Spotlight-like or WhatsApp-like)
                // Also treat as special when spotlightActive (search field detected via AX API)
                // EXCEPT for browsers - they don't support AX API for autocomplete, so ignore spotlightActive for them
                BOOL isSpecialApp = (!isBrowserApp && spotlightActive) || appChars.isSpotlightLike || appChars.needsPrecomposedBatched;

                // BROWSER SHORTCUT FIX: Avoid sending empty character for common shortcut prefixes (like /)
                // or when a new session just started without any previous context.
                // This prevents browsers from deleting the shortcut token (e.g., "/p") 
                // when PHTV tries to break the autocomplete.
                BOOL isPotentialShortcut = (_keycode == KEY_SLASH);
                
                // fix autocomplete - Unified browser fix strategy
                // CRITICAL FIX: NEVER send empty character for SPACE key!
                
                // REFINED HYBRID STRATEGY (Final Safety Fix):
                // 1. Browsers (Content/Sheets): Default to Simple Backspace.
                //    - SAFE: No 'Shift+Left' (prevents selection errors in Sheets).
                //    - SAFE: No 'SendEmptyCharacter' (prevents "iệt Nam" deletion bug).
                // 2. Browsers (Address Bar): Use 'Shift+Left' ONLY if detected (isFocusedElementAddressBar).
                //    - FIX: Breaks autocomplete suggestions to prevent "dđ", "chaào".
                
                BOOL isBrowserFix = vFixRecommendBrowser && isBrowserApp;
                
                // Allow Browser Fix for KEY_SPACE if there is backspace count (restoring word)
                // This fixes "play" -> "pplay" bug where standard backspace fails in address bar on Space key
                BOOL isSpaceRestore = (_keycode == KEY_SPACE && pData->backspaceCount > 0);
                BOOL shouldSkipSpace = (_keycode == KEY_SPACE && !isSpaceRestore);
                
                #ifdef DEBUG
                // Always log browser fix status to debug why it might be skipped
                NSLog(@"[BrowserFix] Status: vFix=%d, app=%@, isBrowser=%d => isFix=%d | bs=%d, ext=%d", 
                      vFixRecommendBrowser, effectiveBundleId, isBrowserApp, isBrowserFix, 
                      (int)pData->backspaceCount, pData->extCode);
                
                if (isBrowserFix && pData->backspaceCount > 0) {
                    NSLog(@"[BrowserFix] Checking logic: fix=%d, ext=%d, special=%d, skipSp=%d, shortcut=%d, bs=%d", 
                          isBrowserFix, pData->extCode, isSpecialApp, shouldSkipSpace, isPotentialShortcut, (int)pData->backspaceCount);
                }
                #endif

                if (isBrowserFix && pData->extCode != 4 && !isSpecialApp && !shouldSkipSpace && !isPotentialShortcut) {
                    if (pData->backspaceCount > 0) {
                        // DETECT ADDRESS BAR:
                        // Use accurate AX API check (cached) instead of unreliable spotlightActive
                        BOOL isAddrBar = vSafeMode ? NO : [PHTVAccessibilityService isFocusedElementAddressBar];
                        
                        #ifdef DEBUG
                        NSLog(@"[BrowserFix] isFocusedElementAddressBar returned: %d", isAddrBar);
                        #endif

                        if (isAddrBar) {
#ifdef DEBUG
                            NSLog(@"[PHTV Browser] Address Bar Detected (AX) -> Using SendEmptyCharacter (Fix Doubling)");
#endif
                            // Revert to SendEmptyCharacter strategy for Address Bar (like v1.7.6)
                            // This fixes the "doubling first character" bug where Shift+Left fails
                            // in some browser profiles/contexts (especially on first char).
                            // SendEmptyCharacter reliably breaks the autocomplete state.
                            SendEmptyCharacter();
                            pData->backspaceCount++;
                            
                            // Note: We do NOT consume backspaces here. We let the standard logic below
                            // handle the actual backspacing. This ensures:
                            // 1. Empty char is sent.
                            // 2. Standard backspace sequence runs: deletes Empty char, then deletes original chars.
                        } else {
                            // Content Mode (Sheets, Docs, Forms)
                            // Do nothing here, let standard SendBackspaceSequence handle it below.
                            // Standard Backspace is the safest method for web editors.
                        }
                    }
                    // CRITICAL: Force fall through to standard backspace logic below.
                } 
                else if (vFixRecommendBrowser && pData->extCode != 4 && (!isSpecialApp || [effectiveBundleId isEqualToString:@"notion.id"]) && _keycode != KEY_SPACE &&
                         !isPotentialShortcut && !isBrowserApp) {
                    // Legacy logic for non-browser apps (Electron, Slack, etc.)
                    // Keep original behavior: shift-left for Chromium, EmptyChar for others
                    BOOL useShiftLeft = appChars.containsUnicodeCompound && pData->backspaceCount > 0;
                    
                    // NOTION CODE BLOCK FIX:
                    // If Notion Code Block detected, fallback to standard backspace (no Shift+Left, no EmptyChar)
                    // This fixes duplicates in code blocks where Shift+Left might fail to select or text is raw
                    BOOL isNotionCodeBlockDetected = [effectiveBundleId isEqualToString:@"notion.id"] &&
                                                     !vSafeMode &&
                                                     [PHTVAccessibilityService isNotionCodeBlock];

                    if (isNotionCodeBlockDetected) {
                        // Do nothing here.
                        // Falls through to SendBackspaceSequence below (Standard Backspace)
                        #ifdef DEBUG
                        NSLog(@"[Notion] Code Block detected - using Standard Backspace");
                        #endif
                    }
                    else if (useShiftLeft) {
                        SendShiftAndLeftArrow();
                        SendPhysicalBackspace();
                        pData->backspaceCount--;
                    } else {
                        SendEmptyCharacter();
                        pData->backspaceCount++;
                    }
                }

                // SAFETY LIMIT: A single Vietnamese word transformation should never delete more than 15 chars.
                // This prevents massive text loss ("iệt Nam" bug) if logic fails or race conditions occur.
                if (pData->backspaceCount > 15) {
#ifdef DEBUG
                    NSLog(@"[PHTV Safety] Blocked excessive backspaceCount: %d -> 15 (Key=%d)", (int)pData->backspaceCount, _keycode);
#endif
                    pData->backspaceCount = 15;
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
                BOOL textReplacementFixEnabled = IsTextReplacementFixEnabled();
                int externalDeleteCount = 0;
                if (textReplacementFixEnabled) {
                    externalDeleteCount = (int)[PHTVSpotlightDetectionService externalDeleteCountValue];
                }

                // Log for debugging text replacement issues (only in Debug builds)
                #ifdef DEBUG
                if (textReplacementFixEnabled &&
                    (pData->backspaceCount > 0 || pData->newCharCount > 0)) {
                    NSLog(@"[PHTV TextReplacement] Key=%d: code=%d, extCode=%d, backspace=%d, newChar=%d, deleteCount=%d",
                          _keycode, pData->code, pData->extCode, (int)pData->backspaceCount, (int)pData->newCharCount, externalDeleteCount);
                }
                #endif

                if (textReplacementFixEnabled &&
                    _keycode == KEY_SPACE &&
                    (pData->backspaceCount > 0 || pData->newCharCount > 0)) {
                    unsigned long long matchedElapsedMs = 0;
                    PHTVTextReplacementDecision decision =
                        (PHTVTextReplacementDecision)[PHTVSpotlightDetectionService detectTextReplacementForCode:pData->code
                                                                                                         extCode:pData->extCode
                                                                                                  backspaceCount:(int)pData->backspaceCount
                                                                                                    newCharCount:(int)pData->newCharCount
                                                                                             externalDeleteCount:externalDeleteCount
                                                                         restoreAndStartNewSessionCode:vRestoreAndStartNewSession
                                                                                         willProcessCode:vWillProcess
                                                                                             restoreCode:vRestore
                                                                                            deleteWindowMs:TEXT_REPLACEMENT_DELETE_WINDOW_MS
                                                                                         matchedElapsedMs:&matchedElapsedMs];

                    if (decision == PHTVTextReplacementDecisionExternalDelete) {
#ifdef DEBUG
                        NSLog(@"[TextReplacement] Text replacement detected - passing through event (code=%d, backspace=%d, newChar=%d, deleteCount=%d, elapsedMs=%llu)",
                              pData->code, (int)pData->backspaceCount, (int)pData->newCharCount, externalDeleteCount, matchedElapsedMs);
#endif
                        // CRITICAL: Return event to let macOS insert Space
                        return event;
                    }

                    if (decision == PHTVTextReplacementDecisionPattern2A ||
                        decision == PHTVTextReplacementDecisionPattern2B) {
#ifdef DEBUG
                        NSLog(@"[PHTV TextReplacement] Pattern %@ matched: code=%d, backspace=%d, newChar=%d, keycode=%d",
                              decision == PHTVTextReplacementDecisionPattern2A ? @"2a" : @"2b",
                              pData->code, (int)pData->backspaceCount, (int)pData->newCharCount, _keycode);
                        NSLog(@"[PHTV TextReplacement] ✅ DETECTED - Skipping processing (code=%d, backspace=%d, newChar=%d)",
                              pData->code, (int)pData->backspaceCount, (int)pData->newCharCount);
#endif
                        // CRITICAL: Return event to let macOS insert Space
                        return event;
                    }

                    if (decision == PHTVTextReplacementDecisionFallbackNoMatch) {
                        // Detection FAILED - will process normally (potential bug!)
#ifdef DEBUG
                        NSLog(@"[PHTV TextReplacement] ❌ NOT DETECTED - Will process normally (code=%d, backspace=%d, newChar=%d) - MAY CAUSE DUPLICATE!",
                              pData->code, (int)pData->backspaceCount, (int)pData->newCharCount);
#endif
                    }
                }

                // No need for HID tap forcing or aggressive delays anymore

                //send backspace
                if (pData->backspaceCount > 0 && pData->backspaceCount < MAX_BUFF) {
                    // Use Spotlight-style deferred backspace when in search field (spotlightActive) or Spotlight-like app
                    // EXCEPT for Chromium apps - they don't support AX API properly
                    if ((!isBrowserApp && spotlightActive) || appChars.isSpotlightLike) {
                        // Defer deletion to AX replacement inside SendNewCharString().
                        _phtvPendingBackspaceCount = (int)pData->backspaceCount;
#ifdef DEBUG
                        PHTVSpotlightDebugLog([NSString stringWithFormat:@"deferBackspace=%d newCharCount=%d", (int)pData->backspaceCount, (int)pData->newCharCount]);
#endif
                    } else {
                        // Send backspaces for all apps.
                        // Safari/Chromium browsers use Shift+Left strategy (handled above).
                        if (appChars.needsStepByStep) {
                            SendBackspaceSequenceWithDelay(pData->backspaceCount, DelayTypeSpotlight);
                        } else {
                            // Browsers, terminals, and normal apps
                            SendBackspaceSequenceWithDelay(pData->backspaceCount, DelayTypeNone);
                        }
                    }
                }

                //send new character - use step by step for timing sensitive apps like Spotlight
                // IMPORTANT: For Spotlight-like targets we rely on SendNewCharString(), which can
                // perform deterministic replacement (AX) and/or per-character Unicode posting.
                // Forcing step-by-step here would skip deferred deletions and cause duplicated letters.
                // EXCEPTION: Auto English restore (extCode=5) on Chromium apps should use step-by-step
                // because Chromium's autocomplete interferes with AX API and Unicode string posting
                BOOL isSpotlightTarget = (!isBrowserApp && spotlightActive) || appChars.isSpotlightLike;
                // Only use step-by-step for explicitly configured apps
                // FIX #121: Also use step-by-step for auto English restore + Enter/Return
                // This ensures Terminal receives characters before the Enter key
                BOOL isAutoEnglishWithEnter = (pData->code == vRestoreAndStartNewSession) &&
                                              (_keycode == KEY_ENTER || _keycode == KEY_RETURN);
                BOOL useStepByStep = (!isSpotlightTarget) &&
                                     (_phtvIsCliTarget ||
                                      vSendKeyStepByStep ||
                                      appChars.needsStepByStep ||
                                      isAutoEnglishWithEnter);
#ifdef DEBUG
                if (isSpotlightTarget) {
                    PHTVSpotlightDebugLog([NSString stringWithFormat:@"willSend stepByStep=%d backspaceCount=%d newCharCount=%d", (int)useStepByStep, (int)pData->backspaceCount, (int)pData->newCharCount]);
                }
#endif
                if (!useStepByStep) {
                    SendNewCharString();
                } else {
                    if (pData->newCharCount > 0 && pData->newCharCount <= MAX_BUFF) {
                        useconds_t cliTextDelay = 0;
                        if (_phtvIsCliTarget) {
                            cliTextDelay = PHTVScaleCliDelay(_phtvCliTextDelayUs);
                        }
                        for (int i = pData->newCharCount - 1; i >= 0; i--) {
                            SendKeyCode(pData->charData[i]);
                            if (cliTextDelay > 0 && i > 0) {
                                usleep(cliTextDelay);
                            }
                        }
                        if (_phtvIsCliTarget && pData->newCharCount > 0) {
                            uint64_t totalBlockUs = PHTVScaleCliDelay64(_phtvCliPostSendBlockUs);
                            if (cliTextDelay > 0 && pData->newCharCount > 1) {
                                totalBlockUs += (uint64_t)cliTextDelay * (uint64_t)(pData->newCharCount - 1);
                            }
                            SetCliBlockForMicroseconds(totalBlockUs);
                        }
                    }
                    if (pData->code == vRestore || pData->code == vRestoreAndStartNewSession) {
                        #ifdef DEBUG
                        if (pData->code == vRestoreAndStartNewSession) {
                            fprintf(stderr, "[AutoEnglish] PROCESSING RESTORE: backspace=%d, newChar=%d\n",
                                   (int)pData->backspaceCount, (int)pData->newCharCount);
                            fflush(stderr);
                        }
                        #endif
                        // No delay needed before final key
                        SendKeyCode(_keycode | ((_flag & kCGEventFlagMaskAlphaShift) || (_flag & kCGEventFlagMaskShift) ? CAPS_MASK : 0));
                    }
                    if (pData->code == vRestoreAndStartNewSession) {
                        startNewSession();
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
