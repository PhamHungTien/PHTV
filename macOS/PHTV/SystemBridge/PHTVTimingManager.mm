//
//  PHTVTimingManager.mm
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import "PHTVTimingManager.h"
#import <mach/mach_time.h>
#import <unistd.h>

@implementation PHTVTimingManager

// High-resolution timing
static mach_timebase_info_data_t _timebase_info;
static dispatch_once_t _timebase_init_token;

#pragma mark - Timing Utilities

+ (uint64_t)machTimeToMs:(uint64_t)machTime {
    dispatch_once(&_timebase_init_token, ^{
        mach_timebase_info(&_timebase_info);
    });

    return (machTime * _timebase_info.numer) / (_timebase_info.denom * 1000000);
}

+ (uint64_t)machTimeToUs:(uint64_t)machTime {
    dispatch_once(&_timebase_init_token, ^{
        mach_timebase_info(&_timebase_info);
    });

    return (machTime * _timebase_info.numer) / (_timebase_info.denom * 1000);
}

+ (void)spotlightTinyDelay {
}

+ (void)delayMicroseconds:(uint64_t)microseconds {
}

@end