//
//  PHTVUtilities.h
//  PHTV - Vietnamese Input Method
//
//  Created by Phạm Hùng Tiến on 2026
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//
//  High-performance utility functions
//

#ifndef PHTVUtilities_h
#define PHTVUtilities_h

#import <Foundation/Foundation.h>
#include "PHTVConstants.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Optimized utility functions for PHTV
 * @author Phạm Hùng Tiến
 */
@interface PHTVUtilities : NSObject

#pragma mark - String Processing (Optimized)
+ (NSString *)formatNumber:(NSNumber *)number;
+ (NSString *)buildDateString;
+ (NSString *)versionString;

#pragma mark - Key Processing
+ (BOOL)isVowelKey:(int)keyCode;
+ (BOOL)isConsonantKey:(int)keyCode;
+ (BOOL)isMarkKey:(int)keyCode inputType:(PHTVInputType)type;
+ (BOOL)isToneKey:(int)keyCode inputType:(PHTVInputType)type;

#pragma mark - Character Conversion
+ (unichar)removeVietnameseTone:(unichar)character;
+ (unichar)addTone:(unichar)character toneType:(int)tone;
+ (NSString *)normalizeVietnameseString:(NSString *)input;

#pragma mark - Performance Utilities
+ (void)executeOnMainThread:(dispatch_block_t)block;
+ (void)executeOnBackgroundThread:(dispatch_block_t)block;
+ (void)executeAfterDelay:(NSTimeInterval)delay block:(dispatch_block_t)block;

#pragma mark - Cache Management
+ (void)clearCache;
+ (NSUInteger)cacheSize;

@end

NS_ASSUME_NONNULL_END

#endif /* PHTVUtilities_h */
