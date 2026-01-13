//
//  AppDelegate.m
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import <Carbon/Carbon.h>
#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import <ServiceManagement/ServiceManagement.h>
#include <stdlib.h>
#include <string.h>
#import "AppDelegate.h"
#import "SparkleManager.h"
#import "../Managers/PHTVManager.h"
#import "../Core/Legacy/MJAccessibilityUtils.h"
#import "PHTV-Swift.h"
#include "../Core/Engine/Engine.h"

static inline int PHTVReadIntWithFallback(NSUserDefaults *defaults, NSString *key, int fallbackValue) {
    if ([defaults objectForKey:key] == nil) {
        return fallbackValue;
    }
    return (int)[defaults integerForKey:key];
}

AppDelegate* appDelegate;

extern "C" {
    // Global function to get AppDelegate instance
    AppDelegate* _Nullable GetAppDelegateInstance(void) {
        return appDelegate;
    }

    void OnTableCodeChange(void);
    void initMacroMap(const unsigned char*, const int&);
    void OnInputMethodChanged(void);
    void RequestNewSession(void);
    void OnActiveAppChanged(void);
    void InvalidateLayoutCache(void);
}

//see document in Engine.h
// VOLATILE: Ensures thread-safe reads in event tap callback
// These are written on main thread, read on event tap thread
volatile int vLanguage = 1;
volatile int vInputType = 0;
int vFreeMark = 0;
volatile int vCodeTable = 0;
volatile int vCheckSpelling = 1;
volatile int vUseModernOrthography = 1;
volatile int vQuickTelex = 0;
// Default: Ctrl + Shift (no key, modifier only)
// Format: bits 0-7 = keycode (0xFE = no key), bit 8 = Control, bit 11 = Shift
#define DEFAULT_SWITCH_STATUS 0x9FE // Ctrl(0x100) + Shift(0x800) + NoKey(0xFE)
volatile int vSwitchKeyStatus = DEFAULT_SWITCH_STATUS;
volatile int vRestoreIfWrongSpelling = 0;
volatile int vFixRecommendBrowser = 1;
volatile int vUseMacro = 1;
volatile int vUseMacroInEnglishMode = 1;
volatile int vAutoCapsMacro = 0;
volatile int vSendKeyStepByStep = 0;
volatile int vUseSmartSwitchKey = 1;
volatile int vUpperCaseFirstChar = 0;
volatile int vTempOffSpelling = 0;
volatile int vAllowConsonantZFWJ = 0;
volatile int vQuickStartConsonant = 0;
volatile int vQuickEndConsonant = 0;
volatile int vRememberCode = 1; //new on version 2.0
volatile int vOtherLanguage = 1; //new on version 2.0
volatile int vTempOffPHTV = 0; //new on version 2.0

// Restore to raw keys (customizable key)
volatile int vRestoreOnEscape = 1; //enable restore to raw keys feature (default: ON)
volatile int vCustomEscapeKey = 0; //custom restore key code (0 = default ESC = 53)

// Pause Vietnamese input when holding a key
volatile int vPauseKeyEnabled = 0; //enable pause key feature (default: OFF)
volatile int vPauseKey = 58; //pause key code (default: Left Option = 58)

// Auto restore English word feature
volatile int vAutoRestoreEnglishWord = 0; //auto restore English words (default: OFF)

int vShowIconOnDock = 0; //new on version 2.0
static BOOL settingsWindowOpen = NO; // Track if settings window is open (to keep dock icon visible)

volatile int vPerformLayoutCompat = 0;

extern int convertToolHotKey;
extern bool convertToolDontAlertWhenCompleted;

static inline BOOL PHTVLiveDebugEnabled(void) {
    static int cachedEnabled = -1;
    if (__builtin_expect(cachedEnabled != -1, 1)) {
        return cachedEnabled == 1;
    }

    const char *env = getenv("PHTV_LIVE_DEBUG");
    if (env != NULL && env[0] != '\0') {
        cachedEnabled = (strcmp(env, "0") != 0) ? 1 : 0;
        return cachedEnabled == 1;
    }

    // Fallback: allow enabling via UserDefaults for easier debugging.
    id stored = [[NSUserDefaults standardUserDefaults] objectForKey:@"PHTV_LIVE_DEBUG"];
    if ([stored respondsToSelector:@selector(intValue)]) {
        cachedEnabled = ([stored intValue] != 0) ? 1 : 0;
        return cachedEnabled == 1;
    }
    
    cachedEnabled = 0;
    return NO;
}

#define PHTV_LIVE_LOG(fmt, ...) do { \
    if (PHTVLiveDebugEnabled()) { \
        NSLog(@"[PHTV Live] " fmt, ##__VA_ARGS__); \
    } \
} while(0)

@interface AppDelegate ()
@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) NSMenu *statusMenu;

// Live settings: status bar font size (set from SwiftUI)
@property (nonatomic, assign) CGFloat statusBarFontSize;

// Performance optimization properties
@property (nonatomic, strong) dispatch_queue_t updateQueue;
@property (nonatomic, assign) NSInteger lastInputMethod;
@property (nonatomic, assign) NSInteger lastCodeTable;
@property (nonatomic, assign) BOOL isUpdatingUI;

// Throttle live applies from NSUserDefaultsDidChangeNotification
@property (nonatomic, assign) CFAbsoluteTime lastDefaultsApplyTime;

// Accessibility monitoring
@property (nonatomic, strong) NSTimer *accessibilityMonitor;
@property (nonatomic, assign) BOOL wasAccessibilityEnabled;
@property (nonatomic, assign) NSUInteger accessibilityStableCount;

// Health watchdog
@property (nonatomic, strong) NSTimer *healthCheckTimer;
@end


@implementation AppDelegate {
    // Excluded app state management
    NSInteger _savedLanguageBeforeExclusion;  // Saved language state before entering excluded app
    NSString* _previousBundleIdentifier;       // Track the previous app's bundle ID
    BOOL _isInExcludedApp;                     // Flag to track if currently in an excluded app

    // Send key step by step app state management
    BOOL _savedSendKeyStepByStepBeforeApp;     // Saved sendKeyStepByStep state before entering app
    BOOL _isInSendKeyStepByStepApp;            // Flag to track if currently in a send key step by step app

    // Re-entry guards to prevent notification ping-pong (performance optimization)
    BOOL _isUpdatingLanguage;
    BOOL _isUpdatingInputType;
    BOOL _isUpdatingCodeTable;

    BOOL _needsRelaunchAfterPermission;

    NSMenuItem* menuInputMethod;
    
    NSMenuItem* mnuTelex;
    NSMenuItem* mnuVNI;
    NSMenuItem* mnuSimpleTelex1;
    NSMenuItem* mnuSimpleTelex2;
    
    NSMenuItem* mnuUnicode;
    NSMenuItem* mnuTCVN;
    NSMenuItem* mnuVNIWindows;
    
    NSMenuItem* mnuUnicodeComposite;
    NSMenuItem* mnuVietnameseLocaleCP1258;
    
    NSMenuItem* mnuQuickConvert;
    
    id _appearanceObserver;
    id _inputSourceObserver;
    NSInteger _savedLanguageBeforeNonLatin;  // Saved language state before switching to non-Latin input source
    BOOL _isInNonLatinInputSource;           // Flag to track if currently using non-Latin input source
}

- (void)observeAppearanceChanges {
    _appearanceObserver = [[NSDistributedNotificationCenter defaultCenter] addObserverForName:@"AppleInterfaceThemeChangedNotification"
                                                                                       object:nil
                                                                                        queue:[NSOperationQueue mainQueue]
                                                                                   usingBlock:^(NSNotification *note) {
        [self fillData];
    }];
}

// Check if input source is Latin-based (can type Vietnamese)
// Returns NO for non-Latin scripts: Japanese, Chinese, Korean, Arabic, Hebrew, Thai, Hindi, Greek, Cyrillic, etc.
- (BOOL)isLatinInputSource:(TISInputSourceRef)inputSource {
    if (inputSource == NULL) return YES;  // Assume Latin if we can't determine
    
    // First, check input source ID for common non-Latin input methods
    CFStringRef sourceID = (CFStringRef)TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID);
    if (sourceID != NULL) {
        NSString *sourceIDStr = (__bridge NSString *)sourceID;
        
        // Known non-Latin input source patterns (fast path)
        static NSArray *nonLatinPatterns = nil;
        static dispatch_once_t patternToken;
        dispatch_once(&patternToken, ^{
            nonLatinPatterns = @[
                // Japanese
                @"com.apple.inputmethod.Kotoeri", @"com.apple.inputmethod.Japanese",
                @"com.google.inputmethod.Japanese", @"jp.co.atok",
                // Chinese
                @"com.apple.inputmethod.SCIM", @"com.apple.inputmethod.TCIM",
                @"com.apple.inputmethod.ChineseHandwriting",
                @"com.sogou.inputmethod", @"com.baidu.inputmethod",
                @"com.tencent.inputmethod", @"com.iflytek.inputmethod",
                // Korean
                @"com.apple.inputmethod.Korean", @"com.apple.inputmethod.KoreanIM",
                // Arabic
                @"com.apple.keylayout.Arabic", @"com.apple.keylayout.ArabicPC",
                // Hebrew
                @"com.apple.keylayout.Hebrew", @"com.apple.keylayout.HebrewQWERTY",
                // Thai
                @"com.apple.keylayout.Thai", @"com.apple.keylayout.ThaiPattachote",
                // Hindi/Devanagari
                @"com.apple.keylayout.Devanagari", @"com.apple.keylayout.Hindi",
                @"com.apple.inputmethod.Hindi",
                // Greek
                @"com.apple.keylayout.Greek", @"com.apple.keylayout.GreekPolytonic",
                // Cyrillic (Russian, Ukrainian, etc.)
                @"com.apple.keylayout.Russian", @"com.apple.keylayout.RussianPC",
                @"com.apple.keylayout.Ukrainian", @"com.apple.keylayout.Bulgarian",
                @"com.apple.keylayout.Serbian", @"com.apple.keylayout.Macedonian",
                // Georgian
                @"com.apple.keylayout.Georgian",
                // Armenian
                @"com.apple.keylayout.Armenian",
                // Tamil, Telugu, Kannada, Malayalam, etc.
                @"com.apple.keylayout.Tamil", @"com.apple.keylayout.Telugu",
                @"com.apple.keylayout.Kannada", @"com.apple.keylayout.Malayalam",
                @"com.apple.keylayout.Gujarati", @"com.apple.keylayout.Punjabi",
                @"com.apple.keylayout.Bengali", @"com.apple.keylayout.Oriya",
                // Myanmar, Khmer, Lao
                @"com.apple.keylayout.Myanmar", @"com.apple.keylayout.Khmer",
                @"com.apple.keylayout.Lao",
                // Tibetan, Nepali, Sinhala
                @"com.apple.keylayout.Tibetan", @"com.apple.keylayout.Nepali",
                @"com.apple.keylayout.Sinhala",
                // Emoji/Symbol input (should not trigger Vietnamese)
                @"com.apple.CharacterPaletteIM", @"com.apple.PressAndHold",
                @"com.apple.inputmethod.EmojiFunctionRowItem"
            ];
        });
        
        for (NSString *pattern in nonLatinPatterns) {
            if ([sourceIDStr containsString:pattern]) {
                return NO;  // Non-Latin input source detected
            }
        }
    }
    
    // Fallback: Check language code
    CFArrayRef languages = (CFArrayRef)TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceLanguages);
    if (languages == NULL || CFArrayGetCount(languages) == 0) return YES;
    
    CFStringRef langRef = (CFStringRef)CFArrayGetValueAtIndex(languages, 0);
    if (langRef == NULL) return YES;
    
    NSString *language = (__bridge NSString *)langRef;
    
    // Latin-based languages that can type Vietnamese
    static NSSet *latinLanguages = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        latinLanguages = [[NSSet alloc] initWithArray:@[
            // Western European
            @"en", @"de", @"fr", @"es", @"it", @"pt", @"nl", @"ca",
            // Nordic
            @"da", @"sv", @"no", @"nb", @"nn", @"fi", @"is", @"fo",
            // Eastern European (Latin script)
            @"pl", @"cs", @"sk", @"hu", @"ro", @"hr", @"sl", @"sr-Latn",
            // Baltic
            @"et", @"lv", @"lt",
            // Other European
            @"sq", @"bs", @"mt",
            // Turkish & Turkic (Latin script)
            @"tr", @"az", @"uz", @"tk",
            // Southeast Asian (Latin script)
            @"id", @"ms", @"vi", @"tl", @"jv", @"su",
            // African (Latin script)
            @"sw", @"ha", @"yo", @"ig", @"zu", @"xh", @"af",
            // Pacific
            @"mi", @"sm", @"to", @"haw",
            // Celtic
            @"ga", @"gd", @"cy", @"br",
            // Other
            @"eo", @"la", @"mul"
        ]];
    });
    
    return [latinLanguages containsObject:language];
}

// Handle input source change notification
// Supports auto-switching for ALL non-Latin keyboards:
// Japanese, Chinese, Korean, Arabic, Hebrew, Thai, Hindi, Greek, Cyrillic, Georgian, Armenian, etc.
- (void)handleInputSourceChanged:(NSNotification *)notification {
    // Invalidate layout compatibility cache
    InvalidateLayoutCache();

    // Only process if vOtherLanguage is enabled (user wants auto-switching)
    if (!vOtherLanguage) return;
    
    TISInputSourceRef currentInputSource = TISCopyCurrentKeyboardInputSource();
    if (currentInputSource == NULL) return;
    
    BOOL isLatin = [self isLatinInputSource:currentInputSource];
    
    // Get localized name for better logging
    CFStringRef localizedName = (CFStringRef)TISGetInputSourceProperty(currentInputSource, kTISPropertyLocalizedName);
    CFStringRef sourceID = (CFStringRef)TISGetInputSourceProperty(currentInputSource, kTISPropertyInputSourceID);
    NSString *displayName = localizedName ? (__bridge NSString *)localizedName : 
                           (sourceID ? (__bridge NSString *)sourceID : @"Unknown");
    
    CFRelease(currentInputSource);
    
    if (!isLatin && !_isInNonLatinInputSource) {
        // Switching TO non-Latin input source → save state and switch to English
        _savedLanguageBeforeNonLatin = vLanguage;
        _isInNonLatinInputSource = YES;
        
        if (vLanguage != 0) {
            NSLog(@"[InputSource] Detected non-Latin keyboard: %@ → Auto-switching PHTV to English", displayName);
            
            vLanguage = 0;  // Switch to English
            __sync_synchronize();
            [[NSUserDefaults standardUserDefaults] setInteger:vLanguage forKey:@"InputMethod"];
            RequestNewSession();
            [self fillData];
            
            // Notify SwiftUI
            [[NSNotificationCenter defaultCenter] postNotificationName:@"LanguageChangedFromObjC" 
                                                                object:@(vLanguage)];
        }
    } else if (isLatin && _isInNonLatinInputSource) {
        // Switching back TO Latin input source → restore previous state
        _isInNonLatinInputSource = NO;
        
        if (_savedLanguageBeforeNonLatin != 0 && vLanguage == 0) {
            NSLog(@"[InputSource] Detected Latin keyboard: %@ → Restoring PHTV to Vietnamese", displayName);
            
            vLanguage = (int)_savedLanguageBeforeNonLatin;
            __sync_synchronize();
            [[NSUserDefaults standardUserDefaults] setInteger:vLanguage forKey:@"InputMethod"];
            RequestNewSession();
            [self fillData];
            
            // Notify SwiftUI
            [[NSNotificationCenter defaultCenter] postNotificationName:@"LanguageChangedFromObjC" 
                                                                object:@(vLanguage)];
        }
    }
}

