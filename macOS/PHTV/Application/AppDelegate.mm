//
//  AppDelegate.m
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import <Carbon/Carbon.h>
#import <Cocoa/Cocoa.h>
#include <stdlib.h>
#include <string.h>
#import "AppDelegate.h"
#import "AppDelegate+Private.h"
#import "AppDelegate+Accessibility.h"
#import "AppDelegate+AppMonitoring.h"
#import "AppDelegate+DockVisibility.h"
#import "AppDelegate+InputState.h"
#import "AppDelegate+InputSourceMonitoring.h"
#import "AppDelegate+LoginItem.h"
#import "AppDelegate+PermissionFlow.h"
#import "AppDelegate+SettingsActions.h"
#import "AppDelegate+Sparkle.h"
#import "SparkleManager.h"
#import "../SystemBridge/PHTVManager.h"
#import "PHTV-Swift.h"
#include "../Core/Engine/Engine.h"

static NSString *const PHTVDefaultsKeyEnableEmojiHotkey = @"vEnableEmojiHotkey";
static NSString *const PHTVDefaultsKeyEmojiHotkeyModifiers = @"vEmojiHotkeyModifiers";
static NSString *const PHTVDefaultsKeyEmojiHotkeyKeyCode = @"vEmojiHotkeyKeyCode";
static NSString *const PHTVDefaultsKeyLiveDebug = @"PHTV_LIVE_DEBUG";
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
static NSString *const PHTVDefaultsKeyMacroList = @"macroList";
static NSString *const PHTVDefaultsKeyMacroListCorruptedBackup = @"macroList.corruptedBackup";
static NSString *const PHTVDefaultsKeyMacroData = @"macroData";
static NSString *const PHTVDefaultsKeyCustomDictionary = @"customDictionary";
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
static NSString *const PHTVNotificationSettingsResetComplete = @"SettingsResetComplete";
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

static inline void PHTVSetIntegerDefault(NSUserDefaults *defaults, NSInteger value, NSString *key) {
    [defaults setInteger:value forKey:key];
}

static inline void PHTVSetIntDefault(NSUserDefaults *defaults,
                                     volatile int *target,
                                     int value,
                                     NSString *key) {
    *target = value;
    PHTVSetIntegerDefault(defaults, value, key);
}

static inline void PHTVSetIntDefault(NSUserDefaults *defaults,
                                     int *target,
                                     int value,
                                     NSString *key) {
    *target = value;
    PHTVSetIntegerDefault(defaults, value, key);
}

static inline void PHTVSetBoolDefault(NSUserDefaults *defaults, BOOL value, NSString *key) {
    [defaults setBool:value forKey:key];
}

static inline void PHTVSetDoubleDefault(NSUserDefaults *defaults, double value, NSString *key) {
    [defaults setDouble:value forKey:key];
}

static inline void PHTVAppendHotkeyComponent(NSMutableString *hotKey,
                                             BOOL *hasComponent,
                                             NSString *component) {
    if (*hasComponent) {
        [hotKey appendString:@" + "];
    }
    [hotKey appendString:component];
    *hasComponent = YES;
}

