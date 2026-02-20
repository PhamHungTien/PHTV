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
#import "AppDelegate+SettingsActions.h"
#import "AppDelegate+Sparkle.h"
#import "AppDelegate+StatusBarMenu.h"
#import "AppDelegate+UIActions.h"
#import "PHTVLiveDebug.h"
#import "SparkleManager.h"
#import "../SystemBridge/PHTVManager.h"
#import "PHTV-Swift.h"
#include "../Core/Engine/Engine.h"

static NSString *const PHTVDefaultsKeyEnableEmojiHotkey = @"vEnableEmojiHotkey";
static NSString *const PHTVDefaultsKeyEmojiHotkeyModifiers = @"vEmojiHotkeyModifiers";
static NSString *const PHTVDefaultsKeyEmojiHotkeyKeyCode = @"vEmojiHotkeyKeyCode";
static NSString *const PHTVDefaultsKeyInputMethod = @"InputMethod";
static NSString *const PHTVDefaultsKeyInputType = @"InputType";
static NSString *const PHTVDefaultsKeyCodeTable = @"CodeTable";
static NSString *const PHTVDefaultsKeySwitchKeyStatus = @"SwitchKeyStatus";
static NSString *const PHTVDefaultsKeySpelling = @"Spelling";
static NSString *const PHTVDefaultsKeyAllowConsonantZFWJ = @"vAllowConsonantZFWJ";
static NSString *const PHTVDefaultsKeyModernOrthography = @"ModernOrthography";
static NSString *const PHTVDefaultsKeyQuickTelex = @"QuickTelex";
static NSString *const PHTVDefaultsKeyUpperCaseFirstChar = @"UpperCaseFirstChar";
static NSString *const PHTVDefaultsKeyAutoRestoreEnglishWord = @"vAutoRestoreEnglishWord";
static NSString *const PHTVDefaultsKeyRunOnStartup = @"RunOnStartup";
static NSString *const PHTVDefaultsKeyRunOnStartupLegacy = @"PHTV_RunOnStartup";
static NSString *const PHTVDefaultsKeyShowIconOnDock = @"vShowIconOnDock";
static NSString *const PHTVDefaultsKeyShowUIOnStartup = @"ShowUIOnStartup";
static NSString *const PHTVDefaultsKeyNonFirstTime = @"NonFirstTime";
static NSString *const PHTVDefaultsKeyInitialToolTipDelay = @"NSInitialToolTipDelay";
static NSString *const PHTVDefaultsKeySendKeyStepByStep = @"SendKeyStepByStep";

static NSString *const PHTVNotificationLanguageChangedFromObjC = @"LanguageChangedFromObjC";
static NSString *const PHTVNotificationShowSettings = @"ShowSettings";
static NSString *const PHTVNotificationRunOnStartupChanged = @"RunOnStartupChanged";
static NSString *const PHTVNotificationApplicationWillTerminate = @"ApplicationWillTerminate";
static NSString *const PHTVNotificationShowMacroTab = @"ShowMacroTab";
static NSString *const PHTVNotificationShowAboutTab = @"ShowAboutTab";
static NSString *const PHTVNotificationInputMethodChanged = @"InputMethodChanged";
static NSString *const PHTVNotificationCodeTableChanged = @"CodeTableChanged";
static NSString *const PHTVNotificationShowDockIcon = @"PHTVShowDockIcon";
static NSString *const PHTVNotificationCustomDictionaryUpdated = @"CustomDictionaryUpdated";
static NSString *const PHTVNotificationSettingsReset = @"SettingsReset";
static NSString *const PHTVNotificationAccessibilityPermissionLost = @"AccessibilityPermissionLost";
static NSString *const PHTVNotificationAccessibilityNeedsRelaunch = @"AccessibilityNeedsRelaunch";
static NSString *const PHTVNotificationLanguageChangedFromBackend = @"LanguageChangedFromBackend";
static NSString *const PHTVNotificationUserInfoEnabledKey = @"enabled";

static inline int PHTVReadIntWithFallback(NSUserDefaults *defaults, NSString *key, int fallbackValue) {
    if ([defaults objectForKey:key] == nil) {
        return fallbackValue;
    }
    return (int)[defaults integerForKey:key];
}

