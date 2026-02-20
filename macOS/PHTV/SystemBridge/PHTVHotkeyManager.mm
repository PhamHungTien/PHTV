//
//  PHTVHotkeyManager.mm
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import "PHTVHotkeyManager.h"
#import "PHTVCacheManager.h"
#import "PHTV-Swift.h"
#import "../Core/phtv_mac_keys.h"
#import <Cocoa/Cocoa.h>

extern volatile int vLanguage;
extern volatile int vPauseKeyEnabled;
extern volatile int vPauseKey;

@implementation PHTVHotkeyManager

static BOOL _pauseKeyPressed = NO;
static int _savedLanguageBeforePause = 1;
static CGKeyCode _layoutCache[256];
static BOOL _layoutCacheValid = NO;

static NSDictionary<NSString *, NSNumber *> *PHTVLayoutKeyStringToKeyCodeMap(void) {
    static NSDictionary<NSString *, NSNumber *> *map = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        map = @{
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
            @"ß": @27,
            @"ü": @33,
            @"ö": @41,
            @"ä": @39,
            @"é": @19,
            @"è": @26,
            @"ù": @39,
            @"²": @50,
            @"«": @30,
            @"»": @42,
            @"µ": @42,
            @"ñ": @41,
            @"¡": @24,
            @"¿": @27,
            @"¬": @50,
            @"ò": @41,
            @"ì": @24,
            @"ç": @41,
            @"º": @50,
            @"ª": @50,
            @"å": @33,
            @"æ": @39,
            @"ø": @41,
            @"§": @50,
            @"½": @50,
            @"¤": @21,
            @"ą": @0, @"ć": @8, @"ę": @14, @"ł": @37, @"ń": @45,
            @"ó": @31, @"ś": @1, @"ź": @7, @"ż": @6,
            @"ě": @19, @"š": @20, @"č": @21, @"ř": @23, @"ž": @22,
            @"ý": @26, @"á": @28, @"í": @25, @"ú": @41, @"ů": @33,
            @"ď": @30, @"ť": @39, @"ň": @42,
            @"ő": @27, @"ű": @42,
            @"ğ": @33, @"ş": @41, @"ı": @34,
            @"´": @24,
            @"¨": @33,
            @"à": @29,
            @"€": @14,
            @"£": @20,
            @"¥": @16,
            @"¢": @8,
            @"©": @8,
            @"®": @15,
            @"™": @17,
            @"°": @28,
            @"±": @24,
            @"×": @7,
            @"÷": @44,
            @"≠": @24,
            @"≤": @43,
            @"≥": @47,
            @"∞": @23,
            @"…": @41,
            @"–": @27,
            @"—": @27,
            @"\u2018": @39,
            @"\u2019": @39,
            @"\u201C": @39,
            @"\u201D": @39
        };
    });
    return map;
}

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
        _layoutCacheValid = NO;
        for (int i = 0; i < 256; ++i) {
            _layoutCache[i] = (CGKeyCode)0xFFFF;
        }
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
    if (keyString == nil || keyString.length == 0) {
        return fallback;
    }

    NSDictionary<NSString *, NSNumber *> *map = PHTVLayoutKeyStringToKeyCodeMap();
    NSNumber *keycode = map[keyString];
    if (keycode != nil) {
        return [keycode intValue];
    }

    NSString *lower = [keyString lowercaseString];
    if (lower != nil && ![lower isEqualToString:keyString]) {
        keycode = map[lower];
        if (keycode != nil) {
            return [keycode intValue];
        }
    }

    return fallback;
}

+ (void)invalidateLayoutCache {
    _layoutCacheValid = NO;
    [PHTVCacheManager invalidateLayoutCache];
}

+ (CGKeyCode)convertEventToKeyboardLayoutCompatKeyCode:(CGEventRef)event fallback:(CGKeyCode)fallback {
    CGKeyCode rawKeyCode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
    if (_layoutCacheValid && rawKeyCode < 256 && _layoutCache[rawKeyCode] != 0xFFFF) {
        return _layoutCache[rawKeyCode];
    }

    if (!_layoutCacheValid) {
        for (int i = 0; i < 256; i++) {
            _layoutCache[i] = (CGKeyCode)0xFFFF;
        }
        _layoutCacheValid = YES;
    }

    NSEvent *layoutEvent = [NSEvent eventWithCGEvent:event];
    if (layoutEvent == nil) {
        return fallback;
    }

    CGKeyCode result = fallback;
    NSString *baseCharacters = layoutEvent.charactersIgnoringModifiers;
    CGKeyCode converted = (CGKeyCode)[self convertKeyStringToKeyCode:baseCharacters fallback:0xFFFF];
    if (converted != 0xFFFF) {
        result = converted;
    } else {
        NSString *actualCharacters = layoutEvent.characters;
        if (actualCharacters != nil && ![actualCharacters isEqualToString:baseCharacters]) {
            converted = (CGKeyCode)[self convertKeyStringToKeyCode:actualCharacters fallback:0xFFFF];
            if (converted != 0xFFFF) {
                result = converted;
            }
        }
    }

    if (result == fallback) {
        static NSDictionary<NSString *, NSNumber *> *azertyShiftedToNumber = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            azertyShiftedToNumber = @{
                @"&": @18,
                @"é": @19,
                @"\"": @20,
                @"'": @21,
                @"(": @23,
                @"-": @22,
                @"è": @26,
                @"_": @28,
                @"ç": @25,
                @"à": @29,
            };
        });

        if (baseCharacters.length == 1) {
            NSNumber *azertyKeycode = azertyShiftedToNumber[baseCharacters];
            if (azertyKeycode != nil) {
                result = [azertyKeycode intValue];
            }
        }
    }

    if (rawKeyCode < 256) {
        _layoutCache[rawKeyCode] = result;
    }

    return result;
}

@end
