//
//  PHTVAppDetectionManager.h
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#ifndef PHTVAppDetectionManager_h
#define PHTVAppDetectionManager_h

#import <Foundation/Foundation.h>

@interface PHTVAppDetectionManager : NSObject

// Initialization
+ (void)initialize;

// Bundle ID Matching
+ (BOOL)isBrowserApp:(NSString*)bundleId;
+ (BOOL)isTerminalApp:(NSString*)bundleId;
+ (BOOL)isSpotlightLikeApp:(NSString*)bundleId;
+ (BOOL)needsPrecomposedBatched:(NSString*)bundleId;
+ (BOOL)needsStepByStep:(NSString*)bundleId;
+ (BOOL)containsUnicodeCompound:(NSString*)bundleId;
+ (BOOL)shouldDisableVietnamese:(NSString*)bundleId;
+ (BOOL)needsNiceSpace:(NSString*)bundleId;

// Focused App Detection
+ (NSString*)getFocusedAppBundleId;
+ (pid_t)getFocusedAppPID;

// Utility
+ (BOOL)bundleIdMatchesAppSet:(NSString*)bundleId appSet:(NSSet*)appSet;

@end

#endif /* PHTVAppDetectionManager_h */