static inline void PHTVLoadEmojiHotkeySettings(NSUserDefaults *defaults,
                                                volatile int *enabled,
                                                volatile int *modifiers,
                                                volatile int *keyCode) {
    // Default: enabled + Command+E
    id enabledObject = [defaults objectForKey:PHTVDefaultsKeyEnableEmojiHotkey];
    *enabled = (enabledObject == nil) ? 1 : ([defaults boolForKey:PHTVDefaultsKeyEnableEmojiHotkey] ? 1 : 0);

    id modifiersObject = [defaults objectForKey:PHTVDefaultsKeyEmojiHotkeyModifiers];
    if (modifiersObject == nil) {
        *modifiers = (int)NSEventModifierFlagCommand;
    } else {
        *modifiers = (int)[defaults integerForKey:PHTVDefaultsKeyEmojiHotkeyModifiers];
    }

    id keyCodeObject = [defaults objectForKey:PHTVDefaultsKeyEmojiHotkeyKeyCode];
    if (keyCodeObject == nil) {
        *keyCode = KEY_E; // E key default
    } else {
        *keyCode = (int)[defaults integerForKey:PHTVDefaultsKeyEmojiHotkeyKeyCode];
    }
}

static inline NSUInteger PHTVFoldSettingsToken(NSUInteger token, id _Nullable value) {
    const NSUInteger hashValue = value ? (NSUInteger)[value hash] : 0u;
    return (token * 16777619u) ^ hashValue;
}

static inline NSUInteger PHTVComputeSettingsToken(NSUserDefaults *defaults) {
    NSUInteger token = 2166136261u;

    token = PHTVFoldSettingsToken(token, [defaults objectForKey:PHTVDefaultsKeySpelling]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:PHTVDefaultsKeyModernOrthography]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:PHTVDefaultsKeyQuickTelex]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:@"UseMacro"]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:@"UseMacroInEnglishMode"]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:@"vAutoCapsMacro"]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:PHTVDefaultsKeySendKeyStepByStep]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:@"UseSmartSwitchKey"]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:PHTVDefaultsKeyUpperCaseFirstChar]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:PHTVDefaultsKeyAllowConsonantZFWJ]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:@"vQuickStartConsonant"]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:@"vQuickEndConsonant"]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:@"vRememberCode"]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:@"vPerformLayoutCompat"]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:PHTVDefaultsKeyShowIconOnDock]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:@"vRestoreOnEscape"]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:@"vCustomEscapeKey"]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:@"vPauseKeyEnabled"]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:@"vPauseKey"]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:PHTVDefaultsKeyAutoRestoreEnglishWord]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:PHTVDefaultsKeyEnableEmojiHotkey]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:PHTVDefaultsKeyEmojiHotkeyModifiers]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:PHTVDefaultsKeyEmojiHotkeyKeyCode]);

    return token;
}

