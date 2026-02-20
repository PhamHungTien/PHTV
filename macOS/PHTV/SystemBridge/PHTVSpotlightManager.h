//
//  PHTVSpotlightManager.h
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#ifndef PHTVSpotlightManager_h
#define PHTVSpotlightManager_h

#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>
#import <Carbon/Carbon.h>

typedef NS_ENUM(NSInteger, PHTVTextReplacementDecision) {
    PHTVTextReplacementDecisionNone = 0,
    PHTVTextReplacementDecisionExternalDelete = 1,
    PHTVTextReplacementDecisionPattern2A = 2,
    PHTVTextReplacementDecisionPattern2B = 3,
    PHTVTextReplacementDecisionFallbackNoMatch = 4
};

@interface PHTVSpotlightManager : NSObject

// Initialization
+ (void)initialize;

// Spotlight Detection
+ (BOOL)isSpotlightActive;
+ (BOOL)isElementSpotlight:(AXUIElementRef)element bundleId:(NSString*)bundleId;
+ (BOOL)containsSearchKeyword:(NSString*)str;

// Safari Detection
+ (BOOL)isSafariAddressBar;
+ (BOOL)isSafariGoogleDocsOrSheets;

// Text Replacement Detection
+ (void)trackExternalDelete;
+ (int)getExternalDeleteCount;
+ (unsigned long long)elapsedSinceLastExternalDeleteMs;
+ (PHTVTextReplacementDecision)detectTextReplacementForCode:(int)code
                                                    extCode:(int)extCode
                                             backspaceCount:(int)backspaceCount
                                               newCharCount:(int)newCharCount
                                        externalDeleteCount:(int)externalDeleteCount
                            restoreAndStartNewSessionCode:(int)restoreAndStartNewSessionCode
                                            willProcessCode:(int)willProcessCode
                                                restoreCode:(int)restoreCode
                                               deleteWindowMs:(unsigned long long)deleteWindowMs
                                            matchedElapsedMs:(unsigned long long *)matchedElapsedMs;

// Cache Invalidation Coordination
+ (void)handleSpotlightCacheInvalidation:(CGEventType)type keycode:(CGKeyCode)keycode flags:(CGEventFlags)flags;

@end

#endif /* PHTVSpotlightManager_h */