// Start observing input source changes
- (void)startInputSourceMonitoring {
    _isInNonLatinInputSource = NO;
    _savedLanguageBeforeNonLatin = 0;
    
    // Listen for keyboard input source changes
    _inputSourceObserver = [[NSDistributedNotificationCenter defaultCenter] 
        addObserverForName:(NSString *)kTISNotifySelectedKeyboardInputSourceChanged
                    object:nil
                     queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification *note) {
        [self handleInputSourceChanged:note];
    }];
    
    NSLog(@"[InputSource] Started monitoring input source changes");
}

- (void)dealloc {
    if (_appearanceObserver) {
        [[NSDistributedNotificationCenter defaultCenter] removeObserver:_appearanceObserver];
    }
    if (_inputSourceObserver) {
        [[NSDistributedNotificationCenter defaultCenter] removeObserver:_inputSourceObserver];
    }
    
    [self stopAccessibilityMonitoring];
    [self stopHealthCheckMonitoring];
}

-(void)askPermission {
    NSAlert *alert = [[NSAlert alloc] init];

    // Check if this is after an app update
    NSString *currentVersion = [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
    NSString *lastVersion = [[NSUserDefaults standardUserDefaults] stringForKey:@"LastRunVersion"];

    if (lastVersion && ![lastVersion isEqualToString:currentVersion]) {
        // App was updated
        [alert setMessageText:@"PHTV đã được cập nhật!"];
        [alert setInformativeText:[NSString stringWithFormat:@"Do macOS yêu cầu bảo mật, bạn cần cấp lại quyền trợ năng sau khi cập nhật ứng dụng lên phiên bản %@.\n\nỨng dụng sẽ tự động khởi động lại sau khi bạn cấp quyền.", currentVersion]];
    } else {
        // First run or no permission yet
        [alert setMessageText:@"PHTV cần bạn cấp quyền để có thể hoạt động!"];
        [alert setInformativeText:@"Ứng dụng sẽ tự động khởi động lại sau khi bạn cấp quyền."];
    }

    [alert addButtonWithTitle:@"Không"];
    [alert addButtonWithTitle:@"Cấp quyền"];

    [alert.window makeKeyAndOrderFront:nil];
    [alert.window setLevel:NSStatusWindowLevel];

    NSModalResponse res = [alert runModal];

    if (res == 1001) {
        MJAccessibilityOpenPanel();

        // Invalidate permission cache for fresh check
        [PHTVManager invalidatePermissionCache];
        NSLog(@"[Accessibility] User opening System Settings - cache invalidated");

        // Save current version
        [[NSUserDefaults standardUserDefaults] setObject:currentVersion forKey:@"LastRunVersion"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    } else {
        [NSApp terminate:0];
    }
}

- (void)startAccessibilityMonitoring {
    [self startAccessibilityMonitoringWithInterval:[self currentMonitoringInterval] resetState:YES];
}

// Start monitoring with specific interval
- (void)startAccessibilityMonitoringWithInterval:(NSTimeInterval)interval {
    // Default: reset state (for backward compatibility)
    [self startAccessibilityMonitoringWithInterval:interval resetState:YES];
}

// Start monitoring with specific interval, optionally resetting state
- (void)startAccessibilityMonitoringWithInterval:(NSTimeInterval)interval resetState:(BOOL)resetState {
    // Stop existing timer if any
    [self stopAccessibilityMonitoring];

    // CRITICAL: Uses test event tap creation - ONLY reliable method (Apple recommended)
    // MJAccessibilityIsEnabled() returns TRUE even when permission is revoked!
    // Dynamic interval: 0.3s when waiting for permission (fast detection), 5s when granted (low overhead)
    self.accessibilityMonitor = [NSTimer scheduledTimerWithTimeInterval:interval
                                                                  target:self
                                                                selector:@selector(checkAccessibilityStatus)
                                                                userInfo:nil
                                                                 repeats:YES];

    // ONLY set initial state on first start, NOT when just changing interval
    // This fixes the bug where permission grant detection fails because state is reset mid-check
    if (resetState) {
        self.wasAccessibilityEnabled = [PHTVManager canCreateEventTap];
    }

    NSLog(@"[Accessibility] Started monitoring via test event tap (interval: %.1fs, resetState: %@)", interval, resetState ? @"YES" : @"NO");
}

// Get appropriate monitoring interval based on current permission state
- (NSTimeInterval)currentMonitoringInterval {
    // When waiting for permission: check every 0.3 seconds for INSTANT response
    // When permission granted: check every 5 seconds to reduce overhead
    // Reduced from 1.0s to 0.3s for faster permission detection
    return self.wasAccessibilityEnabled ? 5.0 : 0.3;
}

- (void)stopAccessibilityMonitoring {
    if (self.accessibilityMonitor) {
        [self.accessibilityMonitor invalidate];
        self.accessibilityMonitor = nil;
        #ifdef DEBUG
        NSLog(@"[Accessibility] Stopped monitoring");
        #endif
    }
}

- (void)startHealthCheckMonitoring {
    [self stopHealthCheckMonitoring];
        // IMPROVED: Very aggressive monitoring (2s) to catch tap disable quickly
        // This complements event-based checking (every 50 events)
        // With 2s timer, max delay is 2 seconds regardless of typing speed
        self.healthCheckTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                              target:self
                                                            selector:@selector(runHealthCheck)
                                                            userInfo:nil
                                                             repeats:YES];
}

- (void)stopHealthCheckMonitoring {
    if (self.healthCheckTimer) {
        [self.healthCheckTimer invalidate];
        self.healthCheckTimer = nil;
    }
}

- (void)runHealthCheck {
    // Skip checks if accessibility permission is missing; restart flow will handle it
    // Use test tap - reliable check (MJAccessibilityIsEnabled is unreliable)
    if (![PHTVManager canCreateEventTap]) {
        return;
    }
    [PHTVManager ensureEventTapAlive];
}

- (void)checkAccessibilityStatus {
    // CRITICAL: Use test event tap creation - ONLY reliable way to check permission
    // MJAccessibilityIsEnabled() returns TRUE even after user removes app from list
    BOOL isEnabled = [PHTVManager canCreateEventTap];

    // Only log and notify when status CHANGES (reduce console spam and CPU)
    BOOL statusChanged = (self.wasAccessibilityEnabled != isEnabled);

    if (statusChanged) {
        NSLog(@"[Accessibility] Status CHANGED: was=%@, now=%@",
              self.wasAccessibilityEnabled ? @"YES" : @"NO",
              isEnabled ? @"YES" : @"NO");

        // Notify SwiftUI only on change
        [[NSNotificationCenter defaultCenter] postNotificationName:@"AccessibilityStatusChanged"
                                                            object:@(isEnabled)];

        // IMPORTANT: Restart timer with appropriate interval based on new permission state
        // When permission granted: switch to 5s interval (low overhead)
        // When permission revoked: switch to 0.3s interval (instant re-detection)
        // CRITICAL: resetState:NO to preserve wasAccessibilityEnabled for transition detection below
        NSTimeInterval newInterval = isEnabled ? 5.0 : 0.3;
        NSLog(@"[Accessibility] Adjusting monitoring interval to %.1fs", newInterval);
        [self startAccessibilityMonitoringWithInterval:newInterval resetState:NO];
    }

    // Permission was just granted (transition from disabled to enabled)
    if (!self.wasAccessibilityEnabled && isEnabled) {
        NSLog(@"[Accessibility] ✅ Permission GRANTED (via test tap) - Initializing...");
        self.accessibilityStableCount = 0;
        [self performAccessibilityGrantedRestart];
    }
    // Permission was revoked while app is running (transition from enabled to disabled)
    else if (self.wasAccessibilityEnabled && !isEnabled) {
        NSLog(@"[Accessibility] 🛑 CRITICAL - Permission REVOKED (test tap failed)!");
        self.accessibilityStableCount = 0;
        [self handleAccessibilityRevoked];
    }
    else if (isEnabled) {
        // Permission stable - increment counter
        self.accessibilityStableCount++;
    }

    // Update state
    self.wasAccessibilityEnabled = isEnabled;
}

- (void)performAccessibilityGrantedRestart {
    NSLog(@"[Accessibility] Permission granted - Initializing event tap...");

    // Save current version to track successful permission grant
    NSString *currentVersion = [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
    [[NSUserDefaults standardUserDefaults] setObject:currentVersion forKey:@"LastRunVersion"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    // Stop monitoring (permission granted)
    [self stopAccessibilityMonitoring];

    // Invalidate permission cache to ensure fresh check
    [PHTVManager invalidatePermissionCache];

    // Initialize event tap with retry mechanism
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL initSuccess = NO;

        // Try up to 3 times with delays to handle TCC propagation
        for (int attempt = 1; attempt <= 3; attempt++) {
            NSLog(@"[EventTap] Init attempt %d/3", attempt);

            if ([PHTVManager initEventTap]) {
                NSLog(@"[EventTap] Initialized successfully on attempt %d - App ready!", attempt);
                initSuccess = YES;
                break;
            }

            if (attempt < 3) {
                // Wait progressively longer between attempts
                usleep(100000 * attempt);  // 100ms, 200ms

                // Force permission recheck
                [PHTVManager invalidatePermissionCache];
            }
        }

        if (!initSuccess) {
            NSLog(@"[EventTap] Failed to initialize after 3 attempts");

            // Show alert suggesting relaunch
            NSAlert *alert = [[NSAlert alloc] init];
            [alert setMessageText:@"🔄 Cần khởi động lại ứng dụng"];
            [alert setInformativeText:@"PHTV đã nhận quyền nhưng cần khởi động lại để quyền có hiệu lực.\n\nBạn có muốn khởi động lại ngay không?"];
            [alert addButtonWithTitle:@"Khởi động lại ngay"];
            [alert addButtonWithTitle:@"Để sau"];
            [alert setAlertStyle:NSAlertStyleInformational];

            NSModalResponse response = [alert runModal];
            if (response == NSAlertFirstButtonReturn) {
                [self relaunchAppAfterPermissionGrant];
            } else {
                [self onControlPanelSelected];
            }
        } else {
            // Success - start normal operation

            // Start monitoring for permission revocation
            [self startAccessibilityMonitoring];
            [self startHealthCheckMonitoring];

            // Start TCC notification listener
            [PHTVManager startTCCNotificationListener];

            // Update menu bar to normal state
            [self fillDataWithAnimation:YES];

            // Show UI if requested
            NSInteger showui = [[NSUserDefaults standardUserDefaults] integerForKey:@"ShowUIOnStartup"];
            if (showui == 1) {
                [self onControlPanelSelected];
            }

            // Clear first-launch relaunch flag - we now initialize immediately without restart
            if (self->_needsRelaunchAfterPermission) {
                self->_needsRelaunchAfterPermission = NO;
                NSLog(@"[Accessibility] Initialized successfully - skipping forced relaunch");
            }
        }
        [self setQuickConvertString];
    });
}

- (void)relaunchAppAfterPermissionGrant {
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    if (bundlePath.length == 0) {
        NSLog(@"[Accessibility] Relaunch skipped: bundle path missing");
        return;
    }

    NSURL *bundleURL = [NSURL fileURLWithPath:bundlePath];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (@available(macOS 10.15, *)) {
            NSWorkspaceOpenConfiguration *config = [NSWorkspaceOpenConfiguration configuration];
            [[NSWorkspace sharedWorkspace] openApplicationAtURL:bundleURL
                                                  configuration:config
                                              completionHandler:^(NSRunningApplication * _Nullable app, NSError * _Nullable error) {
                if (error) {
                    NSLog(@"[Accessibility] Relaunch failed: %@", error.localizedDescription ?: @"unknown error");
                    return;
                }
                NSLog(@"[Accessibility] Relaunching app to finalize permission");
                [NSApp terminate:nil];
            }];
        } else {
            // Fallback for older macOS versions
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Wdeprecated-declarations"
            NSError *error = nil;
            NSRunningApplication *app = [[NSWorkspace sharedWorkspace] launchApplicationAtURL:bundleURL
                                                                          options:NSWorkspaceLaunchDefault
                                                                    configuration:@{}
                                                                            error:&error];
            #pragma clang diagnostic pop
            if (!app) {
                NSLog(@"[Accessibility] Relaunch failed: %@", error.localizedDescription ?: @"unknown error");
                return;
            }
            NSLog(@"[Accessibility] Relaunching app to finalize permission");
            [NSApp terminate:nil];
        }
    });
}

- (void)handleAccessibilityRevoked {
    // CRITICAL: Stop event tap IMMEDIATELY on MAIN THREAD to prevent system freeze
    // CFRunLoopRemoveSource MUST be called on the same thread it was added (main thread)
    if ([PHTVManager isInited]) {
        NSLog(@"🛑 CRITICAL: Accessibility revoked! Stopping event tap immediately...");
        [PHTVManager stopEventTap];
    }

    // Show alert
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"⚠️  Quyền trợ năng đã bị tắt!"];
        [alert setInformativeText:@"PHTV cần quyền trợ năng để hoạt động.\n\nỨng dụng sẽ tự động hoạt động lại khi bạn cấp quyền."];
        [alert setAlertStyle:NSAlertStyleWarning];
        [alert addButtonWithTitle:@"Mở cài đặt"];
        [alert addButtonWithTitle:@"Đóng"];

        NSModalResponse response = [alert runModal];
        if (response == NSAlertFirstButtonReturn) {
            MJAccessibilityOpenPanel();

            // Invalidate cache for fresh permission check
            [PHTVManager invalidatePermissionCache];
            NSLog(@"[Accessibility] User opening System Settings to re-grant");
        }

        // Update menu bar to show disabled state
        if (self.statusItem && self.statusItem.button) {
            NSFont *statusFont = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightSemibold];
            NSDictionary *attributes = @{
                NSFontAttributeName: statusFont,
                NSForegroundColorAttributeName: [NSColor systemRedColor]
            };
            NSAttributedString *title = [[NSAttributedString alloc] initWithString:@"⚠️" attributes:attributes];
            self.statusItem.button.attributedTitle = title;
        }
    });
}