AppDelegate* appDelegate;
static int sLastUpperCaseFirstCharSetting = -1;

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

    // Load ALL settings from UserDefaults BEFORE initializing event tap
    // This ensures settings persist across restart/wake from sleep
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    // Core input settings - CRITICAL for persistence across restart/wake
    vLanguage = PHTVReadIntWithFallback(defaults, PHTVDefaultsKeyInputMethod, vLanguage);
    vInputType = PHTVReadIntWithFallback(defaults, PHTVDefaultsKeyInputType, vInputType);
    vCodeTable = PHTVReadIntWithFallback(defaults, PHTVDefaultsKeyCodeTable, vCodeTable);
    NSLog(@"[AppDelegate] Loaded core settings: language=%d, inputType=%d, codeTable=%d", vLanguage, vInputType, vCodeTable);

    // Spelling and orthography settings
    // NOTE: vCheckSpelling already loaded in initEnglishWordDictionary() for early initialization
    // vCheckSpelling = PHTVReadIntWithFallback(defaults, PHTVDefaultsKeySpelling, 1);
    vUseModernOrthography = PHTVReadIntWithFallback(defaults, PHTVDefaultsKeyModernOrthography, vUseModernOrthography);
    vQuickTelex = PHTVReadIntWithFallback(defaults, PHTVDefaultsKeyQuickTelex, vQuickTelex);
    vFreeMark = PHTVReadIntWithFallback(defaults, @"FreeMark", vFreeMark);

    // Macro settings
    vUseMacro = PHTVReadIntWithFallback(defaults, @"UseMacro", vUseMacro);
    vUseMacroInEnglishMode = PHTVReadIntWithFallback(defaults, @"UseMacroInEnglishMode", vUseMacroInEnglishMode);
    vAutoCapsMacro = PHTVReadIntWithFallback(defaults, @"vAutoCapsMacro", vAutoCapsMacro);

    // Typing behavior settings
    vSendKeyStepByStep = PHTVReadIntWithFallback(defaults, PHTVDefaultsKeySendKeyStepByStep, vSendKeyStepByStep);
    vUseSmartSwitchKey = PHTVReadIntWithFallback(defaults, @"UseSmartSwitchKey", vUseSmartSwitchKey);
    vUpperCaseFirstChar = PHTVReadIntWithFallback(defaults, PHTVDefaultsKeyUpperCaseFirstChar, vUpperCaseFirstChar);
    vAllowConsonantZFWJ = PHTVReadIntWithFallback(defaults, PHTVDefaultsKeyAllowConsonantZFWJ, 1);
    vQuickStartConsonant = PHTVReadIntWithFallback(defaults, @"vQuickStartConsonant", vQuickStartConsonant);
    vQuickEndConsonant = PHTVReadIntWithFallback(defaults, @"vQuickEndConsonant", vQuickEndConsonant);
    vRememberCode = PHTVReadIntWithFallback(defaults, @"vRememberCode", vRememberCode);
    vPerformLayoutCompat = PHTVReadIntWithFallback(defaults, @"vPerformLayoutCompat", vPerformLayoutCompat);

    // Restore to raw keys settings
    vRestoreOnEscape = PHTVReadIntWithFallback(defaults, @"vRestoreOnEscape", vRestoreOnEscape);
    vCustomEscapeKey = PHTVReadIntWithFallback(defaults, @"vCustomEscapeKey", vCustomEscapeKey);

    // Pause key settings
    vPauseKeyEnabled = PHTVReadIntWithFallback(defaults, @"vPauseKeyEnabled", vPauseKeyEnabled);
    vPauseKey = PHTVReadIntWithFallback(defaults, @"vPauseKey", vPauseKey);

    // Auto restore English word
    vAutoRestoreEnglishWord = PHTVReadIntWithFallback(defaults, PHTVDefaultsKeyAutoRestoreEnglishWord, vAutoRestoreEnglishWord);

    // UI settings
    vShowIconOnDock = PHTVReadIntWithFallback(defaults, PHTVDefaultsKeyShowIconOnDock, vShowIconOnDock);

    // Hotkey settings
    NSInteger savedHotkey = [defaults integerForKey:PHTVDefaultsKeySwitchKeyStatus];
    if (savedHotkey != 0) {
        vSwitchKeyStatus = (int)savedHotkey;
        NSLog(@"[AppDelegate] Loaded hotkey from UserDefaults: 0x%X", vSwitchKeyStatus);
    } else {
        NSLog(@"[AppDelegate] No saved hotkey found, using default: 0x%X", vSwitchKeyStatus);
    }

    // Emoji picker hotkey settings
    PHTVLoadEmojiHotkeySettings(defaults, &vEnableEmojiHotkey, &vEmojiHotkeyModifiers, &vEmojiHotkeyKeyCode);

    self.lastSettingsChangeToken = PHTVComputeSettingsToken(defaults);
    NSLog(@"[AppDelegate] All settings loaded from UserDefaults");

    // Memory barrier to ensure event tap thread sees all values
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
                                                 name:PHTVNotificationShowMacroTab
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onShowAboutTab:)
                                                 name:PHTVNotificationShowAboutTab
                                               object:nil];
    
    // Handle input method and code table changes from SwiftUI
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleInputMethodChanged:)
                                                 name:PHTVNotificationInputMethodChanged
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleCodeTableChanged:)
                                                 name:PHTVNotificationCodeTableChanged
                                               object:nil];
    
    // Listen for dock icon visibility changes from SwiftUI
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleShowDockIconNotification:)
                                                 name:PHTVNotificationShowDockIcon
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleCustomDictionaryUpdated:)
                                                 name:PHTVNotificationCustomDictionaryUpdated
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleSettingsReset:)
                                                 name:PHTVNotificationSettingsReset
                                               object:nil];

    // CRITICAL: Handle immediate accessibility permission loss from event tap callback
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleAccessibilityRevoked)
                                                 name:PHTVNotificationAccessibilityPermissionLost
                                               object:nil];

    // Handle when app needs relaunch for permission to take effect
    // This is triggered when AXIsProcessTrusted=YES but test tap fails persistently
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleAccessibilityNeedsRelaunch)
                                                 name:PHTVNotificationAccessibilityNeedsRelaunch
                                               object:nil];

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

