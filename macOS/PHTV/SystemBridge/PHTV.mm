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
#import <mach/mach_time.h>
#import <unistd.h>
#import <stdlib.h>
#import <string.h>
#include <limits>
#import "Engine.h"
#include "../Core/PHTVConstants.h"
#import <Sparkle/Sparkle.h>
#import "PHTV-Swift.h"

// Forward declarations for functions used before definition (inside extern "C" block)
extern "C" {
    NSString* getFocusedAppBundleId(void);
}

#define FRONT_APP [[NSWorkspace sharedWorkspace] frontmostApplication].bundleIdentifier

typedef NS_ENUM(NSInteger, DelayType) {
    DelayTypeNone = 0,
    DelayTypeSpotlight = 2
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
static const int CLI_TEXT_CHUNK_SIZE_DEFAULT = 20;
static const useconds_t CLI_POST_SEND_BLOCK_MIN_US = 20000;
static const useconds_t CLI_PRE_BACKSPACE_DELAY_US = 4000;

// High-resolution timing
static mach_timebase_info_data_t timebase_info;
static dispatch_once_t timebase_init_token;

#ifdef DEBUG
static inline uint64_t mach_time_to_ms(uint64_t mach_time) {
    return (mach_time * timebase_info.numer) / (timebase_info.denom * 1000000);
}
#endif

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

#define OTHER_CONTROL_KEY (_flag & kCGEventFlagMaskCommand) || (_flag & kCGEventFlagMaskControl) || \
                            (_flag & kCGEventFlagMaskAlternate) || (_flag & kCGEventFlagMaskSecondaryFn) || \
                            (_flag & kCGEventFlagMaskNumericPad) || (_flag & kCGEventFlagMaskHelp)

#define DYNA_DATA(macro, pos) (macro ? pData->macroData[pos] : pData->charData[pos])
#define MAX_UNICODE_STRING  20

extern volatile int vSendKeyStepByStep;
extern volatile int vPerformLayoutCompat;
extern volatile int vTempOffPHTV;
extern volatile int vEnableEmojiHotkey;
extern volatile int vEmojiHotkeyModifiers;
extern volatile int vEmojiHotkeyKeyCode;
extern volatile int vPauseKeyEnabled;
extern volatile int vPauseKey;

extern "C" {

    static const uint64_t kAppCharacteristicsCacheMaxAgeMs = 10000;

    // Cache the effective target bundle id for the current event tap callback.
    // This avoids re-querying AX focus inside hot-path send routines.
static NSString* _phtvEffectiveTargetBundleId = nil;
static AppCharacteristics _phtvCurrentAppCharacteristics = {NO, NO, NO, NO, NO};
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
        _phtvCliSpeedFactor = [PHTVCliProfileService nextCliSpeedFactorForDeltaUs:deltaUs
                                                                      currentFactor:_phtvCliSpeedFactor];
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

    static inline void ApplyCliProfile(PHTVCliTimingProfileBox *profile) {
        if (profile == nil) {
            _phtvCliBackspaceDelayUs = 0;
            _phtvCliWaitAfterBackspaceUs = 0;
            _phtvCliTextDelayUs = 0;
            _phtvCliTextChunkSize = (int)[PHTVCliProfileService nonCliTextChunkSize];
            _phtvCliPostSendBlockUs = CLI_POST_SEND_BLOCK_MIN_US;
            return;
        }

        _phtvCliBackspaceDelayUs = (useconds_t)profile.backspaceDelayUs;
        _phtvCliWaitAfterBackspaceUs = (useconds_t)profile.waitAfterBackspaceUs;
        _phtvCliTextDelayUs = (useconds_t)profile.textDelayUs;
        _phtvCliTextChunkSize = (int)profile.textChunkSize;
        _phtvCliPostSendBlockUs = (useconds_t)MAX((uint64_t)CLI_POST_SEND_BLOCK_MIN_US,
                                                  (uint64_t)profile.postSendBlockUs);
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
    __attribute__((always_inline)) static inline BOOL shouldDisableVietnameseForEvent(CGEventRef event) {
        pid_t targetPID = (pid_t)CGEventGetIntegerValueField(event, kCGEventTargetUnixProcessID);
        return [PHTVAppContextService shouldDisableVietnameseForTargetPid:(int32_t)targetPID
                                                           cacheDurationMs:APP_SWITCH_CACHE_DURATION_MS
                                                                  safeMode:vSafeMode
                                                   spotlightCacheDurationMs:SPOTLIGHT_CACHE_DURATION_MS];
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

    
    void PHTVInit() {
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
        [PHTVEventContextBridgeService invalidateAccessibilityContextCaches];

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

        int currentCodeTable = __atomic_load_n(&vCodeTable, __ATOMIC_RELAXED);
        PHTVSessionResetTransitionBox *sessionResetTransition =
            [PHTVHotkeyService sessionResetTransitionForCodeTable:(int32_t)currentCodeTable
                                                allowUppercasePrime:allowUppercasePrime
                                                           safeMode:vSafeMode
                                                    uppercaseEnabled:(int32_t)vUpperCaseFirstChar
                                                   uppercaseExcluded:(int32_t)vUpperCaseExcludedForCurrentApp];

        if (sessionResetTransition.shouldClearSyncKey) {
            _syncKey.clear();
        }
        if (sessionResetTransition.shouldPrimeUppercaseFirstChar) {
            vPrimeUpperCaseFirstChar();
        }
        _pendingUppercasePrimeCheck = sessionResetTransition.pendingUppercasePrimeCheck;
        _lastFlag = (CGEventFlags)sessionResetTransition.lastFlags;
        _willContinuteSending = sessionResetTransition.willContinueSending;
        _willSendControlKey = sessionResetTransition.willSendControlKey;
        _hasJustUsedHotKey = sessionResetTransition.hasJustUsedHotKey;

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
    // Uses Spotlight/focus caches maintained by PHTVAppContextService.
    NSString* getFocusedAppBundleId() {
        NSString *result = [PHTVAppContextService focusedBundleIdForSafeMode:vSafeMode
                                                              cacheDurationMs:SPOTLIGHT_CACHE_DURATION_MS];
        return (result != nil) ? result : FRONT_APP;
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
        if ([PHTVAppContextService needsNiceSpaceForBundleId:FRONT_APP]) {
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
                    if (!(vCodeTable == 3 && _phtvCurrentAppCharacteristics.containsUnicodeCompound)) {
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
                if (!(vCodeTable == 3 && _phtvCurrentAppCharacteristics.containsUnicodeCompound)) {
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
        
        // Treat as Spotlight target if callback selected HID/Spotlight-safe path.
        BOOL isSpotlightTarget = _phtvPostToHIDTap || _phtvCurrentAppCharacteristics.isSpotlightLike;
        // Some apps need precomposed Unicode but still rely on batched synthetic events.
        BOOL isPrecomposedBatched = _phtvCurrentAppCharacteristics.needsPrecomposedBatched;
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
            BOOL axSucceeded = [PHTVEventContextBridgeService replaceFocusedTextViaAXWithBackspaceCount:(int32_t)backspaceCount
                                                                                               insertText:insertStr
                                                                                                   verify:shouldVerify
                                                                                                 safeMode:vSafeMode];
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
                int chunkSize = (_phtvCliTextChunkSize > 0) ? _phtvCliTextChunkSize : 1;
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
            
    void handleMacro() {
        // PERFORMANCE: Use cached bundle ID instead of querying AX API
        NSString *effectiveTarget = _phtvEffectiveTargetBundleId ?: getFocusedAppBundleId();
        // Use _phtvPostToHIDTap which includes spotlightActive (search field detected via AX)
        BOOL isSpotlightLike = _phtvPostToHIDTap || _phtvCurrentAppCharacteristics.isSpotlightLike;

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
            BOOL axSucceeded = [PHTVEventContextBridgeService replaceFocusedTextViaAXWithBackspaceCount:(int32_t)pData->backspaceCount
                                                                                               insertText:macroString
                                                                                                   verify:shouldVerify
                                                                                                 safeMode:vSafeMode];
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
        BOOL useStepByStep = _phtvIsCliTarget || vSendKeyStepByStep || _phtvCurrentAppCharacteristics.needsStepByStep;
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

        // Perform periodic health check and recovery.
        // Explicitly consume result to satisfy warn_unused_result import behavior.
        BOOL tapHealthOk = [PHTVEventTapHealthService checkAndRecoverForEventType:type];
        (void)tapHealthOk;

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

        // TEXT REPLACEMENT DETECTION: Track external delete events.
        // When macOS Text Replacement is triggered (e.g., "ko" -> "không"),
        // macOS sends synthetic delete events that we didn't generate
        // We track these to avoid duplicate characters when SendEmptyCharacter() is called
        if (type == kCGEventKeyDown && _keycode == KEY_DELETE) {
            // This is an external delete event (not from PHTV since we already filtered myEventSource)
            [PHTVEventContextBridgeService trackExternalDelete];
#ifdef DEBUG
            NSLog(@"[TextReplacement] External DELETE detected");
#endif
        }

        // Also track space after deletes to detect text replacement pattern.
        if (type == kCGEventKeyDown && _keycode == KEY_SPACE) {
#ifdef DEBUG
            int externalDeleteCount = (int)[PHTVEventContextBridgeService externalDeleteCountValue];
            unsigned long long elapsed_ms = [PHTVEventContextBridgeService elapsedSinceLastExternalDeleteMs];
            NSLog(@"[TextReplacement] SPACE key pressed: deleteCount=%d, elapsedMs=%llu, sourceID=%lld",
                  externalDeleteCount, elapsed_ms,
                  CGEventGetIntegerValueField(event, kCGEventSourceStateID));
#endif
        }

        // Handle Spotlight detection optimization.
        [PHTVEventContextBridgeService handleSpotlightCacheInvalidationForType:type
                                                                       keycode:(uint16_t)_keycode
                                                                         flags:_flag];

        // If pause key is being held, strip pause modifier from events to prevent special characters
        // BUT only if no other modifiers are pressed (to preserve system shortcuts like Option+Cmd+V)
        if (_pauseKeyPressed && (type == kCGEventKeyDown || type == kCGEventKeyUp)) {
            if ([PHTVHotkeyService shouldStripPauseModifierWithFlags:(uint64_t)_flag
                                                         pauseKeyCode:(int32_t)vPauseKey]) {
                CGEventFlags newFlags = (CGEventFlags)[PHTVHotkeyService stripPauseModifierForFlags:(uint64_t)_flag
                                                                                        pauseKeyCode:(int32_t)vPauseKey];
                CGEventSetFlags(event, newFlags);
                _flag = newFlags;  // Update local flag as well
            }
        }

        if (type == kCGEventKeyDown && vPerformLayoutCompat) {
            // If conversion fail, use current keycode
           _keycode = ConvertEventToKeyboardLayoutCompatKeyCode(event, _keycode);
        }
        
        // Switch-language / quick-convert / emoji hotkey handling
        if (type == kCGEventKeyDown) {
            PHTVKeyDownHotkeyEvaluationBox *hotkeyEvaluation = [PHTVHotkeyService processKeyDownHotkeyWithKeyCode:(uint16_t)_keycode
                                                                                                        lastFlags:(uint64_t)_lastFlag
                                                                                                     currentFlags:(uint64_t)_flag
                                                                                                      switchHotkey:(int32_t)vSwitchKeyStatus
                                                                                                     convertHotkey:(int32_t)gConvertToolOptions.hotKey
                                                                                                      emojiEnabled:(int32_t)vEnableEmojiHotkey
                                                                                                    emojiModifiers:(int32_t)vEmojiHotkeyModifiers
                                                                                               emojiHotkeyKeyCode:(int32_t)vEmojiHotkeyKeyCode];
            _lastFlag = (CGEventFlags)hotkeyEvaluation.lastFlags;
            _hasJustUsedHotKey = hotkeyEvaluation.hasJustUsedHotKey;
            if (hotkeyEvaluation.action != PHTVKeyDownHotkeyActionNone) {
                if ([PHTVRuntimeUIBridgeService handleKeyDownHotkeyAction:(int32_t)hotkeyEvaluation.action]) {
                    _lastFlag = 0;
                    _hasJustUsedHotKey = true;
                    return NULL;
                }
            }
        }

        if (type == kCGEventKeyDown) {
            if (vUpperCaseFirstChar && !vUpperCaseExcludedForCurrentApp) {
                Uint32 keyWithCaps = _keycode | (((_flag & kCGEventFlagMaskShift) || (_flag & kCGEventFlagMaskAlphaShift)) ? CAPS_MASK : 0);
                Uint16 keyCharacter = keyCodeToCharacter(keyWithCaps);
                BOOL isNavigationKey = phtv_mac_key_is_navigation(_keycode);
                PHTVUppercasePrimeTransitionBox *uppercaseTransition = [PHTVHotkeyService uppercasePrimeTransitionForPending:_pendingUppercasePrimeCheck
                                                                                                                     flags:(uint64_t)_flag
                                                                                                                   keyCode:(uint16_t)_keycode
                                                                                                              keyCharacter:(uint16_t)keyCharacter
                                                                                                           isNavigationKey:isNavigationKey];
                _pendingUppercasePrimeCheck = uppercaseTransition.pending;
                if (uppercaseTransition.shouldAttemptPrime) {
                    BOOL shouldPrime = [PHTVAccessibilityService shouldPrimeUppercaseFromAXWithSafeMode:vSafeMode
                                                                                         uppercaseEnabled:vUpperCaseFirstChar
                                                                                        uppercaseExcluded:vUpperCaseExcludedForCurrentApp];
                    if (shouldPrime) {
                        vPrimeUpperCaseFirstChar();
                    }
                }
            }

            PHTVKeyDownModifierTrackingBox *keyDownModifierTracking =
                [PHTVHotkeyService keyDownModifierTrackingForFlags:(uint64_t)_flag
                                                    restoreOnEscape:(int32_t)vRestoreOnEscape
                                                    customEscapeKey:(int32_t)vCustomEscapeKey
                                             restoreModifierPressed:_restoreModifierPressed
                                         keyPressedWithRestoreModifier:_keyPressedWithRestoreModifier
                                                        switchHotkey:(int32_t)vSwitchKeyStatus
                                                       convertHotkey:(int32_t)gConvertToolOptions.hotKey
                                     keyPressedWhileSwitchModifiersHeld:_keyPressedWhileSwitchModifiersHeld
                                                        emojiEnabled:(int32_t)vEnableEmojiHotkey
                                                      emojiModifiers:(int32_t)vEmojiHotkeyModifiers
                                                 emojiHotkeyKeyCode:(int32_t)vEmojiHotkeyKeyCode
                                      keyPressedWhileEmojiModifiersHeld:_keyPressedWhileEmojiModifiersHeld];
            _keyPressedWithRestoreModifier = keyDownModifierTracking.keyPressedWithRestoreModifier;
            _keyPressedWhileSwitchModifiersHeld = keyDownModifierTracking.keyPressedWhileSwitchModifiersHeld;
            _keyPressedWhileEmojiModifiersHeld = keyDownModifierTracking.keyPressedWhileEmojiModifiersHeld;
        } else if (type == kCGEventFlagsChanged) {
            if (_lastFlag == 0 || _lastFlag < _flag) {
                PHTVModifierPressTransitionBox *modifierPressTransition =
                    [PHTVHotkeyService modifierPressTransitionForFlags:(uint64_t)_flag
                                                       restoreOnEscape:(int32_t)vRestoreOnEscape
                                                       customEscapeKey:(int32_t)vCustomEscapeKey
                                        keyPressedWithRestoreModifier:_keyPressedWithRestoreModifier
                                                restoreModifierPressed:_restoreModifierPressed
                                                       pauseKeyEnabled:(int32_t)vPauseKeyEnabled
                                                          pauseKeyCode:(int32_t)vPauseKey
                                                           pausePressed:_pauseKeyPressed
                                                        currentLanguage:(int32_t)vLanguage
                                                          savedLanguage:(int32_t)_savedLanguageBeforePause];

                _lastFlag = (CGEventFlags)modifierPressTransition.lastFlags;
                _keyPressedWithRestoreModifier = modifierPressTransition.keyPressedWithRestoreModifier;
                _restoreModifierPressed = modifierPressTransition.restoreModifierPressed;
                _keyPressedWhileSwitchModifiersHeld = modifierPressTransition.keyPressedWhileSwitchModifiersHeld;
                _keyPressedWhileEmojiModifiersHeld = modifierPressTransition.keyPressedWhileEmojiModifiersHeld;
                _pauseKeyPressed = modifierPressTransition.pausePressed;
                _savedLanguageBeforePause = (int)modifierPressTransition.savedLanguage;
                if (modifierPressTransition.shouldUpdateLanguage) {
                    vLanguage = modifierPressTransition.language;
                }
            } else if (_lastFlag > _flag)  {
                PHTVModifierReleaseTransitionBox *modifierReleaseTransition =
                    [PHTVHotkeyService modifierReleaseTransitionWithRestoreOnEscape:(int32_t)vRestoreOnEscape
                                                             restoreModifierPressed:_restoreModifierPressed
                                                     keyPressedWithRestoreModifier:_keyPressedWithRestoreModifier
                                                                   customEscapeKey:(int32_t)vCustomEscapeKey
                                                                          oldFlags:(uint64_t)_lastFlag
                                                                          newFlags:(uint64_t)_flag
                                                                       switchHotkey:(int32_t)vSwitchKeyStatus
                                                                      convertHotkey:(int32_t)gConvertToolOptions.hotKey
                                                                       emojiEnabled:(int32_t)vEnableEmojiHotkey
                                                                     emojiModifiers:(int32_t)vEmojiHotkeyModifiers
                                                                       emojiKeyCode:(int32_t)vEmojiHotkeyKeyCode
                                             keyPressedWhileSwitchModifiersHeld:_keyPressedWhileSwitchModifiersHeld
                                              keyPressedWhileEmojiModifiersHeld:_keyPressedWhileEmojiModifiersHeld
                                                              hasJustUsedHotkey:_hasJustUsedHotKey
                                                        tempOffSpellingEnabled:(int32_t)vTempOffSpelling
                                                          tempOffEngineEnabled:(int32_t)vTempOffPHTV
                                                                pauseKeyEnabled:(int32_t)vPauseKeyEnabled
                                                                   pauseKeyCode:(int32_t)vPauseKey
                                                                    pausePressed:_pauseKeyPressed
                                                                 currentLanguage:(int32_t)vLanguage
                                                                   savedLanguage:(int32_t)_savedLanguageBeforePause];

                BOOL shouldAttemptRestore = modifierReleaseTransition.shouldAttemptRestore;
                int releaseAction = (int)modifierReleaseTransition.releaseAction;

                // Releasing modifiers - check for restore modifier key first
                if (shouldAttemptRestore) {
                    // Restore modifier released without any other key press - trigger restore
                    if (vRestoreToRawKeys()) {
                        // Successfully restored - pData now contains restore info
                        // Send backspaces to delete Vietnamese characters
                        if (pData->backspaceCount > 0 && pData->backspaceCount < MAX_BUFF) {
                            SendBackspaceSequenceWithDelay(pData->backspaceCount, DelayTypeNone);
                        }

                        // Send the raw ASCII characters
                        SendNewCharString();

                        _lastFlag = (CGEventFlags)modifierReleaseTransition.lastFlags;
                        _restoreModifierPressed = modifierReleaseTransition.restoreModifierPressed;
                        _keyPressedWithRestoreModifier = modifierReleaseTransition.keyPressedWithRestoreModifier;
                        return NULL;
                    }
                }
                _restoreModifierPressed = modifierReleaseTransition.restoreModifierPressed;
                _keyPressedWithRestoreModifier = modifierReleaseTransition.keyPressedWithRestoreModifier;

                _savedLanguageBeforePause = (int)modifierReleaseTransition.savedLanguage;
                _pauseKeyPressed = modifierReleaseTransition.pausePressed;
                if (modifierReleaseTransition.shouldUpdateLanguage) {
                    vLanguage = modifierReleaseTransition.language;
                }

                if ([PHTVRuntimeUIBridgeService handleModifierReleaseHotkeyAction:(int32_t)releaseAction]) {
                    _lastFlag = (CGEventFlags)modifierReleaseTransition.lastFlags;
                    _keyPressedWhileSwitchModifiersHeld = modifierReleaseTransition.keyPressedWhileSwitchModifiersHeld;
                    _keyPressedWhileEmojiModifiersHeld = modifierReleaseTransition.keyPressedWhileEmojiModifiersHeld;
                    _hasJustUsedHotKey = true;
                    return NULL;
                }

                if (releaseAction == PHTVModifierReleaseActionTempOffSpelling) {
                    vTempOffSpellChecking();
                } else if (releaseAction == PHTVModifierReleaseActionTempOffEngine) {
                    vTempOffEngine();
                }

                _lastFlag = (CGEventFlags)modifierReleaseTransition.lastFlags;
                _keyPressedWhileSwitchModifiersHeld = modifierReleaseTransition.keyPressedWhileSwitchModifiersHeld;
                _keyPressedWhileEmojiModifiersHeld = modifierReleaseTransition.keyPressedWhileEmojiModifiersHeld;
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
        if (vOtherLanguage) {
            if (![PHTVInputSourceLanguageService shouldAllowVietnameseForOtherLanguageMode]) {
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
            PHTVEventTargetContextBox *targetContext = [PHTVAppContextService eventTargetContextForEventTargetPid:(int32_t)eventTargetPID
                                                                                                         safeMode:vSafeMode
                                                                                           spotlightCacheDurationMs:SPOTLIGHT_CACHE_DURATION_MS
                                                                                           appCharacteristicsMaxAgeMs:kAppCharacteristicsCacheMaxAgeMs];
            BOOL spotlightActive = targetContext.spotlightActive;
            NSString *effectiveBundleId = targetContext.effectiveBundleId;

            AppCharacteristics appChars = {NO, NO, NO, NO, NO};
            PHTVAppCharacteristicsBox *appCharsBox = targetContext.appCharacteristics;
            if (appCharsBox) {
                appChars.isSpotlightLike = appCharsBox.isSpotlightLike;
                appChars.needsPrecomposedBatched = appCharsBox.needsPrecomposedBatched;
                appChars.needsStepByStep = appCharsBox.needsStepByStep;
                appChars.containsUnicodeCompound = appCharsBox.containsUnicodeCompound;
                appChars.isSafari = appCharsBox.isSafari;
            }

            // Cache for send routines called later in this callback.
            _phtvEffectiveTargetBundleId = effectiveBundleId;
            _phtvCurrentAppCharacteristics = appChars;
            _phtvPostToHIDTap = targetContext.postToHIDTap;
            _phtvIsCliTarget = targetContext.isCliTarget;
            _phtvPostToSessionForCli = _phtvIsCliTarget;
            if (_phtvIsCliTarget) {
                ApplyCliProfile(targetContext.cliTimingProfile);
            } else {
                _phtvCliBackspaceDelayUs = 0;
                _phtvCliWaitAfterBackspaceUs = 0;
                _phtvCliTextDelayUs = 0;
                _phtvCliTextChunkSize = (int)[PHTVCliProfileService nonCliTextChunkSize];
                _phtvCliPostSendBlockUs = CLI_POST_SEND_BLOCK_MIN_US;
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
            NSString *eventTargetBundleId = targetContext.eventTargetBundleId;
            NSString *focusedBundleId = targetContext.focusedBundleId;
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
                            if (_syncKey.back() > 1 && (vCodeTable == 2 || !appChars.containsUnicodeCompound)) {
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
                BOOL isBrowserApp = targetContext.isBrowser;
                BOOL isSpotlightTarget = targetContext.postToHIDTap;
                BOOL isNotionApp = [effectiveBundleId isEqualToString:@"notion.id"];
                PHTVInputStrategyBox *inputStrategy = [PHTVInputStrategyService strategyForSpaceKey:(_keycode == KEY_SPACE)
                                                                                            slashKey:(_keycode == KEY_SLASH)
                                                                                             extCode:pData->extCode
                                                                                      backspaceCount:(int32_t)pData->backspaceCount
                                                                                        isBrowserApp:isBrowserApp
                                                                                    isSpotlightTarget:isSpotlightTarget
                                                                              needsPrecomposedBatched:appChars.needsPrecomposedBatched
                                                                                    browserFixEnabled:vFixRecommendBrowser
                                                                                           isNotionApp:isNotionApp];
                
                #ifdef DEBUG
                BOOL isSpecialApp = inputStrategy.isSpecialApp;
                BOOL isPotentialShortcut = inputStrategy.isPotentialShortcut;
                BOOL isBrowserFix = inputStrategy.isBrowserFix;
                BOOL shouldSkipSpace = inputStrategy.shouldSkipSpace;
                // Always log browser fix status to debug why it might be skipped
                NSLog(@"[BrowserFix] Status: vFix=%d, app=%@, isBrowser=%d => isFix=%d | bs=%d, ext=%d", 
                      vFixRecommendBrowser, effectiveBundleId, isBrowserApp, isBrowserFix, 
                      (int)pData->backspaceCount, pData->extCode);
                
                if (isBrowserFix && pData->backspaceCount > 0) {
                    NSLog(@"[BrowserFix] Checking logic: fix=%d, ext=%d, special=%d, skipSp=%d, shortcut=%d, bs=%d", 
                          isBrowserFix, pData->extCode, isSpecialApp, shouldSkipSpace, isPotentialShortcut, (int)pData->backspaceCount);
                }
                #endif

                if (inputStrategy.shouldTryBrowserAddressBarFix) {
                    if (pData->backspaceCount > 0) {
                        // DETECT ADDRESS BAR:
                        // Use accurate AX API check (cached) instead of unreliable spotlightActive
                        BOOL isAddrBar = [PHTVEventContextBridgeService isFocusedElementAddressBarForSafeMode:vSafeMode];
                        
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
                else if (inputStrategy.shouldTryLegacyNonBrowserFix) {
                    // Legacy logic for non-browser apps (Electron, Slack, etc.)
                    // Keep original behavior: shift-left for Chromium, EmptyChar for others
                    BOOL useShiftLeft = appChars.containsUnicodeCompound && pData->backspaceCount > 0;
                    
                    // NOTION CODE BLOCK FIX:
                    // If Notion Code Block detected, fallback to standard backspace (no Shift+Left, no EmptyChar)
                    // This fixes duplicates in code blocks where Shift+Left might fail to select or text is raw
                    BOOL isNotionCodeBlockDetected = isNotionApp &&
                                                     [PHTVEventContextBridgeService isNotionCodeBlockForSafeMode:vSafeMode];

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
                if (inputStrategy.shouldLogSpaceSkip) {
                    NSLog(@"[TextReplacement] SKIPPED SendEmptyCharacter for SPACE to avoid Text Replacement conflict");
                }
#endif

                // TEXT REPLACEMENT FIX: Skip backspace/newChar if this is SPACE after text replacement
                // Detection methods:
                // 1. External DELETE detected (arrow key selection) - HIGH CONFIDENCE
                // 2. Short backspace + code=3 without DELETE (mouse click selection) - FALLBACK
                int externalDeleteCount = (int)[PHTVEventContextBridgeService externalDeleteCountValue];

                // Log for debugging text replacement issues (only in Debug builds)
                #ifdef DEBUG
                if (pData->backspaceCount > 0 || pData->newCharCount > 0) {
                    NSLog(@"[PHTV TextReplacement] Key=%d: code=%d, extCode=%d, backspace=%d, newChar=%d, deleteCount=%d",
                          _keycode, pData->code, pData->extCode, (int)pData->backspaceCount, (int)pData->newCharCount, externalDeleteCount);
                }
                #endif

                if (_keycode == KEY_SPACE &&
                    (pData->backspaceCount > 0 || pData->newCharCount > 0)) {
                    PHTVTextReplacementDecisionBox *textReplacementDecisionBox =
                        [PHTVTextReplacementDecisionService evaluateForSpaceKey:YES
                                                                          code:pData->code
                                                                       extCode:pData->extCode
                                                                backspaceCount:(int32_t)pData->backspaceCount
                                                                  newCharCount:(int32_t)pData->newCharCount
                                                           externalDeleteCount:(int32_t)externalDeleteCount
                                                       restoreAndStartNewSessionCode:vRestoreAndStartNewSession
                                                                       willProcessCode:vWillProcess
                                                                           restoreCode:vRestore
                                                                          deleteWindowMs:TEXT_REPLACEMENT_DELETE_WINDOW_MS];

                    if (textReplacementDecisionBox.isExternalDelete) {
#ifdef DEBUG
                        NSLog(@"[TextReplacement] Text replacement detected - passing through event (code=%d, backspace=%d, newChar=%d, deleteCount=%d, elapsedMs=%llu)",
                              pData->code, (int)pData->backspaceCount, (int)pData->newCharCount, externalDeleteCount, textReplacementDecisionBox.matchedElapsedMs);
#endif
                        // CRITICAL: Return event to let macOS insert Space
                        return event;
                    }

                    if (textReplacementDecisionBox.isPatternMatch) {
#ifdef DEBUG
                        NSLog(@"[PHTV TextReplacement] Pattern %@ matched: code=%d, backspace=%d, newChar=%d, keycode=%d",
                              textReplacementDecisionBox.patternLabel ?: @"?",
                              pData->code, (int)pData->backspaceCount, (int)pData->newCharCount, _keycode);
                        NSLog(@"[PHTV TextReplacement] ✅ DETECTED - Skipping processing (code=%d, backspace=%d, newChar=%d)",
                              pData->code, (int)pData->backspaceCount, (int)pData->newCharCount);
#endif
                        // CRITICAL: Return event to let macOS insert Space
                        return event;
                    }

                    if (textReplacementDecisionBox.isFallbackNoMatch) {
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
                    if (isSpotlightTarget) {
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
