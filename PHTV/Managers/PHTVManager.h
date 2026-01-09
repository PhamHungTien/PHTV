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

// CRITICAL: Permission loss protection
+(BOOL)hasPermissionLost;
+(void)markPermissionLost;

// COMPREHENSIVE permission check using multiple methods
// Uses BOTH AXIsProcessTrusted() AND test event tap for reliable detection
+(BOOL)canCreateEventTap;
+(void)invalidatePermissionCache;  // Force fresh check on next call
+(BOOL)forcePermissionCheck;       // Bypasses all caching, resets counters

// System Settings detection for adaptive polling
+(BOOL)isSystemSettingsOpen;
+(void)updateSystemSettingsState;

// Relaunch detection - tracks when app needs restart for permission to work
+(BOOL)shouldSuggestRelaunch;
+(void)resetAxYesTapNoCounter;

// Table codes
+(NSArray*)getTableCodes;

// Utilities
+(NSString*)getBuildDate;
+(void)showMessage:(NSWindow*)window message:(NSString*)msg subMsg:(NSString*)subMsg;

// Convert feature
+(BOOL)quickConvert;

// Application Support
+(NSString*)getApplicationSupportFolder;

// Safe Mode - Disables Accessibility API calls for unsupported hardware
+(BOOL)isSafeModeEnabled;
+(void)setSafeModeEnabled:(BOOL)enabled;
+(void)clearAXTestFlag;  // Call on normal app termination

@end

#endif /* PHTVManager_h */
