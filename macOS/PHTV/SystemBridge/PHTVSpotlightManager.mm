//
//  PHTVSpotlightManager.mm
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import "PHTVSpotlightManager.h"
#import "PHTV-Swift.h"

@implementation PHTVSpotlightManager

#pragma mark - Initialization

+ (void)initialize {
    // No-op. State tracking lives in PHTVSpotlightDetectionService.
}

#pragma mark - Spotlight Detection

+ (BOOL)containsSearchKeyword:(NSString*)str {
    return [PHTVSpotlightDetectionService containsSearchKeyword:str];
}

+ (BOOL)isElementSpotlight:(AXUIElementRef)element bundleId:(NSString*)bundleId {
    return [PHTVSpotlightDetectionService isElementSpotlight:element bundleId:bundleId];
}

+ (BOOL)isSpotlightActive {
    // Safe Mode: Skip AX API calls entirely - assume not in Spotlight.
    extern BOOL vSafeMode;
    if (vSafeMode) return NO;
    return [PHTVSpotlightDetectionService isSpotlightActive];
}

#pragma mark - Safari Detection

+ (BOOL)isSafariAddressBar {
    return [PHTVSpotlightDetectionService isSafariAddressBar];
}

+ (BOOL)isSafariGoogleDocsOrSheets {
    return [PHTVSpotlightDetectionService isSafariGoogleDocsOrSheets];
}

#pragma mark - Text Replacement Detection

+ (void)trackExternalDelete {
    [PHTVSpotlightDetectionService trackExternalDelete];
}

+ (int)getExternalDeleteCount {
    return (int)[PHTVSpotlightDetectionService externalDeleteCountValue];
}

+ (unsigned long long)elapsedSinceLastExternalDeleteMs {
    return [PHTVSpotlightDetectionService elapsedSinceLastExternalDeleteMs];
}

+ (PHTVTextReplacementDecision)detectTextReplacementForCode:(int)code
                                                    extCode:(int)extCode
                                             backspaceCount:(int)backspaceCount
                                               newCharCount:(int)newCharCount
                                        externalDeleteCount:(int)externalDeleteCount
                            restoreAndStartNewSessionCode:(int)restoreAndStartNewSessionCode
                                            willProcessCode:(int)willProcessCode
                                                restoreCode:(int)restoreCode
                                               deleteWindowMs:(unsigned long long)deleteWindowMs
                                            matchedElapsedMs:(unsigned long long *)matchedElapsedMs {
    return (PHTVTextReplacementDecision)[PHTVSpotlightDetectionService detectTextReplacementForCode:code
                                                                                             extCode:extCode
                                                                                      backspaceCount:backspaceCount
                                                                                        newCharCount:newCharCount
                                                                                 externalDeleteCount:externalDeleteCount
                                                                     restoreAndStartNewSessionCode:restoreAndStartNewSessionCode
                                                                                     willProcessCode:willProcessCode
                                                                                         restoreCode:restoreCode
                                                                                        deleteWindowMs:deleteWindowMs
                                                                                     matchedElapsedMs:matchedElapsedMs];
}

#pragma mark - Cache Invalidation Coordination

+ (void)handleSpotlightCacheInvalidation:(CGEventType)type keycode:(CGKeyCode)keycode flags:(CGEventFlags)flags {
    [PHTVSpotlightDetectionService handleSpotlightCacheInvalidation:type keycode:keycode flags:flags];
}

@end