// Handle when app needs relaunch for permission to take effect
// This is triggered when AXIsProcessTrusted=YES but CGEventTapCreate fails persistently
// This happens because macOS TCC cache is not invalidated for the running process
- (void)handleAccessibilityNeedsRelaunch {
    static BOOL isShowingRelaunchAlert = NO;

    // Prevent showing multiple alerts
    if (isShowingRelaunchAlert) {
        return;
    }

    isShowingRelaunchAlert = YES;
    NSLog(@"[Accessibility] 🔄 Handling relaunch request - permission granted but not effective yet");

    dispatch_async(dispatch_get_main_queue(), ^{
        // First, try to initialize event tap one more time
        // Sometimes it works after a short delay
        if (![PHTVManager isInited]) {
            NSLog(@"[Accessibility] Attempting event tap initialization before relaunch prompt...");
            if ([PHTVManager initEventTap]) {
                NSLog(@"[Accessibility] ✅ Event tap initialized successfully! No relaunch needed.");
                [PHTVManager resetAxYesTapNoCounter];
                isShowingRelaunchAlert = NO;

                // Update UI and start monitoring
                [self startAccessibilityMonitoring];
                [self startHealthCheckMonitoring];
                [self fillDataWithAnimation:YES];
                return;
            }
        }

        // Event tap still won't initialize - show relaunch prompt
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"🔄 Cần khởi động lại ứng dụng"];
        [alert setInformativeText:@"PHTV đã nhận được quyền trợ năng từ hệ thống, nhưng cần khởi động lại để quyền có hiệu lực.\n\nĐây là yêu cầu bảo mật của macOS. Bạn có muốn khởi động lại ngay không?"];
        [alert setAlertStyle:NSAlertStyleInformational];
        [alert addButtonWithTitle:@"Khởi động lại"];
        [alert addButtonWithTitle:@"Để sau"];

        NSModalResponse response = [alert runModal];
        isShowingRelaunchAlert = NO;

        if (response == NSAlertFirstButtonReturn) {
            NSLog(@"[Accessibility] User requested relaunch to apply permission");
            [PHTVManager resetAxYesTapNoCounter];
            [self relaunchAppAfterPermissionGrant];
        } else {
            NSLog(@"[Accessibility] User deferred relaunch");
            // Reset counter so we don't spam the user
            [PHTVManager resetAxYesTapNoCounter];
        }
    });
}

- (void)checkAccessibilityAndRestart {
    // Legacy method - kept for compatibility
    // Now handled by checkAccessibilityStatus
    // Use test tap - reliable check (MJAccessibilityIsEnabled is unreliable)
    if ([PHTVManager canCreateEventTap]) {
        [self performAccessibilityGrantedRestart];
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSLog(@"🔴🔴🔴 [AppDelegate] applicationDidFinishLaunching STARTED 🔴🔴🔴");

    // Initialize performance optimization
    self.updateQueue = dispatch_queue_create("com.phtv.updateQueue", DISPATCH_QUEUE_SERIAL);
    self.lastInputMethod = -1;
    self.lastCodeTable = -1;
    self.isUpdatingUI = NO;

    // Initialize excluded app state tracking
    _savedLanguageBeforeExclusion = 0;  // Default to English
    _previousBundleIdentifier = nil;
    _isInExcludedApp = NO;

    // Initialize send key step by step app state tracking
    _savedSendKeyStepByStepBeforeApp = NO;  // Default to disabled
    _isInSendKeyStepByStepApp = NO;

    // Initialize re-entry guards
    _isUpdatingLanguage = NO;
    _isUpdatingInputType = NO;
    _isUpdatingCodeTable = NO;

    BOOL isFirstLaunch = ([[NSUserDefaults standardUserDefaults] boolForKey:@"NonFirstTime"] == 0);
    // Use test tap - reliable check (MJAccessibilityIsEnabled is unreliable)
    _needsRelaunchAfterPermission = (isFirstLaunch && ![PHTVManager canCreateEventTap]);

    appDelegate = self;
    
    [self registerSupportedNotification];
    
    //set quick tooltip
    [[NSUserDefaults standardUserDefaults] setObject: [NSNumber numberWithInt: 50]
                                              forKey: @"NSInitialToolTipDelay"];
    
    //check whether this app has been launched before that or not
    NSArray<NSRunningApplication *> *runningApps = [[NSWorkspace sharedWorkspace] runningApplications];
    NSString *currentBundleID = [[NSBundle mainBundle] bundleIdentifier];
    
    for (NSRunningApplication *app in runningApps) {
        if ([app.bundleIdentifier isEqualToString:currentBundleID] && 
            app.processIdentifier != [[NSProcessInfo processInfo] processIdentifier]) {
            // Found existing instance running - terminate it
            NSLog(@"Found existing instance (PID: %d), terminating it...", app.processIdentifier);
            [app terminate];
            
            // Wait a bit for old app to terminate completely
            [NSThread sleepForTimeInterval:0.5];
            break;
        }
    }
    
    // Always use accessory mode - menu bar only, no dock icon
    // But respect user preference for dock icon display
    BOOL showDockIcon = [[NSUserDefaults standardUserDefaults] boolForKey:@"vShowIconOnDock"];
    [NSApp setActivationPolicy: showDockIcon ? NSApplicationActivationPolicyRegular : NSApplicationActivationPolicyAccessory];
    
    // Beep on startup is now handled by SwiftUI if enabled
    // (removed NSBeep() to avoid duplicate sounds)

    // Initialize SwiftUI integration
    [self setupSwiftUIBridge];
    
    // Load existing macros from UserDefaults to binary format (macroData)
    [self loadExistingMacros];

    // Initialize English word dictionary for auto-restore feature
    [self initEnglishWordDictionary];
    NSLog(@"DEBUG-POINT-A");

    // Initialize EmojiHotkeyManager via Swift bridge
    NSLog(@"DEBUG-POINT-B");
    @try {
        [EmojiHotkeyBridge initializeEmojiHotkeyManager];
        NSLog(@"DEBUG-POINT-C");
    } @catch (NSException *exception) {
        NSLog(@"DEBUG-POINT-ERROR: %@", exception);
    }

    // Load hotkey settings from UserDefaults BEFORE initializing event tap
    NSInteger savedHotkey = [[NSUserDefaults standardUserDefaults] integerForKey:@"SwitchKeyStatus"];
    if (savedHotkey != 0) {
        vSwitchKeyStatus = (int)savedHotkey;
        NSLog(@"[AppDelegate] Loaded hotkey from UserDefaults: 0x%X", vSwitchKeyStatus);
    } else {
        NSLog(@"[AppDelegate] No saved hotkey found, using default: 0x%X", vSwitchKeyStatus);
    }
    // Memory barrier to ensure event tap thread sees the hotkey value
    __sync_synchronize();
    
    // Observe Dark Mode changes
    [self observeAppearanceChanges];
    
    // Check binary integrity on startup (detect CleanMyMac modifications)
    BOOL binaryIntact = [PHTVManager checkBinaryIntegrity];
    if (!binaryIntact) {
        NSLog(@"⚠️⚠️⚠️ [AppDelegate] Binary integrity check FAILED - may cause permission issues");
    }

    // Start TCC notification listener immediately (works even without permission)
    [PHTVManager startTCCNotificationListener];
    NSLog(@"[TCC] Notification listener started at app launch");

    // check if user granted Accessabilty permission
    // Use test tap - ONLY reliable way to check (MJAccessibilityIsEnabled is unreliable)
    if (![PHTVManager canCreateEventTap]) {
        [self askPermission];
        [self startAccessibilityMonitoring];
        [self stopHealthCheckMonitoring];
        return;
    }

    //init
    dispatch_async(dispatch_get_main_queue(), ^{
        if (![PHTVManager initEventTap]) {
            // Show settings via SwiftUI notification
            [[NSNotificationCenter defaultCenter] postNotificationName:@"ShowSettings" object:nil];
        } else {
            NSLog(@"[EventTap] Initialized successfully");

            // Start continuous monitoring for accessibility permission changes
            [self startAccessibilityMonitoring];
            [self startHealthCheckMonitoring];

            // Start monitoring input source changes
            [self startInputSourceMonitoring];

            NSInteger showui = [[NSUserDefaults standardUserDefaults] integerForKey:@"ShowUIOnStartup"];
            if (showui == 1) {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"ShowSettings" object:nil];
            }
        }
        [self setQuickConvertString];

        // Initialize Sparkle auto-updater with delay
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSLog(@"[Sparkle] Checking for updates (delayed start)...");
            [[SparkleManager shared] checkForUpdates];
        });
    });
    
    //load default config if is first launch
    if (isFirstLaunch) {
        [self loadDefaultConfig];
        // Mark as non-first-time to prevent re-initialization on next launch
        [[NSUserDefaults standardUserDefaults] setInteger:1 forKey:@"NonFirstTime"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        NSLog(@"[AppDelegate] First launch: loaded default config and marked NonFirstTime");
    }

    // CRITICAL FIX: Sync Launch at Login with actual SMAppService status
    // This ensures UserDefaults matches reality after app restart
    if (@available(macOS 13.0, *)) {
        SMAppService *appService = [SMAppService mainAppService];
        SMAppServiceStatus actualStatus = appService.status;
        BOOL actuallyEnabled = (actualStatus == SMAppServiceStatusEnabled);

        NSInteger savedValue = [[NSUserDefaults standardUserDefaults] integerForKey:@"RunOnStartup"];
        BOOL savedEnabled = (savedValue == 1);

        NSLog(@"[LoginItem] Startup sync - Actual: %d, Saved: %d, Status: %ld",
              actuallyEnabled, savedEnabled, (long)actualStatus);

        // If first launch, enable immediately (default behavior)
        if (isFirstLaunch) {
            NSLog(@"[LoginItem] First launch detected - enabling Launch at Login");
            [self setRunOnStartup:YES];
        }
        // If mismatch between actual status and saved preference
        else if (actuallyEnabled != savedEnabled) {
            // User enabled but macOS disabled it (e.g., after reboot, signature issues)
            if (savedEnabled && !actuallyEnabled) {
                NSLog(@"[LoginItem] ⚠️ User enabled but SMAppService is disabled - syncing UI to OFF");
                NSLog(@"[LoginItem] Possible causes: code signature, system policy, or macOS disabled it");

                // Update UserDefaults to match reality
                [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"RunOnStartup"];
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"PHTV_RunOnStartup"];
                [[NSUserDefaults standardUserDefaults] synchronize];

                // Notify SwiftUI to update toggle to OFF
                [[NSNotificationCenter defaultCenter] postNotificationName:@"RunOnStartupChanged"
                                                                    object:nil
                                                                  userInfo:@{@"enabled": @(NO)}];
            }
            // User disabled but macOS still has it enabled (rare case)
            else if (!savedEnabled && actuallyEnabled) {
                NSLog(@"[LoginItem] User disabled but SMAppService still enabled - disabling");
                [self setRunOnStartup:NO];
            }
        }
        // Both agree - status is consistent
        else {
            NSLog(@"[LoginItem] ✅ Status consistent: %@", actuallyEnabled ? @"ENABLED" : @"DISABLED");
        }
    } else {
        // Legacy macOS < 13: just load saved preference
        NSInteger val = [[NSUserDefaults standardUserDefaults] integerForKey:@"RunOnStartup"];
        [self setRunOnStartup:val];
    }
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    [self onControlPanelSelected];
    return YES;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Clear AX test flag on normal termination to prevent false safe mode activation
    [PHTVManager clearAXTestFlag];

    // Post notification for SwiftUI cleanup instead of direct call
    // AppState is @MainActor and cannot be called directly from Objective-C
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ApplicationWillTerminate" object:nil];
}

#pragma mark - SwiftUI Bridge

- (void)setupSwiftUIBridge {
    PHTV_LIVE_LOG(@"setupSwiftUIBridge registering observers");
    // AppState loads its own settings from UserDefaults in init()
    // No need to sync here - both backend and SwiftUI read from same source
    // [self syncStateToSwiftUI];  // Removed to prevent race conditions

    // Setup notification observers for SwiftUI integration
    // Note: ShowSettings is now handled by SettingsWindowManager in Swift
    // We only need to handle ShowMacroTab and ShowAboutTab here
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onShowMacroTab:)
                                                 name:@"ShowMacroTab"
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onShowAboutTab:)
                                                 name:@"ShowAboutTab"
                                               object:nil];
    
    // Handle input method and code table changes from SwiftUI
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleInputMethodChanged:)
                                                 name:@"InputMethodChanged"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleCodeTableChanged:)
                                                 name:@"CodeTableChanged"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleSettingsChanged:)
                                                 name:@"PHTVSettingsChanged"
                                               object:nil];
    
    // Listen for dock icon visibility changes from SwiftUI
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleShowDockIconNotification:)
                                                 name:@"PHTVShowDockIcon"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleHotkeyChanged:)
                                                 name:@"HotkeyChanged"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleLanguageChangedFromSwiftUI:)
                                                 name:@"LanguageChangedFromSwiftUI"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleMacrosUpdated:)
                                                 name:@"MacrosUpdated"
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleCustomDictionaryUpdated:)
                                                 name:@"CustomDictionaryUpdated"
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleSettingsReset:)
                                                 name:@"SettingsReset"
                                               object:nil];

    // CRITICAL: Handle immediate accessibility permission loss from event tap callback
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleAccessibilityRevoked)
                                                 name:@"AccessibilityPermissionLost"
                                               object:nil];

    // Handle when app needs relaunch for permission to take effect
    // This is triggered when AXIsProcessTrusted=YES but test tap fails persistently
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleAccessibilityNeedsRelaunch)
                                                 name:@"AccessibilityNeedsRelaunch"
                                               object:nil];

    // Excluded apps changes: apply immediately (don't wait for app switch)
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleExcludedAppsChanged:)
                                                 name:@"ExcludedAppsChanged"
                                               object:nil];

    // Send key step by step apps changes: apply immediately
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleSendKeyStepByStepAppsChanged:)
                                                 name:@"SendKeyStepByStepAppsChanged"
                                               object:nil];

    // Menu bar font size changes
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleMenuBarIconSizeChanged:)
                                                 name:@"MenuBarIconSizeChanged"
                                               object:nil];
}

