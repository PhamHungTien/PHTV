//
//  AppDelegate.m
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import <Carbon/Carbon.h>
#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"
#import "AppDelegate+Private.h"
#import "AppDelegate+Accessibility.h"
#import "AppDelegate+AppMonitoring.h"
#import "AppDelegate+Defaults.h"
#import "AppDelegate+DockVisibility.h"
#import "AppDelegate+InputState.h"
#import "AppDelegate+InputSourceMonitoring.h"
#import "AppDelegate+LoginItem.h"
#import "AppDelegate+MacroData.h"
#import "AppDelegate+PermissionFlow.h"
#import "AppDelegate+RuntimeSettings.h"
#import "AppDelegate+SettingsBridge.h"
#import "AppDelegate+SettingsActions.h"
#import "AppDelegate+Sparkle.h"
#import "AppDelegate+StatusBarMenu.h"
#import "AppDelegate+UIActions.h"
#import "SparkleManager.h"
#import "../SystemBridge/PHTVManager.h"
#import "PHTV-Swift.h"
#include "../Core/Engine/Engine.h"

static NSString *const PHTVDefaultsKeyShowIconOnDock = @"vShowIconOnDock";
static NSString *const PHTVDefaultsKeyShowUIOnStartup = @"ShowUIOnStartup";
static NSString *const PHTVDefaultsKeyNonFirstTime = @"NonFirstTime";
static NSString *const PHTVDefaultsKeyInitialToolTipDelay = @"NSInitialToolTipDelay";

static NSString *const PHTVNotificationShowSettings = @"ShowSettings";
static NSString *const PHTVNotificationApplicationWillTerminate = @"ApplicationWillTerminate";

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
volatile int vSwitchKeyStatus = PHTV_DEFAULT_SWITCH_HOTKEY_STATUS;
volatile int vFixRecommendBrowser = 1;
volatile int vUseMacro = 1;
volatile int vUseMacroInEnglishMode = 0;
volatile int vAutoCapsMacro = 0;
volatile int vSendKeyStepByStep = 0;
volatile int vUseSmartSwitchKey = 1;
volatile int vUpperCaseFirstChar = 0;
volatile int vUpperCaseExcludedForCurrentApp = 0;  // 1 = current app is in uppercase excluded list
volatile int vTempOffSpelling = 0;
volatile int vAllowConsonantZFWJ = 1;
volatile int vQuickStartConsonant = 0;
volatile int vQuickEndConsonant = 0;
volatile int vRememberCode = 1; //new on version 2.0
volatile int vOtherLanguage = 1; //new on version 2.0
volatile int vTempOffPHTV = 0; //new on version 2.0

// Restore to raw keys (customizable key)
volatile int vRestoreOnEscape = 1; //enable restore to raw keys feature (default: ON)
volatile int vCustomEscapeKey = 0; //custom restore key code (0 = default ESC = KEY_ESC)

// Pause Vietnamese input when holding a key
volatile int vPauseKeyEnabled = 0; //enable pause key feature (default: OFF)
volatile int vPauseKey = KEY_LEFT_OPTION; //pause key code (default: Left Option)

// Auto restore English word feature
volatile int vAutoRestoreEnglishWord = 1; //auto restore English words (default: ON)

// Emoji picker hotkey (handled in event tap callback, OpenKey style)
volatile int vEnableEmojiHotkey = 1;
volatile int vEmojiHotkeyModifiers = NSEventModifierFlagCommand;
volatile int vEmojiHotkeyKeyCode = KEY_E; // E key

int vShowIconOnDock = 0; //new on version 2.0

volatile int vPerformLayoutCompat = 0;

@implementation AppDelegate

