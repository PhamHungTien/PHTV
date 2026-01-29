//
//  PHTVTimingManager.h
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#ifndef PHTVTimingManager_h
#define PHTVTimingManager_h

#import <Foundation/Foundation.h>

// Delay types for app-specific timing
typedef NS_ENUM(NSInteger, DelayType) {
    DelayTypeNone = 0,
    DelayTypeTerminal = 1,
    DelayTypeSpotlight = 2
};

@interface PHTVTimingManager : NSObject

// Timing Utilities
+ (uint64_t)machTimeToMs:(uint64_t)machTime;
+ (uint64_t)machTimeToUs:(uint64_t)machTime;
+ (void)spotlightTinyDelay;
+ (void)delayMicroseconds:(uint64_t)microseconds;

@end

#endif /* PHTVTimingManager_h */