- (void)handleExcludedAppsChanged:(NSNotification *)notification {
    // Re-evaluate current app against the updated excluded list.
    NSRunningApplication *frontmost = [[NSWorkspace sharedWorkspace] frontmostApplication];
    if (frontmost.bundleIdentifier.length > 0) {
        [self checkExcludedApp:frontmost.bundleIdentifier];
    }
}

- (void)handleSendKeyStepByStepAppsChanged:(NSNotification *)notification {
    // Re-evaluate current app against the updated send key step by step list.
    NSRunningApplication *frontmost = [[NSWorkspace sharedWorkspace] frontmostApplication];
    if (frontmost.bundleIdentifier.length > 0) {
        [self checkSendKeyStepByStepApp:frontmost.bundleIdentifier];
    }
}

- (void)handleMenuBarIconSizeChanged:(NSNotification *)notification {
    NSNumber *value = notification.object;
    CGFloat size = 12.0;
    if (value) {
        size = (CGFloat)value.doubleValue;
    } else {
        double stored = [[NSUserDefaults standardUserDefaults] doubleForKey:@"vMenuBarIconSize"];
        if (stored > 0) {
            size = (CGFloat)stored;
        }
    }

    // Clamp to keep the menu bar usable
    if (size < 10.0) size = 10.0;
    if (size > 28.0) size = 28.0;

    self.statusBarFontSize = size;
    [self fillData];
}

- (void)handleLanguageChangedFromSwiftUI:(NSNotification *)notification {
    // Re-entry guard: prevent notification ping-pong
    if (_isUpdatingLanguage) {
        #ifdef DEBUG
        NSLog(@"[SwiftUI] Ignoring language change (already updating)");
        #endif
        return;
    }

    NSNumber *language = notification.object;
    if (language) {
        int newLanguage = language.intValue;
        if (vLanguage != newLanguage) {
            #ifdef DEBUG
            NSLog(@"[SwiftUI] Language changing from %d to %d", vLanguage, newLanguage);
            #endif

            _isUpdatingLanguage = YES;

            #ifdef DEBUG
            NSLog(@"========================================");
            NSLog(@"[SwiftUI] CHANGING LANGUAGE: %d -> %d", vLanguage, newLanguage);
            NSLog(@"========================================");
            #endif

            // CRITICAL: Synchronous state change to prevent race conditions
            // 1. Update global variable
            vLanguage = newLanguage;

            // 2. Memory barrier to ensure event tap thread sees new value
            __sync_synchronize();

            // 3. Save to UserDefaults (async - no synchronize, auto-saves periodically)
            [[NSUserDefaults standardUserDefaults] setInteger:vLanguage forKey:@"InputMethod"];

            // 4. Reset engine state IMMEDIATELY (synchronous!)
            RequestNewSession();

            // 4. Update UI
            [self fillData];

            // 5. Notify engine (async is OK since state is reset) - only if SmartSwitchKey enabled
            if (vUseSmartSwitchKey) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    OnInputMethodChanged();
                });
            }

            NSLog(@"[SwiftUI] Language changed to: %d (engine reset complete)", vLanguage);

            _isUpdatingLanguage = NO;
        }
    }
}

- (void)handleInputMethodChanged:(NSNotification *)notification {
    // Re-entry guard: prevent notification ping-pong
    if (_isUpdatingInputType) {
        #ifdef DEBUG
        NSLog(@"[SwiftUI] Ignoring input method change (already updating)");
        #endif
        return;
    }

    NSNumber *inputMethod = notification.object;
    if (inputMethod) {
        int newIndex = inputMethod.intValue;
        if (vInputType != newIndex) {
            #ifdef DEBUG
            NSLog(@"[SwiftUI] Input method changing from %d to %d", vInputType, newIndex);
            #endif

            _isUpdatingInputType = YES;

            #ifdef DEBUG
            NSLog(@"========================================");
            NSLog(@"[SwiftUI] CHANGING INPUT TYPE: %d -> %d", vInputType, newIndex);
            NSLog(@"========================================");
            #endif

            // CRITICAL: All changes must be synchronous to prevent race conditions
            // 1. Update global variable
            vInputType = newIndex;

            // 2. Memory barrier to ensure event tap thread sees new value
            __sync_synchronize();

            // 3. Save to UserDefaults (async - no synchronize, auto-saves periodically)
            [[NSUserDefaults standardUserDefaults] setInteger:newIndex forKey:@"InputType"];

            // 4. Reset engine state IMMEDIATELY (synchronous, not async!)
            RequestNewSession();

            // 4. Update UI
            [self fillData];

            // 5. Notify engine (can be async since state is already reset) - only if SmartSwitchKey enabled
            if (vUseSmartSwitchKey) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    OnInputMethodChanged();
                });
            }

            NSLog(@"[SwiftUI] Input method changed to: %d (engine reset complete)", newIndex);

            _isUpdatingInputType = NO;
        }
    }
}

- (void)handleCodeTableChanged:(NSNotification *)notification {
    NSNumber *codeTable = notification.object;
    if (codeTable) {
        int newIndex = codeTable.intValue;
        [self onCodeTableChanged:newIndex];
        #ifdef DEBUG
        NSLog(@"[SwiftUI] Code table changed to: %d", newIndex);
        #endif
    }
}

- (void)handleHotkeyChanged:(NSNotification *)notification {
    PHTV_LIVE_LOG(@"received HotkeyChanged");
    NSNumber *hotkey = notification.object;
    if (hotkey) {
        vSwitchKeyStatus = hotkey.intValue;

        // Memory barrier to ensure event tap thread sees new value immediately
        __sync_synchronize();

        [[NSUserDefaults standardUserDefaults] setInteger:vSwitchKeyStatus forKey:@"SwitchKeyStatus"];
        [[NSUserDefaults standardUserDefaults] synchronize];

        // Update UI to reflect hotkey change
        [self fillData];

        #ifdef DEBUG
        BOOL hasBeep = PHTV_HAS_BEEP(vSwitchKeyStatus);
        NSLog(@"[SwiftUI] Hotkey changed to: 0x%X (beep=%@)", vSwitchKeyStatus, hasBeep ? @"YES" : @"NO");
        #endif
    }
}

- (void)handleTCCDatabaseChanged:(NSNotification *)notification {
    NSLog(@"[TCC] TCC database change notification received in AppDelegate");
    NSLog(@"[TCC] userInfo: %@", notification.userInfo);

    // Invalidate permission cache to handle the change
    [PHTVManager invalidatePermissionCache];

    // Force check accessibility status immediately
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                  dispatch_get_main_queue(), ^{
        [self checkAccessibilityStatus];
    });
}

// Helper to robustly check if settings window is visible
- (BOOL)isSettingsWindowVisible {
    for (NSWindow *window in [NSApp windows]) {
        NSString *identifier = window.identifier;
        // SwiftUI windows have identifier starting with "settings" (set in PHTVApp.swift)
        if (identifier && [identifier hasPrefix:@"settings"] && window.isVisible) {
            return YES;
        }
    }
    return NO;
}

// Handle dock icon visibility notification from SwiftUI
- (void)handleShowDockIconNotification:(NSNotification *)notification {
    BOOL visible = [[notification.userInfo objectForKey:@"visible"] boolValue];
    NSLog(@"[AppDelegate] handleShowDockIconNotification: visible=%d", visible);
    
    // Update settingsWindowOpen for legacy checks, but rely on isSettingsWindowVisible for logic
    settingsWindowOpen = visible;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (visible || [self isSettingsWindowVisible]) {
            [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
            [NSApp activateIgnoringOtherApps:YES];
            
            // Bring settings window to front
            for (NSWindow *window in [NSApp windows]) {
                NSString *identifier = window.identifier;
                if (identifier && [identifier hasPrefix:@"settings"]) {
                    [window makeKeyAndOrderFront:nil];
                    // FORCE window to be main/key to prevent sinking
                    [window makeKeyWindow]; 
                    [window orderFrontRegardless];
                    NSLog(@"[AppDelegate] Brought settings window to front: %@", identifier);
                    break;
                }
            }
            
            NSLog(@"[AppDelegate] Dock icon shown (settings window open)");
        } else {
            // Restore to user preference
            BOOL userPrefersDock = [[NSUserDefaults standardUserDefaults] boolForKey:@"vShowIconOnDock"];
            NSApplicationActivationPolicy policy = userPrefersDock ? NSApplicationActivationPolicyRegular : NSApplicationActivationPolicyAccessory;
            [NSApp setActivationPolicy:policy];
            NSLog(@"[AppDelegate] Dock icon restored to user preference: %d", userPrefersDock);
        }
    });
}

- (void)handleSettingsChanged:(NSNotification *)notification {
    PHTV_LIVE_LOG(@"received PHTVSettingsChanged");
    // Reload settings from UserDefaults when SwiftUI changes them
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    // Capture previous values for group-1 settings to decide whether to reset session.
    int oldCheckSpelling = vCheckSpelling;
    int oldModernOrthography = vUseModernOrthography;
    int oldQuickTelex = vQuickTelex;
    int oldRestoreIfWrongSpelling = vRestoreIfWrongSpelling;

    // Capture previous values for other groups (macros/typing/system) for live apply.
    int oldUseMacro = vUseMacro;
    int oldUseMacroInEnglishMode = vUseMacroInEnglishMode;
    int oldAutoCapsMacro = vAutoCapsMacro;
    int oldSendKeyStepByStep = vSendKeyStepByStep;
    int oldUseSmartSwitchKey = vUseSmartSwitchKey;
    int oldUpperCaseFirstChar = vUpperCaseFirstChar;
    int oldAllowConsonantZFWJ = vAllowConsonantZFWJ;
    int oldQuickStartConsonant = vQuickStartConsonant;
    int oldQuickEndConsonant = vQuickEndConsonant;
    int oldRememberCode = vRememberCode;
    int oldPerformLayoutCompat = vPerformLayoutCompat;
    
    vCheckSpelling = PHTVReadIntWithFallback(defaults, @"Spelling", vCheckSpelling);
    vUseModernOrthography = PHTVReadIntWithFallback(defaults, @"ModernOrthography", vUseModernOrthography);
    vQuickTelex = PHTVReadIntWithFallback(defaults, @"QuickTelex", vQuickTelex);
    vRestoreIfWrongSpelling = PHTVReadIntWithFallback(defaults, @"RestoreIfInvalidWord", vRestoreIfWrongSpelling);
    vUseMacro = PHTVReadIntWithFallback(defaults, @"UseMacro", vUseMacro);
    vUseMacroInEnglishMode = PHTVReadIntWithFallback(defaults, @"UseMacroInEnglishMode", vUseMacroInEnglishMode);
    vAutoCapsMacro = PHTVReadIntWithFallback(defaults, @"vAutoCapsMacro", vAutoCapsMacro);
    vSendKeyStepByStep = PHTVReadIntWithFallback(defaults, @"SendKeyStepByStep", vSendKeyStepByStep);
    vUseSmartSwitchKey = PHTVReadIntWithFallback(defaults, @"UseSmartSwitchKey", vUseSmartSwitchKey);
    vUpperCaseFirstChar = PHTVReadIntWithFallback(defaults, @"UpperCaseFirstChar", vUpperCaseFirstChar);
    vAllowConsonantZFWJ = PHTVReadIntWithFallback(defaults, @"vAllowConsonantZFWJ", vAllowConsonantZFWJ);
    vQuickStartConsonant = PHTVReadIntWithFallback(defaults, @"vQuickStartConsonant", vQuickStartConsonant);
    vQuickEndConsonant = PHTVReadIntWithFallback(defaults, @"vQuickEndConsonant", vQuickEndConsonant);
    vRememberCode = PHTVReadIntWithFallback(defaults, @"vRememberCode", vRememberCode);
    vPerformLayoutCompat = PHTVReadIntWithFallback(defaults, @"vPerformLayoutCompat", vPerformLayoutCompat);
    vShowIconOnDock = PHTVReadIntWithFallback(defaults, @"vShowIconOnDock", vShowIconOnDock);

    // Restore to raw keys (customizable key)
    vRestoreOnEscape = PHTVReadIntWithFallback(defaults, @"vRestoreOnEscape", vRestoreOnEscape);
    vCustomEscapeKey = PHTVReadIntWithFallback(defaults, @"vCustomEscapeKey", vCustomEscapeKey);

    // Pause Vietnamese input when holding a key
    vPauseKeyEnabled = PHTVReadIntWithFallback(defaults, @"vPauseKeyEnabled", vPauseKeyEnabled);
    vPauseKey = PHTVReadIntWithFallback(defaults, @"vPauseKey", vPauseKey);

    // Auto restore English word feature
    vAutoRestoreEnglishWord = PHTVReadIntWithFallback(defaults, @"vAutoRestoreEnglishWord", vAutoRestoreEnglishWord);

    // Memory barrier to ensure event tap thread sees new values immediately
    __sync_synchronize();

    // Sync spell checking state specifically (fixes issue where vCheckSpelling is reset to stale _useSpellCheckingBefore)
    vSetCheckSpelling();

    // Always reset the session on any settings change.
    // This matches the "restart app" effect without requiring restart.
    RequestNewSession();

    if (PHTVLiveDebugEnabled()) {
        BOOL changed1 = (oldCheckSpelling != vCheckSpelling ||
                         oldModernOrthography != vUseModernOrthography ||
                         oldQuickTelex != vQuickTelex ||
                         oldRestoreIfWrongSpelling != vRestoreIfWrongSpelling);
        BOOL changed2 = (oldUseMacro != vUseMacro ||
                         oldUseMacroInEnglishMode != vUseMacroInEnglishMode ||
                         oldAutoCapsMacro != vAutoCapsMacro ||
                         oldSendKeyStepByStep != vSendKeyStepByStep ||
                         oldUpperCaseFirstChar != vUpperCaseFirstChar ||
                         oldAllowConsonantZFWJ != vAllowConsonantZFWJ ||
                         oldQuickStartConsonant != vQuickStartConsonant ||
                         oldQuickEndConsonant != vQuickEndConsonant ||
                         oldRememberCode != vRememberCode ||
                         oldPerformLayoutCompat != vPerformLayoutCompat);
        PHTV_LIVE_LOG(@"settings loaded; changedGroup1=%@ changedGroup2=%@ useMacro=%d upperCaseFirst=%d", changed1 ? @"YES" : @"NO", changed2 ? @"YES" : @"NO", vUseMacro, vUpperCaseFirstChar);
    }

    // If SmartSwitchKey was just enabled, sync once to current app immediately.
    if (oldUseSmartSwitchKey == 0 && vUseSmartSwitchKey != 0 && [PHTVManager isInited]) {
        OnActiveAppChanged();
    }
    
    #ifdef DEBUG
    NSLog(@"[SwiftUI] Settings reloaded from UserDefaults");
    NSLog(@"  - useMacro=%d, autoCapsMacro=%d, useMacroInEnglishMode=%d", vUseMacro, vAutoCapsMacro, vUseMacroInEnglishMode);
    NSLog(@"  - performLayoutCompat=%d", vPerformLayoutCompat);
    #endif
    
    // Apply dock icon visibility immediately with async dispatch
    // BUT only if settings window is not currently open (it needs dock icon visible)
    dispatch_async(dispatch_get_main_queue(), ^{
        // CRITICAL FIX: Use isSettingsWindowVisible check instead of fragile boolean
        if ([self isSettingsWindowVisible] || settingsWindowOpen) {
            // Settings window is open - keep dock icon visible regardless of preference
            NSLog(@"[AppDelegate] Settings window open (verified), keeping dock icon visible");
            return;
        }
        NSApplicationActivationPolicy policy = vShowIconOnDock ? NSApplicationActivationPolicyRegular : NSApplicationActivationPolicyAccessory;
        [NSApp setActivationPolicy:policy];
        if (vShowIconOnDock) {
            [NSApp activate];
        }
    });

    // IMPORTANT:
    // Do NOT push values back into SwiftUI AppState here.
    // This notification is emitted by SwiftUI itself; writing back can cause
    // a notification ping-pong loop (SwiftUI -> backend -> SwiftUI -> ...)
    // which can lead to crashes/abort.
}

