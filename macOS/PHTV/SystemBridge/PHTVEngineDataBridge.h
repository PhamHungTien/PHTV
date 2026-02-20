//
//  PHTVEngineDataBridge.h
//  PHTV
//
//  Objective-C bridge for C++ engine data/dictionary APIs used by Swift.
//

#ifndef PHTVEngineDataBridge_h
#define PHTVEngineDataBridge_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PHTVEngineDataBridge : NSObject

+(void)initializeMacroMapWithData:(NSData *)data;

+(BOOL)initializeEnglishDictionaryAtPath:(NSString *)path;
+(NSUInteger)englishDictionarySize;

+(BOOL)initializeVietnameseDictionaryAtPath:(NSString *)path;
+(NSUInteger)vietnameseDictionarySize;

+(void)initializeCustomDictionaryWithJSONData:(NSData *)jsonData;
+(NSUInteger)customEnglishWordCount;
+(NSUInteger)customVietnameseWordCount;
+(void)clearCustomDictionary;

+(void)setCheckSpellingValue:(int)value;
+(NSString *)quickConvertMenuTitle;

@end

NS_ASSUME_NONNULL_END

#endif /* PHTVEngineDataBridge_h */
