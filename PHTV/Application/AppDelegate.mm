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
#import "../Utils/MJAccessibilityUtils.h"
#import "../Utils/UsageStats.h"
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

volatile int vPerformLayoutCompat = 0;

//beta feature
volatile int vFixChromiumBrowser = 0; //new on version 2.0

extern int convertToolHotKey;
extern bool convertToolDontAlertWhenCompleted;

static inline BOOL PHTVLiveDebugEnabled(void) {
    const char *env = getenv("PHTV_LIVE_DEBUG");
    if (env != NULL && env[0] != '\0') {
        return strcmp(env, "0") != 0;
    }

    // Fallback: allow enabling via UserDefaults for easier debugging.
    // Example: defaults write com.phamhungtien.phtv PHTV_LIVE_DEBUG -int 1
    id stored = [[NSUserDefaults standardUserDefaults] objectForKey:@"PHTV_LIVE_DEBUG"];
    if ([stored respondsToSelector:@selector(intValue)]) {
        return [stored intValue] != 0;
    }
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
}

- (void)observeAppearanceChanges {
    _appearanceObserver = [[NSDistributedNotificationCenter defaultCenter] addObserverForName:@"AppleInterfaceThemeChangedNotification"
                                                                                       object:nil
                                                                                        queue:[NSOperationQueue mainQueue]
                                                                                   usingBlock:^(NSNotification *note) {
        [self fillData];
    }];
}