// Apply changes when UserDefaults are updated from non-SwiftUI sources
// (legacy menus, external writes, etc.)
- (void)handleUserDefaultsDidChange:(NSNotification *)notification {
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (self.lastDefaultsApplyTime > 0 && (now - self.lastDefaultsApplyTime) < 0.10) {
        return;
    }
    self.lastDefaultsApplyTime = now;

    PHTV_LIVE_LOG(@"received NSUserDefaultsDidChangeNotification");

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    // Hotkey: apply from defaults without writing back (avoid loops)
    int newSwitchKeyStatus = PHTVReadIntWithFallback(defaults, @"SwitchKeyStatus", vSwitchKeyStatus);
    if (newSwitchKeyStatus != vSwitchKeyStatus) {
        vSwitchKeyStatus = newSwitchKeyStatus;
        __sync_synchronize();
        [self fillData];
        PHTV_LIVE_LOG(@"applied SwitchKeyStatus from defaults: 0x%X", vSwitchKeyStatus);
    }

    // Apply all typing-related toggles
    [self handleSettingsChanged:nil];
}


- (void)syncMacrosFromUserDefaultsResetSession:(BOOL)resetSession {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSData *macroListData = [defaults dataForKey:@"macroList"];

    if (macroListData && macroListData.length > 0) {
        NSError *error = nil;
        NSArray *macros = [NSJSONSerialization JSONObjectWithData:macroListData
                                                         options:NSJSONReadingMutableContainers
                                                           error:&error];
        if (error || ![macros isKindOfClass:[NSArray class]]) {
            NSLog(@"[AppDelegate] ERROR: Failed to parse macroList: %@", error);
            return;
        }

        NSMutableData *binaryData = [NSMutableData data];
        uint16_t macroCount = (uint16_t)[macros count];
        [binaryData appendBytes:&macroCount length:2];

        // Snippet type mapping from Swift enum to C++ enum
        NSDictionary *snippetTypeMap = @{
            @"static": @0,
            @"date": @1,
            @"time": @2,
            @"datetime": @3,
            @"clipboard": @4,
            @"random": @5,
            @"counter": @6
        };

        for (NSDictionary *macro in macros) {
            if (![macro isKindOfClass:[NSDictionary class]]) {
                continue;
            }
            NSString *shortcut = macro[@"shortcut"] ?: @"";
            NSString *expansion = macro[@"expansion"] ?: @"";
            NSString *snippetTypeStr = macro[@"snippetType"] ?: @"static";

            uint8_t shortcutLen = (uint8_t)[shortcut lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
            [binaryData appendBytes:&shortcutLen length:1];
            [binaryData appendData:[shortcut dataUsingEncoding:NSUTF8StringEncoding]];

            uint16_t expansionLen = (uint16_t)[expansion lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
            [binaryData appendBytes:&expansionLen length:2];
            [binaryData appendData:[expansion dataUsingEncoding:NSUTF8StringEncoding]];

            // Append snippet type (1 byte)
            uint8_t snippetType = [snippetTypeMap[snippetTypeStr] unsignedCharValue];
            [binaryData appendBytes:&snippetType length:1];
        }

        [defaults setObject:binaryData forKey:@"macroData"];
        [defaults synchronize];

        initMacroMap((const unsigned char *)[binaryData bytes], (int)[binaryData length]);
        PHTV_LIVE_LOG(@"macros synced: count=%u", macroCount);
    } else {
        [defaults removeObjectForKey:@"macroData"];
        [defaults synchronize];

        uint16_t macroCount = 0;
        NSMutableData *emptyData = [NSMutableData data];
        [emptyData appendBytes:&macroCount length:2];
        initMacroMap((const unsigned char *)[emptyData bytes], (int)[emptyData length]);
        PHTV_LIVE_LOG(@"macros cleared");
    }

    if (resetSession) {
        RequestNewSession();
    }
}

- (void)handleMacrosUpdated:(NSNotification *)notification {
    PHTV_LIVE_LOG(@"received MacrosUpdated");
    [self syncMacrosFromUserDefaultsResetSession:YES];
}

- (void)loadExistingMacros {
    // On app startup, sync macroData from macroList (source of truth).
    [self syncMacrosFromUserDefaultsResetSession:NO];
}

- (void)initEnglishWordDictionary {
    // Load English dictionary (binary only - PHT3 format)
    NSString *enBundlePath = [[NSBundle mainBundle] pathForResource:@"en_dict" ofType:@"bin"];
    if (enBundlePath) {
        std::string path = [enBundlePath UTF8String];
        if (initEnglishDictionary(path)) {
            NSLog(@"[EnglishWordDetector] English dictionary loaded: %zu words", getEnglishDictionarySize());
        } else {
            NSLog(@"[EnglishWordDetector] Failed to load English dictionary");
        }
    } else {
        NSLog(@"[EnglishWordDetector] en_dict.bin not found in bundle");
    }

    // Load Vietnamese dictionary (binary only - PHT3 format)
    NSString *viBundlePath = [[NSBundle mainBundle] pathForResource:@"vi_dict" ofType:@"bin"];
    if (viBundlePath) {
        std::string path = [viBundlePath UTF8String];
        if (initVietnameseDictionary(path)) {
            NSLog(@"[EnglishWordDetector] Vietnamese dictionary loaded: %zu words", getVietnameseDictionarySize());
        } else {
            NSLog(@"[EnglishWordDetector] Failed to load Vietnamese dictionary");
        }
    } else {
        NSLog(@"[EnglishWordDetector] vi_dict.bin not found in bundle");
    }

    // Load custom dictionary from UserDefaults
    [self syncCustomDictionaryFromUserDefaults];
}

- (void)syncCustomDictionaryFromUserDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSData *customDictData = [defaults dataForKey:@"customDictionary"];

    if (customDictData && customDictData.length > 0) {
        NSError *error = nil;
        NSArray *words = [NSJSONSerialization JSONObjectWithData:customDictData options:0 error:&error];

        if (error || !words) {
            NSLog(@"[CustomDictionary] Failed to parse JSON: %@", error.localizedDescription);
            return;
        }

        // Re-serialize to JSON string for C++ parser
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:words options:0 error:&error];
        if (jsonData) {
            initCustomDictionary((const char*)jsonData.bytes, (int)jsonData.length);
            NSLog(@"[CustomDictionary] Loaded %zu English, %zu Vietnamese custom words",
                  getCustomEnglishWordCount(), getCustomVietnameseWordCount());
        }
    } else {
        // Clear custom dictionary if no data
        clearCustomDictionary();
        NSLog(@"[CustomDictionary] No custom words found");
    }
}

- (void)handleCustomDictionaryUpdated:(NSNotification *)notification {
    PHTV_LIVE_LOG(@"received CustomDictionaryUpdated");
    [self syncCustomDictionaryFromUserDefaults];
}

#pragma mark - Sparkle Update Handlers

- (void)handleSparkleManualCheck:(NSNotification *)notification {
    NSLog(@"[Sparkle] Manual check requested from UI");
    [[SparkleManager shared] checkForUpdatesWithFeedback];
}

- (void)handleSparkleUpdateFound:(NSNotification *)notification {
    NSDictionary *updateInfo = notification.object;

    dispatch_async(dispatch_get_main_queue(), ^{
        // Forward to SwiftUI in legacy format for compatibility
        [[NSNotificationCenter defaultCenter] postNotificationName:@"CheckForUpdatesResponse"
                                                            object:@{
            @"message": [NSString stringWithFormat:@"Phiên bản mới %@ có sẵn", updateInfo[@"version"]],
            @"isError": @NO,
            @"updateAvailable": @YES,
            @"latestVersion": updateInfo[@"version"],
            @"downloadUrl": updateInfo[@"downloadURL"],
            @"releaseNotes": updateInfo[@"releaseNotes"]
        }];
    });
}

// Show "up to date" alert when user manually checks for updates (only for manual checks)
- (void)handleSparkleNoUpdate:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *currentVersion = [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];

        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Đã cập nhật"];
        [alert setInformativeText:[NSString stringWithFormat:@"Bạn đang sử dụng phiên bản mới nhất của PHTV (%@).", currentVersion]];
        [alert addButtonWithTitle:@"OK"];
        [alert setAlertStyle:NSAlertStyleInformational];
        [alert runModal];
    });
}

- (void)handleUpdateFrequencyChanged:(NSNotification *)notification {
    if (NSNumber *interval = notification.object) {
        NSLog(@"[Sparkle] Update frequency changed to: %.0f seconds", [interval doubleValue]);
        [[SparkleManager shared] setUpdateCheckInterval:[interval doubleValue]];
    }
}

- (void)handleBetaChannelChanged:(NSNotification *)notification {
    if (NSNumber *enabled = notification.object) {
        NSLog(@"[Sparkle] Beta channel changed to: %@", [enabled boolValue] ? @"ENABLED" : @"DISABLED");
        [[SparkleManager shared] setBetaChannelEnabled:[enabled boolValue]];
    }
}

- (void)handleSparkleInstallUpdate:(NSNotification *)notification {
    NSLog(@"[Sparkle] Install update requested from custom banner");
    // Trigger Sparkle's native update UI which will handle download and installation
    [[SparkleManager shared] checkForUpdatesWithFeedback];
}

// handleSparkleInstallUpdateSilently removed - auto-install is now handled directly by PHSilentUserDriver

- (void)handleSettingsReset:(NSNotification *)notification {
    // Settings have been reset, post confirmation to UI
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SettingsResetComplete" object:nil];
        
        #ifdef DEBUG
        NSLog(@"[Settings Reset] Reset complete, UI will refresh");
        #endif
    });
}

- (void)onShowMacroTab:(NSNotification *)notification {
    // First open settings window, then switch to macro tab
    [self onControlPanelSelected];
}

- (void)onShowAboutTab:(NSNotification *)notification {
    // First open settings window
    [self onControlPanelSelected];
}

#pragma mark - Menu Creation Helpers

/**
 * Modern helper method to create menu items efficiently
 */
- (NSMenuItem *)createMenuItem:(NSString *)title action:(SEL)action {
    return [self createMenuItem:title action:action tag:0];
}

- (NSMenuItem *)createMenuItem:(NSString *)title action:(SEL)action tag:(NSInteger)tag {
    return [self createMenuItem:title action:action keyEquiv:@"" modifiers:0 tag:tag];
}

- (NSMenuItem *)createMenuItem:(NSString *)title 
                        action:(SEL)action 
                      keyEquiv:(NSString *)key 
                     modifiers:(NSEventModifierFlags)modifiers {
    return [self createMenuItem:title action:action keyEquiv:key modifiers:modifiers tag:0];
}

- (NSMenuItem *)createMenuItem:(NSString *)title 
                        action:(SEL)action 
                      keyEquiv:(NSString *)key 
                     modifiers:(NSEventModifierFlags)modifiers 
                           tag:(NSInteger)tag {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title 
                                                  action:action 
                                           keyEquivalent:key];
    item.target = self;
    if (modifiers != 0) {
        item.keyEquivalentModifierMask = modifiers;
    }
    if (tag != 0) {
        item.tag = tag;
    }
    return item;
}

#pragma mark - Status Bar Menu

