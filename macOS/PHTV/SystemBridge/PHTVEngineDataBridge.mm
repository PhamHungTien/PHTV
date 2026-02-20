//
//  PHTVEngineDataBridge.mm
//  PHTV
//
//  Objective-C bridge for C++ engine data/dictionary APIs used by Swift.
//

#import "PHTVEngineDataBridge.h"
#include "../Core/Engine/Engine.h"

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

@end
