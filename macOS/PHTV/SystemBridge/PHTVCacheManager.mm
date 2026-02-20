//
//  PHTVCacheManager.mm
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import "PHTVCacheManager.h"
#import "PHTV-Swift.h"
#import <Cocoa/Cocoa.h>
#import <os/lock.h>
#import <mach/mach_time.h>
#import <libproc.h>
#import <Carbon/Carbon.h>

// Performance & Cache Configuration
static const uint64_t PID_CACHE_CLEAN_INTERVAL_MS = 60000;   // 60 seconds
static const NSUInteger PID_CACHE_INITIAL_CAPACITY = 128;
static const uint64_t SPOTLIGHT_INVALIDATION_DEDUP_MS = 30;  // Skip duplicate invalidations within 30ms

@implementation PHTVCacheManager

// PID Cache
static NSMutableDictionary<NSNumber*, NSString*> *_pidBundleCache = nil;
static uint64_t _lastCacheCleanTime = 0;
static os_unfair_lock _pidCacheLock = OS_UNFAIR_LOCK_INIT;

// App Characteristics Cache
static NSMutableDictionary<NSString*, NSValue*> *_appCharacteristicsCache = nil;
static os_unfair_lock _appCharCacheLock = OS_UNFAIR_LOCK_INIT;
static NSString* _lastCachedBundleId = nil;
static uint64_t _lastCacheInvalidationTime = 0;

// Shared mach time conversion cache
static mach_timebase_info_data_t _cacheTimebaseInfo;
static dispatch_once_t _cacheTimebaseInitToken;

static inline uint64_t PHTVCacheMachTimeToMs(uint64_t machTime) {
    dispatch_once(&_cacheTimebaseInitToken, ^{
        mach_timebase_info(&_cacheTimebaseInfo);
    });
    return (machTime * _cacheTimebaseInfo.numer) / (_cacheTimebaseInfo.denom * 1000000);
}

#pragma mark - Initialization

+ (void)initialize {
    if (self == [PHTVCacheManager class]) {
        // Initialize PID cache
        _pidBundleCache = [[NSMutableDictionary alloc] initWithCapacity:PID_CACHE_INITIAL_CAPACITY];

        // Initialize App Characteristics cache
        _appCharacteristicsCache = [[NSMutableDictionary alloc] init];
    }
}

#pragma mark - PID Cache

+ (NSString*)getBundleIdFromPID:(pid_t)pid {
    if (__builtin_expect(pid <= 0, 0)) return nil;

    // Fast path: check cache with modern lock
    NSNumber *pidKey = @(pid);
    os_unfair_lock_lock(&_pidCacheLock);

    // Initialize cache on first use
    if (__builtin_expect(_pidBundleCache == nil, 0)) {
        _pidBundleCache = [NSMutableDictionary dictionaryWithCapacity:PID_CACHE_INITIAL_CAPACITY];
        _lastCacheCleanTime = mach_absolute_time();
    }

    NSString *cached = _pidBundleCache[pidKey];

    // Smart cache cleanup: Check every 60 seconds
    uint64_t now = mach_absolute_time();
    uint64_t elapsed_ms = PHTVCacheMachTimeToMs(now - _lastCacheCleanTime);

    if (__builtin_expect(elapsed_ms > PID_CACHE_CLEAN_INTERVAL_MS, 0)) {
        [_pidBundleCache removeAllObjects];
        _lastCacheCleanTime = now;
        #ifdef DEBUG
        NSLog(@"[Cache] PID cache cleared (interval expired)");
        #endif
    }

    os_unfair_lock_unlock(&_pidCacheLock);

    if (cached) {
        return [cached isEqualToString:@""] ? nil : cached;
    }

    // Try to get bundle ID from running application
    NSRunningApplication *app = [NSRunningApplication runningApplicationWithProcessIdentifier:pid];
    if (app) {
        NSString *bundleId = app.bundleIdentifier ?: @"";
        os_unfair_lock_lock(&_pidCacheLock);
        _pidBundleCache[pidKey] = bundleId;
        os_unfair_lock_unlock(&_pidCacheLock);
        return bundleId.length > 0 ? bundleId : nil;
    }

    // Safe Mode: Skip proc_pidpath for system processes
    extern BOOL vSafeMode;
    if (vSafeMode) {
        os_unfair_lock_lock(&_pidCacheLock);
        _pidBundleCache[pidKey] = @"";
        os_unfair_lock_unlock(&_pidCacheLock);
        return nil;
    }

    // Fallback: get process path
    char pathBuffer[PROC_PIDPATHINFO_MAXSIZE];
    if (proc_pidpath(pid, pathBuffer, sizeof(pathBuffer)) > 0) {
        NSString *path = [NSString stringWithUTF8String:pathBuffer];
        #ifdef DEBUG
        NSLog(@"PHTV DEBUG: PID=%d path=%@", pid, path);
        #endif
        // Check for known system processes
        if ([path containsString:@"Spotlight"]) {
            os_unfair_lock_lock(&_pidCacheLock);
            _pidBundleCache[pidKey] = @"com.apple.Spotlight";
            os_unfair_lock_unlock(&_pidCacheLock);
            return @"com.apple.Spotlight";
        }
        if ([path containsString:@"SystemUIServer"]) {
            os_unfair_lock_lock(&_pidCacheLock);
            _pidBundleCache[pidKey] = @"com.apple.systemuiserver";
            os_unfair_lock_unlock(&_pidCacheLock);
            return @"com.apple.systemuiserver";
        }
        if ([path containsString:@"Launchpad"]) {
            os_unfair_lock_lock(&_pidCacheLock);
            _pidBundleCache[pidKey] = @"com.apple.launchpad.launcher";
            os_unfair_lock_unlock(&_pidCacheLock);
            return @"com.apple.launchpad.launcher";
        }
    }

    // Cache negative result
    os_unfair_lock_lock(&_pidCacheLock);
    _pidBundleCache[pidKey] = @"";
    os_unfair_lock_unlock(&_pidCacheLock);
    return nil;
}