- (void)dealloc {
    [self stopInputSourceMonitoring];
    
    [self stopAccessibilityMonitoring];
    [self stopHealthCheckMonitoring];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSLog(@"🔴🔴🔴 [AppDelegate] applicationDidFinishLaunching STARTED 🔴🔴🔴");

    // Initialize performance optimization
    self.updateQueue = dispatch_queue_create("com.phtv.updateQueue", DISPATCH_QUEUE_SERIAL);
    self.lastInputMethod = -1;
    self.lastCodeTable = -1;
    self.isUpdatingUI = NO;

    // Initialize excluded app state tracking
    self.savedLanguageBeforeExclusion = 0;  // Default to English
    self.previousBundleIdentifier = nil;
    self.isInExcludedApp = NO;

    // Initialize send key step by step app state tracking
    self.savedSendKeyStepByStepBeforeApp = NO;  // Default to disabled
    self.isInSendKeyStepByStepApp = NO;

    // Initialize re-entry guards
    self.isUpdatingLanguage = NO;
    self.isUpdatingInputType = NO;
    self.isUpdatingCodeTable = NO;

    // Single-source registration for UserDefaults defaults shared across Swift and ObjC layers.
    [SettingsBootstrap registerDefaults];

    BOOL isFirstLaunch = ([[NSUserDefaults standardUserDefaults] boolForKey:PHTVDefaultsKeyNonFirstTime] == 0);
    // Use test tap - reliable check (MJAccessibilityIsEnabled is unreliable)
    self.needsRelaunchAfterPermission = (isFirstLaunch && ![PHTVManager canCreateEventTap]);

    appDelegate = self;
    
    [self registerSupportedNotification];
    
    //set quick tooltip
    [[NSUserDefaults standardUserDefaults] setObject: [NSNumber numberWithInt: 50]
                                              forKey: PHTVDefaultsKeyInitialToolTipDelay];
    
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
    BOOL showDockIcon = [[NSUserDefaults standardUserDefaults] boolForKey:PHTVDefaultsKeyShowIconOnDock];
    [NSApp setActivationPolicy: showDockIcon ? NSApplicationActivationPolicyRegular : NSApplicationActivationPolicyAccessory];
    
    // Beep on startup is now handled by SwiftUI if enabled

    // Initialize SwiftUI integration
    [self setupSwiftUIBridge];
    
    // Load existing macros from UserDefaults to binary format (macroData)
    [self loadExistingMacros];

    // Initialize English word dictionary for auto-restore feature
    [self initEnglishWordDictionary];

    [self loadRuntimeSettingsFromUserDefaults];
    
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

        // In rare cases the app disappears from the Accessibility list (corrupt TCC entry).
        // Attempt a one-time automatic repair so the user can re-grant permission.
        [self attemptAutomaticTCCRepairIfNeeded];

        [self startAccessibilityMonitoring];
        [self stopHealthCheckMonitoring];
        return;
    }

    //init
    dispatch_async(dispatch_get_main_queue(), ^{
        if (![PHTVManager initEventTap]) {
            // Show settings via SwiftUI notification
            [[NSNotificationCenter defaultCenter] postNotificationName:PHTVNotificationShowSettings object:nil];
        } else {
            NSLog(@"[EventTap] Initialized successfully");

            // Start continuous monitoring for accessibility permission changes
            [self startAccessibilityMonitoring];
            [self startHealthCheckMonitoring];

            // Start monitoring input source changes
            [self startInputSourceMonitoring];

            NSInteger showui = [[NSUserDefaults standardUserDefaults] integerForKey:PHTVDefaultsKeyShowUIOnStartup];
            if (showui == 1) {
                [[NSNotificationCenter defaultCenter] postNotificationName:PHTVNotificationShowSettings object:nil];
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
        [[NSUserDefaults standardUserDefaults] setInteger:1 forKey:PHTVDefaultsKeyNonFirstTime];
        NSLog(@"[AppDelegate] First launch: loaded default config and marked NonFirstTime");
    }

    [self syncRunOnStartupStatusWithFirstLaunch:isFirstLaunch];
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
    [[NSNotificationCenter defaultCenter] postNotificationName:PHTVNotificationApplicationWillTerminate object:nil];
}

@end