-(void) createStatusBarMenu {
    // Must be on main thread
    if (![NSThread isMainThread]) {
        NSLog(@"[StatusBar] createStatusBarMenu called off main thread - dispatching to main");
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self createStatusBarMenu];
        });
        return;
    }
    
    NSLog(@"[StatusBar] Creating status bar menu...");
    
    // Get system status bar
    NSStatusBar *statusBar = [NSStatusBar systemStatusBar];
    
    // Create status item with VARIABLE length (important for text)
    self.statusItem = [statusBar statusItemWithLength:NSVariableStatusItemLength];
    
    if (!self.statusItem) {
        NSLog(@"[StatusBar] FATAL - Failed to create status item");
        return;
    }
    
    // Get button reference
    NSStatusBarButton *button = self.statusItem.button;
    if (!button) {
        NSLog(@"[StatusBar] FATAL - Status item has no button");
        return;
    }
    
    // Configure button with native appearance
    button.title = @"En";
    button.toolTip = @"PHTV - Bộ gõ tiếng Việt";
    
    // Modern button styling
    if (@available(macOS 11.0, *)) {
        button.bezelStyle = NSBezelStyleTexturedRounded;
    }
    
    // Create menu with native styling
    self.statusMenu = [[NSMenu alloc] init];
    self.statusMenu.autoenablesItems = NO;
    
    // Use system font for consistency
    if (@available(macOS 10.15, *)) {
        self.statusMenu.font = [NSFont menuFontOfSize:0];
    }
    
    // === LANGUAGE TOGGLE ===
    menuInputMethod = [[NSMenuItem alloc] initWithTitle:@"Bật Tiếng Việt" 
                                                 action:@selector(onInputMethodSelected) 
                                          keyEquivalent:@"v"];
    menuInputMethod.target = self;
    menuInputMethod.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;
    [self.statusMenu addItem:menuInputMethod];
    
    [self.statusMenu addItem:[NSMenuItem separatorItem]];
    
    // === INPUT TYPE HEADER ===
    NSMenuItem* menuInputType = [[NSMenuItem alloc] initWithTitle:@"Kiểu gõ" 
                                                          action:nil 
                                                   keyEquivalent:@""];
    menuInputType.enabled = YES;  // Must be enabled for submenu to work
    [self.statusMenu addItem:menuInputType];
    
    [self.statusMenu addItem:[NSMenuItem separatorItem]];
    
    // === CODE TABLE ITEMS ===
    mnuUnicode = [[NSMenuItem alloc] initWithTitle:@"Unicode dựng sẵn" 
                                            action:@selector(onCodeSelected:) 
                                     keyEquivalent:@""];
    mnuUnicode.target = self;
    mnuUnicode.tag = 0;
    [self.statusMenu addItem:mnuUnicode];
    
    mnuTCVN = [[NSMenuItem alloc] initWithTitle:@"TCVN3 (ABC)" 
                                         action:@selector(onCodeSelected:) 
                                  keyEquivalent:@""];
    mnuTCVN.target = self;
    mnuTCVN.tag = 1;
    [self.statusMenu addItem:mnuTCVN];
    
    mnuVNIWindows = [[NSMenuItem alloc] initWithTitle:@"VNI Windows" 
                                               action:@selector(onCodeSelected:) 
                                        keyEquivalent:@""];
    mnuVNIWindows.target = self;
    mnuVNIWindows.tag = 2;
    [self.statusMenu addItem:mnuVNIWindows];
    
    NSMenuItem* menuCode = [[NSMenuItem alloc] initWithTitle:@"Bảng mã khác..." 
                                                      action:nil 
                                               keyEquivalent:@""];
    [self.statusMenu addItem:menuCode];
    
    [self.statusMenu addItem:[NSMenuItem separatorItem]];

    // === TOOLS ===
    mnuQuickConvert = [[NSMenuItem alloc] initWithTitle:@"Chuyển mã nhanh" 
                                                 action:@selector(onQuickConvert) 
                                          keyEquivalent:@""];
    mnuQuickConvert.target = self;
    [self.statusMenu addItem:mnuQuickConvert];
    
    [self.statusMenu addItem:[NSMenuItem separatorItem]];
    
    // === SETTINGS ===
    NSMenuItem* startupItem = [[NSMenuItem alloc] initWithTitle:@"Khởi động cùng hệ thống" 
                                                         action:@selector(toggleStartupItem:) 
                                                  keyEquivalent:@""];
    startupItem.target = self;
    [self.statusMenu addItem:startupItem];
    
    [self.statusMenu addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem* controlPanelItem = [[NSMenuItem alloc] initWithTitle:@"Bảng điều khiển..." 
                                                              action:@selector(onControlPanelSelected) 
                                                       keyEquivalent:@","];
    controlPanelItem.target = self;
    controlPanelItem.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    [self.statusMenu addItem:controlPanelItem];
    
    NSMenuItem* macroItem = [[NSMenuItem alloc] initWithTitle:@"Gõ tắt..." 
                                                       action:@selector(onMacroSelected) 
                                                keyEquivalent:@"m"];
    macroItem.target = self;
    macroItem.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    [self.statusMenu addItem:macroItem];
    
    NSMenuItem* aboutItem = [[NSMenuItem alloc] initWithTitle:@"Giới thiệu" 
                                                       action:@selector(onAboutSelected) 
                                                keyEquivalent:@""];
    aboutItem.target = self;
    [self.statusMenu addItem:aboutItem];
    
    [self.statusMenu addItem:[NSMenuItem separatorItem]];
    
    // === QUIT ===
    NSMenuItem* quitItem = [[NSMenuItem alloc] initWithTitle:@"Thoát PHTV" 
                                                      action:@selector(terminate:) 
                                               keyEquivalent:@"q"];
    quitItem.target = NSApp;
    quitItem.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    [self.statusMenu addItem:quitItem];
    
    // Setup submenus
    [self setInputTypeMenu:menuInputType];
    [self setCodeMenu:menuCode];
    
    // ================================================
    // CRITICAL: Assign menu to status item
    // This is what makes the menu bar icon clickable!
    // ================================================
    self.statusItem.menu = self.statusMenu;
    
    // Log success
    NSLog(@"[StatusBar] Menu created successfully");
    NSLog(@"[StatusBar] Total items: %ld", (long)self.statusMenu.numberOfItems);
    NSLog(@"[StatusBar] Button title: '%@'", button.title);
    NSLog(@"[StatusBar] Menu assigned: %@", self.statusItem.menu ? @"YES" : @"NO");
    
    // Update UI with current settings (no animation on startup)
    [self fillDataWithAnimation:NO];
}

-(void)setQuickConvertString {
    NSMutableString* hotKey = [NSMutableString stringWithString:@""];
    bool hasAdd = false;
    if (convertToolHotKey & 0x100) {
        [hotKey appendString:@"⌃"];
        hasAdd = true;
    }
    if (convertToolHotKey & 0x200) {
        if (hasAdd)
            [hotKey appendString:@" + "];
        [hotKey appendString:@"⌥"];
        hasAdd = true;
    }
    if (convertToolHotKey & 0x400) {
        if (hasAdd)
            [hotKey appendString:@" + "];
        [hotKey appendString:@"⌘"];
        hasAdd = true;
    }
    if (convertToolHotKey & 0x800) {
        if (hasAdd)
            [hotKey appendString:@" + "];
        [hotKey appendString:@"⇧"];
        hasAdd = true;
    }
    
    unsigned short k = ((convertToolHotKey>>24) & 0xFF);
    if (k != 0xFE) {
        if (hasAdd)
            [hotKey appendString:@" + "];
        if (k == kVK_Space)
            [hotKey appendFormat:@"%@", @"␣ "];
        else
            [hotKey appendFormat:@"%c", k];
    }
    [mnuQuickConvert setTitle: hasAdd ? [NSString stringWithFormat:@"Chuyển mã nhanh - [%@]", [hotKey uppercaseString]] : @"Chuyển mã nhanh"];
}

-(void)loadDefaultConfig {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    vLanguage = 1; [defaults setInteger:vLanguage forKey:@"InputMethod"];
    vInputType = 0; [defaults setInteger:vInputType forKey:@"InputType"];
    vFreeMark = 0; [defaults setInteger:vFreeMark forKey:@"FreeMark"];
    vCheckSpelling = 1; [defaults setInteger:vCheckSpelling forKey:@"Spelling"];
    vCodeTable = 0; [defaults setInteger:vCodeTable forKey:@"CodeTable"];
    vSwitchKeyStatus = DEFAULT_SWITCH_STATUS; [defaults setInteger:vSwitchKeyStatus forKey:@"SwitchKeyStatus"];
    vQuickTelex = 0; [defaults setInteger:vQuickTelex forKey:@"QuickTelex"];
    vUseModernOrthography = 0; [defaults setInteger:vUseModernOrthography forKey:@"ModernOrthography"];
    vRestoreIfWrongSpelling = 0; [defaults setInteger:vRestoreIfWrongSpelling forKey:@"RestoreIfInvalidWord"];
    vFixRecommendBrowser = 1; [defaults setInteger:vFixRecommendBrowser forKey:@"FixRecommendBrowser"];
    vUseMacro = 1; [defaults setInteger:vUseMacro forKey:@"UseMacro"];
    vUseMacroInEnglishMode = 0; [defaults setInteger:vUseMacroInEnglishMode forKey:@"UseMacroInEnglishMode"];
    vSendKeyStepByStep = 0; [defaults setInteger:vSendKeyStepByStep forKey:@"SendKeyStepByStep"];
    vUseSmartSwitchKey = 1; [defaults setInteger:vUseSmartSwitchKey forKey:@"UseSmartSwitchKey"];
    vUpperCaseFirstChar = 0;[[NSUserDefaults standardUserDefaults] setInteger:vUpperCaseFirstChar forKey:@"UpperCaseFirstChar"];
    vTempOffSpelling = 0; [defaults setInteger:vTempOffSpelling forKey:@"vTempOffSpelling"];
    vAllowConsonantZFWJ = 0; [defaults setInteger:vAllowConsonantZFWJ forKey:@"vAllowConsonantZFWJ"];
    vQuickStartConsonant = 0; [defaults setInteger:vQuickStartConsonant forKey:@"vQuickStartConsonant"];
    vQuickEndConsonant = 0; [defaults setInteger:vQuickEndConsonant forKey:@"vQuickEndConsonant"];
    vRememberCode = 1; [defaults setInteger:vRememberCode forKey:@"vRememberCode"];
    vOtherLanguage = 1; [defaults setInteger:vOtherLanguage forKey:@"vOtherLanguage"];
    vTempOffPHTV = 0; [defaults setInteger:vTempOffPHTV forKey:@"vTempOffPHTV"];

    // Auto restore English words - default: ON for new users
    vAutoRestoreEnglishWord = 1; [defaults setInteger:vAutoRestoreEnglishWord forKey:@"vAutoRestoreEnglishWord"];

    // Restore to raw keys (customizable key) - default: ON with ESC key
    vRestoreOnEscape = 1; [defaults setInteger:vRestoreOnEscape forKey:@"vRestoreOnEscape"];
    vCustomEscapeKey = 0; [defaults setInteger:vCustomEscapeKey forKey:@"vCustomEscapeKey"];

    vShowIconOnDock = 0; [defaults setInteger:vShowIconOnDock forKey:@"vShowIconOnDock"];
    vPerformLayoutCompat = 0; [defaults setInteger:vPerformLayoutCompat forKey:@"vPerformLayoutCompat"];

    [defaults setInteger:1 forKey:@"GrayIcon"];
    [defaults setInteger:1 forKey:@"RunOnStartup"];

    // IMPORTANT: DO NOT reset macroList/macroData here!
    // User's custom abbreviations should be preserved when resetting other settings.
    // If user wants to clear macros, they can do it from the Macro Settings UI.

    [defaults synchronize];

    [self fillData];
}

-(void)setRunOnStartup:(BOOL)val {
    // Use SMAppService for macOS 13+ (application target is macOS 13+)
    SMAppService *appService = [SMAppService mainAppService];
    NSError *error = nil;
    BOOL actualSuccess = NO;  // Track actual registration result

    // Log current status
    NSLog(@"[LoginItem] Current SMAppService status: %ld", (long)appService.status);

    if (val) {
        if (appService.status != SMAppServiceStatusEnabled) {
            // Verify code signing before attempting registration
            NSBundle *bundle = [NSBundle mainBundle];
            NSString *bundlePath = bundle.bundlePath;

            // Check if app is properly code signed
            NSTask *verifyTask = [[NSTask alloc] init];
            verifyTask.launchPath = @"/usr/bin/codesign";
            verifyTask.arguments = @[@"--verify", @"--deep", @"--strict", bundlePath];

            NSPipe *pipe = [NSPipe pipe];
            verifyTask.standardError = pipe;

            @try {
                [verifyTask launch];
                [verifyTask waitUntilExit];

                int status = verifyTask.terminationStatus;
                if (status != 0) {
                    NSData *errorData = [[pipe fileHandleForReading] readDataToEndOfFile];
                    NSString *errorString = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding];
                    NSLog(@"⚠️ [LoginItem] Code signature verification failed: %@", errorString);
                    NSLog(@"⚠️ [LoginItem] SMAppService may reject unsigned/ad-hoc signed apps");
                } else {
                    NSLog(@"✅ [LoginItem] Code signature verified");
                }
            } @catch (NSException *exception) {
                NSLog(@"⚠️ [LoginItem] Failed to verify code signature: %@", exception);
            }

            // Attempt registration
            BOOL success = [appService registerAndReturnError:&error];
            if (success) {
                NSLog(@"✅ [LoginItem] Registered with SMAppService");
                actualSuccess = YES;
            } else {
                NSLog(@"❌ [LoginItem] Failed to register with SMAppService");
                NSLog(@"   Error: %@", error.localizedDescription);
                NSLog(@"   Error Domain: %@", error.domain);
                NSLog(@"   Error Code: %ld", (long)error.code);

                if (error.userInfo) {
                    NSLog(@"   Error UserInfo: %@", error.userInfo);
                }

                // Common error codes and solutions
                if ([error.domain isEqualToString:@"SMAppServiceErrorDomain"]) {
                    switch (error.code) {
                        case 1: { // kSMAppServiceErrorAlreadyRegistered
                            NSLog(@"   → App already registered (stale state). Trying to unregister first...");
                            [appService unregisterAndReturnError:nil];
                            // Retry after brief delay
                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                NSError *retryError = nil;
                                if ([appService registerAndReturnError:&retryError]) {
                                    NSLog(@"✅ [LoginItem] Registration succeeded on retry");

                                    // Update UserDefaults on success
                                    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"PHTV_RunOnStartup"];
                                    [[NSUserDefaults standardUserDefaults] setInteger:1 forKey:@"RunOnStartup"];
                                    [[NSUserDefaults standardUserDefaults] synchronize];

                                    // Notify SwiftUI
                                    [[NSNotificationCenter defaultCenter] postNotificationName:@"RunOnStartupChanged"
                                                                                        object:nil
                                                                                      userInfo:@{@"enabled": @(YES)}];
                                } else {
                                    NSLog(@"❌ [LoginItem] Registration still failed: %@", retryError.localizedDescription);

                                    // Notify SwiftUI to revert toggle
                                    [[NSNotificationCenter defaultCenter] postNotificationName:@"RunOnStartupChanged"
                                                                                        object:nil
                                                                                      userInfo:@{@"enabled": @(NO)}];
                                }
                            });
                            return;  // Exit early - retry will handle notification
                        }
                        case 2: { // kSMAppServiceErrorInvalidSignature
                            NSLog(@"   → Invalid code signature. App must be properly signed with Developer ID");
                            NSLog(@"   → Ad-hoc signed apps (for development) are NOT supported by SMAppService");
                            NSLog(@"   → Solution: Sign with Apple Developer ID certificate or use notarization");
                            break;
                        }
                        case 3: { // kSMAppServiceErrorInvalidPlist
                            NSLog(@"   → Invalid Info.plist configuration");
                            break;
                        }
                        default: {
                            NSLog(@"   → Unknown SMAppService error");
                            break;
                        }
                    }
                }

                // Registration failed - revert toggle to OFF
                actualSuccess = NO;
            }
        } else {
            NSLog(@"ℹ️ [LoginItem] Already enabled, skipping registration");
            actualSuccess = YES;  // Already enabled = success
        }
    } else {
        if (appService.status == SMAppServiceStatusEnabled) {
            BOOL success = [appService unregisterAndReturnError:&error];
            if (success) {
                NSLog(@"✅ [LoginItem] Unregistered from SMAppService");
                actualSuccess = YES;
            } else {
                NSLog(@"❌ [LoginItem] Failed to unregister: %@", error.localizedDescription);
                NSLog(@"   Error Domain: %@, Code: %ld", error.domain, (long)error.code);
                actualSuccess = NO;
            }
        } else {
            NSLog(@"ℹ️ [LoginItem] Already disabled, skipping unregistration");
            actualSuccess = YES;  // Already disabled = success
        }
    }

    // CRITICAL FIX: Only update UserDefaults if operation succeeded
    if (actualSuccess) {
        [[NSUserDefaults standardUserDefaults] setBool:val forKey:@"PHTV_RunOnStartup"];
        [[NSUserDefaults standardUserDefaults] setInteger:(val ? 1 : 0) forKey:@"RunOnStartup"];
        [[NSUserDefaults standardUserDefaults] synchronize];

        // Notify SwiftUI to sync UI
        [[NSNotificationCenter defaultCenter] postNotificationName:@"RunOnStartupChanged"
                                                            object:nil
                                                          userInfo:@{@"enabled": @(val)}];

        NSLog(@"[LoginItem] ✅ Launch at Login %@ - UserDefaults saved and UI notified", val ? @"ENABLED" : @"DISABLED");
    } else {
        // Registration/unregistration failed - revert toggle to opposite state
        NSLog(@"[LoginItem] ❌ Operation failed - reverting toggle to %@", val ? @"OFF" : @"ON");

        // Notify SwiftUI to revert toggle
        [[NSNotificationCenter defaultCenter] postNotificationName:@"RunOnStartupChanged"
                                                            object:nil
                                                          userInfo:@{@"enabled": @(!val)}];
    }
}

