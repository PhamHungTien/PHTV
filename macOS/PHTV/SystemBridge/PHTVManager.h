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

// Permission check based on test event tap creation (reliable runtime signal)
+(BOOL)canCreateEventTap;
+(void)invalidatePermissionCache;  // Force fresh check on next call
+(BOOL)forcePermissionCheck;       // Bypasses all caching, resets counters

// TCC entry corruption detection and auto-fix
+(BOOL)isTCCEntryCorrupt;          // Check if TCC entry is corrupt (app not appearing in System Settings)
+(BOOL)autoFixTCCEntryWithError:(NSError **)error;  // Automatically fix TCC corruption (shows password prompt)
+(void)restartTCCDaemon;           // Restart per-user tccd to propagate freshly granted permission

// TCC change notification
+(void)startTCCNotificationListener;  // Start listening for TCC database changes
+(void)stopTCCNotificationListener;   // Stop listening

// Table codes
+(NSArray*)getTableCodes;

// Utilities
+(NSString*)getBuildDate;
+(void)showMessage:(NSWindow*)window message:(NSString*)msg subMsg:(NSString*)subMsg;
+(void)requestNewSession;
+(void)invalidateLayoutCache;
+(int)currentLanguage;
+(void)setCurrentLanguage:(int)language;
+(int)otherLanguageMode;
+(void)setDockIconRuntimeVisible:(BOOL)visible;
+(int)toggleSpellCheckSetting;
+(int)toggleAllowConsonantZFWJSetting;
+(int)toggleModernOrthographySetting;
+(int)toggleQuickTelexSetting;
+(int)toggleUpperCaseFirstCharSetting;
+(int)toggleAutoRestoreEnglishWordSetting;
+(NSUInteger)loadRuntimeSettingsFromUserDefaults;
+(void)loadDefaultConfig;

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
