//
//  PHTVCacheManager.mm
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import "PHTVCacheManager.h"
#import "PHTV-Swift.h"

static const uint64_t SPOTLIGHT_INVALIDATION_DEDUP_MS = 30;  // Skip duplicate invalidations within 30ms

@implementation PHTVCacheManager

#pragma mark - Initialization

+ (void)initialize {
    // No-op. Cache states are managed by PHTVCacheStateService.
}

#pragma mark - PID Cache

+ (NSString*)getBundleIdFromPID:(pid_t)pid {
    extern BOOL vSafeMode;
    return [PHTVCacheStateService bundleIdFromPID:(int32_t)pid safeMode:vSafeMode];
}

+ (void)cleanPIDCacheIfNeeded {
    [PHTVCacheStateService cleanPIDCacheIfNeeded];
}

+ (void)invalidatePIDCache {
    [PHTVCacheStateService invalidatePIDCache];
}

#pragma mark - App Characteristics Cache

+ (AppCharacteristics)getAppCharacteristics:(NSString*)bundleId {
    AppCharacteristics characteristics = {NO, NO, NO, NO, NO};
    [self tryGetAppCharacteristics:bundleId outCharacteristics:&characteristics];
    return characteristics;
}

+ (BOOL)tryGetAppCharacteristics:(NSString*)bundleId outCharacteristics:(AppCharacteristics*)outCharacteristics {
    if (outCharacteristics == NULL) {
        return NO;
    }

    PHTVAppCharacteristicsBox *box = [PHTVCacheStateService appCharacteristicsForBundleId:bundleId];
    if (!box) {
        return NO;
    }

    outCharacteristics->isSpotlightLike = box.isSpotlightLike;
    outCharacteristics->needsPrecomposedBatched = box.needsPrecomposedBatched;
    outCharacteristics->needsStepByStep = box.needsStepByStep;
    outCharacteristics->containsUnicodeCompound = box.containsUnicodeCompound;
    outCharacteristics->isSafari = box.isSafari;
    return YES;
}

+ (void)setAppCharacteristics:(AppCharacteristics)characteristics forBundleId:(NSString*)bundleId {
    [PHTVCacheStateService setAppCharacteristicsForBundleId:bundleId
                                           isSpotlightLike:characteristics.isSpotlightLike
                                    needsPrecomposedBatched:characteristics.needsPrecomposedBatched
                                            needsStepByStep:characteristics.needsStepByStep
                                    containsUnicodeCompound:characteristics.containsUnicodeCompound
                                                   isSafari:characteristics.isSafari];
}

+ (int)prepareAppCharacteristicsCacheForBundleId:(NSString*)bundleId maxAgeMs:(uint64_t)maxAgeMs {
    return (int)[PHTVCacheStateService prepareAppCharacteristicsCacheForBundleId:bundleId maxAgeMs:maxAgeMs];
}

+ (void)invalidateAppCharacteristicsCache {
    [PHTVCacheStateService invalidateAppCharacteristicsCache];
}

+ (NSString*)getLastCachedBundleId {
    return [PHTVCacheStateService lastCachedBundleId];
}

+ (void)setLastCachedBundleId:(NSString*)bundleId {
    [PHTVCacheStateService setLastCachedBundleId:bundleId];
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