-(void)setGrayIcon:(BOOL)val {
    [self fillData];
}

-(void)setDockIconVisible:(BOOL)visible {
    NSLog(@"[AppDelegate] setDockIconVisible called with: %d", visible);
    
    // Track whether settings window is open (don't modify vShowIconOnDock - that's user preference)
    settingsWindowOpen = visible;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // Only change dock visibility, don't affect menu bar
        // LSUIElement in Info.plist keeps app hidden from dock by default
        // This toggles visibility temporarily for settings window
        if (visible) {
            // Show icon on dock (regular app)
            [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
            // Activate app and bring windows to front
            [NSApp activateIgnoringOtherApps:YES];
        } else {
            // Settings closed - restore to user preference
            BOOL userPrefersDock = [[NSUserDefaults standardUserDefaults] boolForKey:@"vShowIconOnDock"];
            NSApplicationActivationPolicy policy = userPrefersDock ? NSApplicationActivationPolicyRegular : NSApplicationActivationPolicyAccessory;
            [NSApp setActivationPolicy:policy];
        }
    });
}

-(void)showIcon:(BOOL)onDock {
    NSLog(@"[AppDelegate] showIcon called with onDock: %d", onDock);
    
    // Save to UserDefaults first
    [[NSUserDefaults standardUserDefaults] setBool:onDock forKey:@"vShowIconOnDock"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    vShowIconOnDock = onDock ? 1 : 0;
    
    // Apply activation policy on main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        NSApplicationActivationPolicy policy = onDock ? NSApplicationActivationPolicyRegular : NSApplicationActivationPolicyAccessory;
        [NSApp setActivationPolicy: policy];
        
        // If showing dock icon, activate the app to refresh the dock
        if (onDock) {
            [NSApp activateIgnoringOtherApps:YES];
        }
    });
}

#pragma mark -StatusBar menu data

- (void)setInputTypeMenu:(NSMenuItem*) parent {
    // Create submenu if not exists
    if (!parent.submenu) {
        NSMenu *sub = [[NSMenu alloc] init];
        sub.autoenablesItems = NO;
        parent.submenu = sub;
    }
    
    NSMenu *sub = parent.submenu;
    [sub removeAllItems]; // Clear old items
    
    mnuTelex = [[NSMenuItem alloc] initWithTitle:@"Telex" action:@selector(onInputTypeSelected:) keyEquivalent:@""];
    mnuTelex.target = self;
    mnuTelex.tag = 0;
    [sub addItem:mnuTelex];
    
    mnuVNI = [[NSMenuItem alloc] initWithTitle:@"VNI" action:@selector(onInputTypeSelected:) keyEquivalent:@""];
    mnuVNI.target = self;
    mnuVNI.tag = 1;
    [sub addItem:mnuVNI];
    
    mnuSimpleTelex1 = [[NSMenuItem alloc] initWithTitle:@"Simple Telex 1" action:@selector(onInputTypeSelected:) keyEquivalent:@""];
    mnuSimpleTelex1.target = self;
    mnuSimpleTelex1.tag = 2;
    [sub addItem:mnuSimpleTelex1];
    
    mnuSimpleTelex2 = [[NSMenuItem alloc] initWithTitle:@"Simple Telex 2" action:@selector(onInputTypeSelected:) keyEquivalent:@""];
    mnuSimpleTelex2.target = self;
    mnuSimpleTelex2.tag = 3;
    [sub addItem:mnuSimpleTelex2];
}

- (void)setCodeMenu:(NSMenuItem*) parent {
    // Create submenu if not exists
    if (!parent.submenu) {
        NSMenu *sub = [[NSMenu alloc] init];
        sub.autoenablesItems = NO;
        parent.submenu = sub;
    }
    
    NSMenu *sub = parent.submenu;
    [sub removeAllItems]; // Clear old items
    
    mnuUnicodeComposite = [[NSMenuItem alloc] initWithTitle:@"Unicode tổ hợp" action:@selector(onCodeSelected:) keyEquivalent:@""];
    mnuUnicodeComposite.target = self;
    mnuUnicodeComposite.tag = 3;
    [sub addItem:mnuUnicodeComposite];
    
    mnuVietnameseLocaleCP1258 = [[NSMenuItem alloc] initWithTitle:@"Vietnamese Locale CP 1258" action:@selector(onCodeSelected:) keyEquivalent:@""];
    mnuVietnameseLocaleCP1258.target = self;
    mnuVietnameseLocaleCP1258.tag = 4;
    [sub addItem:mnuVietnameseLocaleCP1258];
}

- (void) fillData {
    [self fillDataWithAnimation:YES];
}

- (void) fillDataWithAnimation:(BOOL)animated {
    if (!self.statusItem || !self.statusItem.button) {
        return;  // Silent fail - no logging on hot path
    }

    // PERFORMANCE: Use global variables directly (already in cache)
    // DO NOT re-read from UserDefaults - eliminates disk I/O
    NSInteger intInputMethod = vLanguage;
    NSInteger intInputType = vInputType;
    NSInteger intCode = vCodeTable;

    // PERFORMANCE: Skip animation for faster response
    // Users want instant feedback, not 150ms animation delay
    static NSFont *statusFont = nil;
    static CGFloat lastFontSize = 0.0;
    CGFloat desiredSize = (self.statusBarFontSize > 0.0) ? self.statusBarFontSize : 12.0;
    if (!statusFont || lastFontSize != desiredSize) {
        lastFontSize = desiredSize;
        statusFont = [NSFont monospacedSystemFontOfSize:desiredSize weight:NSFontWeightSemibold];
    }

    NSString *statusText = (intInputMethod == 1) ? @"Vi" : @"En";

    // PERFORMANCE: Use simple color, skip grayIcon check (not critical for UX)
    NSColor *textColor = (intInputMethod == 1) ? [NSColor systemBlueColor] : [NSColor secondaryLabelColor];

    NSDictionary *attributes = @{
        NSFontAttributeName: statusFont,
        NSForegroundColorAttributeName: textColor
    };
    NSAttributedString *newTitle = [[NSAttributedString alloc] initWithString:statusText attributes:attributes];

    // PERFORMANCE: No animation - instant update
    self.statusItem.button.attributedTitle = newTitle;

    // Update menu input method state
    [menuInputMethod setState:(intInputMethod == 1) ? NSControlStateValueOn : NSControlStateValueOff];

    // PERFORMANCE: Update only the active items, skip title updates
    [mnuTelex setState:(intInputType == 0) ? NSControlStateValueOn : NSControlStateValueOff];
    [mnuVNI setState:(intInputType == 1) ? NSControlStateValueOn : NSControlStateValueOff];
    [mnuSimpleTelex1 setState:(intInputType == 2) ? NSControlStateValueOn : NSControlStateValueOff];
    [mnuSimpleTelex2 setState:(intInputType == 3) ? NSControlStateValueOn : NSControlStateValueOff];

    // PERFORMANCE: Direct updates, skip array iteration
    [mnuUnicode setState:(intCode == 0) ? NSControlStateValueOn : NSControlStateValueOff];
    [mnuTCVN setState:(intCode == 1) ? NSControlStateValueOn : NSControlStateValueOff];
    [mnuVNIWindows setState:(intCode == 2) ? NSControlStateValueOn : NSControlStateValueOff];
    [mnuUnicodeComposite setState:(intCode == 3) ? NSControlStateValueOn : NSControlStateValueOff];
    [mnuVietnameseLocaleCP1258 setState:(intCode == 4) ? NSControlStateValueOn : NSControlStateValueOff];
}

-(void)onImputMethodChanged:(BOOL)willNotify {
    // Re-entry guard: prevent notification ping-pong
    if (_isUpdatingLanguage) {
        #ifdef DEBUG
        NSLog(@"[MenuBar] Ignoring language change (already updating)");
        #endif
        return;
    }

    NSInteger intInputMethod = [[NSUserDefaults standardUserDefaults] integerForKey:@"InputMethod"];
    intInputMethod = (intInputMethod == 0) ? 1 : 0;

    if (vLanguage == (int)intInputMethod) {
        #ifdef DEBUG
        NSLog(@"[MenuBar] Language already at %d, skipping", vLanguage);
        #endif
        return;
    }

    #ifdef DEBUG
    NSLog(@"[MenuBar] Language changing from %d to %d", vLanguage, (int)intInputMethod);
    #endif

    _isUpdatingLanguage = YES;

    #ifdef DEBUG
    NSLog(@"========================================");
    NSLog(@"[MenuBar] TOGGLING LANGUAGE: %d -> %d", vLanguage, (int)intInputMethod);
    NSLog(@"========================================");
    #endif

    // CRITICAL: Synchronous state change to prevent race conditions
    // 1. Update global variable
    vLanguage = (int)intInputMethod;

    // 2. Memory barrier to ensure event tap thread sees new value
    __sync_synchronize();

    // 3. Save to UserDefaults (async - no synchronize, auto-saves periodically)
    [[NSUserDefaults standardUserDefaults] setInteger:intInputMethod forKey:@"InputMethod"];

    // 4. Reset engine state IMMEDIATELY (synchronous!)
    RequestNewSession();

    // 4. Update UI
    [self fillData];

    // 5. Notify SwiftUI about language change
    [[NSNotificationCenter defaultCenter] postNotificationName:@"LanguageChangedFromBackend" object:@(vLanguage)];

    // 6. Notify engine (async is OK since state is already reset) - only if SmartSwitchKey enabled
    if (willNotify && vUseSmartSwitchKey) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            OnInputMethodChanged();
        });
    }

    #ifdef DEBUG
    NSLog(@"[MenuBar] Language changed to: %d (engine reset complete)", vLanguage);
    #endif

    _isUpdatingLanguage = NO;
}

#pragma mark -StatusBar menu action
- (void)onInputMethodSelected {
    [self onImputMethodChanged:YES];
}

- (void)onInputTypeSelected:(id)sender {
    NSMenuItem *menuItem = (NSMenuItem*) sender;
    [self onInputTypeSelectedIndex:(int)menuItem.tag];
}

- (void)onInputTypeSelectedIndex:(int)index {
    // Re-entry guard: prevent notification ping-pong
    if (_isUpdatingInputType) {
        NSLog(@"[MenuBar] Ignoring input type change (already updating)");
        return;
    }

    if (vInputType == index) {
        NSLog(@"[MenuBar] Input type already at %d, skipping", index);
        return;
    }

    NSLog(@"[MenuBar] Input type changing from %d to %d", vInputType, index);

    _isUpdatingInputType = YES;

    NSLog(@"========================================");
    NSLog(@"[MenuBar] CHANGING INPUT TYPE: %d -> %d", vInputType, index);
    NSLog(@"========================================");

    // CRITICAL: Synchronous state change to prevent race conditions
    // 1. Update global variable
    vInputType = index;

    // 2. Memory barrier to ensure event tap thread sees new value
    __sync_synchronize();

    // 3. Save to UserDefaults (async - no synchronize, auto-saves periodically)
    [[NSUserDefaults standardUserDefaults] setInteger:index forKey:@"InputType"];

    // 4. Reset engine state IMMEDIATELY (synchronous!)
    RequestNewSession();

    // 4. Update UI
    [self fillData];

    // 5. Notify SwiftUI about input type change
    [[NSNotificationCenter defaultCenter] postNotificationName:@"LanguageChangedFromBackend" object:@(vLanguage)];

    // 6. Notify engine (async is OK since state is already reset) - only if SmartSwitchKey enabled
    if (vUseSmartSwitchKey) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            OnInputMethodChanged();
        });
    }

    NSLog(@"[MenuBar] Input type changed to: %d (engine reset complete)", index);

    _isUpdatingInputType = NO;
}

