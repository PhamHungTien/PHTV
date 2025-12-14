//
//  UsageStats.m
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import "UsageStats.h"

#define STATS_TOTAL_WORDS @"StatsTotalWords"
#define STATS_TOTAL_CHARS @"StatsTotalCharacters"
#define STATS_TODAY_WORDS @"StatsTodayWords"
#define STATS_TODAY_CHARS @"StatsTodayCharacters"
#define STATS_LAST_RESET_DATE @"StatsLastResetDate"

@implementation UsageStats

+ (instancetype)shared {
    static UsageStats *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
        [instance checkAndResetDailyStats];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // Check and reset stats daily
        [self checkAndResetDailyStats];
    }
    return self;
}

- (void)checkAndResetDailyStats {
    NSString *lastResetDate = [[NSUserDefaults standardUserDefaults] stringForKey:STATS_LAST_RESET_DATE];
    NSString *today = [self getTodayDateString];
    
    if (!lastResetDate || ![lastResetDate isEqualToString:today]) {
        [self resetDailyStats];
    }
}

- (NSString *)getTodayDateString {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd"];
    return [formatter stringFromDate:[NSDate date]];
}

- (void)incrementWordCount {
    NSInteger total = [self getTotalWords];
    NSInteger today = [self getTodayWords];
    
    [[NSUserDefaults standardUserDefaults] setInteger:total + 1 forKey:STATS_TOTAL_WORDS];
    [[NSUserDefaults standardUserDefaults] setInteger:today + 1 forKey:STATS_TODAY_WORDS];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)incrementCharacterCount {
    NSInteger total = [self getTotalCharacters];
    NSInteger today = [self getTodayCharacters];
    
    [[NSUserDefaults standardUserDefaults] setInteger:total + 1 forKey:STATS_TOTAL_CHARS];
    [[NSUserDefaults standardUserDefaults] setInteger:today + 1 forKey:STATS_TODAY_CHARS];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSInteger)getTotalWords {
    return [[NSUserDefaults standardUserDefaults] integerForKey:STATS_TOTAL_WORDS];
}

- (NSInteger)getTotalCharacters {
    return [[NSUserDefaults standardUserDefaults] integerForKey:STATS_TOTAL_CHARS];
}

- (NSInteger)getTodayWords {
    [self checkAndResetDailyStats];
    return [[NSUserDefaults standardUserDefaults] integerForKey:STATS_TODAY_WORDS];
}

- (NSInteger)getTodayCharacters {
    [self checkAndResetDailyStats];
    return [[NSUserDefaults standardUserDefaults] integerForKey:STATS_TODAY_CHARS];
}

- (void)resetDailyStats {
    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:STATS_TODAY_WORDS];
    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:STATS_TODAY_CHARS];
    [[NSUserDefaults standardUserDefaults] setObject:[self getTodayDateString] forKey:STATS_LAST_RESET_DATE];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSDictionary *)getStatsSummary {
    return @{
        @"totalWords": @([self getTotalWords]),
        @"totalCharacters": @([self getTotalCharacters]),
        @"todayWords": @([self getTodayWords]),
        @"todayCharacters": @([self getTodayCharacters])
    };
}

@end
