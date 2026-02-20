//
//  PHTVAppDetectionManager.mm
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import "PHTVAppDetectionManager.h"
#import "PHTV-Swift.h"

@implementation PHTVAppDetectionManager

#pragma mark - Bundle ID Matching

+ (BOOL)isBrowserApp:(NSString*)bundleId {
    return [PHTVAppDetectionService isBrowserApp:bundleId];
}

+ (BOOL)isSpotlightLikeApp:(NSString*)bundleId {
    return [PHTVAppDetectionService isSpotlightLikeApp:bundleId];
}

+ (BOOL)needsPrecomposedBatched:(NSString*)bundleId {
    return [PHTVAppDetectionService needsPrecomposedBatched:bundleId];
}

+ (BOOL)needsStepByStep:(NSString*)bundleId {
    return [PHTVAppDetectionService needsStepByStep:bundleId];
}

+ (BOOL)containsUnicodeCompound:(NSString*)bundleId {
    return [PHTVAppDetectionService containsUnicodeCompound:bundleId];
}

+ (BOOL)isSafariApp:(NSString*)bundleId {
    return [PHTVAppDetectionService isSafariApp:bundleId];
}

+ (BOOL)shouldDisableVietnamese:(NSString*)bundleId {
    return [PHTVAppDetectionService shouldDisableVietnamese:bundleId];
}

+ (BOOL)needsNiceSpace:(NSString*)bundleId {
    return [PHTVAppDetectionService needsNiceSpace:bundleId];
}

+ (BOOL)isTerminalApp:(NSString*)bundleId {
    return [PHTVAppDetectionService isTerminalApp:bundleId];
}

+ (BOOL)isFastTerminalApp:(NSString*)bundleId {
    return [PHTVAppDetectionService isFastTerminalApp:bundleId];
}

+ (BOOL)isMediumTerminalApp:(NSString*)bundleId {
    return [PHTVAppDetectionService isMediumTerminalApp:bundleId];
}

+ (BOOL)isSlowTerminalApp:(NSString*)bundleId {
    return [PHTVAppDetectionService isSlowTerminalApp:bundleId];
}

+ (BOOL)isVSCodeFamilyApp:(NSString*)bundleId {
    return [PHTVAppDetectionService isVSCodeFamilyApp:bundleId];
}

+ (BOOL)isJetBrainsApp:(NSString*)bundleId {
    return [PHTVAppDetectionService isJetBrainsApp:bundleId];
}

+ (BOOL)isIDEApp:(NSString*)bundleId {
    return [PHTVAppDetectionService isIDEApp:bundleId];
}

+ (BOOL)containsTerminalKeyword:(NSString*)value {
    return [PHTVAppDetectionService containsTerminalKeyword:value];
}

#pragma mark - Utility

+ (BOOL)bundleIdMatchesAppSet:(NSString*)bundleId appSet:(NSSet*)appSet {
    return [PHTVAppDetectionService bundleIdMatchesAppSet:bundleId appSet:appSet];
}

@end
