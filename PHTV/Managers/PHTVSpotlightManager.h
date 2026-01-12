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
+ (BOOL)isElementSpotlight:(AXUIElementRef)element;
+ (BOOL)containsSearchKeyword:(NSString*)str;

// Text Replacement Detection
+ (void)trackExternalDelete;
+ (BOOL)hasRecentExternalDeletes;
+ (int)getExternalDeleteCount;
+ (void)resetExternalDeleteTracking;

// Cache Invalidation Coordination
+ (void)handleSpotlightCacheInvalidation:(CGEventType)type keycode:(CGKeyCode)keycode flags:(CGEventFlags)flags;

@end

#endif /* PHTVSpotlightManager_h */
