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

#define FRONT_APP [[NSWorkspace sharedWorkspace] frontmostApplication].bundleIdentifier

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
    if (lastLogTime != 0 && mach_time_to_ms(now - lastLogTime) < 500) {
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

// Check if Spotlight or similar overlay is currently active using Accessibility API
BOOL isSpotlightActive(void) {
    // Get the system-wide focused element
    AXUIElementRef systemWide = AXUIElementCreateSystemWide();
    AXUIElementRef focusedElement = NULL;
    AXError error = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute, (CFTypeRef *)&focusedElement);
    CFRelease(systemWide);
    
    if (error != kAXErrorSuccess || focusedElement == NULL) {
        return NO;
    }
    
    // Get the PID of the app that owns the focused element
    pid_t focusedPID = 0;
    error = AXUIElementGetPid(focusedElement, &focusedPID);
    CFRelease(focusedElement);
    
    if (error != kAXErrorSuccess || focusedPID == 0) {
        return NO;
    }
    
    // Get the bundle ID from the PID
    NSRunningApplication *app = [NSRunningApplication runningApplicationWithProcessIdentifier:focusedPID];
    NSString *bundleId = app.bundleIdentifier;
    
    // Check if it's Spotlight or similar
    if ([bundleId isEqualToString:@"com.apple.Spotlight"] ||
        [bundleId hasPrefix:@"com.apple.Spotlight"]) {
        return YES;
    }
    
    // Also check by process path for system processes without bundle ID
    if (bundleId == nil) {
        char pathBuffer[PROC_PIDPATHINFO_MAXSIZE];
        if (proc_pidpath(focusedPID, pathBuffer, sizeof(pathBuffer)) > 0) {
            NSString *path = [NSString stringWithUTF8String:pathBuffer];
            if ([path containsString:@"Spotlight"]) {
                return YES;
            }
        }
    }
    
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
        _pidBundleCache = [NSMutableDictionary dictionaryWithCapacity:64];
        _lastCacheCleanTime = mach_absolute_time();
    }
    
    NSString *cached = _pidBundleCache[pidKey];
    
    // Smart cache cleanup with zero-allocation timing
    uint64_t now = mach_absolute_time();
    uint64_t elapsed_ms = mach_time_to_ms(now - _lastCacheCleanTime);
    if (__builtin_expect(elapsed_ms > 120000, 0)) { // 2 minutes
        if (_pidBundleCache.count > 50) {
            [_pidBundleCache removeAllObjects];
        }
        _lastCacheCleanTime = now;
    }
    
    os_unfair_lock_unlock(&_pidCacheLock);
    
    if (cached) {
        return [cached isEqualToString:@""] ? nil : cached;
    }
    
    // Try to get bundle ID from running applications
    NSArray *runningApps = [[NSWorkspace sharedWorkspace] runningApplications];
    for (NSRunningApplication *app in runningApps) {
        if (app.processIdentifier == pid) {
            NSString *bundleId = app.bundleIdentifier ?: @"";
            os_unfair_lock_lock(&_pidCacheLock);
            _pidBundleCache[pidKey] = bundleId;
            os_unfair_lock_unlock(&_pidCacheLock);
            return bundleId.length > 0 ? bundleId : nil;
        }
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
NSDictionary *keyStringToKeyCodeMap = @{
    // Characters from number row
    @"`": @50, @"~": @50, @"1": @18, @"!": @18, @"2": @19, @"@": @19, @"3": @20, @"#": @20, @"4": @21, @"$": @21,
    @"5": @23, @"%": @23, @"6": @22, @"^": @22, @"7": @26, @"&": @26, @"8": @28, @"*": @28, @"9": @25, @"(": @25,
    @"0": @29, @")": @29, @"-": @27, @"_": @27, @"=": @24, @"+": @24,
    // Characters from first keyboard row
    @"q": @12, @"w": @13, @"e": @14, @"r": @15, @"t": @17, @"y": @16, @"u": @32, @"i": @34, @"o": @31, @"p": @35,
    @"[": @33, @"{": @33, @"]": @30, @"}": @30, @"\\": @42, @"|": @42,
    // Characters from second keyboard row
    @"a": @0, @"s": @1, @"d": @2, @"f": @3, @"g": @5, @"h": @4, @"j": @38, @"k": @40, @"l": @37,
    @";": @41, @":": @41, @"'": @39, @"\"": @39,
    // Characters from second third row
    @"z": @6, @"x": @7, @"c": @8, @"v": @9, @"b": @11, @"n": @45, @"m": @46,
    @",": @43, @"<": @43, @".": @47, @">": @47, @"/": @44, @"?": @44
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
                                                           @"com.microsoft.Edge",
                                                           @"net.whatsapp.WhatsApp"]];  // WhatsApp Desktop (Electron/Chromium-based)

    // Apps that need to FORCE Unicode precomposed (not compound) - Using NSSet for O(1) lookup performance
    // These apps don't handle Unicode combining characters properly
    NSSet* _forcePrecomposedAppSet = [NSSet setWithArray:@[@"com.apple.Spotlight",
                                                            @"com.apple.systemuiserver"]];  // Spotlight runs under SystemUIServer

    //app which needs step by step key sending (timing sensitive apps) - Using NSSet for O(1) lookup performance
    NSSet* _stepByStepAppSet = [NSSet setWithArray:@[// Commented out for testing Vietnamese input:
                                                      // @"com.apple.Spotlight",
                                                      // @"com.apple.systemuiserver",  // Spotlight runs under SystemUIServer
                                                      @"com.apple.loginwindow",     // Login window
                                                      @"com.apple.SecurityAgent",   // Security dialogs
                                                      @"com.raycast.macos",
                                                      @"com.alfredapp.Alfred",
                                                      @"com.apple.launchpad",       // Launchpad/Ứng dụng
                                                      @"net.whatsapp.WhatsApp"]];   // WhatsApp Desktop (caption field needs step-by-step)

    // Apps where Vietnamese input should be disabled (search/launcher apps) - Using NSSet for O(1) lookup performance
    NSSet* _disableVietnameseAppSet = [NSSet setWithArray:@[
        @"com.apple.apps.launcher",       // Apps.app (Applications)
        @"com.apple.ScreenContinuity",    // iPhone Mirroring
        // Spotlight is handled separately (force precomposed Unicode instead of disabling)
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

    __attribute__((always_inline)) static inline BOOL isSpotlightLikeApp(NSString* bundleId) {
        return bundleIdMatchesAppSet(bundleId, _forcePrecomposedAppSet);
    }

    // Cache the effective target bundle id for the current event tap callback.
    // This avoids re-querying AX focus inside hot-path send routines.
    static NSString* _phtvEffectiveTargetBundleId = nil;
    static BOOL _phtvPostToHIDTap = NO;
    static int64_t _phtvKeyboardType = 0;
    static int _phtvPendingBackspaceCount = 0;

    __attribute__((always_inline)) static inline void SpotlightTinyDelay(void) {
        // Spotlight/SystemUIServer input fields are timing-sensitive.
        // A tiny delay helps ensure backspace + replacement is applied in order.
        // This is only used when AX API fallback to synthetic events (rare)
        usleep(10000); // 10ms (fallback path - AX API is preferred)
    }

    static BOOL ReplaceFocusedTextViaAX(NSInteger backspaceCount, NSString* insertText) {
        if (backspaceCount < 0) backspaceCount = 0;
        if (insertText == nil) insertText = @"";

        AXUIElementRef systemWide = AXUIElementCreateSystemWide();
        AXUIElementRef focusedElement = NULL;
        AXError error = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute, (CFTypeRef *)&focusedElement);
        CFRelease(systemWide);
        if (error != kAXErrorSuccess || focusedElement == NULL) {
#ifdef DEBUG
            PHTVSpotlightDebugLog([NSString stringWithFormat:@"AX focus failed err=%d", (int)error]);
#endif
            return NO;
        }

        CFTypeRef valueRef = NULL;
        error = AXUIElementCopyAttributeValue(focusedElement, kAXValueAttribute, &valueRef);
        if (error != kAXErrorSuccess) {
#ifdef DEBUG
            PHTVSpotlightDebugLog([NSString stringWithFormat:@"AX value read failed err=%d", (int)error]);
#endif
            CFRelease(focusedElement);
            return NO;
        }

        NSString *valueStr = nil;
        if (valueRef != NULL && CFGetTypeID(valueRef) == CFStringGetTypeID()) {
            valueStr = (__bridge NSString *)valueRef;
        } else {
            valueStr = @"";
        }

        CFTypeRef rangeRef = NULL;
        error = AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextRangeAttribute, &rangeRef);
        if (error != kAXErrorSuccess || rangeRef == NULL || CFGetTypeID(rangeRef) != AXValueGetTypeID()) {
#ifdef DEBUG
            PHTVSpotlightDebugLog([NSString stringWithFormat:@"AX selectedRange read failed err=%d typeOk=%d", (int)error, (rangeRef != NULL && CFGetTypeID(rangeRef) == AXValueGetTypeID())]);
#endif
            if (valueRef) CFRelease(valueRef);
            CFRelease(focusedElement);
            if (rangeRef) CFRelease(rangeRef);
            return NO;
        }

        CFRange selection = CFRangeMake(0, 0);
        if (!AXValueGetValue((AXValueRef)rangeRef, PHTV_AXVALUE_CFRANGE_TYPE, &selection)) {
#ifdef DEBUG
            PHTVSpotlightDebugLog(@"AX range decode failed");
#endif
            if (valueRef) CFRelease(valueRef);
            CFRelease(rangeRef);
            CFRelease(focusedElement);
            return NO;
        }

        NSInteger caretLocation = (NSInteger)selection.location;
        if (caretLocation < 0) caretLocation = 0;
        if (caretLocation > (NSInteger)valueStr.length) caretLocation = (NSInteger)valueStr.length;

        NSInteger start = caretLocation - backspaceCount;
        if (start < 0) start = 0;
        NSInteger len = caretLocation - start;
        if (len < 0) len = 0;
        if (start + len > (NSInteger)valueStr.length) {
            len = (NSInteger)valueStr.length - start;
            if (len < 0) len = 0;
        }

        NSString *newValue = [valueStr stringByReplacingCharactersInRange:NSMakeRange((NSUInteger)start, (NSUInteger)len)
                                                              withString:insertText];

        AXError setValueErr = AXUIElementSetAttributeValue(focusedElement, kAXValueAttribute, (__bridge CFTypeRef)newValue);
        if (setValueErr != kAXErrorSuccess) {
#ifdef DEBUG
            PHTVSpotlightDebugLog([NSString stringWithFormat:@"AX value write failed err=%d", (int)setValueErr]);
#endif
            if (valueRef) CFRelease(valueRef);
            CFRelease(rangeRef);
            CFRelease(focusedElement);
            return NO;
        }

        CFRange newSel = CFRangeMake(start + (NSInteger)insertText.length, 0);
        AXValueRef newRange = AXValueCreate(PHTV_AXVALUE_CFRANGE_TYPE, &newSel);
        if (newRange != NULL) {
            AXUIElementSetAttributeValue(focusedElement, kAXSelectedTextRangeAttribute, newRange);
            CFRelease(newRange);
        }

        if (valueRef) CFRelease(valueRef);
        CFRelease(rangeRef);
        CFRelease(focusedElement);

    #ifdef DEBUG
        PHTVSpotlightDebugLog([NSString stringWithFormat:@"AX replace ok del=%ld ins=%ld", (long)backspaceCount, (long)insertText.length]);
    #endif
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

        // Fast path: reuse last decision if same PID and checked recently (~100ms)
        // Very short cache for immediate app-switch response
        uint64_t elapsed_ms = mach_time_to_ms(now - lastCheckTime);
        if (__builtin_expect(targetPID > 0 && targetPID == lastPid && elapsed_ms < 100, 1)) {
            return lastResult;
        }

        // First, check using Accessibility API to get the actual focused window's app
        AXUIElementRef systemWide = AXUIElementCreateSystemWide();
        AXUIElementRef focusedElement = NULL;
        AXError error = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute, (CFTypeRef *)&focusedElement);
        CFRelease(systemWide);

        NSString *bundleId = nil;
        pid_t cachePid = targetPID; // cache key we will use for next lookup

        if (error == kAXErrorSuccess && focusedElement != NULL) {
            pid_t focusedPID = 0;
            error = AXUIElementGetPid(focusedElement, &focusedPID);
            CFRelease(focusedElement);

            if (error == kAXErrorSuccess && focusedPID != 0) {
                bundleId = getBundleIdFromPID(focusedPID);
                cachePid = focusedPID;
            }
        }

        // Fallback to target PID from event if accessibility fails
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

        myEventSource = CGEventSourceCreate(kCGEventSourceStatePrivate);
        pData = (vKeyHookState*)vKeyInit();

        // Performance optimization: Pre-allocate _syncKey vector to avoid reallocations
        // Typical typing buffer is ~50 chars, reserve 256 for safety margin
        _syncKey.reserve(256);

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
                if (!(vCodeTable == 3 && containUnicodeCompoundApp(getFocusedAppBundleId()))) {
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
        BOOL forcePrecomposed = (vCodeTable == 3) && isSpotlightTarget;
        
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
            // Prefer AX value replacement for Spotlight/SystemUIServer.
            // This avoids the search field mis-handling synthetic backspace + unicode replacement.
            NSString *insertStr = [NSString stringWithCharacters:(const unichar *)_finalCharString length:_finalCharSize];
            int backspaceCount = _phtvPendingBackspaceCount;
            _phtvPendingBackspaceCount = 0;

            // Retry AX replacement up to 3 times when typing very fast
            // Spotlight can be busy (searching) causing AX API to fail temporarily
            BOOL axSucceeded = NO;
            for (int retry = 0; retry < 3 && !axSucceeded; retry++) {
                if (retry > 0) {
                    usleep(5000); // 5ms delay before retry (Spotlight might be busy)
                }
                axSucceeded = ReplaceFocusedTextViaAX(backspaceCount, insertStr);
            }

            if (axSucceeded) {
                return;  // AX replacement succeeded - no need for synthetic events
            }
            // If AX fails after retries, fall back to synthetic events below.
            // IMPORTANT: we deferred deletion in the callback; perform it here now.
            if (backspaceCount > 0) {
                int maxDeletes = backspaceCount;
                for (int del = 0; del < maxDeletes; del++) {
                    if (IS_DOUBLE_CODE(vCodeTable) && _syncKey.size() == 0) {
                        break;
                    }
                    SendBackspace();
                }
            }
        }
        
        if (isSpotlightTarget) {
            // Spotlight's search field is sensitive to batched Unicode replacement.
            // Send as per-character Unicode events to avoid mark reordering/duplication.
            for (int idx = 0; idx < _finalCharSize; idx++) {
                UniChar oneChar = (UniChar)_finalCharString[idx];
                _newEventDown = CGEventCreateKeyboardEvent(myEventSource, 0, true);
                _newEventUp = CGEventCreateKeyboardEvent(myEventSource, 0, false);
                if (_phtvKeyboardType != 0) {
                    CGEventSetIntegerValueField(_newEventDown, kCGKeyboardEventKeyboardType, _phtvKeyboardType);
                    CGEventSetIntegerValueField(_newEventUp, kCGKeyboardEventKeyboardType, _phtvKeyboardType);
                }
                CGEventFlags uFlags = CGEventGetFlags(_newEventDown);
                uFlags |= kCGEventFlagMaskNonCoalesced;
                CGEventSetFlags(_newEventDown, uFlags);
                CGEventSetFlags(_newEventUp, uFlags);
                CGEventKeyboardSetUnicodeString(_newEventDown, 1, &oneChar);
                CGEventKeyboardSetUnicodeString(_newEventUp, 1, &oneChar);
                PostSyntheticEvent(_proxy, _newEventDown);
                PostSyntheticEvent(_proxy, _newEventUp);
                SpotlightTinyDelay();
                CFRelease(_newEventDown);
                CFRelease(_newEventUp);
            }
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
            for (int i = 0; i < pData->backspaceCount; i++) {
                SendBackspace();
            }
        }
        //send real data - use step by step for timing sensitive apps like Spotlight
        BOOL useStepByStep = vSendKeyStepByStep || needsStepByStep(getFocusedAppBundleId());
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

    // TODO: Research API to convert character into CGKeyCode more elegantly!
    int ConvertKeyStringToKeyCode(NSString *keyString, CGKeyCode fallback) {
        // Infomation about capitalization (shift/caps) is already included
        // in the original CGEvent, only find out which position on keyboard a key is pressed
        NSString *lowercasedKeyString = [keyString lowercaseString];
        if (!lowercasedKeyString) {
            return fallback;
        }
        
        NSNumber *keycode = [keyStringToKeyCodeMap objectForKey:lowercasedKeyString];

        if (keycode) {
            return [keycode intValue];
        }
        return fallback;
    }

    // If conversion fails, return fallbackKeyCode
    CGKeyCode ConvertEventToKeyboadLayoutCompatKeyCode(CGEventRef keyEvent, CGKeyCode fallbackKeyCode) {
        NSEvent *kbLayoutCompatEvent = [NSEvent eventWithCGEvent:keyEvent];
        NSString *kbLayoutCompatKeyString = kbLayoutCompatEvent.charactersIgnoringModifiers;
        return ConvertKeyStringToKeyCode(kbLayoutCompatKeyString,
                                         fallbackKeyCode);
    }

    /**
     * MAIN HOOK entry, very important function.
     * MAIN Callback.
     */
    CGEventRef PHTVCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
        @autoreleasepool {
        // Auto-recover when macOS temporarily disables the event tap
        if (__builtin_expect(type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput, 0)) {
            [PHTVManager handleEventTapDisabled:type];
            return event;
        }

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
            } else {
                // Tap is healthy, increment counter
                if (__builtin_expect(healthyCounter < 2000, 1)) healthyCounter++;
            }
        }

        //dont handle my event
        if (CGEventGetIntegerValueField(event, kCGEventSourceStateID) == CGEventSourceGetSourceStateID(myEventSource)) {
            return event;
        }
        
        _flag = CGEventGetFlags(event);
        _keycode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
        
        if (type == kCGEventKeyDown && vPerformLayoutCompat) {
            // If conversion fail, use current keycode
           _keycode = ConvertEventToKeyboadLayoutCompatKeyCode(event, _keycode);
        }
        
        //switch language shortcut; convert hotkey
        if (type == kCGEventKeyDown) {
            // Check hotkey match immediately - don't reset _lastFlag for non-hotkey presses
            // This keeps modifier state and makes hotkey more responsive
            if (GET_SWITCH_KEY(vSwitchKeyStatus) == _keycode && checkHotKey(vSwitchKeyStatus, GET_SWITCH_KEY(vSwitchKeyStatus) != 0xFE)){
                switchLanguage();
                _lastFlag = 0;
                _hasJustUsedHotKey = true;
                return NULL;
            }
            if (GET_SWITCH_KEY(convertToolHotKey) == _keycode && checkHotKey(convertToolHotKey, GET_SWITCH_KEY(convertToolHotKey) != 0xFE)){
                [appDelegate onQuickConvert];
                _lastFlag = 0;
                _hasJustUsedHotKey = true;
                return NULL;
            }
            // Only mark as used hotkey if we had modifiers pressed
            _hasJustUsedHotKey = _lastFlag != 0;
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
                if (vPauseKeyEnabled && vPauseKey > 0 && !_pauseKeyPressed) {
                    bool pauseKeyPressed = false;

                    // Check common modifier keys
                    if (vPauseKey == KEY_LEFT_OPTION || vPauseKey == KEY_RIGHT_OPTION) {
                        pauseKeyPressed = (_flag & kCGEventFlagMaskAlternate);
                    } else if (vPauseKey == KEY_LEFT_CONTROL || vPauseKey == KEY_RIGHT_CONTROL) {
                        pauseKeyPressed = (_flag & kCGEventFlagMaskControl);
                    } else if (vPauseKey == KEY_LEFT_SHIFT || vPauseKey == KEY_RIGHT_SHIFT) {
                        pauseKeyPressed = (_flag & kCGEventFlagMaskShift);
                    } else if (vPauseKey == KEY_LEFT_COMMAND || vPauseKey == KEY_RIGHT_COMMAND) {
                        pauseKeyPressed = (_flag & kCGEventFlagMaskCommand);
                    } else if (vPauseKey == 63) {  // Fn key
                        pauseKeyPressed = (_flag & kCGEventFlagMaskSecondaryFn);
                    }

                    if (pauseKeyPressed) {
                        // Save current language state and temporarily switch to English
                        _savedLanguageBeforePause = vLanguage;
                        if (vLanguage == 1) {
                            // Only switch if currently in Vietnamese mode
                            vLanguage = 0;  // Switch to English
                        }
                        _pauseKeyPressed = true;
                    }
                }
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
                                for (int i = 0; i < pData->backspaceCount; i++) {
                                    SendBackspace();
                                    if (isTerminal) {
                                        usleep(3000);  // 3ms delay for terminals
                                    }
                                }
                                // Extra settle time for terminals after all backspaces
                                if (isTerminal) {
                                    usleep(8000);  // 8ms settle time
                                }
                            }

                            // Send the raw ASCII characters
                            SendNewCharString();

                            // Final settle time for terminals (20ms) after all text is sent
                            if (isTerminal) {
                                usleep(20000);  // 20ms final settle time for terminals
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
                if (_pauseKeyPressed) {
                    bool pauseKeyReleased = false;

                    // Check which key was released
                    if (vPauseKey == KEY_LEFT_OPTION || vPauseKey == KEY_RIGHT_OPTION) {
                        pauseKeyReleased = (_lastFlag & kCGEventFlagMaskAlternate) && !(_flag & kCGEventFlagMaskAlternate);
                    } else if (vPauseKey == KEY_LEFT_CONTROL || vPauseKey == KEY_RIGHT_CONTROL) {
                        pauseKeyReleased = (_lastFlag & kCGEventFlagMaskControl) && !(_flag & kCGEventFlagMaskControl);
                    } else if (vPauseKey == KEY_LEFT_SHIFT || vPauseKey == KEY_RIGHT_SHIFT) {
                        pauseKeyReleased = (_lastFlag & kCGEventFlagMaskShift) && !(_flag & kCGEventFlagMaskShift);
                    } else if (vPauseKey == KEY_LEFT_COMMAND || vPauseKey == KEY_RIGHT_COMMAND) {
                        pauseKeyReleased = (_lastFlag & kCGEventFlagMaskCommand) && !(_flag & kCGEventFlagMaskCommand);
                    } else if (vPauseKey == 63) {  // Fn key
                        pauseKeyReleased = (_lastFlag & kCGEventFlagMaskSecondaryFn) && !(_flag & kCGEventFlagMaskSecondaryFn);
                    }

                    if (pauseKeyReleased) {
                        // Restore previous language state
                        vLanguage = _savedLanguageBeforePause;
                        _pauseKeyPressed = false;
                    }
                }

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
                        cachedLanguage = [(__bridge NSString *)langRef copy];  // Copy to retain
                    }
                    CFRelease(isource);  // Only release isource (we copied it)
                    lastLanguageCheckTime = now;
                }
            }

            currentLanguage = cachedLanguage;
            if (currentLanguage && ![currentLanguage isLike:@"en"]) {
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

            // Cache for send routines called later in this callback.
            _phtvEffectiveTargetBundleId = effectiveBundleId;
            _phtvPostToHIDTap = spotlightActive || isSpotlightLikeApp(effectiveBundleId);
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
            if (currentCodeTable == 3 && (spotlightActive || isSpotlightLikeApp(effectiveBundleId))) {
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
                
                //fix autocomplete
                if (vFixRecommendBrowser && pData->extCode != 4 && !isSpotlightLikeApp(effectiveBundleId)) {
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
                
                //send backspace
                if (pData->backspaceCount > 0 && pData->backspaceCount < MAX_BUFF) {
                    if (isSpotlightLikeApp(effectiveBundleId)) {
                        // Defer deletion to AX replacement inside SendNewCharString().
                        _phtvPendingBackspaceCount = (int)pData->backspaceCount;
#ifdef DEBUG
                        PHTVSpotlightDebugLog([NSString stringWithFormat:@"deferBackspace=%d newCharCount=%d", (int)pData->backspaceCount, (int)pData->newCharCount]);
#endif
                    } else {
                        for (_i = 0; _i < pData->backspaceCount; _i++) {
                            SendBackspace();
                        }
                    }
                }
                
                //send new character - use step by step for timing sensitive apps like Spotlight
                // IMPORTANT: For Spotlight-like targets we rely on SendNewCharString(), which can
                // perform deterministic replacement (AX) and/or per-character Unicode posting.
                // Forcing step-by-step here would skip deferred deletions and cause duplicated letters.
                BOOL isSpotlightTarget = spotlightActive || isSpotlightLikeApp(effectiveBundleId);
                BOOL useStepByStep = (!isSpotlightTarget) && (vSendKeyStepByStep || needsStepByStep(effectiveBundleId));
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