static inline NSString *PHTVHotkeyKeyDisplayLabel(unsigned short keyCode) {
    if (keyCode == kVK_Space || keyCode == KEY_SPACE) {
        return @"␣";
    }

    const Uint16 keyChar = keyCodeToCharacter(static_cast<Uint32>(keyCode) | CAPS_MASK);
    if (keyChar >= 33 && keyChar <= 126) {
        const unichar displayChar = (unichar)keyChar;
        return [NSString stringWithCharacters:&displayChar length:1];
    }

    return [NSString stringWithFormat:@"KEY_%hu", keyCode];
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
    id stored = [[NSUserDefaults standardUserDefaults] objectForKey:PHTVDefaultsKeyLiveDebug];
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

@implementation AppDelegate {
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
    
    NSMenuItem* mnuSpellCheck;
    NSMenuItem* mnuAllowConsonantZFWJ;
    NSMenuItem* mnuModernOrthography;
    NSMenuItem* mnuQuickTelex;
    NSMenuItem* mnuUpperCaseFirstChar;
    NSMenuItem* mnuAutoRestoreEnglishWord;
}

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


- (void)syncMacrosFromUserDefaultsResetSession:(BOOL)resetSession {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSData *macroListData = [defaults dataForKey:PHTVDefaultsKeyMacroList];

    if (macroListData && macroListData.length > 0) {
        NSError *error = nil;
        NSArray *macros = [NSJSONSerialization JSONObjectWithData:macroListData
                                                         options:NSJSONReadingMutableContainers
                                                           error:&error];
        if (error || ![macros isKindOfClass:[NSArray class]]) {
            NSLog(@"[AppDelegate] ERROR: Failed to parse macroList: %@", error);
            [defaults setObject:macroListData forKey:PHTVDefaultsKeyMacroListCorruptedBackup];
            [defaults removeObjectForKey:PHTVDefaultsKeyMacroList];
            [defaults removeObjectForKey:PHTVDefaultsKeyMacroData];

            uint16_t macroCount = 0;
            NSMutableData *emptyData = [NSMutableData data];
            [emptyData appendBytes:&macroCount length:2];
            initMacroMap((const unsigned char *)[emptyData bytes], (int)[emptyData length]);
            PHTV_LIVE_LOG(@"macroList parse failed, backed up to %@ and reset", PHTVDefaultsKeyMacroListCorruptedBackup);

            if (resetSession) {
                RequestNewSession();
            }
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

        [defaults setObject:binaryData forKey:PHTVDefaultsKeyMacroData];

        initMacroMap((const unsigned char *)[binaryData bytes], (int)[binaryData length]);
        PHTV_LIVE_LOG(@"macros synced: count=%u", macroCount);
    } else {
        [defaults removeObjectForKey:PHTVDefaultsKeyMacroData];

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

    // CRITICAL FIX: Load spell check setting NOW (before event tap starts)
    // Problem: First keystroke may happen before vCheckSpelling is loaded from UserDefaults
    // This causes English word detection to skip spell check on first attempt
    // Solution: Ensure vCheckSpelling is set IMMEDIATELY after dictionary loads
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    vCheckSpelling = PHTVReadIntWithFallback(defaults, PHTVDefaultsKeySpelling, 1);
    NSLog(@"[EnglishWordDetector] Spell check enabled: %d", vCheckSpelling);
}

- (void)syncCustomDictionaryFromUserDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSData *customDictData = [defaults dataForKey:PHTVDefaultsKeyCustomDictionary];

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

- (void)handleSettingsReset:(NSNotification *)notification {
    // Settings have been reset, post confirmation to UI
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:PHTVNotificationSettingsResetComplete object:nil];
        
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
    menuInputType.enabled = YES;
    [self.statusMenu addItem:menuInputType];
    
    // === CODE TABLE HEADER ===
    NSMenuItem* menuCode = [[NSMenuItem alloc] initWithTitle:@"Bảng mã" 
                                                      action:nil 
                                               keyEquivalent:@""];
    menuCode.enabled = YES;
    [self.statusMenu addItem:menuCode];
    
    // === TYPING OPTIONS HEADER ===
    NSMenuItem* menuOptions = [[NSMenuItem alloc] initWithTitle:@"Tùy chọn gõ" 
                                                         action:nil 
                                                  keyEquivalent:@""];
    menuOptions.enabled = YES;
    [self.statusMenu addItem:menuOptions];
    
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
    [self setOptionsMenu:menuOptions];
    
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
    NSMutableString *hotKey = [NSMutableString string];
    BOOL hasComponent = NO;
    const int quickConvertHotkey = gConvertToolOptions.hotKey;

    if (HAS_CONTROL(quickConvertHotkey)) {
        PHTVAppendHotkeyComponent(hotKey, &hasComponent, @"⌃");
    }
    if (HAS_OPTION(quickConvertHotkey)) {
        PHTVAppendHotkeyComponent(hotKey, &hasComponent, @"⌥");
    }
    if (HAS_COMMAND(quickConvertHotkey)) {
        PHTVAppendHotkeyComponent(hotKey, &hasComponent, @"⌘");
    }
    if (HAS_SHIFT(quickConvertHotkey)) {
        PHTVAppendHotkeyComponent(hotKey, &hasComponent, @"⇧");
    }

    if (HOTKEY_HAS_KEY(quickConvertHotkey)) {
        const unsigned short keyCode = (unsigned short)GET_SWITCH_KEY(quickConvertHotkey);
        PHTVAppendHotkeyComponent(hotKey, &hasComponent, PHTVHotkeyKeyDisplayLabel(keyCode));
    }

    [mnuQuickConvert setTitle:hasComponent
                             ? [NSString stringWithFormat:@"Chuyển mã nhanh - [%@]", [hotKey uppercaseString]]
                             : @"Chuyển mã nhanh"];
}

-(void)loadDefaultConfig {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    PHTVSetIntDefault(defaults, &vLanguage, 1, PHTVDefaultsKeyInputMethod);
    PHTVSetIntDefault(defaults, &vInputType, 0, PHTVDefaultsKeyInputType);
    PHTVSetIntDefault(defaults, &vFreeMark, 0, @"FreeMark");
    PHTVSetIntDefault(defaults, &vCheckSpelling, 1, PHTVDefaultsKeySpelling);
    PHTVSetIntDefault(defaults, &vCodeTable, 0, PHTVDefaultsKeyCodeTable);
    PHTVSetIntDefault(defaults, &vSwitchKeyStatus, PHTV_DEFAULT_SWITCH_HOTKEY_STATUS, PHTVDefaultsKeySwitchKeyStatus);
    PHTVSetIntDefault(defaults, &vQuickTelex, 0, PHTVDefaultsKeyQuickTelex);
    PHTVSetIntDefault(defaults, &vUseModernOrthography, 1, PHTVDefaultsKeyModernOrthography);
    PHTVSetIntDefault(defaults, &vFixRecommendBrowser, 1, @"FixRecommendBrowser");
    PHTVSetIntDefault(defaults, &vUseMacro, 1, @"UseMacro");
    PHTVSetIntDefault(defaults, &vUseMacroInEnglishMode, 0, @"UseMacroInEnglishMode");
    PHTVSetIntDefault(defaults, &vSendKeyStepByStep, 0, PHTVDefaultsKeySendKeyStepByStep);
    PHTVSetIntDefault(defaults, &vUseSmartSwitchKey, 1, @"UseSmartSwitchKey");
    PHTVSetIntDefault(defaults, &vUpperCaseFirstChar, 0, PHTVDefaultsKeyUpperCaseFirstChar);
    PHTVSetIntDefault(defaults, &vTempOffSpelling, 0, @"vTempOffSpelling");
    PHTVSetIntDefault(defaults, &vAllowConsonantZFWJ, 1, PHTVDefaultsKeyAllowConsonantZFWJ); // Always enabled
    PHTVSetIntDefault(defaults, &vQuickStartConsonant, 0, @"vQuickStartConsonant");
    PHTVSetIntDefault(defaults, &vQuickEndConsonant, 0, @"vQuickEndConsonant");
    PHTVSetIntDefault(defaults, &vRememberCode, 1, @"vRememberCode");
    PHTVSetIntDefault(defaults, &vOtherLanguage, 1, @"vOtherLanguage");
    PHTVSetIntDefault(defaults, &vTempOffPHTV, 0, @"vTempOffPHTV");

    // Auto restore English words - default: ON for new users
    PHTVSetIntDefault(defaults, &vAutoRestoreEnglishWord, 1, PHTVDefaultsKeyAutoRestoreEnglishWord);

    // Restore to raw keys (customizable key) - default: ON with ESC key
    PHTVSetIntDefault(defaults, &vRestoreOnEscape, 1, @"vRestoreOnEscape");
    PHTVSetIntDefault(defaults, &vCustomEscapeKey, 0, @"vCustomEscapeKey");

    PHTVSetIntDefault(defaults, &vShowIconOnDock, 0, PHTVDefaultsKeyShowIconOnDock);
    PHTVSetIntDefault(defaults, &vPerformLayoutCompat, 0, @"vPerformLayoutCompat");

    PHTVSetIntegerDefault(defaults, 1, @"GrayIcon");
    PHTVSetBoolDefault(defaults, NO, PHTVDefaultsKeyRunOnStartupLegacy);
    PHTVSetIntegerDefault(defaults, 0, PHTVDefaultsKeyRunOnStartup);
    PHTVSetIntegerDefault(defaults, 1, @"vSettingsWindowAlwaysOnTop");
    PHTVSetIntegerDefault(defaults, 0, @"vBeepOnModeSwitch");
    PHTVSetDoubleDefault(defaults, 0.5, @"vBeepVolume");
    PHTVSetDoubleDefault(defaults, 18.0, @"vMenuBarIconSize");
    PHTVSetIntegerDefault(defaults, 0, @"vUseVietnameseMenubarIcon");

    PHTVSetIntegerDefault(defaults, 86400, @"SUScheduledCheckInterval");
    PHTVSetBoolDefault(defaults, YES, @"vAutoInstallUpdates");

    PHTVSetBoolDefault(defaults, YES, @"vIncludeSystemInfo");
    PHTVSetBoolDefault(defaults, NO, @"vIncludeLogs");
    PHTVSetBoolDefault(defaults, YES, @"vIncludeCrashLogs");

    // IMPORTANT: DO NOT reset macroList/macroData here!
    // User's custom abbreviations should be preserved when resetting other settings.
    // If user wants to clear macros, they can do it from the Macro Settings UI.


    [self fillData];
}

-(void)setGrayIcon:(BOOL)val {
    [self fillData];
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
    
    mnuUnicode = [[NSMenuItem alloc] initWithTitle:@"Unicode dựng sẵn" action:@selector(onCodeSelected:) keyEquivalent:@""];
    mnuUnicode.target = self;
    mnuUnicode.tag = 0;
    [sub addItem:mnuUnicode];
    
    mnuTCVN = [[NSMenuItem alloc] initWithTitle:@"TCVN3 (ABC)" action:@selector(onCodeSelected:) keyEquivalent:@""];
    mnuTCVN.target = self;
    mnuTCVN.tag = 1;
    [sub addItem:mnuTCVN];
    
    mnuVNIWindows = [[NSMenuItem alloc] initWithTitle:@"VNI Windows" action:@selector(onCodeSelected:) keyEquivalent:@""];
    mnuVNIWindows.target = self;
    mnuVNIWindows.tag = 2;
    [sub addItem:mnuVNIWindows];
    
    mnuUnicodeComposite = [[NSMenuItem alloc] initWithTitle:@"Unicode tổ hợp" action:@selector(onCodeSelected:) keyEquivalent:@""];
    mnuUnicodeComposite.target = self;
    mnuUnicodeComposite.tag = 3;
    [sub addItem:mnuUnicodeComposite];
    
    mnuVietnameseLocaleCP1258 = [[NSMenuItem alloc] initWithTitle:@"Vietnamese Locale CP 1258" action:@selector(onCodeSelected:) keyEquivalent:@""];
    mnuVietnameseLocaleCP1258.target = self;
    mnuVietnameseLocaleCP1258.tag = 4;
    [sub addItem:mnuVietnameseLocaleCP1258];
}

- (void)setOptionsMenu:(NSMenuItem*) parent {
    if (!parent.submenu) {
        NSMenu *sub = [[NSMenu alloc] init];
        sub.autoenablesItems = NO;
        parent.submenu = sub;
    }
    
    NSMenu *sub = parent.submenu;
    [sub removeAllItems];
    
    mnuSpellCheck = [[NSMenuItem alloc] initWithTitle:@"Kiểm tra chính tả" action:@selector(toggleSpellCheck:) keyEquivalent:@""];
    mnuSpellCheck.target = self;
    [sub addItem:mnuSpellCheck];
    
    mnuModernOrthography = [[NSMenuItem alloc] initWithTitle:@"Chính tả mới (oà, uý)" action:@selector(toggleModernOrthography:) keyEquivalent:@""];
    mnuModernOrthography.target = self;
    [sub addItem:mnuModernOrthography];
    
    [sub addItem:[NSMenuItem separatorItem]];
    
    mnuQuickTelex = [[NSMenuItem alloc] initWithTitle:@"Gõ nhanh Telex" action:@selector(toggleQuickTelex:) keyEquivalent:@""];
    mnuQuickTelex.target = self;
    [sub addItem:mnuQuickTelex];
    
    mnuAllowConsonantZFWJ = [[NSMenuItem alloc] initWithTitle:@"Phụ âm Z, F, W, J" action:@selector(toggleAllowConsonantZFWJ:) keyEquivalent:@""];
    mnuAllowConsonantZFWJ.target = self;
    [sub addItem:mnuAllowConsonantZFWJ];
    
    [sub addItem:[NSMenuItem separatorItem]];
    
    mnuUpperCaseFirstChar = [[NSMenuItem alloc] initWithTitle:@"Viết hoa đầu câu" action:@selector(toggleUpperCaseFirstChar:) keyEquivalent:@""];
    mnuUpperCaseFirstChar.target = self;
    [sub addItem:mnuUpperCaseFirstChar];
    
    mnuAutoRestoreEnglishWord = [[NSMenuItem alloc] initWithTitle:@"Tự động khôi phục tiếng Anh" action:@selector(toggleAutoRestoreEnglishWord:) keyEquivalent:@""];
    mnuAutoRestoreEnglishWord.target = self;
    [sub addItem:mnuAutoRestoreEnglishWord];
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

    // Update typing features state
    [mnuSpellCheck setState:vCheckSpelling ? NSControlStateValueOn : NSControlStateValueOff];
    [mnuModernOrthography setState:vUseModernOrthography ? NSControlStateValueOn : NSControlStateValueOff];
    [mnuQuickTelex setState:vQuickTelex ? NSControlStateValueOn : NSControlStateValueOff];
    [mnuAllowConsonantZFWJ setState:vAllowConsonantZFWJ ? NSControlStateValueOn : NSControlStateValueOff];
    [mnuUpperCaseFirstChar setState:vUpperCaseFirstChar ? NSControlStateValueOn : NSControlStateValueOff];
    [mnuAutoRestoreEnglishWord setState:vAutoRestoreEnglishWord ? NSControlStateValueOn : NSControlStateValueOff];
}

#pragma mark -StatusBar menu action

-(void)onQuickConvert {
    if ([PHTVManager quickConvert]) {
        if (!gConvertToolOptions.dontAlertWhenCompleted) {
            [PHTVManager showMessage: nil message:@"Chuyển mã thành công!" subMsg:@"Kết quả đã được lưu trong clipboard."];
        }
    } else {
        [PHTVManager showMessage: nil message:@"Không có dữ liệu trong clipboard!" subMsg:@"Hãy sao chép một đoạn text để chuyển đổi!"];
    }
}

-(void)onEmojiHotkeyTriggered {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            [EmojiHotkeyBridge openEmojiPicker];
        } @catch (NSException *exception) {
            NSLog(@"[EmojiHotkey] failed to open picker: %@", exception);
        }
    });
}

