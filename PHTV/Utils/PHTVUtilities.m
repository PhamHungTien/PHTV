//
//  PHTVUtilities.m
//  PHTV - Vietnamese Input Method
//
//  Created by Phạm Hùng Tiến on 2026
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import "PHTVUtilities.h"

@implementation PHTVUtilities

#pragma mark - String Formatting

+ (NSString *)formatNumber:(NSNumber *)number {
    static NSNumberFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSNumberFormatter alloc] init];
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
        formatter.groupingSeparator = @".";
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"vi_VN"];
    });
    return [formatter stringFromNumber:number];
}

+ (NSString *)buildDateString {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"dd/MM/yyyy"];
    [formatter setLocale:[NSLocale localeWithLocaleIdentifier:@"vi_VN"]];
    
    // Parse build date from __DATE__ macro
    NSString *buildDate = [NSString stringWithUTF8String:__DATE__];
    NSDateFormatter *compiler = [[NSDateFormatter alloc] init];
    [compiler setDateFormat:@"MMM dd yyyy"];
    [compiler setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US"]];
    
    NSDate *date = [compiler dateFromString:buildDate];
    return date ? [formatter stringFromDate:date] : @"N/A";
}

+ (NSString *)versionString {
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *build = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    return [NSString stringWithFormat:@"%@ (build %@)", version, build];
}

#pragma mark - Key Processing (Optimized with lookup tables)

+ (BOOL)isVowelKey:(int)keyCode {
    // Fast lookup using switch - compiler optimizes to jump table
    switch (keyCode) {
        case 0:   // KEY_A
        case 14:  // KEY_E
        case 34:  // KEY_I
        case 31:  // KEY_O
        case 32:  // KEY_U
        case 16:  // KEY_Y
            return YES;
        default:
            return NO;
    }
}

+ (BOOL)isConsonantKey:(int)keyCode {
    return ![self isVowelKey:keyCode];
}

+ (BOOL)isMarkKey:(int)keyCode inputType:(PHTVInputType)type {
    if (type == PHTVInputTypeVNI) {
        return (keyCode >= 18 && keyCode <= 23); // 1-5 keys
    } else {
        // Telex: s, f, r, x, j
        return (keyCode == 1 || keyCode == 3 || keyCode == 15 || 
                keyCode == 7 || keyCode == 38);
    }
}

+ (BOOL)isToneKey:(int)keyCode inputType:(PHTVInputType)type {
    if (type == PHTVInputTypeVNI) {
        return (keyCode == 22); // KEY_6
    } else {
        return (keyCode == 13); // KEY_W
    }
}

#pragma mark - Character Conversion (Optimized)

+ (unichar)removeVietnameseTone:(unichar)character {
    // Fast tone removal using range checks
    static const unichar ranges[][3] = {
        {0xE0, 0xE5, 0x61}, // à-å -> a
        {0xE8, 0xEB, 0x65}, // è-ë -> e
        {0xEC, 0xEF, 0x69}, // ì-ï -> i
        {0xF2, 0xF6, 0x6F}, // ò-ö -> o
        {0xF9, 0xFC, 0x75}, // ù-ü -> u
        {0xC0, 0xC5, 0x41}, // À-Å -> A
        {0xC8, 0xCB, 0x45}, // È-Ë -> E
        {0xCC, 0xCF, 0x49}, // Ì-Ï -> I
        {0xD2, 0xD6, 0x4F}, // Ò-Ö -> O
        {0xD9, 0xDC, 0x55}, // Ù-Ü -> U
    };
    
    for (int i = 0; i < 10; i++) {
        if (character >= ranges[i][0] && character <= ranges[i][1]) {
            return ranges[i][2];
        }
    }
    return character;
}

+ (unichar)addTone:(unichar)character toneType:(int)tone {
    // Optimized tone addition
    // Implementation depends on Vietnamese character table
    return character; // Placeholder
}

+ (NSString *)normalizeVietnameseString:(NSString *)input {
    if (!input || input.length == 0) return @"";
    
    NSMutableString *result = [NSMutableString stringWithCapacity:input.length];
    for (NSUInteger i = 0; i < input.length; i++) {
        unichar ch = [input characterAtIndex:i];
        [result appendFormat:@"%C", [self removeVietnameseTone:ch]];
    }
    return result;
}

#pragma mark - Threading (Optimized)

+ (void)executeOnMainThread:(dispatch_block_t)block {
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

+ (void)executeOnBackgroundThread:(dispatch_block_t)block {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), block);
}

+ (void)executeAfterDelay:(NSTimeInterval)delay block:(dispatch_block_t)block {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), block);
}

#pragma mark - Cache

static NSCache *_sharedCache = nil;

+ (void)clearCache {
    if (_sharedCache) {
        [_sharedCache removeAllObjects];
    }
}

+ (NSUInteger)cacheSize {
    return _sharedCache ? _sharedCache.countLimit : 0;
}

@end
