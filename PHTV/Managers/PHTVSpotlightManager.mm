//
//  PHTVSpotlightManager.mm
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import "PHTVSpotlightManager.h"
#import "PHTVCacheManager.h"
#import "PHTVAppDetectionManager.h"
#import "PHTVTimingManager.h"
#import <mach/mach_time.h>

@implementation PHTVSpotlightManager

// Text Replacement detection
static BOOL _externalDeleteDetected = NO;
static uint64_t _lastExternalDeleteTime = 0;
static int _externalDeleteCount = 0;

#pragma mark - Initialization

+ (void)initialize {
    if (self == [PHTVSpotlightManager class]) {
        // Initialize state
        _externalDeleteDetected = NO;
        _lastExternalDeleteTime = 0;
        _externalDeleteCount = 0;
    }
}

#pragma mark - Spotlight Detection

+ (BOOL)isSpotlightActive {
    // Placeholder - will be implemented when extracting from PHTV.mm
    return NO;
}

+ (BOOL)isElementSpotlight:(AXUIElementRef)element {
    // Placeholder - will be implemented when extracting from PHTV.mm
    return NO;
}

+ (BOOL)containsSearchKeyword:(NSString*)str {
    // Placeholder - will be implemented when extracting from PHTV.mm
    return NO;
}

#pragma mark - Text Replacement Detection

+ (void)trackExternalDelete {
    uint64_t now = mach_absolute_time();

    // Reset count if too much time passed (>30000ms = 30 seconds)
    if (_lastExternalDeleteTime != 0) {
        uint64_t elapsed_ms = [PHTVTimingManager machTimeToMs:now - _lastExternalDeleteTime];
        if (elapsed_ms > 30000) {
            _externalDeleteCount = 0;
        }
    }

    _lastExternalDeleteTime = now;
    _externalDeleteCount++;
    _externalDeleteDetected = YES;
}

+ (BOOL)hasRecentExternalDeletes {
    return _externalDeleteDetected;
}

+ (int)getExternalDeleteCount {
    return _externalDeleteCount;
}

+ (void)resetExternalDeleteTracking {
    _externalDeleteDetected = NO;
    _lastExternalDeleteTime = 0;
    _externalDeleteCount = 0;
}

#pragma mark - Cache Invalidation Coordination

+ (void)handleSpotlightCacheInvalidation:(CGEventType)type keycode:(CGKeyCode)keycode flags:(CGEventFlags)flags {
    // Check if Cmd+Space was pressed (Spotlight shortcut)
    if (type == kCGEventKeyDown && keycode == 49 && (flags & kCGEventFlagMaskCommand)) { // Space = 49
        [PHTVCacheManager invalidateSpotlightCache];
    }
}

@end
