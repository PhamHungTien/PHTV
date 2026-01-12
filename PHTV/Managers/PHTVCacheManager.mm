//
//  PHTVCacheManager.mm
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import "PHTVCacheManager.h"
#import <Cocoa/Cocoa.h>
#import <os/lock.h>
#import <mach/mach_time.h>
#import <libproc.h>
#import <Carbon/Carbon.h>

// Performance & Cache Configuration
static const uint64_t PID_CACHE_CLEAN_INTERVAL_MS = 60000;   // 60 seconds
static const NSUInteger PID_CACHE_INITIAL_CAPACITY = 128;

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

// Spotlight Cache
static BOOL _cachedSpotlightActive = NO;
static uint64_t _lastSpotlightCheckTime = 0;
static pid_t _cachedFocusedPID = 0;
static NSString* _cachedFocusedBundleId = nil;
static os_unfair_lock _spotlightCacheLock = OS_UNFAIR_LOCK_INIT;

// Layout Cache
static CGKeyCode _layoutCache[256];
static BOOL _layoutCacheValid = NO;

#pragma mark - Initialization

+ (void)initialize {
    if (self == [PHTVCacheManager class]) {
        // Initialize PID cache
        _pidBundleCache = [[NSMutableDictionary alloc] initWithCapacity:PID_CACHE_INITIAL_CAPACITY];

        // Initialize App Characteristics cache
        _appCharacteristicsCache = [[NSMutableDictionary alloc] init];

        // Initialize Layout cache
        memset(_layoutCache, 0, sizeof(_layoutCache));
        _layoutCacheValid = NO;
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
    static mach_timebase_info_data_t timebase;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mach_timebase_info(&timebase);
    });
    uint64_t elapsed_ms = (now - _lastCacheCleanTime) * timebase.numer / (timebase.denom * 1000000);

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
        static mach_timebase_info_data_t timebase;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            mach_timebase_info(&timebase);
        });
        uint64_t elapsed_ms = (now - _lastCacheCleanTime) * timebase.numer / (timebase.denom * 1000000);

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
    os_unfair_lock_lock(&_spotlightCacheLock);
    BOOL isActive = _cachedSpotlightActive;
    os_unfair_lock_unlock(&_spotlightCacheLock);
    return isActive;
}

+ (pid_t)getCachedFocusedPID {
    os_unfair_lock_lock(&_spotlightCacheLock);
    pid_t pid = _cachedFocusedPID;
    os_unfair_lock_unlock(&_spotlightCacheLock);
    return pid;
}

+ (NSString*)getCachedFocusedBundleId {
    os_unfair_lock_lock(&_spotlightCacheLock);
    NSString* bundleId = _cachedFocusedBundleId;
    os_unfair_lock_unlock(&_spotlightCacheLock);
    return bundleId;
}

+ (uint64_t)getLastSpotlightCheckTime {
    os_unfair_lock_lock(&_spotlightCacheLock);
    uint64_t time = _lastSpotlightCheckTime;
    os_unfair_lock_unlock(&_spotlightCacheLock);
    return time;
}

+ (void)updateSpotlightCache:(BOOL)isActive pid:(pid_t)pid bundleId:(NSString*)bundleId {
    os_unfair_lock_lock(&_spotlightCacheLock);
    _cachedSpotlightActive = isActive;
    _lastSpotlightCheckTime = mach_absolute_time();
    _cachedFocusedPID = pid;
    _cachedFocusedBundleId = bundleId;
    os_unfair_lock_unlock(&_spotlightCacheLock);
}

+ (void)invalidateSpotlightCache {
    os_unfair_lock_lock(&_spotlightCacheLock);
    _lastSpotlightCheckTime = 0;
    _cachedFocusedPID = 0;
    _cachedFocusedBundleId = nil;
    os_unfair_lock_unlock(&_spotlightCacheLock);
}

#pragma mark - Layout Cache

+ (CGKeyCode)getCachedLayoutConversion:(CGKeyCode)keycode {
    if (keycode >= 256) {
        return 0;
    }
    return _layoutCache[keycode];
}

+ (void)setCachedLayoutConversion:(CGKeyCode)keycode result:(CGKeyCode)result {
    if (keycode < 256) {
        _layoutCache[keycode] = result;
        _layoutCacheValid = YES;
    }
}

+ (void)invalidateLayoutCache {
    memset(_layoutCache, 0, sizeof(_layoutCache));
    _layoutCacheValid = NO;
}

+ (BOOL)isLayoutCacheValid {
    return _layoutCacheValid;
}

@end
