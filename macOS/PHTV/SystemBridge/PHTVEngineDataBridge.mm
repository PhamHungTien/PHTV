//
//  PHTVEngineDataBridge.mm
//  PHTV
//
//  Objective-C bridge for C++ engine data/dictionary APIs used by Swift.
//

#import "PHTVEngineDataBridge.h"
#include "../Core/Engine/Engine.h"
#include <Carbon/Carbon.h>

static inline void PHTVAppendHotkeyComponent(NSMutableString *hotKey,
                                             BOOL *hasComponent,
                                             NSString *component) {
    if (*hasComponent) {
        [hotKey appendString:@" + "];
    }
    [hotKey appendString:component];
    *hasComponent = YES;
}

static inline NSString *PHTVHotkeyKeyDisplayLabel(unsigned short keyCode) {
    if (keyCode == kVK_Space || keyCode == KEY_SPACE) {
        return @"␣";
    }

    const Uint16 keyChar = keyCodeToCharacter(static_cast<Uint32>(keyCode) | CAPS_MASK);
    if (keyChar >= 33 && keyChar <= 126) {
        const unichar displayChar = (unichar)keyChar;
        return [NSString stringWithCharacters:&displayChar length:1];
    }

    return [NSString stringWithFormat:@"KEY_%hu", keyCode];
}

@implementation PHTVEngineDataBridge

+(void)initializeMacroMapWithData:(NSData *)data {
    initMacroMap((const unsigned char *)data.bytes, (int)data.length);
}

+(BOOL)initializeEnglishDictionaryAtPath:(NSString *)path {
    std::string cppPath = path.UTF8String;
    return initEnglishDictionary(cppPath);
}

+(NSUInteger)englishDictionarySize {
    return getEnglishDictionarySize();
}

+(BOOL)initializeVietnameseDictionaryAtPath:(NSString *)path {
    std::string cppPath = path.UTF8String;
    return initVietnameseDictionary(cppPath);
}

+(NSUInteger)vietnameseDictionarySize {
    return getVietnameseDictionarySize();
}

+(void)initializeCustomDictionaryWithJSONData:(NSData *)jsonData {
    initCustomDictionary((const char *)jsonData.bytes, (int)jsonData.length);
}

+(NSUInteger)customEnglishWordCount {
    return getCustomEnglishWordCount();
}

+(NSUInteger)customVietnameseWordCount {
    return getCustomVietnameseWordCount();
}

+(void)clearCustomDictionary {
    clearCustomDictionary();
}

+(void)setCheckSpellingValue:(int)value {
    vCheckSpelling = value;
}

+(NSString *)quickConvertMenuTitle {
    NSMutableString *hotKey = [NSMutableString string];
    BOOL hasComponent = NO;
    const int quickConvertHotkey = gConvertToolOptions.hotKey;

    if (HAS_CONTROL(quickConvertHotkey)) {
        PHTVAppendHotkeyComponent(hotKey, &hasComponent, @"⌃");
    }
    if (HAS_OPTION(quickConvertHotkey)) {
        PHTVAppendHotkeyComponent(hotKey, &hasComponent, @"⌥");
    }
    if (HAS_COMMAND(quickConvertHotkey)) {
        PHTVAppendHotkeyComponent(hotKey, &hasComponent, @"⌘");
    }
    if (HAS_SHIFT(quickConvertHotkey)) {
        PHTVAppendHotkeyComponent(hotKey, &hasComponent, @"⇧");
    }

    if (HOTKEY_HAS_KEY(quickConvertHotkey)) {
        const unsigned short keyCode = (unsigned short)GET_SWITCH_KEY(quickConvertHotkey);
        PHTVAppendHotkeyComponent(hotKey, &hasComponent, PHTVHotkeyKeyDisplayLabel(keyCode));
    }

    if (hasComponent) {
        return [NSString stringWithFormat:@"Chuyển mã nhanh - [%@]", hotKey.uppercaseString];
    }
    return @"Chuyển mã nhanh";
}

@end
