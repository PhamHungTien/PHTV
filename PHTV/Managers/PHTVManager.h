//
//  PHTVManager.h
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#ifndef PHTVManager_h
#define PHTVManager_h

#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>

@interface PHTVManager : NSObject

// Core functionality
+(BOOL)isInited;
+(BOOL)initEventTap;
+(BOOL)stopEventTap;
+(void)handleEventTapDisabled:(CGEventType)type;
+(BOOL)isEventTapEnabled;
+(void)ensureEventTapAlive;

// Table codes
+(NSArray*)getTableCodes;

// Utilities
+(NSString*)getBuildDate;
+(void)showMessage:(NSWindow*)window message:(NSString*)msg subMsg:(NSString*)subMsg;

// Convert feature
+(BOOL)quickConvert;

// Application Support
+(NSString*)getApplicationSupportFolder;

@end

#endif /* PHTVManager_h */