- (void)dealloc {
    if (_appearanceObserver) {
        [[NSDistributedNotificationCenter defaultCenter] removeObserver:_appearanceObserver];
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

        // CRITICAL: Invalidate permission cache immediately
        // User is going to System Settings to grant permission
        // Next timer check MUST do fresh permission test
        [PHTVManager invalidatePermissionCache];
        NSLog(@"[Accessibility] User opening System Settings - cache invalidated for fresh check");

        // Save current version after user agrees to grant permission
        [[NSUserDefaults standardUserDefaults] setObject:currentVersion forKey:@"LastRunVersion"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    } else {
        [NSApp terminate:0];
    }
}

- (void)startAccessibilityMonitoring {
    // Monitor accessibility status with 5s interval (optimized from 1s to reduce CPU usage)
    // CRITICAL: Uses test event tap creation - ONLY reliable method (Apple recommended)
    // MJAccessibilityIsEnabled() returns TRUE even when permission is revoked!
    // 5s is sufficient - permission changes are rare during normal operation
    self.accessibilityMonitor = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                                  target:self
                                                                selector:@selector(checkAccessibilityStatus)
                                                                userInfo:nil
                                                                 repeats:YES];

    // Set initial state using test tap (reliable)
    self.wasAccessibilityEnabled = [PHTVManager canCreateEventTap];

    #ifdef DEBUG
    NSLog(@"[Accessibility] Started monitoring via test event tap (interval: 5s)");
    #endif
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
        // Aggressive monitoring (10s) to eliminate any delay
        self.healthCheckTimer = [NSTimer scheduledTimerWithTimeInterval:10.0
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

    // Stop monitoring (permission granted, no need to monitor for grant anymore)
    [self stopAccessibilityMonitoring];

    // Initialize event tap immediately - NO RESTART NEEDED!
    dispatch_async(dispatch_get_main_queue(), ^{
        if (![PHTVManager initEventTap]) {
            NSLog(@"[EventTap] Failed to initialize");
            [self onControlPanelSelected];
        } else {
            NSLog(@"[EventTap] Initialized successfully - App ready!");
            
            // Start monitoring for permission revocation
            [self startAccessibilityMonitoring];
            [self startHealthCheckMonitoring];
            
            // Update menu bar to normal state
            [self fillDataWithAnimation:YES];
            
            // Show UI if requested
            NSInteger showui = [[NSUserDefaults standardUserDefaults] integerForKey:@"ShowUIOnStartup"];
            if (showui == 1) {
                [self onControlPanelSelected];
            }

            // On very first launch, relaunch once after permission is granted so the
            // accessibility trust state is fully applied to the process.
            if (self->_needsRelaunchAfterPermission) {
                self->_needsRelaunchAfterPermission = NO;
                [self relaunchAppAfterPermissionGrant];
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

            // CRITICAL: Invalidate permission cache
            // User is going to System Settings to re-grant permission
            [PHTVManager invalidatePermissionCache];
            NSLog(@"[Accessibility] User opening System Settings to re-grant - cache invalidated");
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

- (void)checkAccessibilityAndRestart {
    // Legacy method - kept for compatibility
    // Now handled by checkAccessibilityStatus
    // Use test tap - reliable check (MJAccessibilityIsEnabled is unreliable)
    if ([PHTVManager canCreateEventTap]) {
        [self performAccessibilityGrantedRestart];
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
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
            // This detects if permission is revoked while app is running
            [self startAccessibilityMonitoring];
            [self startHealthCheckMonitoring];
            
            NSInteger showui = [[NSUserDefaults standardUserDefaults] integerForKey:@"ShowUIOnStartup"];
            if (showui == 1) {
                // Show settings via SwiftUI notification
                [[NSNotificationCenter defaultCenter] postNotificationName:@"ShowSettings" object:nil];
            }
        }
        [self setQuickConvertString];

        // Initialize Sparkle auto-updater with delay to ensure network is ready
        // Wait 10 seconds after launch to avoid network errors on system startup
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

    //correct run on startup
    NSInteger val = [[NSUserDefaults standardUserDefaults] integerForKey:@"RunOnStartup"];
    [appDelegate setRunOnStartup:val];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    [self onControlPanelSelected];
    return YES;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Clear AX test flag on normal termination to prevent false safe mode activation
    [PHTVManager clearAXTestFlag];
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
    int oldFixChromiumBrowser = vFixChromiumBrowser;
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
    vFixChromiumBrowser = PHTVReadIntWithFallback(defaults, @"vFixChromiumBrowser", vFixChromiumBrowser);
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
                         oldFixChromiumBrowser != vFixChromiumBrowser ||
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
    NSLog(@"  - fixChromiumBrowser=%d, performLayoutCompat=%d", vFixChromiumBrowser, vPerformLayoutCompat);
    #endif
    
    // Apply dock icon visibility immediately with async dispatch
    dispatch_async(dispatch_get_main_queue(), ^{
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

// Disabled: No longer show "up to date" message to avoid annoying users
// Only notify when there IS an update available
//- (void)handleSparkleNoUpdate:(NSNotification *)notification {
//    dispatch_async(dispatch_get_main_queue(), ^{
//        NSString *currentVersion = [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
//        [[NSNotificationCenter defaultCenter] postNotificationName:@"CheckForUpdatesResponse"
//                                                            object:@{
//            @"message": [NSString stringWithFormat:@"Phiên bản hiện tại (%@) là mới nhất", currentVersion],
//            @"isError": @NO,
//            @"updateAvailable": @NO
//        }];
//    });
//}

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
    
    // === EXTRAS ===
    NSMenuItem* statsItem = [[NSMenuItem alloc] initWithTitle:@"Thống kê sử dụng" 
                                                       action:@selector(showUsageStats) 
                                                keyEquivalent:@"s"];
    statsItem.target = self;
    statsItem.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    [self.statusMenu addItem:statsItem];

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

    // Restore to raw keys (customizable key) - default: ON with ESC key
    vRestoreOnEscape = 1; [defaults setInteger:vRestoreOnEscape forKey:@"vRestoreOnEscape"];
    vCustomEscapeKey = 0; [defaults setInteger:vCustomEscapeKey forKey:@"vCustomEscapeKey"];

    vShowIconOnDock = 0; [defaults setInteger:vShowIconOnDock forKey:@"vShowIconOnDock"];
    vFixChromiumBrowser = 0; [defaults setInteger:vFixChromiumBrowser forKey:@"vFixChromiumBrowser"];
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
    // Use SMAppService for macOS 13+, SMLoginItemSetEnabled for older versions
    
    if (@available(macOS 13.0, *)) {
        // Modern approach: Use SMAppService
        SMAppService *appService = [SMAppService mainAppService];
        NSError *error = nil;
        
        if (val) {
            if (appService.status != SMAppServiceStatusEnabled) {
                BOOL success = [appService registerAndReturnError:&error];
                if (success) {
                    NSLog(@"✅ [LoginItem] Registered with SMAppService");
                } else {
                    NSLog(@"❌ [LoginItem] Failed to register: %@", error.localizedDescription);
                }
            }
        } else {
            if (appService.status == SMAppServiceStatusEnabled) {
                BOOL success = [appService unregisterAndReturnError:&error];
                if (success) {
                    NSLog(@"✅ [LoginItem] Unregistered from SMAppService");
                } else {
                    NSLog(@"❌ [LoginItem] Failed to unregister: %@", error.localizedDescription);
                }
            }
        }
    } else {
        // Legacy approach for macOS < 13
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (!bundleID) {
            NSLog(@"[LoginItem] Cannot get bundle identifier");
            return;
        }
        
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        Boolean success = SMLoginItemSetEnabled((__bridge CFStringRef)bundleID, val);
        #pragma clang diagnostic pop
        
        if (success) {
            NSLog(@"✅ Login item %@", val ? @"enabled" : @"disabled");
        } else {
            NSLog(@"❌ Failed to %@ login item", val ? @"enable" : @"disable");
        }
    }
    
    // Update user defaults
    [[NSUserDefaults standardUserDefaults] setBool:val forKey:@"PHTV_RunOnStartup"];
    [[NSUserDefaults standardUserDefaults] setInteger:(val ? 1 : 0) forKey:@"RunOnStartup"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

-(void)setGrayIcon:(BOOL)val {
    [self fillData];
}

-(void)showIconOnDock:(BOOL)val {
    NSLog(@"[AppDelegate] showIconOnDock called with: %d", val);
    vShowIconOnDock = val ? 1 : 0;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // Only change dock visibility, don't affect menu bar
        // LSUIElement in Info.plist keeps app hidden from dock by default
        // This toggles visibility temporarily for settings window
        if (val) {
            // Show icon on dock (regular app)
            [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
            [NSApp activate];
        } else {
            // Hide from dock (accessory app - stay in menu bar only)
            [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
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
            [NSApp activate];
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
    [self showIconOnDock:YES];

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

#pragma mark - Update Checker
- (void)showUsageStats {
    NSDictionary *stats = [[UsageStats shared] getStatsSummary];
    
    NSString *message = [NSString stringWithFormat:
        @"📊 THỐNG KÊ SỬ DỤNG\n\n"
        @"Hôm nay:\n"
        @"• Từ đã gõ: %@ từ\n"
        @"• Ký tự đã gõ: %@ ký tự\n\n"
        @"Tổng cộng:\n"
        @"• Từ đã gõ: %@ từ\n"
        @"• Ký tự đã gõ: %@ ký tự",
        [self formatNumber:stats[@"todayWords"]],
        [self formatNumber:stats[@"todayCharacters"]],
        [self formatNumber:stats[@"totalWords"]],
        [self formatNumber:stats[@"totalCharacters"]]
    ];
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Thống kê sử dụng PHTV"];
    [alert setInformativeText:message];
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Reset thống kê"];
    [alert setAlertStyle:NSAlertStyleInformational];
    
    NSModalResponse response = [alert runModal];
    if (response == NSAlertSecondButtonReturn) {
        NSAlert *confirmAlert = [[NSAlert alloc] init];
        [confirmAlert setMessageText:@"Xác nhận reset"];
        [confirmAlert setInformativeText:@"Bạn có chắc muốn reset toàn bộ thống kê?"];
        [confirmAlert addButtonWithTitle:@"Hủy"];
        [confirmAlert addButtonWithTitle:@"Reset"];
        [confirmAlert setAlertStyle:NSAlertStyleWarning];
        
        if ([confirmAlert runModal] == NSAlertSecondButtonReturn) {
            [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"StatsTotalWords"];
            [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"StatsTotalCharacters"];
            [[UsageStats shared] resetDailyStats];
            
            NSAlert *doneAlert = [[NSAlert alloc] init];
            [doneAlert setMessageText:@"Đã reset thống kê"];
            [doneAlert setInformativeText:@"Thống kê đã được reset về 0."];
            [doneAlert addButtonWithTitle:@"OK"];
            [doneAlert runModal];
        }
    }
}

- (NSString *)formatNumber:(NSNumber *)number {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    [formatter setGroupingSeparator:@"."];
    return [formatter stringFromNumber:number];
}

#pragma mark -Short key event
-(void)onSwitchLanguage {
    [self onInputMethodSelected];
}

#pragma mark Reset PHTV after mac computer awake
-(void)receiveWakeNote: (NSNotification*)note {
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

    // Disabled: No longer show "up to date" message
    // [[NSNotificationCenter defaultCenter] addObserver:self
    //                                          selector:@selector(handleSparkleNoUpdate:)
    //                                              name:@"SparkleNoUpdateFound"
    //                                            object:NULL];

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
}
@end
