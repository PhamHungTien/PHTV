//
//  PHTVCacheManager.h
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#ifndef PHTVCacheManager_h
#define PHTVCacheManager_h

#import <Foundation/Foundation.h>
#import <Carbon/Carbon.h>

// App characteristics structure for caching app behavior
typedef struct {
    BOOL isSpotlightLike;
    BOOL needsPrecomposedBatched;
    BOOL isTerminal;
    BOOL needsStepByStep;
    BOOL containsUnicodeCompound;
} AppCharacteristics;

@interface PHTVCacheManager : NSObject

// Initialization
+ (void)initialize;

// PID Cache
+ (NSString*)getBundleIdFromPID:(pid_t)pid;
+ (void)cleanPIDCacheIfNeeded;
+ (void)invalidatePIDCache;

// App Characteristics Cache
+ (AppCharacteristics)getAppCharacteristics:(NSString*)bundleId;
+ (void)invalidateAppCharacteristicsCache;
+ (NSString*)getLastCachedBundleId;
+ (void)setLastCachedBundleId:(NSString*)bundleId;

// Spotlight Cache
+ (BOOL)getCachedSpotlightActive;
+ (pid_t)getCachedFocusedPID;
+ (NSString*)getCachedFocusedBundleId;
+ (uint64_t)getLastSpotlightCheckTime;
+ (void)updateSpotlightCache:(BOOL)isActive pid:(pid_t)pid bundleId:(NSString*)bundleId;
+ (void)invalidateSpotlightCache;

// Layout Cache
+ (CGKeyCode)getCachedLayoutConversion:(CGKeyCode)keycode;
+ (void)setCachedLayoutConversion:(CGKeyCode)keycode result:(CGKeyCode)result;
+ (void)invalidateLayoutCache;
+ (BOOL)isLayoutCacheValid;

@end

#endif /* PHTVCacheManager_h */
