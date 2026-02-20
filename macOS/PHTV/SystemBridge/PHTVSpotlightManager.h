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
+ (unsigned long long)consumeRecentExternalDeleteWithinMs:(unsigned long long)thresholdMs;

// Cache Invalidation Coordination
+ (void)handleSpotlightCacheInvalidation:(CGEventType)type keycode:(CGKeyCode)keycode flags:(CGEventFlags)flags;

@end

#endif /* PHTVSpotlightManager_h */
