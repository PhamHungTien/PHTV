//
//  PHTVTimingManager.mm
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import "PHTVTimingManager.h"
#import "PHTV-Swift.h"

@implementation PHTVTimingManager

#pragma mark - Timing Utilities

+ (uint64_t)machTimeToMs:(uint64_t)machTime {
    return [PHTVTimingService machTimeToMs:machTime];
}

+ (uint64_t)machTimeToUs:(uint64_t)machTime {
    return [PHTVTimingService machTimeToUs:machTime];
}

+ (void)spotlightTinyDelay {
    [PHTVTimingService spotlightTinyDelay];
}

+ (void)delayMicroseconds:(uint64_t)microseconds {
    [PHTVTimingService delayMicroseconds:microseconds];
}

@end