- (void)handleHotkeyChanged:(NSNotification *)notification {
    PHTV_LIVE_LOG(@"received HotkeyChanged");
    NSNumber *hotkey = notification.object;
    if (hotkey) {
        vSwitchKeyStatus = hotkey.intValue;

        // Memory barrier to ensure event tap thread sees new value immediately
        __sync_synchronize();

        [[NSUserDefaults standardUserDefaults] setInteger:vSwitchKeyStatus forKey:PHTVDefaultsKeySwitchKeyStatus];

        // Update UI to reflect hotkey change
        [self fillData];

        #ifdef DEBUG
        BOOL hasBeep = HAS_BEEP(vSwitchKeyStatus);
        NSLog(@"[SwiftUI] Hotkey changed to: 0x%X (beep=%@)", vSwitchKeyStatus, hasBeep ? @"YES" : @"NO");
        #endif
    }
}

- (void)handleEmojiHotkeySettingsChanged:(NSNotification *)notification {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    PHTVLoadEmojiHotkeySettings(defaults, &vEnableEmojiHotkey, &vEmojiHotkeyModifiers, &vEmojiHotkeyKeyCode);

    // Memory barrier to ensure event tap thread sees new values immediately
    __sync_synchronize();

    #ifdef DEBUG
    NSLog(@"[SwiftUI] Emoji hotkey changed: enabled=%d modifiers=0x%X keyCode=%d",
          vEnableEmojiHotkey, vEmojiHotkeyModifiers, vEmojiHotkeyKeyCode);
    #endif
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

- (void)handleSettingsChanged:(NSNotification *)notification {
    PHTV_LIVE_LOG(@"received PHTVSettingsChanged");
    // Reload settings from UserDefaults when SwiftUI changes them
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    const NSUInteger settingsToken = PHTVComputeSettingsToken(defaults);

    // Capture previous values for group-1 settings to decide whether to reset session.
    int oldCheckSpelling = vCheckSpelling;
    int oldModernOrthography = vUseModernOrthography;
    int oldQuickTelex = vQuickTelex;

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
    int oldShowIconOnDock = vShowIconOnDock;
    int oldRestoreOnEscape = vRestoreOnEscape;
    int oldCustomEscapeKey = vCustomEscapeKey;
    int oldPauseKeyEnabled = vPauseKeyEnabled;
    int oldPauseKey = vPauseKey;
    int oldAutoRestoreEnglishWord = vAutoRestoreEnglishWord;
    int oldEnableEmojiHotkey = vEnableEmojiHotkey;
    int oldEmojiHotkeyModifiers = vEmojiHotkeyModifiers;
    int oldEmojiHotkeyKeyCode = vEmojiHotkeyKeyCode;
    
    vCheckSpelling = PHTVReadIntWithFallback(defaults, PHTVDefaultsKeySpelling, 1);
    vUseModernOrthography = PHTVReadIntWithFallback(defaults, PHTVDefaultsKeyModernOrthography, vUseModernOrthography);
    vQuickTelex = PHTVReadIntWithFallback(defaults, PHTVDefaultsKeyQuickTelex, vQuickTelex);
    vUseMacro = PHTVReadIntWithFallback(defaults, @"UseMacro", vUseMacro);
    vUseMacroInEnglishMode = PHTVReadIntWithFallback(defaults, @"UseMacroInEnglishMode", vUseMacroInEnglishMode);
    vAutoCapsMacro = PHTVReadIntWithFallback(defaults, @"vAutoCapsMacro", vAutoCapsMacro);
    vSendKeyStepByStep = PHTVReadIntWithFallback(defaults, PHTVDefaultsKeySendKeyStepByStep, vSendKeyStepByStep);
    vUseSmartSwitchKey = PHTVReadIntWithFallback(defaults, @"UseSmartSwitchKey", vUseSmartSwitchKey);
    vUpperCaseFirstChar = PHTVReadIntWithFallback(defaults, PHTVDefaultsKeyUpperCaseFirstChar, vUpperCaseFirstChar);
    vAllowConsonantZFWJ = PHTVReadIntWithFallback(defaults, PHTVDefaultsKeyAllowConsonantZFWJ, 1);
    vQuickStartConsonant = PHTVReadIntWithFallback(defaults, @"vQuickStartConsonant", vQuickStartConsonant);
    vQuickEndConsonant = PHTVReadIntWithFallback(defaults, @"vQuickEndConsonant", vQuickEndConsonant);
    vRememberCode = PHTVReadIntWithFallback(defaults, @"vRememberCode", vRememberCode);
    vPerformLayoutCompat = PHTVReadIntWithFallback(defaults, @"vPerformLayoutCompat", vPerformLayoutCompat);
    vShowIconOnDock = PHTVReadIntWithFallback(defaults, PHTVDefaultsKeyShowIconOnDock, vShowIconOnDock);

    // Restore to raw keys (customizable key)
    vRestoreOnEscape = PHTVReadIntWithFallback(defaults, @"vRestoreOnEscape", vRestoreOnEscape);
    vCustomEscapeKey = PHTVReadIntWithFallback(defaults, @"vCustomEscapeKey", vCustomEscapeKey);

    // Pause Vietnamese input when holding a key
    vPauseKeyEnabled = PHTVReadIntWithFallback(defaults, @"vPauseKeyEnabled", vPauseKeyEnabled);
    vPauseKey = PHTVReadIntWithFallback(defaults, @"vPauseKey", vPauseKey);

    // Auto restore English word feature
    vAutoRestoreEnglishWord = PHTVReadIntWithFallback(defaults, PHTVDefaultsKeyAutoRestoreEnglishWord, vAutoRestoreEnglishWord);

    // Emoji picker hotkey
    PHTVLoadEmojiHotkeySettings(defaults, &vEnableEmojiHotkey, &vEmojiHotkeyModifiers, &vEmojiHotkeyKeyCode);

    BOOL justEnabledUppercase = NO;
    if (sLastUpperCaseFirstCharSetting != -1) {
        justEnabledUppercase = (sLastUpperCaseFirstCharSetting == 0 && vUpperCaseFirstChar != 0);
    }

    BOOL changed1 = (oldCheckSpelling != vCheckSpelling ||
                     oldModernOrthography != vUseModernOrthography ||
                     oldQuickTelex != vQuickTelex);
    BOOL changed2 = (oldUseMacro != vUseMacro ||
                     oldUseMacroInEnglishMode != vUseMacroInEnglishMode ||
                     oldAutoCapsMacro != vAutoCapsMacro ||
                     oldSendKeyStepByStep != vSendKeyStepByStep ||
                     oldUseSmartSwitchKey != vUseSmartSwitchKey ||
                     oldUpperCaseFirstChar != vUpperCaseFirstChar ||
                     oldAllowConsonantZFWJ != vAllowConsonantZFWJ ||
                     oldQuickStartConsonant != vQuickStartConsonant ||
                     oldQuickEndConsonant != vQuickEndConsonant ||
                     oldRememberCode != vRememberCode ||
                     oldPerformLayoutCompat != vPerformLayoutCompat);
    BOOL changedRestorePause = (oldRestoreOnEscape != vRestoreOnEscape ||
                                oldCustomEscapeKey != vCustomEscapeKey ||
                                oldPauseKeyEnabled != vPauseKeyEnabled ||
                                oldPauseKey != vPauseKey ||
                                oldAutoRestoreEnglishWord != vAutoRestoreEnglishWord);
    BOOL changedEmoji = (oldEnableEmojiHotkey != vEnableEmojiHotkey ||
                         oldEmojiHotkeyModifiers != vEmojiHotkeyModifiers ||
                         oldEmojiHotkeyKeyCode != vEmojiHotkeyKeyCode);
    BOOL changedDockVisibility = (oldShowIconOnDock != vShowIconOnDock);

    BOOL changedSessionSettings = (changed1 || changed2 || changedRestorePause || changedEmoji);
    BOOL changedAny = (changedSessionSettings || changedDockVisibility);

    // No effective change, skip expensive reset/session churn.
    if (!changedAny) {
        self.lastSettingsChangeToken = settingsToken;
        return;
    }

    if (changedSessionSettings) {
        // Memory barrier to ensure event tap thread sees new values immediately.
        __sync_synchronize();

        // Sync spell checking state specifically (fixes issue where vCheckSpelling is reset to stale _useSpellCheckingBefore).
        vSetCheckSpelling();

        // Reset engine state only when an engine-related setting actually changed.
        RequestNewSession();

        // Prime auto-capitalization when the feature is just enabled.
        if (justEnabledUppercase) {
            vPrimeUpperCaseFirstChar();
        }
    }

    if (PHTVLiveDebugEnabled()) {
        PHTV_LIVE_LOG(@"settings loaded; changedGroup1=%@ changedGroup2=%@ changedRestorePause=%@ changedEmoji=%@ changedDock=%@ useMacro=%d upperCaseFirst=%d",
                      changed1 ? @"YES" : @"NO",
                      changed2 ? @"YES" : @"NO",
                      changedRestorePause ? @"YES" : @"NO",
                      changedEmoji ? @"YES" : @"NO",
                      changedDockVisibility ? @"YES" : @"NO",
                      vUseMacro,
                      vUpperCaseFirstChar);
    }

    // If SmartSwitchKey was just enabled, sync once to current app immediately.
    if (changedSessionSettings && oldUseSmartSwitchKey == 0 && vUseSmartSwitchKey != 0 && [PHTVManager isInited]) {
        OnActiveAppChanged();
    }

    sLastUpperCaseFirstCharSetting = vUpperCaseFirstChar;
    self.lastSettingsChangeToken = settingsToken;
    
    #ifdef DEBUG
    if (changedAny) {
        NSLog(@"[SwiftUI] Settings reloaded from UserDefaults");
        NSLog(@"  - useMacro=%d, autoCapsMacro=%d, useMacroInEnglishMode=%d", vUseMacro, vAutoCapsMacro, vUseMacroInEnglishMode);
        NSLog(@"  - performLayoutCompat=%d", vPerformLayoutCompat);
        NSLog(@"  - emojiHotkey enabled=%d modifiers=0x%X keyCode=%d",
              vEnableEmojiHotkey, vEmojiHotkeyModifiers, vEmojiHotkeyKeyCode);
    }
    #endif
    
    if (changedDockVisibility) {
        // Apply dock icon visibility immediately with async dispatch.
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self isSettingsWindowVisible]) {
                // Settings window is open - keep dock icon visible regardless of preference.
                NSLog(@"[AppDelegate] Settings window open (verified), keeping dock icon visible");
                return;
            }
            NSApplicationActivationPolicy policy = vShowIconOnDock ? NSApplicationActivationPolicyRegular : NSApplicationActivationPolicyAccessory;
            [NSApp setActivationPolicy:policy];
            if (vShowIconOnDock) {
                [NSApp activate];
            }
        });
    }

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
    int newSwitchKeyStatus = PHTVReadIntWithFallback(defaults, PHTVDefaultsKeySwitchKeyStatus, vSwitchKeyStatus);
    if (newSwitchKeyStatus != vSwitchKeyStatus) {
        vSwitchKeyStatus = newSwitchKeyStatus;
        __sync_synchronize();
        [self fillData];
        PHTV_LIVE_LOG(@"applied SwitchKeyStatus from defaults: 0x%X", vSwitchKeyStatus);
    }

    // Apply typing/system settings only when relevant defaults changed.
    const NSUInteger settingsToken = PHTVComputeSettingsToken(defaults);
    if (settingsToken == self.lastSettingsChangeToken) {
        return;
    }
    [self handleSettingsChanged:nil];
}


@end
