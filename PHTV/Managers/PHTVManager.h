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

// TCC entry corruption detection and auto-fix
+(BOOL)isTCCEntryCorrupt;          // Check if TCC entry is corrupt (app not appearing in System Settings)
+(BOOL)autoFixTCCEntryWithError:(NSError **)error;  // Automatically fix TCC corruption (shows password prompt)

// TCC change notification
+(void)startTCCNotificationListener;  // Start listening for TCC database changes
+(void)stopTCCNotificationListener;   // Stop listening

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

// Binary integrity check - Detects if CleanMyMac or similar tools modified the app
+(BOOL)checkBinaryIntegrity;  // Returns YES if binary is intact (Universal or properly signed)
+(NSString*)getBinaryArchitectures;  // Returns architecture info (e.g., "arm64 + x86_64" or "arm64 only")
+(NSString*)getBinaryHash;  // Returns SHA-256 hash of executable for tracking changes
+(BOOL)hasBinaryChangedSinceLastRun;  // Detects if binary was modified between app runs

@end

#endif /* PHTVManager_h */
