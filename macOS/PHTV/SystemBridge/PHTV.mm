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
#import <string.h>
#import "Engine.h"
#include "../Core/PHTVConstants.h"
#import <Sparkle/Sparkle.h>
#import "PHTV-Swift.h"

#define FRONT_APP [[NSWorkspace sharedWorkspace] frontmostApplication].bundleIdentifier

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
static const useconds_t CLI_PRE_BACKSPACE_DELAY_US = 4000;

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
    extern volatile int vSafeMode;

    static const uint64_t kAppCharacteristicsCacheMaxAgeMs = 10000;

    __attribute__((always_inline)) static inline void PostSyntheticEvent(CGEventRef e) {
        CGEventSetIntegerValueField(e, kCGEventSourceUserData, kPHTVEventMarker);
        if ([PHTVEventRuntimeContextService postToHIDTapEnabled]) {
            CGEventPost(kCGHIDEventTap, e);
        } else if ([PHTVEventRuntimeContextService postToSessionForCliEnabled]) {
            CGEventPost(kCGSessionEventTap, e);
        } else {
            CGEventTapProxy currentProxy = (CGEventTapProxy)(uintptr_t)[PHTVEventRuntimeContextService eventTapProxyRawValue];
            CGEventTapPostEvent(currentProxy, e);
        }
    }

    CGEventSourceRef myEventSource = NULL;
    vKeyHookState* pData;
    CGEventRef eventBackSpaceDown;
    CGEventRef eventBackSpaceUp;

    
    void PHTVInit() {
        [PHTVCoreSettingsBootstrapService loadFromUserDefaults];

        [PHTVSafeModeStartupService recoverAndValidateAccessibilityState];

        [PHTVLayoutCompatibilityService autoEnableIfNeeded];

        myEventSource = CGEventSourceCreate(kCGEventSourceStatePrivate);
        pData = (vKeyHookState*)vKeyInit();

        [PHTVTypingSyncStateService setupSyncKeyCapacity:(int32_t)SYNC_KEY_RESERVE_SIZE];

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
            [PHTVTypingSyncStateService clearSyncKey];
        }
        if (sessionResetTransition.shouldPrimeUppercaseFirstChar) {
            vPrimeUpperCaseFirstChar();
        }
        [PHTVModifierRuntimeStateService applySessionResetTransition:sessionResetTransition];

        // Release barrier: ensure state reset is visible to all threads
        __atomic_thread_fence(__ATOMIC_RELEASE);

        #ifdef DEBUG
        NSLog(@"[RequestNewSession] Session reset complete");
        #endif
    }

    void RequestNewSession() {
        RequestNewSessionInternal(true);
    }
    
    void InsertKeyLength(const Uint8& len) {
        [PHTVTypingSyncStateService appendSyncKeyLength:(int32_t)len];
    }
    
    void SendPureCharacter(const Uint16& ch) {
        CGEventRef newEventDown = CGEventCreateKeyboardEvent(myEventSource, 0, true);
        CGEventRef newEventUp = CGEventCreateKeyboardEvent(myEventSource, 0, false);
        ApplyKeyboardTypeAndFlags(newEventDown, newEventUp);
        CGEventKeyboardSetUnicodeString(newEventDown, 1, &ch);
        CGEventKeyboardSetUnicodeString(newEventUp, 1, &ch);
        PostSyntheticEvent(newEventDown);
        PostSyntheticEvent(newEventUp);
        if ([PHTVEventRuntimeContextService postToHIDTapEnabled]) [PHTVTimingService spotlightTinyDelay];
        CFRelease(newEventDown);
        CFRelease(newEventUp);
        if (IS_DOUBLE_CODE(vCodeTable)) {
            InsertKeyLength(1);
        }
    }
    
    void SendKeyCode(Uint32 data) {
        UniChar newChar = (Uint16)data;
        UniChar newCharHi = 0;
        if (!(data & CHAR_CODE_MASK)) {
            if (IS_DOUBLE_CODE(vCodeTable)) //VNI
                InsertKeyLength(1);
            
            CGEventRef newEventDown = CGEventCreateKeyboardEvent(myEventSource, newChar, true);
            CGEventRef newEventUp = CGEventCreateKeyboardEvent(myEventSource, newChar, false);
            CGEventFlags privateFlag = CGEventGetFlags(newEventDown);
            
            if (data & CAPS_MASK) {
                privateFlag |= kCGEventFlagMaskShift;
            } else {
                privateFlag &= ~kCGEventFlagMaskShift;
            }
            privateFlag |= kCGEventFlagMaskNonCoalesced;
            
            // CRITICAL FIX: Clear Fn/Globe flag to prevent triggering system hotkeys
            // (e.g., Fn+E opens Character Viewer/Emoji picker on macOS)
            // This prevents the bug where typing 'eee' triggers the emoji picker
            privateFlag &= ~kCGEventFlagMaskSecondaryFn;
            
            CGEventSetFlags(newEventDown, privateFlag);
            CGEventSetFlags(newEventUp, privateFlag);
            ApplyKeyboardTypeAndFlags(newEventDown, newEventUp);
            PostSyntheticEvent(newEventDown);
            PostSyntheticEvent(newEventUp);
            if ([PHTVEventRuntimeContextService postToHIDTapEnabled]) [PHTVTimingService spotlightTinyDelay];
            CFRelease(newEventDown);
            CFRelease(newEventUp);
        } else {
            if (vCodeTable == 0) { //unicode 2 bytes code
                CGEventRef newEventDown = CGEventCreateKeyboardEvent(myEventSource, 0, true);
                CGEventRef newEventUp = CGEventCreateKeyboardEvent(myEventSource, 0, false);
                ApplyKeyboardTypeAndFlags(newEventDown, newEventUp);
                CGEventKeyboardSetUnicodeString(newEventDown, 1, &newChar);
                CGEventKeyboardSetUnicodeString(newEventUp, 1, &newChar);
                PostSyntheticEvent(newEventDown);
                PostSyntheticEvent(newEventUp);
                if ([PHTVEventRuntimeContextService postToHIDTapEnabled]) [PHTVTimingService spotlightTinyDelay];
                CFRelease(newEventDown);
                CFRelease(newEventUp);
            } else if (vCodeTable == 1 || vCodeTable == 2 || vCodeTable == 4) { //others such as VNI Windows, TCVN3: 1 byte code
                newCharHi = HIBYTE(newChar);
                newChar = LOBYTE(newChar);
                
                CGEventRef newEventDown = CGEventCreateKeyboardEvent(myEventSource, 0, true);
                CGEventRef newEventUp = CGEventCreateKeyboardEvent(myEventSource, 0, false);
                ApplyKeyboardTypeAndFlags(newEventDown, newEventUp);
                CGEventKeyboardSetUnicodeString(newEventDown, 1, &newChar);
                CGEventKeyboardSetUnicodeString(newEventUp, 1, &newChar);
                PostSyntheticEvent(newEventDown);
                PostSyntheticEvent(newEventUp);
                if ([PHTVEventRuntimeContextService postToHIDTapEnabled]) [PHTVTimingService spotlightTinyDelay];
                if (newCharHi > 32) {
                    if (vCodeTable == 2) //VNI
                        InsertKeyLength(2);
                    CFRelease(newEventDown);
                    CFRelease(newEventUp);
                    newEventDown = CGEventCreateKeyboardEvent(myEventSource, 0, true);
                    newEventUp = CGEventCreateKeyboardEvent(myEventSource, 0, false);
                    ApplyKeyboardTypeAndFlags(newEventDown, newEventUp);
                    CGEventKeyboardSetUnicodeString(newEventDown, 1, &newCharHi);
                    CGEventKeyboardSetUnicodeString(newEventUp, 1, &newCharHi);
                    PostSyntheticEvent(newEventDown);
                    PostSyntheticEvent(newEventUp);
                    if ([PHTVEventRuntimeContextService postToHIDTapEnabled]) [PHTVTimingService spotlightTinyDelay];
                } else {
                    if (vCodeTable == 2) //VNI
                        InsertKeyLength(1);
                }
                CFRelease(newEventDown);
                CFRelease(newEventUp);
            } else if (vCodeTable == 3) { //Unicode Compound
                UniChar uniChar[2];
                newCharHi = (newChar >> 13);
                newChar &= 0x1FFF;
                uniChar[0] = newChar;
                uniChar[1] = newCharHi > 0 ? (_unicodeCompoundMark[newCharHi - 1]) : 0;
                InsertKeyLength(newCharHi > 0 ? 2 : 1);
                CGEventRef newEventDown = CGEventCreateKeyboardEvent(myEventSource, 0, true);
                CGEventRef newEventUp = CGEventCreateKeyboardEvent(myEventSource, 0, false);
                ApplyKeyboardTypeAndFlags(newEventDown, newEventUp);
                CGEventKeyboardSetUnicodeString(newEventDown, (newCharHi > 0 ? 2 : 1), uniChar);
                CGEventKeyboardSetUnicodeString(newEventUp, (newCharHi > 0 ? 2 : 1), uniChar);
                PostSyntheticEvent(newEventDown);
                PostSyntheticEvent(newEventUp);
                if ([PHTVEventRuntimeContextService postToHIDTapEnabled]) [PHTVTimingService spotlightTinyDelay];
                CFRelease(newEventDown);
                CFRelease(newEventUp);
            }
        }
    }

    void SendEmptyCharacter() {
        if (IS_DOUBLE_CODE(vCodeTable)) //VNI or Unicode Compound
            InsertKeyLength(1);

        UniChar newChar = 0x202F; //empty char
        if ([PHTVAppContextService needsNiceSpaceForBundleId:FRONT_APP]) {
            newChar = 0x200C; //Unicode character with empty space
        }

        CGEventRef newEventDown = CGEventCreateKeyboardEvent(myEventSource, 0, true);
        CGEventRef newEventUp = CGEventCreateKeyboardEvent(myEventSource, 0, false);
        ApplyKeyboardTypeAndFlags(newEventDown, newEventUp);
        CGEventKeyboardSetUnicodeString(newEventDown, 1, &newChar);
        CGEventKeyboardSetUnicodeString(newEventUp, 1, &newChar);
        PostSyntheticEvent(newEventDown);
        PostSyntheticEvent(newEventUp);
        if ([PHTVEventRuntimeContextService postToHIDTapEnabled]) [PHTVTimingService spotlightTinyDelay];
        CFRelease(newEventDown);
        CFRelease(newEventUp);

        // BROWSER FIX REMOVED: Shift+Left strategy eliminates need for delays
        // No delay needed after empty character - the select-then-delete approach handles it
    }
    
    void SendVirtualKey(const Byte& vKey) {
        CGEventRef eventVkeyDown = CGEventCreateKeyboardEvent (myEventSource, vKey, true);
        CGEventRef eventVkeyUp = CGEventCreateKeyboardEvent (myEventSource, vKey, false);
        
        PostSyntheticEvent(eventVkeyDown);
        PostSyntheticEvent(eventVkeyUp);
        
        CFRelease(eventVkeyDown);
        CFRelease(eventVkeyUp);
    }

    void SendPhysicalBackspace() {
        if ([PHTVEventRuntimeContextService postToHIDTapEnabled]) {
            CGEventRef bsDown = CGEventCreateKeyboardEvent(myEventSource, KEY_DELETE, true);
            CGEventRef bsUp = CGEventCreateKeyboardEvent(myEventSource, KEY_DELETE, false);
            if ([PHTVEventRuntimeContextService currentKeyboardTypeValue] != 0) {
                CGEventSetIntegerValueField(bsDown, kCGKeyboardEventKeyboardType, [PHTVEventRuntimeContextService currentKeyboardTypeValue]);
                CGEventSetIntegerValueField(bsUp, kCGKeyboardEventKeyboardType, [PHTVEventRuntimeContextService currentKeyboardTypeValue]);
            }
            CGEventFlags bsFlags = CGEventGetFlags(bsDown);
            bsFlags |= kCGEventFlagMaskNonCoalesced;
            bsFlags &= ~kCGEventFlagMaskSecondaryFn;
            CGEventSetFlags(bsDown, bsFlags);
            CGEventSetFlags(bsUp, bsFlags);
            PostSyntheticEvent(bsDown);
            PostSyntheticEvent(bsUp);
            [PHTVTimingService spotlightTinyDelay];
            CFRelease(bsDown);
            CFRelease(bsUp);
        } else {
            PostSyntheticEvent(eventBackSpaceDown);
            PostSyntheticEvent(eventBackSpaceUp);
        }
    }

    static inline void ConsumeSyncKeyOnBackspace() {
        if (!IS_DOUBLE_CODE(vCodeTable)) {
            return;
        }
        [PHTVTypingSyncStateService consumeSyncKeyOnBackspace];
    }

    void SendBackspace() {
        SendPhysicalBackspace();

        if (IS_DOUBLE_CODE(vCodeTable)) { //VNI or Unicode Compound
            if (![PHTVTypingSyncStateService syncKeyIsEmpty]) {
                if ([PHTVTypingSyncStateService syncKeyBackValue] > 1) {
                    if (!(vCodeTable == 3 && [PHTVEventRuntimeContextService appContainsUnicodeCompound])) {
                        SendPhysicalBackspace();
                    }
                }
                [PHTVTypingSyncStateService popSyncKeyIfAny];
            }
        }
    }


    void SendShiftAndLeftArrow() {
        CGEventRef eventVkeyDown = CGEventCreateKeyboardEvent (myEventSource, KEY_LEFT, true);
        CGEventRef eventVkeyUp = CGEventCreateKeyboardEvent (myEventSource, KEY_LEFT, false);
        CGEventFlags privateFlag = CGEventGetFlags(eventVkeyDown);
        privateFlag |= kCGEventFlagMaskShift;
        CGEventSetFlags(eventVkeyDown, privateFlag);
        CGEventSetFlags(eventVkeyUp, privateFlag);
        
        PostSyntheticEvent(eventVkeyDown);
        PostSyntheticEvent(eventVkeyUp);
        
        if (IS_DOUBLE_CODE(vCodeTable) && ![PHTVTypingSyncStateService syncKeyIsEmpty]) { //VNI or Unicode Compound
            if ([PHTVTypingSyncStateService syncKeyBackValue] > 1) {
                if (!(vCodeTable == 3 && [PHTVEventRuntimeContextService appContainsUnicodeCompound])) {
                    PostSyntheticEvent(eventVkeyDown);
                    PostSyntheticEvent(eventVkeyUp);
                }
            }
            [PHTVTypingSyncStateService popSyncKeyIfAny];
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
        double cliSpeedFactor = [PHTVCliRuntimeStateService currentSpeedFactor];
        uint64_t cliPostSendBlockUs = [PHTVCliRuntimeStateService cliPostSendBlockUs];
        uint64_t effectiveDelayUs = interDelayUs;
        if ([PHTVEventRuntimeContextService isCliTargetEnabled] && interDelayUs > 0) {
            effectiveDelayUs = [PHTVTimingService scaleDelayMicroseconds:interDelayUs factor:cliSpeedFactor];
        }
        if ([PHTVEventRuntimeContextService isCliTargetEnabled]) {
            uint64_t totalBlockUs = [PHTVTimingService scaleDelayMicroseconds:cliPostSendBlockUs factor:cliSpeedFactor];
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

            CGEventRef newEventDown = CGEventCreateKeyboardEvent(myEventSource, 0, true);
            CGEventRef newEventUp = CGEventCreateKeyboardEvent(myEventSource, 0, false);
            if ([PHTVEventRuntimeContextService currentKeyboardTypeValue] != 0) {
                CGEventSetIntegerValueField(newEventDown, kCGKeyboardEventKeyboardType, [PHTVEventRuntimeContextService currentKeyboardTypeValue]);
                CGEventSetIntegerValueField(newEventUp, kCGKeyboardEventKeyboardType, [PHTVEventRuntimeContextService currentKeyboardTypeValue]);
            }
            CGEventFlags flags = CGEventGetFlags(newEventDown) | kCGEventFlagMaskNonCoalesced;
            flags &= ~kCGEventFlagMaskSecondaryFn;
            CGEventSetFlags(newEventDown, flags);
            CGEventSetFlags(newEventUp, flags);
            CGEventKeyboardSetUnicodeString(newEventDown, chunkLen, chars + i);
            CGEventKeyboardSetUnicodeString(newEventUp, chunkLen, chars + i);
            PostSyntheticEvent(newEventDown);
            PostSyntheticEvent(newEventUp);
            CFRelease(newEventDown);
            CFRelease(newEventUp);
            if (effectiveDelayUs > 0 && (i + chunkSize) < len) {
                useconds_t sleepUs = [PHTVTimingService clampToUseconds:effectiveDelayUs];
                usleep(sleepUs);
            }
        }

        if ([PHTVEventRuntimeContextService isCliTargetEnabled]) {
            uint64_t totalBlockUs = [PHTVTimingService scaleDelayMicroseconds:cliPostSendBlockUs factor:cliSpeedFactor];
            if (effectiveDelayUs > 0 && len > 1) {
                totalBlockUs += effectiveDelayUs * (uint64_t)(len - 1);
            }
            SetCliBlockForMicroseconds(totalBlockUs);
        }
    }

    // Consolidated helper function to send multiple backspaces
    // Delays and throttling removed for standard application behavior
    void SendBackspaceSequenceWithDelay(int count) {
        if (count <= 0) return;

        if ([PHTVEventRuntimeContextService isCliTargetEnabled]) {
            double cliSpeedFactor = [PHTVCliRuntimeStateService currentSpeedFactor];
            uint64_t cliBackspaceDelayUs = [PHTVCliRuntimeStateService cliBackspaceDelayUs];
            uint64_t cliWaitAfterBackspaceUs = [PHTVCliRuntimeStateService cliWaitAfterBackspaceUs];
            uint64_t cliPostSendBlockUs = [PHTVCliRuntimeStateService cliPostSendBlockUs];
            useconds_t backspaceDelay = [PHTVTimingService scaleDelayUseconds:[PHTVTimingService clampToUseconds:cliBackspaceDelayUs] factor:cliSpeedFactor];
            useconds_t waitDelay = [PHTVTimingService scaleDelayUseconds:[PHTVTimingService clampToUseconds:cliWaitAfterBackspaceUs] factor:cliSpeedFactor];
            uint64_t totalBlockUs = [PHTVTimingService scaleDelayMicroseconds:cliPostSendBlockUs factor:cliSpeedFactor];
            if (backspaceDelay > 0 && count > 0) {
                totalBlockUs += (uint64_t)backspaceDelay * (uint64_t)count;
            }
            totalBlockUs += (uint64_t)waitDelay;
            SetCliBlockForMicroseconds(totalBlockUs);
            if (cliSpeedFactor > 1.05) {
                useconds_t preDelay = [PHTVTimingService scaleDelayUseconds:CLI_PRE_BACKSPACE_DELAY_US factor:cliSpeedFactor];
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

    void SendNewCharString(const bool& dataFromMacro=false,
                           const Uint16& offset=0,
                           const CGKeyCode keycode=0,
                           const CGEventFlags flags=0) {
        int outputIndex = 0;
        int loopIndex = 0;
        int newCharSize = dataFromMacro ? (int)pData->macroData.size() : (int)pData->newCharCount;
        Uint16 newCharString[MAX_UNICODE_STRING];
        bool willContinueSending = false;
        bool willSendControlKey = false;
        
        // Treat as Spotlight target if callback selected HID/Spotlight-safe path.
        BOOL isSpotlightTarget = [PHTVEventRuntimeContextService postToHIDTapEnabled] || [PHTVEventRuntimeContextService appIsSpotlightLike];
        // Some apps need precomposed Unicode but still rely on batched synthetic events.
        BOOL isPrecomposedBatched = [PHTVEventRuntimeContextService appNeedsPrecomposedBatched];
        // Force precomposed for: Unicode Compound (code 3) on Spotlight, OR any Unicode on WhatsApp-like apps
        BOOL forcePrecomposed = ((vCodeTable == 3) && isSpotlightTarget) ||
                                 ((vCodeTable == 0 || vCodeTable == 3) && isPrecomposedBatched);
        
        if (newCharSize > 0) {
            for (loopIndex = dataFromMacro ? (int)offset : (int)pData->newCharCount - 1 - (int)offset;
                dataFromMacro ? loopIndex < (int)pData->macroData.size() : loopIndex >= 0;
                 dataFromMacro ? loopIndex++ : loopIndex--) {
                
                if (outputIndex >= 16) {
                    willContinueSending = true;
                    break;
                }
                
                Uint32 tempChar = DYNA_DATA(dataFromMacro, loopIndex);
                if (tempChar & PURE_CHARACTER_MASK) {
                    newCharString[outputIndex++] = tempChar;
                    if (IS_DOUBLE_CODE(vCodeTable)) {
                        InsertKeyLength(1);
                    }
                } else if (!(tempChar & CHAR_CODE_MASK)) {
                    if (IS_DOUBLE_CODE(vCodeTable)) //VNI
                        InsertKeyLength(1);
                    newCharString[outputIndex++] = keyCodeToCharacter(tempChar);
                } else {
                    if (vCodeTable == 0) {  //unicode 2 bytes code
                        newCharString[outputIndex++] = tempChar;
                    } else if (vCodeTable == 1 || vCodeTable == 2 || vCodeTable == 4) { //others such as VNI Windows, TCVN3: 1 byte code
                        UniChar newChar = tempChar;
                        UniChar newCharHi = HIBYTE(newChar);
                        newChar = LOBYTE(newChar);
                        newCharString[outputIndex++] = newChar;
                        
                        if (newCharHi > 32) {
                            if (vCodeTable == 2) //VNI
                                InsertKeyLength(2);
                            newCharString[outputIndex++] = newCharHi;
                            newCharSize++;
                        } else {
                            if (vCodeTable == 2) //VNI
                                InsertKeyLength(1);
                        }
                    } else if (vCodeTable == 3) { //Unicode Compound
                        UniChar newChar = tempChar;
                        UniChar newCharHi = (newChar >> 13);
                        newChar &= 0x1FFF;
                        
                        // Always build compound form first (will be converted to precomposed later if needed)
                        InsertKeyLength(newCharHi > 0 ? 2 : 1);
                        newCharString[outputIndex++] = newChar;
                        if (newCharHi > 0) {
                            newCharSize++;
                            newCharString[outputIndex++] = _unicodeCompoundMark[newCharHi - 1];
                        }
                        
                    }
                }
            }//end for
        }
        
        if (!willContinueSending && (pData->code == vRestore || pData->code == vRestoreAndStartNewSession)) { //if is restore
            if (keyCodeToCharacter(keycode) != 0) {
                newCharSize++;
                newCharString[outputIndex++] = keyCodeToCharacter(keycode | ((flags & kCGEventFlagMaskAlphaShift) || (flags & kCGEventFlagMaskShift) ? CAPS_MASK : 0));
            } else {
                willSendControlKey = true;
            }
        }
        if (!willContinueSending && pData->code == vRestoreAndStartNewSession) {
            startNewSession();
        }
        
        // If we need to force precomposed Unicode (for apps like Spotlight), 
        // convert the entire string from compound to precomposed form
        Uint16 _finalCharString[MAX_UNICODE_STRING];
        int _finalCharSize = willContinueSending ? 16 : newCharSize - (int)offset;
        
        if (forcePrecomposed && _finalCharSize > 0) {
            // Create NSString from Unicode characters and get precomposed version
            NSString *tempStr = [NSString stringWithCharacters:(const unichar *)newCharString length:_finalCharSize];
            NSString *precomposed = [tempStr precomposedStringWithCanonicalMapping];
            _finalCharSize = (int)[precomposed length];
            [precomposed getCharacters:(unichar *)_finalCharString range:NSMakeRange(0, _finalCharSize)];
        } else {
            // Use original string
            memcpy(_finalCharString, newCharString, _finalCharSize * sizeof(Uint16));
        }

        if (isSpotlightTarget) {
            // Try AX API first - it's atomic and most reliable when it works
            NSString *insertStr = [NSString stringWithCharacters:(const unichar *)_finalCharString length:_finalCharSize];
            int backspaceCount = (int)[PHTVEventRuntimeContextService takePendingBackspaceCount];

            BOOL shouldVerify = (backspaceCount > 0);
            BOOL axSucceeded = [PHTVEventContextBridgeService replaceFocusedTextViaAXWithBackspaceCount:(int32_t)backspaceCount
                                                                                               insertText:insertStr
                                                                                                   verify:shouldVerify
                                                                                                 safeMode:vSafeMode];
            if (axSucceeded) {
                goto FinalizeSend;
            }

            // AX failed - fallback to synthetic events
            SendBackspaceSequenceWithDelay(backspaceCount);

            CGEventRef newEventDown = CGEventCreateKeyboardEvent(myEventSource, 0, true);
            CGEventRef newEventUp = CGEventCreateKeyboardEvent(myEventSource, 0, false);
            if ([PHTVEventRuntimeContextService currentKeyboardTypeValue] != 0) {
                CGEventSetIntegerValueField(newEventDown, kCGKeyboardEventKeyboardType, [PHTVEventRuntimeContextService currentKeyboardTypeValue]);
                CGEventSetIntegerValueField(newEventUp, kCGKeyboardEventKeyboardType, [PHTVEventRuntimeContextService currentKeyboardTypeValue]);
            }
            CGEventFlags uFlags = CGEventGetFlags(newEventDown) | kCGEventFlagMaskNonCoalesced;
            // Clear Fn/Globe flag to prevent triggering system hotkeys
            uFlags &= ~kCGEventFlagMaskSecondaryFn;
            CGEventSetFlags(newEventDown, uFlags);
            CGEventSetFlags(newEventUp, uFlags);
            CGEventKeyboardSetUnicodeString(newEventDown, _finalCharSize, _finalCharString);
            CGEventKeyboardSetUnicodeString(newEventUp, _finalCharSize, _finalCharString);
            PostSyntheticEvent(newEventDown);
            PostSyntheticEvent(newEventUp);
            CFRelease(newEventDown);
            CFRelease(newEventUp);
            goto FinalizeSend;
        } else {
            if ([PHTVEventRuntimeContextService isCliTargetEnabled]) {
                int chunkSize = (int)[PHTVCliRuntimeStateService cliTextChunkSize];
                if (chunkSize < 1) {
                    chunkSize = 1;
                }
                SendUnicodeStringChunked(_finalCharString,
                                         _finalCharSize,
                                         chunkSize,
                                         [PHTVCliRuntimeStateService cliTextDelayUs]);
                goto FinalizeSend;
            }
            CGEventRef newEventDown = CGEventCreateKeyboardEvent(myEventSource, 0, true);
            CGEventRef newEventUp = CGEventCreateKeyboardEvent(myEventSource, 0, false);
            if ([PHTVEventRuntimeContextService currentKeyboardTypeValue] != 0) {
                CGEventSetIntegerValueField(newEventDown, kCGKeyboardEventKeyboardType, [PHTVEventRuntimeContextService currentKeyboardTypeValue]);
                CGEventSetIntegerValueField(newEventUp, kCGKeyboardEventKeyboardType, [PHTVEventRuntimeContextService currentKeyboardTypeValue]);
            }
            CGEventKeyboardSetUnicodeString(newEventDown, _finalCharSize, _finalCharString);
            CGEventKeyboardSetUnicodeString(newEventUp, _finalCharSize, _finalCharString);
            PostSyntheticEvent(newEventDown);
            PostSyntheticEvent(newEventUp);
            CFRelease(newEventDown);
            CFRelease(newEventUp);
        }

    FinalizeSend:
        if (willContinueSending) {
            SendNewCharString(dataFromMacro, dataFromMacro ? (Uint16)loopIndex : 16, keycode, flags);
        }
        
        //the case when hCode is vRestore or vRestoreAndStartNewSession, the word is invalid and last key is control key such as TAB, LEFT ARROW, RIGHT ARROW,...
        if (willSendControlKey) {
            SendKeyCode(keycode);
        }
    }
            
    void handleMacro(CGKeyCode keycode, CGEventFlags flags) {
        // PERFORMANCE: Use cached bundle ID instead of querying AX API
        NSString *effectiveTarget = [PHTVEventRuntimeContextService effectiveTargetBundleIdValue];
        if (effectiveTarget == nil) {
            effectiveTarget = [PHTVAppContextService focusedBundleIdForSafeMode:vSafeMode
                                                                 cacheDurationMs:SPOTLIGHT_CACHE_DURATION_MS];
            if (effectiveTarget == nil) {
                effectiveTarget = FRONT_APP;
            }
        }
        PHTVMacroPlanBox *macroPlan =
            [PHTVInputStrategyService macroPlanForPostToHIDTap:[PHTVEventRuntimeContextService postToHIDTapEnabled]
                                            appIsSpotlightLike:[PHTVEventRuntimeContextService appIsSpotlightLike]
                                              browserFixEnabled:vFixRecommendBrowser
                                           originalBackspaceCount:(int32_t)pData->backspaceCount
                                                     cliTarget:[PHTVEventRuntimeContextService isCliTargetEnabled]
                                              globalStepByStep:vSendKeyStepByStep
                                              appNeedsStepByStep:[PHTVEventRuntimeContextService appNeedsStepByStep]];
        BOOL isSpotlightLike = macroPlan.isSpotlightLikeTarget;

        #ifdef DEBUG
        NSLog(@"[Macro] handleMacro: target='%@', isSpotlight=%d (postToHID=%d), backspaceCount=%d, macroSize=%zu",
              effectiveTarget, isSpotlightLike, [PHTVEventRuntimeContextService postToHIDTapEnabled], (int)pData->backspaceCount, pData->macroData.size());
        #endif

        // CRITICAL FIX: Spotlight requires AX API for macro replacement
        // Synthetic backspace events don't work reliably in Spotlight
        if (macroPlan.shouldTryAXReplacement) {
            BOOL replacedByAX =
                [PHTVEngineDataBridge replaceSpotlightLikeMacroIfNeeded:(isSpotlightLike ? 1 : 0)
                                                         backspaceCount:(int32_t)pData->backspaceCount
                                                              macroData:pData->macroData.data()
                                                                  count:(int32_t)pData->macroData.size()
                                                              codeTable:(int32_t)vCodeTable
                                                               safeMode:vSafeMode];
            if (replacedByAX) {
                #ifdef DEBUG
                NSLog(@"[Macro] Spotlight: AX API succeeded");
                #endif
                return;
            }

            #ifdef DEBUG
            NSLog(@"[Macro] Spotlight: AX API failed, falling back to synthetic events");
            #endif
            // AX failed - fallback to synthetic events below
        }

        //fix autocomplete
        if (macroPlan.shouldApplyBrowserFix) {
            SendEmptyCharacter();
            pData->backspaceCount = (Byte)macroPlan.adjustedBackspaceCount;
        }

        // Send backspace if needed
        if (pData->backspaceCount > 0) {
            SendBackspaceSequenceWithDelay(pData->backspaceCount);
        }

        //send real data - use step by step for timing sensitive apps like Spotlight
        BOOL useStepByStep = macroPlan.useStepByStepSend;
        if (!useStepByStep) {
            SendNewCharString(true, 0, keycode, flags);
        } else {
            int32_t macroCount = (int32_t)pData->macroData.size();
            double cliSpeedFactor = [PHTVCliRuntimeStateService currentSpeedFactor];
            uint64_t scaledCliTextDelayUs = [PHTVEventRuntimeContextService isCliTargetEnabled] ? (uint64_t)[PHTVTimingService scaleDelayUseconds:[PHTVTimingService clampToUseconds:[PHTVCliRuntimeStateService cliTextDelayUs]] factor:cliSpeedFactor] : 0;
            uint64_t scaledCliPostSendBlockUs = [PHTVEventRuntimeContextService isCliTargetEnabled] ? [PHTVTimingService scaleDelayMicroseconds:[PHTVCliRuntimeStateService cliPostSendBlockUs] factor:cliSpeedFactor] : 0;
            PHTVSendSequencePlanBox *sendPlan =
                [PHTVSendSequenceService sequencePlanForCliTarget:[PHTVEventRuntimeContextService isCliTargetEnabled]
                                                         itemCount:macroCount
                                              scaledCliTextDelayUs:(int64_t)scaledCliTextDelayUs
                                         scaledCliPostSendBlockUs:(int64_t)scaledCliPostSendBlockUs];
            useconds_t interItemDelayUs = [PHTVTimingService clampToUseconds:(uint64_t)MAX((int64_t)0, sendPlan.interItemDelayUs)];

            for (int i = 0; i < pData->macroData.size(); i++) {
                if (pData->macroData[i] & PURE_CHARACTER_MASK) {
                    SendPureCharacter(pData->macroData[i]);
                } else {
                    SendKeyCode(pData->macroData[i]);
                }
                if (interItemDelayUs > 0 && i + 1 < pData->macroData.size()) {
                    usleep(interItemDelayUs);
                }
            }
            if (sendPlan.shouldScheduleCliBlock) {
                SetCliBlockForMicroseconds((uint64_t)MAX((int64_t)0, sendPlan.cliBlockUs));
            }
        }

        // Send trigger key for non-Spotlight apps
        if (macroPlan.shouldSendTriggerKey) {
            SendKeyCode(keycode | (flags & kCGEventFlagMaskShift ? CAPS_MASK : 0));
        }
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
        if (type == kCGEventKeyDown) {
            uint64_t remainUs = [PHTVCliRuntimeStateService remainingBlockMicrosecondsForNowMachTime:mach_absolute_time()];
            if (remainUs > 0) {
                usleep([PHTVTimingService clampToUseconds:remainUs]);
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

        [PHTVEventRuntimeContextService clearCliPostFlags];
        CGEventFlags eventFlags = CGEventGetFlags(event);
        CGKeyCode eventKeycode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);

        // Track text-replacement keydown patterns (external DELETE and following SPACE).
        if (type == kCGEventKeyDown) {
            [PHTVTextReplacementDecisionService handleKeyDownTextReplacementTrackingForKeyCode:(int32_t)eventKeycode
                                                                                 deleteKeyCode:(int32_t)KEY_DELETE
                                                                                  spaceKeyCode:(int32_t)KEY_SPACE
                                                                                  sourceStateID:CGEventGetIntegerValueField(event, kCGEventSourceStateID)];
        }

        // Handle Spotlight detection optimization.
        [PHTVEventContextBridgeService handleSpotlightCacheInvalidationForType:type
                                                                       keycode:(uint16_t)eventKeycode
                                                                         flags:eventFlags];

        // If pause key is being held, strip pause modifier from events to prevent special characters
        // BUT only if no other modifiers are pressed (to preserve system shortcuts like Option+Cmd+V)
        if ([PHTVModifierRuntimeStateService pausePressedValue] && (type == kCGEventKeyDown || type == kCGEventKeyUp)) {
            if ([PHTVHotkeyService shouldStripPauseModifierWithFlags:(uint64_t)eventFlags
                                                         pauseKeyCode:(int32_t)vPauseKey]) {
                CGEventFlags newFlags = (CGEventFlags)[PHTVHotkeyService stripPauseModifierForFlags:(uint64_t)eventFlags
                                                                                        pauseKeyCode:(int32_t)vPauseKey];
                CGEventSetFlags(event, newFlags);
                eventFlags = newFlags;  // Update local flag as well
            }
        }

        if (type == kCGEventKeyDown && vPerformLayoutCompat) {
            // If conversion fail, use current keycode
           eventKeycode = ConvertEventToKeyboardLayoutCompatKeyCode(event, eventKeycode);
        }
        
        // Switch-language / quick-convert / emoji hotkey handling
        if (type == kCGEventKeyDown) {
            int32_t hotkeyAction =
                [PHTVEventContextBridgeService processKeyDownHotkeyAndApplyStateForKeyCode:(uint16_t)eventKeycode
                                                                                currentFlags:(uint64_t)eventFlags
                                                                                 switchHotkey:(int32_t)vSwitchKeyStatus
                                                                                convertHotkey:(int32_t)gConvertToolOptions.hotKey
                                                                                 emojiEnabled:(int32_t)vEnableEmojiHotkey
                                                                               emojiModifiers:(int32_t)vEmojiHotkeyModifiers
                                                                          emojiHotkeyKeyCode:(int32_t)vEmojiHotkeyKeyCode];
            if (hotkeyAction != PHTVKeyDownHotkeyActionNone) {
                if ([PHTVRuntimeUIBridgeService handleKeyDownHotkeyAction:hotkeyAction]) {
                    [PHTVModifierRuntimeStateService setLastFlagsValue:0];
                    [PHTVModifierRuntimeStateService setHasJustUsedHotKeyValue:YES];
                    return NULL;
                }
            }
        }

        if (type == kCGEventKeyDown) {
            if (vUpperCaseFirstChar && !vUpperCaseExcludedForCurrentApp) {
                Uint32 keyWithCaps = eventKeycode | (((eventFlags & kCGEventFlagMaskShift) || (eventFlags & kCGEventFlagMaskAlphaShift)) ? CAPS_MASK : 0);
                Uint16 keyCharacter = keyCodeToCharacter(keyWithCaps);
                BOOL isNavigationKey = phtv_mac_key_is_navigation(eventKeycode);
                BOOL shouldPrimeUppercase =
                    [PHTVEventContextBridgeService shouldPrimeUppercaseOnKeyDownWithFlags:(uint64_t)eventFlags
                                                                                   keyCode:(uint16_t)eventKeycode
                                                                              keyCharacter:(uint16_t)keyCharacter
                                                                           isNavigationKey:isNavigationKey
                                                                                  safeMode:vSafeMode
                                                                          uppercaseEnabled:(int32_t)vUpperCaseFirstChar
                                                                         uppercaseExcluded:(int32_t)vUpperCaseExcludedForCurrentApp];
                if (shouldPrimeUppercase) {
                    vPrimeUpperCaseFirstChar();
                }
            }

            [PHTVEventContextBridgeService applyKeyDownModifierTrackingForFlags:(uint64_t)eventFlags
                                                                 restoreOnEscape:(int32_t)vRestoreOnEscape
                                                                 customEscapeKey:(int32_t)vCustomEscapeKey
                                                                      switchHotkey:(int32_t)vSwitchKeyStatus
                                                                     convertHotkey:(int32_t)gConvertToolOptions.hotKey
                                                                      emojiEnabled:(int32_t)vEnableEmojiHotkey
                                                                    emojiModifiers:(int32_t)vEmojiHotkeyModifiers
                                                               emojiHotkeyKeyCode:(int32_t)vEmojiHotkeyKeyCode];
        } else if (type == kCGEventFlagsChanged) {
            if ([PHTVModifierRuntimeStateService lastFlagsValue] == 0 ||
                [PHTVModifierRuntimeStateService lastFlagsValue] < (uint64_t)eventFlags) {
                PHTVModifierTransitionResultBox *pressResult =
                    [PHTVEventContextBridgeService handleModifierPressWithFlags:(uint64_t)eventFlags
                                                                restoreOnEscape:(int32_t)vRestoreOnEscape
                                                                customEscapeKey:(int32_t)vCustomEscapeKey
                                                                 pauseKeyEnabled:(int32_t)vPauseKeyEnabled
                                                                    pauseKeyCode:(int32_t)vPauseKey
                                                                  currentLanguage:(int32_t)vLanguage];

                if (pressResult.shouldUpdateLanguage) {
                    vLanguage = pressResult.language;
                }
            } else if ([PHTVModifierRuntimeStateService lastFlagsValue] > (uint64_t)eventFlags)  {
                PHTVModifierTransitionResultBox *releaseResult =
                    [PHTVEventContextBridgeService handleModifierReleaseWithOldFlags:[PHTVModifierRuntimeStateService lastFlagsValue]
                                                                             newFlags:(uint64_t)eventFlags
                                                                      restoreOnEscape:(int32_t)vRestoreOnEscape
                                                                      customEscapeKey:(int32_t)vCustomEscapeKey
                                                                         switchHotkey:(int32_t)vSwitchKeyStatus
                                                                        convertHotkey:(int32_t)gConvertToolOptions.hotKey
                                                                         emojiEnabled:(int32_t)vEnableEmojiHotkey
                                                                       emojiModifiers:(int32_t)vEmojiHotkeyModifiers
                                                                         emojiKeyCode:(int32_t)vEmojiHotkeyKeyCode
                                                             tempOffSpellingEnabled:(int32_t)vTempOffSpelling
                                                               tempOffEngineEnabled:(int32_t)vTempOffPHTV
                                                                   pauseKeyEnabled:(int32_t)vPauseKeyEnabled
                                                                      pauseKeyCode:(int32_t)vPauseKey
                                                                    currentLanguage:(int32_t)vLanguage];

                BOOL shouldAttemptRestore = releaseResult.shouldAttemptRestore;
                int releaseAction = (int)releaseResult.releaseAction;

                // Releasing modifiers - check for restore modifier key first
                if (shouldAttemptRestore) {
                    // Restore modifier released without any other key press - trigger restore
                    if (vRestoreToRawKeys()) {
                        // Successfully restored - pData now contains restore info
                        // Send backspaces to delete Vietnamese characters
                        if (pData->backspaceCount > 0 && pData->backspaceCount < MAX_BUFF) {
                            SendBackspaceSequenceWithDelay(pData->backspaceCount);
                        }

                        // Send the raw ASCII characters
                        SendNewCharString(false, 0, eventKeycode, eventFlags);
                        return NULL;
                    }
                }

                if (releaseResult.shouldUpdateLanguage) {
                    vLanguage = releaseResult.language;
                }

                if ([PHTVRuntimeUIBridgeService handleModifierReleaseHotkeyAction:(int32_t)releaseAction]) {
                    [PHTVModifierRuntimeStateService setHasJustUsedHotKeyValue:YES];
                    return NULL;
                }

                if (releaseAction == PHTVModifierReleaseActionTempOffSpelling) {
                    vTempOffSpellChecking();
                } else if (releaseAction == PHTVModifierReleaseActionTempOffEngine) {
                    vTempOffEngine();
                }

                [PHTVModifierRuntimeStateService setHasJustUsedHotKeyValue:NO];
            }
        }

        // Also check correct event hooked
        if ((type != kCGEventKeyDown) && (type != kCGEventKeyUp) &&
            (type != kCGEventLeftMouseDown) && (type != kCGEventRightMouseDown))
            return event;
        
        [PHTVEventRuntimeContextService setEventTapProxyRawValue:(uint64_t)(uintptr_t)proxy];
        
        // Skip Vietnamese processing for Spotlight and similar launcher apps
        // Use PID-based detection to properly detect overlay windows like Spotlight
        if ([PHTVEventContextBridgeService shouldDisableVietnameseForEvent:event
                                                                  safeMode:vSafeMode
                                                            cacheDurationMs:APP_SWITCH_CACHE_DURATION_MS
                                                     spotlightCacheDurationMs:SPOTLIGHT_CACHE_DURATION_MS]) {
            return event;
        }
        
        //If is in english mode
        // Use atomic read to ensure thread-safe access from event tap thread
        int currentLanguage = __atomic_load_n(&vLanguage, __ATOMIC_RELAXED);
        if (currentLanguage == 0) {
            if (vUseMacro && vUseMacroInEnglishMode && type == kCGEventKeyDown) {
                vEnglishMode((type == kCGEventKeyDown ? vKeyEventState::KeyDown : vKeyEventState::MouseDown),
                             eventKeycode,
                             (eventFlags & kCGEventFlagMaskShift) || (eventFlags & kCGEventFlagMaskAlphaShift),
                             [PHTVEventContextBridgeService hasOtherControlKeyWithFlags:(uint64_t)eventFlags]);

                if (pData->code == vReplaceMaro) { //handle macro in english mode
                    (void)[PHTVEventContextBridgeService prepareTargetContextAndConfigureRuntimeForEvent:event
                                                                                                safeMode:vSafeMode
                                                                                  spotlightCacheDurationMs:SPOTLIGHT_CACHE_DURATION_MS
                                                                               appCharacteristicsMaxAgeMs:kAppCharacteristicsCacheMaxAgeMs];
                    handleMacro(eventKeycode, eventFlags);
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
            PHTVEventTargetContextBox *targetContext =
                [PHTVEventContextBridgeService prepareTargetContextAndConfigureRuntimeForEvent:event
                                                                                       safeMode:vSafeMode
                                                                         spotlightCacheDurationMs:SPOTLIGHT_CACHE_DURATION_MS
                                                                      appCharacteristicsMaxAgeMs:kAppCharacteristicsCacheMaxAgeMs];
            BOOL spotlightActive = targetContext.spotlightActive;
            NSString *effectiveBundleId = targetContext.effectiveBundleId;
            PHTVAppCharacteristicsBox *appChars = targetContext.appCharacteristics;

#ifdef DEBUG
            NSString *eventTargetBundleId = targetContext.eventTargetBundleId;
            NSString *focusedBundleId = targetContext.focusedBundleId;
            // Diagnostic logs: either we believe the target is Spotlight-like, or AX says Spotlight is active.
            // This helps detect bundle-id mismatches (e.g. Spotlight field hosted by another process).
            if ([PHTVEventRuntimeContextService postToHIDTapEnabled] || spotlightActive) {
                int currentCodeTable = __atomic_load_n(&vCodeTable, __ATOMIC_RELAXED);
                [PHTVSpotlightDetectionService emitRuntimeDebugLog:[NSString stringWithFormat:@"spotlightActive=%d targetPID=%d eventTarget=%@ focused=%@ effective=%@ codeTable=%d keycode=%d",
                                                                  (int)spotlightActive,
                                                                  (int)eventTargetPID,
                                                                  eventTargetBundleId,
                                                                  focusedBundleId,
                                                                  effectiveBundleId,
                                                                  currentCodeTable,
                                                                  (int)eventKeycode]
                                                          throttleMs:DEBUG_LOG_THROTTLE_MS];
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
            if ([PHTVInputStrategyService shouldTemporarilyUseUnicodeCodeTableForCurrentCodeTable:(int32_t)currentCodeTable
                                                                                   spotlightActive:spotlightActive
                                                                                     spotlightLikeApp:appChars.isSpotlightLike]) {
                codeTableGuard.active = true;
                codeTableGuard.saved = currentCodeTable;
                __atomic_store_n(&vCodeTable, 0, __ATOMIC_RELAXED);
            }

            //send event signal to Engine
            vKeyHandleEvent(vKeyEvent::Keyboard,
                            vKeyEventState::KeyDown,
                            eventKeycode,
                            eventFlags & kCGEventFlagMaskShift ? 1 : (eventFlags & kCGEventFlagMaskAlphaShift ? 2 : 0),
                            [PHTVEventContextBridgeService hasOtherControlKeyWithFlags:(uint64_t)eventFlags]);

#ifdef DEBUG
            // Log engine result for space key
            if (eventKeycode == KEY_SPACE) {
                NSLog(@"[TextReplacement] Engine result for SPACE: code=%d, extCode=%d, backspace=%d, newChar=%d",
                      pData->code, pData->extCode, pData->backspaceCount, pData->newCharCount);
            }

            // AUTO ENGLISH DEBUG LOGGING
            // Log when Auto English should trigger (extCode=5)
            if (pData->extCode == 5) {
                if (pData->code == vRestore || pData->code == vRestoreAndStartNewSession) {
                    NSLog(@"[AutoEnglish] ✓ RESTORE TRIGGERED: code=%d, backspace=%d, newChar=%d, keycode=%d (0x%X)",
                          pData->code, (int)pData->backspaceCount, (int)pData->newCharCount, eventKeycode, eventKeycode);
                } else {
                    NSLog(@"[AutoEnglish] ⚠️ WARNING: extCode=5 but code=%d (not restore!)", pData->code);
                }
            }
            // Log when Auto English might have failed (SPACE key with no restore)
            else if (eventKeycode == KEY_SPACE && pData->code == vDoNothing) {
                NSLog(@"[AutoEnglish] ✗ NO RESTORE on SPACE: code=%d, extCode=%d",
                      pData->code, pData->extCode);
            }
#endif

            int signalAction = (int)[PHTVInputStrategyService engineSignalActionForEngineCode:(int32_t)pData->code
                                                                                   doNothingCode:(int32_t)vDoNothing
                                                                                 willProcessCode:(int32_t)vWillProcess
                                                                                    restoreCode:(int32_t)vRestore
                                                               restoreAndStartNewSessionCode:(int32_t)vRestoreAndStartNewSession
                                                                                  replaceMacroCode:(int32_t)vReplaceMaro];

            if (signalAction == PHTVEngineSignalActionDoNothing) { //do nothing
                // Navigation keys: trigger session restore to support keyboard-based edit-in-place
                if (phtv_mac_key_is_navigation(eventKeycode)) {
                    // TryToRestoreSessionFromAX();
                }

                // Use atomic read for thread safety.
                int currentCodeTable = __atomic_load_n(&vCodeTable, __ATOMIC_RELAXED);
                BOOL shouldSendExtraBackspace =
                    [PHTVEventContextBridgeService applyDoNothingSyncStateTransitionForCodeTable:(int32_t)currentCodeTable
                                                                                        extCode:(int32_t)pData->extCode
                                                                         containsUnicodeCompound:appChars.containsUnicodeCompound];
                if (shouldSendExtraBackspace) {
                    // Send one more backspace before popping sync length.
                    PostSyntheticEvent(eventBackSpaceDown);
                    PostSyntheticEvent(eventBackSpaceUp);
                }
                return event;
            } else if (signalAction == PHTVEngineSignalActionProcessSignal) { //handle result signal
                // BROWSER FIX: Browsers (Chromium, Safari, Firefox, etc.) don't support AX API properly
                // for their address bar autocomplete. When spotlightActive=true on a browser, 
                // we should NOT use Spotlight-style handling.
                BOOL isBrowserApp = targetContext.isBrowser;
                BOOL isSpotlightTarget = targetContext.postToHIDTap;
                PHTVProcessSignalPlanBox *processSignalPlan =
                    [PHTVInputStrategyService processSignalPlanForBundleId:effectiveBundleId
                                                                    keyCode:(int32_t)eventKeycode
                                                               spaceKeyCode:(int32_t)KEY_SPACE
                                                               slashKeyCode:(int32_t)KEY_SLASH
                                                                     extCode:(int32_t)pData->extCode
                                                              backspaceCount:(int32_t)pData->backspaceCount
                                                                newCharCount:(int32_t)pData->newCharCount
                                                                isBrowserApp:isBrowserApp
                                                            isSpotlightTarget:isSpotlightTarget
                                                      needsPrecomposedBatched:appChars.needsPrecomposedBatched
                                                            browserFixEnabled:vFixRecommendBrowser];

                // FIGMA FIX: Force pass-through for Space key to support "Hand tool" (Hold Space)
                // When PHTV consumes Space and sends a synthetic one, it breaks the "hold" state.
                if (processSignalPlan.shouldBypassForFigma) {
                    return event;
                }

                #ifdef DEBUG
                if (pData->code == vRestoreAndStartNewSession) {
                    fprintf(stderr, "[AutoEnglish] vRestoreAndStartNewSession START: backspace=%d, newChar=%d, keycode=%d\n",
                           (int)pData->backspaceCount, (int)pData->newCharCount, eventKeycode);
                    fflush(stderr);
                }
                #endif

                #ifdef DEBUG
                BOOL isSpecialApp = processSignalPlan.isSpecialApp;
                BOOL isPotentialShortcut = processSignalPlan.isPotentialShortcut;
                BOOL isBrowserFix = processSignalPlan.isBrowserFix;
                BOOL shouldSkipSpace = processSignalPlan.shouldSkipSpace;
                // Always log browser fix status to debug why it might be skipped
                NSLog(@"[BrowserFix] Status: vFix=%d, app=%@, isBrowser=%d => isFix=%d | bs=%d, ext=%d", 
                      vFixRecommendBrowser, effectiveBundleId, isBrowserApp, isBrowserFix, 
                      (int)pData->backspaceCount, pData->extCode);
                
                if (isBrowserFix && pData->backspaceCount > 0) {
                    NSLog(@"[BrowserFix] Checking logic: fix=%d, ext=%d, special=%d, skipSp=%d, shortcut=%d, bs=%d", 
                          isBrowserFix, pData->extCode, isSpecialApp, shouldSkipSpace, isPotentialShortcut, (int)pData->backspaceCount);
                }
                #endif

                BOOL isAddrBar = NO;
                if (processSignalPlan.shouldTryBrowserAddressBarFix) {
                    // Use accurate AX API check (cached) instead of unreliable spotlightActive.
                    isAddrBar = [PHTVEventContextBridgeService isFocusedElementAddressBarForSafeMode:vSafeMode];
#ifdef DEBUG
                    NSLog(@"[BrowserFix] isFocusedElementAddressBar returned: %d", isAddrBar);
#endif
                }

                BOOL isNotionCodeBlockDetected = NO;
                if (processSignalPlan.shouldTryLegacyNonBrowserFix) {
                    // Notion code block should use standard backspace path.
                    isNotionCodeBlockDetected = processSignalPlan.isNotionApp &&
                        [PHTVEventContextBridgeService isNotionCodeBlockForSafeMode:vSafeMode];
#ifdef DEBUG
                    if (isNotionCodeBlockDetected) {
                        NSLog(@"[Notion] Code Block detected - using Standard Backspace");
                    }
#endif
                }

                PHTVResolvedBackspacePlanBox *resolvedBackspacePlan =
                    [PHTVInputStrategyService resolvedBackspacePlanForBrowserAddressBarFix:processSignalPlan.shouldTryBrowserAddressBarFix
                                                                           addressBarDetected:isAddrBar
                                                                         legacyNonBrowserFix:processSignalPlan.shouldTryLegacyNonBrowserFix
                                                                     containsUnicodeCompound:appChars.containsUnicodeCompound
                                                                     notionCodeBlockDetected:isNotionCodeBlockDetected
                                                                              backspaceCount:(int32_t)pData->backspaceCount
                                                                                  maxBuffer:(int32_t)MAX_BUFF
                                                                                 safetyLimit:15];
                int adjustmentAction = (int)resolvedBackspacePlan.adjustmentAction;
                if (adjustmentAction == PHTVBackspaceAdjustmentActionSendShiftLeftThenBackspace) {
                    SendShiftAndLeftArrow();
                    SendPhysicalBackspace();
                } else if (adjustmentAction == PHTVBackspaceAdjustmentActionSendEmptyCharacter) {
#ifdef DEBUG
                    if (isAddrBar) {
                        NSLog(@"[PHTV Browser] Address Bar Detected (AX) -> Using SendEmptyCharacter (Fix Doubling)");
                    }
#endif
                    SendEmptyCharacter();
                }

                int adjustedBackspaceCount = (int)resolvedBackspacePlan.sanitizedBackspaceCount;
                pData->backspaceCount = (Byte)adjustedBackspaceCount;

                // SAFETY LOG: A single Vietnamese word transformation should never delete more than 15 chars.
                if (resolvedBackspacePlan.isSafetyClampApplied) {
#ifdef DEBUG
                    NSLog(@"[PHTV Safety] Blocked excessive backspaceCount: %d -> 15 (Key=%d)", (int)resolvedBackspacePlan.adjustedBackspaceCount, eventKeycode);
#endif
                }
#ifdef DEBUG
                if (processSignalPlan.shouldLogSpaceSkip) {
                    NSLog(@"[TextReplacement] SKIPPED SendEmptyCharacter for SPACE to avoid Text Replacement conflict");
                }
#endif

                // TEXT REPLACEMENT FIX: Skip backspace/newChar if this is SPACE after text replacement
                // Detection methods:
                // 1. External DELETE detected (arrow key selection) - HIGH CONFIDENCE
                // 2. Short backspace + code=3 without DELETE (mouse click selection) - FALLBACK
                int externalDeleteCount = (int)[PHTVEventContextBridgeService externalDeleteCountValue];
                BOOL shouldEvaluateTextReplacement =
                    [PHTVTextReplacementDecisionService shouldEvaluateForKeyCode:(int32_t)eventKeycode
                                                                     spaceKeyCode:(int32_t)KEY_SPACE
                                                                   backspaceCount:(int32_t)pData->backspaceCount
                                                                     newCharCount:(int32_t)pData->newCharCount];

                // Log for debugging text replacement issues (only in Debug builds)
                #ifdef DEBUG
                if (shouldEvaluateTextReplacement) {
                    NSLog(@"[PHTV TextReplacement] Key=%d: code=%d, extCode=%d, backspace=%d, newChar=%d, deleteCount=%d",
                          eventKeycode, pData->code, pData->extCode, (int)pData->backspaceCount, (int)pData->newCharCount, externalDeleteCount);
                }
                #endif

                if (shouldEvaluateTextReplacement) {
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

                    if (textReplacementDecisionBox.shouldBypassEvent) {
#ifdef DEBUG
                        if (textReplacementDecisionBox.isExternalDelete) {
                            NSLog(@"[TextReplacement] Text replacement detected - passing through event (code=%d, backspace=%d, newChar=%d, deleteCount=%d, elapsedMs=%llu)",
                                  pData->code, (int)pData->backspaceCount, (int)pData->newCharCount, externalDeleteCount, textReplacementDecisionBox.matchedElapsedMs);
                        } else if (textReplacementDecisionBox.isPatternMatch) {
                            NSLog(@"[PHTV TextReplacement] Pattern %@ matched: code=%d, backspace=%d, newChar=%d, keycode=%d",
                                  textReplacementDecisionBox.patternLabel ?: @"?",
                                  pData->code, (int)pData->backspaceCount, (int)pData->newCharCount, eventKeycode);
                            NSLog(@"[PHTV TextReplacement] ✅ DETECTED - Skipping processing (code=%d, backspace=%d, newChar=%d)",
                                  pData->code, (int)pData->backspaceCount, (int)pData->newCharCount);
                        }
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

                PHTVCharacterSendPlanBox *characterSendPlan =
                    [PHTVInputStrategyService characterSendPlanForSpotlightTarget:isSpotlightTarget
                                                                        cliTarget:[PHTVEventRuntimeContextService isCliTargetEnabled]
                                                                 globalStepByStep:vSendKeyStepByStep
                                                                 appNeedsStepByStep:appChars.needsStepByStep
                                                                           keyCode:(int32_t)eventKeycode
                                                                        engineCode:(int32_t)pData->code
                                                                       restoreCode:(int32_t)vRestore
                                                          restoreAndStartNewSessionCode:(int32_t)vRestoreAndStartNewSession
                                                                       enterKeyCode:(int32_t)KEY_ENTER
                                                                      returnKeyCode:(int32_t)KEY_RETURN];

                //send backspace
                if (pData->backspaceCount > 0 && pData->backspaceCount < MAX_BUFF) {
                    if (characterSendPlan.deferBackspaceToAX) {
                        // Defer deletion to AX replacement inside SendNewCharString().
                        [PHTVEventRuntimeContextService setPendingBackspaceCount:(int32_t)pData->backspaceCount];
#ifdef DEBUG
                        [PHTVSpotlightDetectionService emitRuntimeDebugLog:[NSString stringWithFormat:@"deferBackspace=%d newCharCount=%d", (int)pData->backspaceCount, (int)pData->newCharCount]
                                                                  throttleMs:DEBUG_LOG_THROTTLE_MS];
#endif
                    } else {
                        SendBackspaceSequenceWithDelay(pData->backspaceCount);
                    }
                }

                //send new character - use step by step for timing sensitive apps like Spotlight
                BOOL useStepByStep = characterSendPlan.useStepByStepCharacterSend;
#ifdef DEBUG
                if (isSpotlightTarget) {
                    [PHTVSpotlightDetectionService emitRuntimeDebugLog:[NSString stringWithFormat:@"willSend stepByStep=%d backspaceCount=%d newCharCount=%d", (int)useStepByStep, (int)pData->backspaceCount, (int)pData->newCharCount]
                                                              throttleMs:DEBUG_LOG_THROTTLE_MS];
                }
#endif
                if (!useStepByStep) {
                    SendNewCharString(false, 0, eventKeycode, eventFlags);
                } else {
                    if (pData->newCharCount > 0 && pData->newCharCount <= MAX_BUFF) {
                        int32_t newCharCount = (int32_t)pData->newCharCount;
                        double cliSpeedFactor = [PHTVCliRuntimeStateService currentSpeedFactor];
                        uint64_t scaledCliTextDelayUs = [PHTVEventRuntimeContextService isCliTargetEnabled] ? (uint64_t)[PHTVTimingService scaleDelayUseconds:[PHTVTimingService clampToUseconds:[PHTVCliRuntimeStateService cliTextDelayUs]] factor:cliSpeedFactor] : 0;
                        uint64_t scaledCliPostSendBlockUs = [PHTVEventRuntimeContextService isCliTargetEnabled] ? [PHTVTimingService scaleDelayMicroseconds:[PHTVCliRuntimeStateService cliPostSendBlockUs] factor:cliSpeedFactor] : 0;
                        PHTVSendSequencePlanBox *sendPlan =
                            [PHTVSendSequenceService sequencePlanForCliTarget:[PHTVEventRuntimeContextService isCliTargetEnabled]
                                                                     itemCount:newCharCount
                                                          scaledCliTextDelayUs:(int64_t)scaledCliTextDelayUs
                                                     scaledCliPostSendBlockUs:(int64_t)scaledCliPostSendBlockUs];
                        useconds_t interItemDelayUs = [PHTVTimingService clampToUseconds:(uint64_t)MAX((int64_t)0, sendPlan.interItemDelayUs)];

                        for (int i = pData->newCharCount - 1; i >= 0; i--) {
                            SendKeyCode(pData->charData[i]);
                            if (interItemDelayUs > 0 && i > 0) {
                                usleep(interItemDelayUs);
                            }
                        }
                        if (sendPlan.shouldScheduleCliBlock) {
                            SetCliBlockForMicroseconds((uint64_t)MAX((int64_t)0, sendPlan.cliBlockUs));
                        }
                    }
                    if (characterSendPlan.shouldSendRestoreTriggerKey) {
                        #ifdef DEBUG
                        if (pData->code == vRestoreAndStartNewSession) {
                            fprintf(stderr, "[AutoEnglish] PROCESSING RESTORE: backspace=%d, newChar=%d\n",
                                   (int)pData->backspaceCount, (int)pData->newCharCount);
                            fflush(stderr);
                        }
                        #endif
                        // No delay needed before final key
                        SendKeyCode(eventKeycode | ((eventFlags & kCGEventFlagMaskAlphaShift) || (eventFlags & kCGEventFlagMaskShift) ? CAPS_MASK : 0));
                    }
                    if (characterSendPlan.shouldStartNewSessionAfterSend) {
                        startNewSession();
                    }
                }
            } else if (signalAction == PHTVEngineSignalActionReplaceMacro) { //MACRO
                handleMacro(eventKeycode, eventFlags);
            }

            return NULL;
        }
        
        return event;
        } // @autoreleasepool
    }