// MARK: - UI Actions (SwiftUI Integration)
// Old Storyboard-based window methods - replaced with SwiftUI
// Kept for backward compatibility during transition

-(void) onControlPanelSelected {
    // Show dock icon when opening settings
    [self setDockIconVisible:YES];

    // Mark that user has opened settings, so defaults won't overwrite their changes
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults integerForKey:PHTVDefaultsKeyNonFirstTime] == 0) {
        [defaults setInteger:1 forKey:PHTVDefaultsKeyNonFirstTime];
        NSLog(@"Marking NonFirstTime after user opened settings");
    }

    // Post notification - SettingsWindowManager in Swift will handle it
    NSLog(@"[AppDelegate] Posting ShowSettings notification");
    [[NSNotificationCenter defaultCenter] postNotificationName:PHTVNotificationShowSettings object:nil];
}

-(void) onMacroSelected {
    // Show SwiftUI Macro tab
    [[NSNotificationCenter defaultCenter] postNotificationName:PHTVNotificationShowMacroTab object:nil];
}

-(void) onAboutSelected {
    // Show SwiftUI About tab
    [[NSNotificationCenter defaultCenter] postNotificationName:PHTVNotificationShowAboutTab object:nil];
}

#pragma mark -Short key event
-(void)onSwitchLanguage {
    [self onInputMethodSelected];
}
@end
