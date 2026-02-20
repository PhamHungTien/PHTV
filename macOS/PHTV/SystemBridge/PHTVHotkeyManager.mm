//
//  PHTVHotkeyManager.mm
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import "PHTVHotkeyManager.h"
#import "PHTV-Swift.h"
#import "../Core/phtv_mac_keys.h"
#import <Cocoa/Cocoa.h>

extern volatile int vLanguage;
extern volatile int vPauseKeyEnabled;
extern volatile int vPauseKey;

@implementation PHTVHotkeyManager

static BOOL _pauseKeyPressed = NO;
static int _savedLanguageBeforePause = 1;

static inline CGEventFlags PHTVPauseModifierMaskForKeyCode(int pauseKey) {
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

+ (void)initialize {
    if (self == [PHTVHotkeyManager class]) {
        _pauseKeyPressed = NO;
        _savedLanguageBeforePause = 1;
        [PHTVHotkeyService invalidateLayoutCache];
    }
}

+ (BOOL)checkHotKey:(int)hotKeyData checkKeyCode:(BOOL)checkKeyCode currentKeycode:(CGKeyCode)keycode currentFlags:(CGEventFlags)flags {
    return [PHTVHotkeyService checkHotKey:(int32_t)hotKeyData
                             checkKeyCode:checkKeyCode
                           currentKeycode:(uint16_t)keycode
                             currentFlags:(uint64_t)flags];
}

+ (BOOL)hotkeyModifiersAreHeld:(int)hotKeyData currentFlags:(CGEventFlags)flags {
    return [PHTVHotkeyService hotkeyModifiersAreHeld:(int32_t)hotKeyData
                                        currentFlags:(uint64_t)flags];
}

+ (BOOL)isModifierOnlyHotkey:(int)hotKeyData {
    return [PHTVHotkeyService isModifierOnlyHotkey:(int32_t)hotKeyData];
}

+ (BOOL)isPauseKeyPressed {
    return _pauseKeyPressed;
}

+ (CGEventFlags)pauseModifierMaskForCurrentPauseKey {
    return PHTVPauseModifierMaskForKeyCode(vPauseKey);
}

+ (BOOL)isPauseKeyActiveForFlags:(CGEventFlags)flags {
    if (!vPauseKeyEnabled || vPauseKey <= 0) {
        return NO;
    }
    CGEventFlags pauseMask = [self pauseModifierMaskForCurrentPauseKey];
    return pauseMask != 0 && ((flags & pauseMask) != 0);
}

+ (CGEventFlags)stripPauseModifier:(CGEventFlags)flags {
    CGEventFlags pauseMask = [self pauseModifierMaskForCurrentPauseKey];
    if (pauseMask == 0) {
        return flags;
    }
    return flags & ~pauseMask;
}

+ (void)handlePauseKeyPressWithFlags:(CGEventFlags)flags {
    if (_pauseKeyPressed) {
        return;
    }

    if ([self isPauseKeyActiveForFlags:flags]) {
        _savedLanguageBeforePause = vLanguage;
        if (vLanguage == 1) {
            vLanguage = 0;
        }
        _pauseKeyPressed = YES;
    }
}

+ (void)handlePauseKeyReleaseFromFlags:(CGEventFlags)oldFlags toFlags:(CGEventFlags)newFlags {
    if (!_pauseKeyPressed) {
        return;
    }

    if (![self isPauseKeyActiveForFlags:newFlags] && [self isPauseKeyActiveForFlags:oldFlags]) {
        vLanguage = _savedLanguageBeforePause;
        _pauseKeyPressed = NO;
    }
}

+ (int)convertKeyStringToKeyCode:(NSString*)keyString fallback:(CGKeyCode)fallback {
    return (int)[PHTVHotkeyService convertKeyStringToKeyCode:keyString
                                                    fallback:(uint16_t)fallback];
}

+ (void)invalidateLayoutCache {
    [PHTVHotkeyService invalidateLayoutCache];
}

+ (CGKeyCode)convertEventToKeyboardLayoutCompatKeyCode:(CGEventRef)event fallback:(CGKeyCode)fallback {
    return (CGKeyCode)[PHTVHotkeyService convertEventToKeyboardLayoutCompatKeyCode:event
                                                                           fallback:(uint16_t)fallback];
}

@end