- (void)onCodeTableChanged:(int)index {
    // Re-entry guard: prevent notification ping-pong
    if (_isUpdatingCodeTable) {
        NSLog(@"[MenuBar] Ignoring code table change (already updating)");
        return;
    }

    if (vCodeTable == index) {
        NSLog(@"[MenuBar] Code table already at %d, skipping", index);
        return;
    }

    NSLog(@"[MenuBar] Code table changing from %d to %d", vCodeTable, index);

    _isUpdatingCodeTable = YES;

    NSLog(@"========================================");
    NSLog(@"[MenuBar] CHANGING CODE TABLE: %d -> %d", vCodeTable, index);
    NSLog(@"========================================");

    // CRITICAL: Synchronous state change to prevent race conditions
    // 1. Update global variable
    vCodeTable = index;

    // 2. Memory barrier to ensure event tap thread sees new value
    __sync_synchronize();

    // 3. Save to UserDefaults (async - no synchronize, auto-saves periodically)
    [[NSUserDefaults standardUserDefaults] setInteger:index forKey:@"CodeTable"];

    // 4. Reset engine state IMMEDIATELY (synchronous!)
    RequestNewSession();

    // 4. Update UI
    [self fillData];

    // 5. Notify engine (async is OK since state is reset)
    // Always refresh macro conversion state when code table changes.
    // OnTableCodeChange() will internally skip per-app persistence when RememberCode is off.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        OnTableCodeChange();
    });

    NSLog(@"[MenuBar] Code table changed to: %d (engine reset complete)", index);

    _isUpdatingCodeTable = NO;
}

- (void)onCodeSelected:(id)sender {
    NSMenuItem *menuItem = (NSMenuItem*) sender;
    [self onCodeTableChanged:(int)menuItem.tag];
}

-(void)onQuickConvert {
    if ([PHTVManager quickConvert]) {
        if (!convertToolDontAlertWhenCompleted) {
            [PHTVManager showMessage: nil message:@"Chuyển mã thành công!" subMsg:@"Kết quả đã được lưu trong clipboard."];
        }
    } else {
        [PHTVManager showMessage: nil message:@"Không có dữ liệu trong clipboard!" subMsg:@"Hãy sao chép một đoạn text để chuyển đổi!"];
    }
}

// MARK: - UI Actions (SwiftUI Integration)
// Old Storyboard-based window methods - replaced with SwiftUI
// Kept for backward compatibility during transition

-(void) onControlPanelSelected {
    // Show dock icon when opening settings
    [self setDockIconVisible:YES];

    // Mark that user has opened settings, so defaults won't overwrite their changes
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults integerForKey:@"NonFirstTime"] == 0) {
        [defaults setInteger:1 forKey:@"NonFirstTime"];
        [defaults synchronize];
        NSLog(@"Marking NonFirstTime after user opened settings");
    }

    // Post notification - SettingsWindowManager in Swift will handle it
    NSLog(@"[AppDelegate] Posting ShowSettings notification");
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ShowSettings" object:nil];
}

-(void) onMacroSelected {
    // Show SwiftUI Macro tab
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ShowMacroTab" object:nil];
}

-(void) onAboutSelected {
    // Show SwiftUI About tab
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ShowAboutTab" object:nil];
}

-(void)toggleStartupItem:(NSMenuItem*)sender {
    // Toggle startup setting
    NSInteger currentValue = [[NSUserDefaults standardUserDefaults] integerForKey:@"RunOnStartup"];
    BOOL newValue = !currentValue;
    
    [self setRunOnStartup:newValue];
    
    // Update menu item state
    [self fillData];
    
    // Show notification
    NSString *message = newValue ? 
        @"✅ PHTV sẽ tự động khởi động cùng hệ thống" : 
        @"❌ Đã tắt khởi động cùng hệ thống";
    
    NSLog(@"%@", message);
}

#pragma mark -Short key event
-(void)onSwitchLanguage {
    [self onInputMethodSelected];
}

#pragma mark Reset PHTV after mac computer awake
-(void)receiveWakeNote: (NSNotification*)note {
    // Force stop/start on wake to ensure fresh connection to Window Server
    // This fixes issues where event tap dies during sleep or Mach port becomes invalid
    [PHTVManager stopEventTap];
    [PHTVManager initEventTap];
}

-(void)receiveSleepNote: (NSNotification*)note {
    [PHTVManager stopEventTap];
}

-(void)receiveActiveSpaceChanged: (NSNotification*)note {
    RequestNewSession();
}

-(void)activeAppChanged: (NSNotification*)note {
    if (vUseSmartSwitchKey && [PHTVManager isInited]) {
        OnActiveAppChanged();
    }

    // Check if the newly active app is in the excluded list
    NSRunningApplication *activeApp = [[note userInfo] objectForKey:NSWorkspaceApplicationKey];
    if (activeApp && activeApp.bundleIdentifier) {
        [self checkExcludedApp:activeApp.bundleIdentifier];
        [self checkSendKeyStepByStepApp:activeApp.bundleIdentifier];
    }
}

-(void)checkExcludedApp:(NSString *)bundleIdentifier {
    // Skip if bundle ID is nil or same as previous app
    if (!bundleIdentifier || [bundleIdentifier isEqualToString:_previousBundleIdentifier]) {
        return;
    }

    // Load excluded apps from UserDefaults
    NSData *data = [[NSUserDefaults standardUserDefaults] dataForKey:@"ExcludedApps"];
    NSArray *excludedApps = nil;
    if (data) {
        NSError *error;
        excludedApps = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            excludedApps = nil;
        }
    }

    // Check if current app is excluded
    BOOL isExcluded = NO;
    if (excludedApps) {
        for (NSDictionary *app in excludedApps) {
            NSString *excludedBundleId = app[@"bundleIdentifier"];
            if ([bundleIdentifier isEqualToString:excludedBundleId]) {
                isExcluded = YES;
                break;
            }
        }
    }

    // Handle state transition
    if (isExcluded && !_isInExcludedApp) {
        // Entering an excluded app - save current language and switch to English
        _savedLanguageBeforeExclusion = vLanguage;
        _isInExcludedApp = YES;

        if (vLanguage == 1) {  // Currently in Vietnamese mode
            vLanguage = 0;  // Switch to English
            [[NSUserDefaults standardUserDefaults] setInteger:vLanguage forKey:@"InputMethod"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [self fillData];

            NSLog(@"[ExcludedApp] Entered excluded app '%@' - switched to English (saved state: Vietnamese)", bundleIdentifier);

            // Notify SwiftUI (use special notification to avoid beep sound)
            [[NSNotificationCenter defaultCenter] postNotificationName:@"LanguageChangedFromExcludedApp" object:@(vLanguage)];
        } else {
            NSLog(@"[ExcludedApp] Entered excluded app '%@' - already in English (saved state: English)", bundleIdentifier);
        }
    }
    else if (!isExcluded && _isInExcludedApp) {
        // Leaving an excluded app - restore previous language state
        _isInExcludedApp = NO;

        if (_savedLanguageBeforeExclusion == 1 && vLanguage == 0) {
            // Restore Vietnamese mode
            vLanguage = 1;
            [[NSUserDefaults standardUserDefaults] setInteger:vLanguage forKey:@"InputMethod"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [self fillData];

            NSLog(@"[ExcludedApp] Left excluded app, switched to '%@' - restored Vietnamese mode", bundleIdentifier);

            // Notify SwiftUI (use special notification to avoid beep sound)
            [[NSNotificationCenter defaultCenter] postNotificationName:@"LanguageChangedFromExcludedApp" object:@(vLanguage)];
        } else {
            NSLog(@"[ExcludedApp] Left excluded app, switched to '%@' - staying in English", bundleIdentifier);
        }
    }
    else if (isExcluded && _isInExcludedApp) {
        // Moving between excluded apps - stay in English
        NSLog(@"[ExcludedApp] Moved from excluded app to another excluded app '%@' - staying in English", bundleIdentifier);
    }
    // else: moving between non-excluded apps, no action needed

    // Update previous bundle identifier
    _previousBundleIdentifier = bundleIdentifier;
}

-(void)checkSendKeyStepByStepApp:(NSString *)bundleIdentifier {
    // Skip if bundle ID is nil
    if (!bundleIdentifier) {
        return;
    }

    // Load send key step by step apps from UserDefaults
    NSData *data = [[NSUserDefaults standardUserDefaults] dataForKey:@"SendKeyStepByStepApps"];
    NSArray *sendKeyStepByStepApps = nil;
    if (data) {
        NSError *error;
        sendKeyStepByStepApps = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            sendKeyStepByStepApps = nil;
        }
    }

    // Check if current app is in the list
    BOOL isInList = NO;
    if (sendKeyStepByStepApps) {
        for (NSDictionary *app in sendKeyStepByStepApps) {
            NSString *appBundleId = app[@"bundleIdentifier"];
            if ([bundleIdentifier isEqualToString:appBundleId]) {
                isInList = YES;
                break;
            }
        }
    }

    // Handle state transition
    if (isInList && !_isInSendKeyStepByStepApp) {
        // Entering a send key step by step app - save current state and enable
        _savedSendKeyStepByStepBeforeApp = vSendKeyStepByStep;
        _isInSendKeyStepByStepApp = YES;

        if (!vSendKeyStepByStep) {  // Currently disabled
            vSendKeyStepByStep = YES;  // Enable
            [[NSUserDefaults standardUserDefaults] setBool:vSendKeyStepByStep forKey:@"SendKeyStepByStep"];
            [[NSUserDefaults standardUserDefaults] synchronize];

            NSLog(@"[SendKeyStepByStepApp] Entered app '%@' - enabled send key step by step", bundleIdentifier);
        } else {
            NSLog(@"[SendKeyStepByStepApp] Entered app '%@' - already enabled", bundleIdentifier);
        }
    }
    else if (!isInList && _isInSendKeyStepByStepApp) {
        // Leaving a send key step by step app - restore previous state
        _isInSendKeyStepByStepApp = NO;

        if (!_savedSendKeyStepByStepBeforeApp && vSendKeyStepByStep) {
            // Restore disabled state
            vSendKeyStepByStep = NO;
            [[NSUserDefaults standardUserDefaults] setBool:vSendKeyStepByStep forKey:@"SendKeyStepByStep"];
            [[NSUserDefaults standardUserDefaults] synchronize];

            NSLog(@"[SendKeyStepByStepApp] Left app '%@' - disabled send key step by step", bundleIdentifier);
        } else {
            NSLog(@"[SendKeyStepByStepApp] Left app '%@' - keeping send key step by step state", bundleIdentifier);
        }
    }
    else if (isInList && _isInSendKeyStepByStepApp) {
        // Moving between apps in the list - stay enabled
        NSLog(@"[SendKeyStepByStepApp] Moved to another app in list '%@' - keeping enabled", bundleIdentifier);
    }
    // else: moving between apps not in the list, no action needed
}

#pragma mark - SwiftUI Notification Handlers

/**
 * Handler for InputMethodChanged notification from SwiftUI
 * Called when user changes input method (Telex, VNI, etc.)
 */
- (void)onInputMethodChangedFromSwiftUI:(NSNotification *)notification {
    NSNumber *newInputMethodValue = (NSNumber *)notification.object;
    if (newInputMethodValue) {
        int index = [newInputMethodValue intValue];
        NSLog(@"[SwiftUI] InputMethodChanged notification received: %d", index);
        [self onInputTypeSelectedIndex:index];
    }
}

/**
 * Handler for CodeTableChanged notification from SwiftUI
 * Called when user changes character encoding table (Unicode, TCVN, VNI Windows, etc.)
 */
- (void)onCodeTableChangedFromSwiftUI:(NSNotification *)notification {
    NSNumber *newCodeTableValue = (NSNumber *)notification.object;
    if (newCodeTableValue) {
        int index = [newCodeTableValue intValue];
        NSLog(@"[SwiftUI] CodeTableChanged notification received: %d", index);
        [self onCodeTableChanged:index];
    }
}

-(void)registerSupportedNotification {
    PHTV_LIVE_LOG(@"registerSupportedNotification registering observers");
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self
                                                           selector: @selector(receiveWakeNote:)
                                                               name: NSWorkspaceDidWakeNotification object: NULL];
    
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self
                                                           selector: @selector(receiveSleepNote:)
                                                               name: NSWorkspaceWillSleepNotification object: NULL];
    
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self
                                                           selector: @selector(receiveActiveSpaceChanged:)
                                                               name: NSWorkspaceActiveSpaceDidChangeNotification object: NULL];
    
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self
                                                           selector: @selector(activeAppChanged:)
                                                               name: NSWorkspaceDidActivateApplicationNotification object: NULL];
    
    // Listen for SwiftUI setting changes (hot-reload without restart)
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(onInputMethodChangedFromSwiftUI:)
                                                 name: @"InputMethodChanged"
                                               object: NULL];
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(onCodeTableChangedFromSwiftUI:)
                                                 name: @"CodeTableChanged"
                                               object: NULL];
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(handleHotkeyChanged:)
                                                 name: @"HotkeyChanged"
                                               object: NULL];

    // Listen for TCC database changes (posted by PHTVManager)
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(handleTCCDatabaseChanged:)
                                                 name: @"TCCDatabaseChanged"
                                               object: NULL];

        // Also observe the full set of SwiftUI-driven live settings.
        // Some builds/flows rely on registerSupportedNotification rather than setupSwiftUIBridge.
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                                                         selector:@selector(handleSettingsChanged:)
                                                                                                 name:@"PHTVSettingsChanged"
                                                                                             object:NULL];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                                                         selector:@selector(handleMacrosUpdated:)
                                                                                                 name:@"MacrosUpdated"
                                                                                             object:NULL];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                                                         selector:@selector(handleExcludedAppsChanged:)
                                                                                                 name:@"ExcludedAppsChanged"
                                                                                             object:NULL];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                                                         selector:@selector(handleMenuBarIconSizeChanged:)
                                                                                                 name:@"MenuBarIconSizeChanged"
                                                                                             object:NULL];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                                                         selector:@selector(handleLanguageChangedFromSwiftUI:)
                                                                                                 name:@"LanguageChangedFromSwiftUI"
                                                                                             object:NULL];

        // Apply live updates when defaults are changed outside SwiftUI.
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                                                         selector:@selector(handleUserDefaultsDidChange:)
                                                                                                 name:NSUserDefaultsDidChangeNotification
                                                                                             object:NULL];

    // Sparkle update notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleSparkleManualCheck:)
                                                 name:@"SparkleManualCheck"
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleSparkleUpdateFound:)
                                                 name:@"SparkleUpdateFound"
                                               object:NULL];

    // Show "up to date" alert when user manually checks (SparkleManager only sends this for manual checks)
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleSparkleNoUpdate:)
                                                 name:@"SparkleNoUpdateFound"
                                               object:NULL];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleUpdateFrequencyChanged:)
                                                 name:@"UpdateCheckFrequencyChanged"
                                               object:NULL];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleBetaChannelChanged:)
                                                 name:@"BetaChannelChanged"
                                               object:NULL];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleSparkleInstallUpdate:)
                                                 name:@"SparkleInstallUpdate"
                                               object:nil];

    // SparkleInstallUpdateSilently observer removed - auto-install is now handled directly by PHSilentUserDriver
}
@end
