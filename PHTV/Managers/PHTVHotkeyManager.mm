//
//  PHTVHotkeyManager.mm
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import "PHTVHotkeyManager.h"
#import "PHTVCacheManager.h"
#import "PHTVEventSynthesisManager.h"

@implementation PHTVHotkeyManager

// Pause key state
static BOOL _pauseKeyPressed = NO;
static int _savedLanguageBeforePause = 0;

// Keyboard layout map (for international keyboards)
static NSDictionary* _keyStringToKeyCodeMap = nil;

#pragma mark - Initialization

+ (void)initialize {
    if (self == [PHTVHotkeyManager class]) {
        // Initialize pause key state
        _pauseKeyPressed = NO;
        _savedLanguageBeforePause = 0;

        // Initialize keyboard layout map
        // This will be populated when we extract from PHTV.mm
        _keyStringToKeyCodeMap = @{};
    }
}

#pragma mark - Hotkey Detection

+ (CGEventRef)handleHotkeyPress:(CGEventType)type keycode:(CGKeyCode)keycode flags:(CGEventFlags)flags {
    // Placeholder - will be implemented when extracting from PHTV.mm
    // Returns (CGEventRef)-1 if hotkey was consumed, otherwise returns event unchanged
    return NULL;
}

+ (BOOL)checkHotKey:(int)hotKeyData checkKeyCode:(BOOL)checkKeyCode currentKeycode:(CGKeyCode)keycode currentFlags:(CGEventFlags)flags {
    if ((hotKeyData & (~0x8000)) == EMPTY_HOTKEY)
        return NO;
    if (HAS_CONTROL(hotKeyData) ^ GET_BOOL(flags & kCGEventFlagMaskControl))
        return NO;
    if (HAS_OPTION(hotKeyData) ^ GET_BOOL(flags & kCGEventFlagMaskAlternate))
        return NO;
    if (HAS_COMMAND(hotKeyData) ^ GET_BOOL(flags & kCGEventFlagMaskCommand))
        return NO;
    if (HAS_SHIFT(hotKeyData) ^ GET_BOOL(flags & kCGEventFlagMaskShift))
        return NO;
    if (HAS_FN(hotKeyData) ^ GET_BOOL(flags & kCGEventFlagMaskSecondaryFn))
        return NO;
    if (checkKeyCode) {
        if (GET_SWITCH_KEY(hotKeyData) != keycode)
            return NO;
    }
    return YES;
}

+ (BOOL)hotkeyModifiersAreHeld:(int)hotKeyData currentFlags:(CGEventFlags)flags {
    if ((hotKeyData & (~0x8000)) == EMPTY_HOTKEY)
        return NO;

    // Check if all required modifiers are present in current flags
    if (HAS_CONTROL(hotKeyData) && !(flags & kCGEventFlagMaskControl))
        return NO;
    if (HAS_OPTION(hotKeyData) && !(flags & kCGEventFlagMaskAlternate))
        return NO;
    if (HAS_COMMAND(hotKeyData) && !(flags & kCGEventFlagMaskCommand))
        return NO;
    if (HAS_SHIFT(hotKeyData) && !(flags & kCGEventFlagMaskShift))
        return NO;
    if (HAS_FN(hotKeyData) && !(flags & kCGEventFlagMaskSecondaryFn))
        return NO;

    return YES;
}

+ (BOOL)isModifierOnlyHotkey:(int)hotKeyData {
    return GET_SWITCH_KEY(hotKeyData) == 0xFE;
}

#pragma mark - Language Switching

+ (void)switchLanguage {
    // Placeholder - will be implemented when extracting from PHTV.mm
    // Toggles between Vietnamese and English
}

#pragma mark - Macro Triggering

+ (void)handleMacro {
    // Placeholder - will be implemented when extracting from PHTV.mm
}

#pragma mark - Pause Key Management

+ (BOOL)isPauseKeyPressed {
    return _pauseKeyPressed;
}

+ (void)setPauseKeyPressed:(BOOL)pressed {
    _pauseKeyPressed = pressed;
}

+ (CGEventFlags)stripPauseModifier:(CGEventFlags)flags {
    // Placeholder - will be implemented when extracting from PHTV.mm
    return flags;
}

+ (void)handlePauseKeyPress {
    // Placeholder - will be implemented when extracting from PHTV.mm
}

+ (void)handlePauseKeyRelease {
    // Placeholder - will be implemented when extracting from PHTV.mm
}

#pragma mark - Keyboard Layout Compatibility

+ (CGKeyCode)convertEventToKeyboardLayoutCompatKeyCode:(CGEventRef)event fallback:(CGKeyCode)fallback {
    // Placeholder - will be implemented when extracting from PHTV.mm
    return fallback;
}

+ (int)convertKeyStringToKeyCode:(NSString*)keyString fallback:(CGKeyCode)fallback {
    // Placeholder - will be implemented when extracting from PHTV.mm
    return fallback;
}

+ (void)invalidateLayoutCache {
    [PHTVCacheManager invalidateLayoutCache];
}

@end