+ (void)cleanPIDCacheIfNeeded {
    uint64_t now = mach_absolute_time();
    os_unfair_lock_lock(&_pidCacheLock);

    if (_pidBundleCache != nil) {
        uint64_t elapsed_ms = PHTVCacheMachTimeToMs(now - _lastCacheCleanTime);

        if (elapsed_ms > PID_CACHE_CLEAN_INTERVAL_MS) {
            [_pidBundleCache removeAllObjects];
            _lastCacheCleanTime = now;
        }
    }

    os_unfair_lock_unlock(&_pidCacheLock);
}

+ (void)invalidatePIDCache {
    os_unfair_lock_lock(&_pidCacheLock);
    [_pidBundleCache removeAllObjects];
    _lastCacheCleanTime = 0;
    os_unfair_lock_unlock(&_pidCacheLock);
}

#pragma mark - App Characteristics Cache

+ (AppCharacteristics)getAppCharacteristics:(NSString*)bundleId {
    AppCharacteristics characteristics = {NO, NO, NO, NO, NO};

    if (!bundleId) {
        return characteristics;
    }

    os_unfair_lock_lock(&_appCharCacheLock);
    NSValue* cachedValue = _appCharacteristicsCache[bundleId];
    if (cachedValue) {
        [cachedValue getValue:&characteristics];
    }
    os_unfair_lock_unlock(&_appCharCacheLock);

    return characteristics;
}

+ (void)invalidateAppCharacteristicsCache {
    os_unfair_lock_lock(&_appCharCacheLock);
    [_appCharacteristicsCache removeAllObjects];
    _lastCachedBundleId = nil;
    _lastCacheInvalidationTime = mach_absolute_time();
    os_unfair_lock_unlock(&_appCharCacheLock);
}

+ (NSString*)getLastCachedBundleId {
    os_unfair_lock_lock(&_appCharCacheLock);
    NSString* bundleId = _lastCachedBundleId;
    os_unfair_lock_unlock(&_appCharCacheLock);
    return bundleId;
}

+ (void)setLastCachedBundleId:(NSString*)bundleId {
    os_unfair_lock_lock(&_appCharCacheLock);
    _lastCachedBundleId = bundleId;
    os_unfair_lock_unlock(&_appCharCacheLock);
}

#pragma mark - Spotlight Cache

+ (BOOL)getCachedSpotlightActive {
    return [PHTVCacheStateService cachedSpotlightActive];
}

+ (pid_t)getCachedFocusedPID {
    return (pid_t)[PHTVCacheStateService cachedFocusedPID];
}

+ (NSString*)getCachedFocusedBundleId {
    return [PHTVCacheStateService cachedFocusedBundleId];
}

+ (uint64_t)getLastSpotlightCheckTime {
    return [PHTVCacheStateService lastSpotlightCheckTime];
}

+ (uint64_t)getLastSpotlightInvalidationTime {
    return [PHTVCacheStateService lastSpotlightInvalidationTime];
}

+ (void)updateSpotlightCache:(BOOL)isActive pid:(pid_t)pid bundleId:(NSString*)bundleId {
    [PHTVCacheStateService updateSpotlightCache:isActive
                                            pid:(int32_t)pid
                                       bundleId:bundleId];
}

+ (void)invalidateSpotlightCache {
    int status = (int)[PHTVCacheStateService invalidateSpotlightCacheWithDedupWindowMs:SPOTLIGHT_INVALIDATION_DEDUP_MS];

    // Log cache invalidation only in debug builds.
#ifdef DEBUG
    if (status == 2) {
        NSLog(@"[Spotlight] 🔄 CACHE INVALIDATED (was active)");
    }
#endif
}

#pragma mark - Layout Cache

+ (CGKeyCode)getCachedLayoutConversion:(CGKeyCode)keycode {
    return (CGKeyCode)[PHTVCacheStateService cachedLayoutConversion:(uint16_t)keycode];
}

+ (void)setCachedLayoutConversion:(CGKeyCode)keycode result:(CGKeyCode)result {
    [PHTVCacheStateService setCachedLayoutConversion:(uint16_t)keycode result:(uint16_t)result];
}

+ (void)invalidateLayoutCache {
    [PHTVCacheStateService invalidateLayoutCache];
}

+ (BOOL)isLayoutCacheValid {
    return [PHTVCacheStateService isLayoutCacheValid];
}

@end
