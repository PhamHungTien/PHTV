//
//  PHTVTimingManager.mm
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import "PHTVTimingManager.h"
#import <mach/mach_time.h>
#import <os/lock.h>
#import <unistd.h>

// Terminal/IDE Delay Configuration
static const uint64_t TERMINAL_KEYSTROKE_DELAY_US = 1500;    // Per-character delay (reduced from 3000us)
static const uint64_t TERMINAL_SETTLE_DELAY_US = 4000;       // After all backspaces (reduced from 8000us)
static const uint64_t TERMINAL_FINAL_SETTLE_US = 10000;      // Final settle after all text (reduced from 20000us)
static const uint64_t SPOTLIGHT_TINY_DELAY_US = 2000;        // Spotlight timing delay (reduced from 3000us)

@implementation PHTVTimingManager

// Adaptive delay tracking
static uint64_t _lastKeystrokeTimestamp = 0;
static uint64_t _averageResponseTimeUs = 0;
static NSUInteger _responseTimeSamples = 0;
static os_unfair_lock _adaptiveDelayLock = OS_UNFAIR_LOCK_INIT;

// High-resolution timing
static mach_timebase_info_data_t _timebase_info;
static dispatch_once_t _timebase_init_token;

#pragma mark - Initialization

+ (void)initialize {
    if (self == [PHTVTimingManager class]) {
        // Initialize timebase info
        dispatch_once(&_timebase_init_token, ^{
            mach_timebase_info(&_timebase_info);
        });
    }
}

#pragma mark - Delay Constants

+ (uint64_t)getTerminalKeystrokeDelay {
    return TERMINAL_KEYSTROKE_DELAY_US;
}

+ (uint64_t)getTerminalSettleDelay {
    return TERMINAL_SETTLE_DELAY_US;
}

+ (uint64_t)getTerminalFinalSettle {
    return TERMINAL_FINAL_SETTLE_US;
}

+ (uint64_t)getSpotlightTinyDelay {
    return SPOTLIGHT_TINY_DELAY_US;
}

#pragma mark - Adaptive Delay Tracking

+ (void)updateResponseTimeTracking {
    dispatch_once(&_timebase_init_token, ^{
        mach_timebase_info(&_timebase_info);
    });

    uint64_t now = mach_absolute_time();

    os_unfair_lock_lock(&_adaptiveDelayLock);

    if (_lastKeystrokeTimestamp != 0) {
        uint64_t elapsed = now - _lastKeystrokeTimestamp;
        uint64_t elapsedUs = (elapsed * _timebase_info.numer) / (_timebase_info.denom * 1000);

        // Update running average
        if (_responseTimeSamples == 0) {
            _averageResponseTimeUs = elapsedUs;
            _responseTimeSamples = 1;
        } else {
            _averageResponseTimeUs = (_averageResponseTimeUs * _responseTimeSamples + elapsedUs) / (_responseTimeSamples + 1);
            _responseTimeSamples++;

            // Cap samples to prevent overflow
            if (_responseTimeSamples > 100) {
                _responseTimeSamples = 100;
            }
        }
    }

    _lastKeystrokeTimestamp = now;

    os_unfair_lock_unlock(&_adaptiveDelayLock);
}

+ (uint64_t)getAdaptiveDelay:(uint64_t)baseDelay maxDelay:(uint64_t)maxDelay {
    os_unfair_lock_lock(&_adaptiveDelayLock);

    uint64_t adaptiveDelay = baseDelay;

    // If system is under load (high response time), increase delays
    if (_averageResponseTimeUs > 50000) {  // > 50ms average response time
        // Scale delay proportionally (up to maxDelay)
        double scaleFactor = (double)_averageResponseTimeUs / 50000.0;
        adaptiveDelay = (uint64_t)(baseDelay * scaleFactor);

        if (adaptiveDelay > maxDelay) {
            adaptiveDelay = maxDelay;
        }
    }

    os_unfair_lock_unlock(&_adaptiveDelayLock);

    return adaptiveDelay;
}

+ (uint64_t)getAverageResponseTime {
    os_unfair_lock_lock(&_adaptiveDelayLock);
    uint64_t avgTime = _averageResponseTimeUs;
    os_unfair_lock_unlock(&_adaptiveDelayLock);
    return avgTime;
}

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
    usleep((useconds_t)SPOTLIGHT_TINY_DELAY_US);
}

+ (void)delayMicroseconds:(uint64_t)microseconds {
    usleep((useconds_t)microseconds);
}

@end
