//
//  UsageStats.h
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface UsageStats : NSObject

+ (instancetype)shared;
- (void)incrementWordCount;
- (void)incrementCharacterCount;
- (NSInteger)getTotalWords;
- (NSInteger)getTotalCharacters;
- (NSInteger)getTodayWords;
- (NSInteger)getTodayCharacters;
- (void)resetDailyStats;
- (NSDictionary *)getStatsSummary;

@end

NS_ASSUME_NONNULL_END
