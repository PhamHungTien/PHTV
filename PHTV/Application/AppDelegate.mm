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
#import "AppDelegate.h"
#import "../Managers/PHTVManager.h"
#import "../Utils/MJAccessibilityUtils.h"
#import "../Utils/UsageStats.h"
#import "PHTV-Swift.h"

AppDelegate* appDelegate;
extern "C" {
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
int vCheckSpelling = 1;
int vUseModernOrthography = 1;
int vQuickTelex = 0;
// Default: Ctrl + Shift (no key, modifier only)
// Format: bits 0-7 = keycode (0xFE = no key), bit 8 = Control, bit 11 = Shift
#define DEFAULT_SWITCH_STATUS 0x9FE // Ctrl(0x100) + Shift(0x800) + NoKey(0xFE)
int vSwitchKeyStatus = DEFAULT_SWITCH_STATUS;
int vRestoreIfWrongSpelling = 0;
int vFixRecommendBrowser = 1;
int vUseMacro = 1;
int vUseMacroInEnglishMode = 1;
int vAutoCapsMacro = 0;
int vSendKeyStepByStep = 0;
int vUseSmartSwitchKey = 1;
int vUpperCaseFirstChar = 0;
int vTempOffSpelling = 0;
int vAllowConsonantZFWJ = 0;
int vQuickStartConsonant = 0;
int vQuickEndConsonant = 0;
int vRememberCode = 1; //new on version 2.0
int vOtherLanguage = 1; //new on version 2.0
int vTempOffPHTV = 0; //new on version 2.0

int vShowIconOnDock = 0; //new on version 2.0

int vPerformLayoutCompat = 0;

//beta feature
int vFixChromiumBrowser = 0; //new on version 2.0

extern int convertToolHotKey;
extern bool convertToolDontAlertWhenCompleted;

@interface AppDelegate ()
@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) NSMenu *statusMenu;

// Performance optimization properties
@property (nonatomic, strong) dispatch_queue_t updateQueue;
@property (nonatomic, assign) NSInteger lastInputMethod;
@property (nonatomic, assign) NSInteger lastCodeTable;
@property (nonatomic, assign) BOOL isUpdatingUI;

// Accessibility monitoring
@property (nonatomic, strong) NSTimer *accessibilityMonitor;
@property (nonatomic, assign) BOOL wasAccessibilityEnabled;
@end


@implementation AppDelegate {
    // Excluded app state management
    NSInteger _savedLanguageBeforeExclusion;  // Saved language state before entering excluded app
    NSString* _previousBundleIdentifier;       // Track the previous app's bundle ID
    BOOL _isInExcludedApp;                     // Flag to track if currently in an excluded app

    // Re-entry guards to prevent notification ping-pong (performance optimization)
    BOOL _isUpdatingLanguage;
    BOOL _isUpdatingInputType;
    BOOL _isUpdatingCodeTable;

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
}

-(void)askPermission {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText: [NSString stringWithFormat:@"PHTV cần bạn cấp quyền để có thể hoạt động!"]];
    [alert setInformativeText:@"Ứng dụng sẽ tự động khởi động lại sau khi bạn cấp quyền."];

    [alert addButtonWithTitle:@"Không"];
    [alert addButtonWithTitle:@"Cấp quyền"];

    [alert.window makeKeyAndOrderFront:nil];
    [alert.window setLevel:NSStatusWindowLevel];

    NSModalResponse res = [alert runModal];

    if (res == 1001) {
        MJAccessibilityOpenPanel();
    } else {
        [NSApp terminate:0];
    }
}

- (void)startAccessibilityMonitoring {
    // Monitor accessibility status less frequently (every 3 seconds instead of 2)
    // This reduces CPU usage while still detecting permission changes
    self.accessibilityMonitor = [NSTimer scheduledTimerWithTimeInterval:3.0
                                                                  target:self
                                                                selector:@selector(checkAccessibilityStatus)
                                                                userInfo:nil
                                                                 repeats:YES];
    
    // Set initial state
    self.wasAccessibilityEnabled = MJAccessibilityIsEnabled();
    
    #ifdef DEBUG
    NSLog(@"[Accessibility] Started monitoring (interval: 3s)");
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

- (void)checkAccessibilityStatus {
    BOOL isEnabled = MJAccessibilityIsEnabled();
    
    // Always notify SwiftUI about current status
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AccessibilityStatusChanged"
                                                        object:@(isEnabled)];
    
    // Permission was just granted (transition from disabled to enabled)
    if (!self.wasAccessibilityEnabled && isEnabled) {
        NSLog(@"[Accessibility] Permission GRANTED - Restarting app...");
        [self performAccessibilityGrantedRestart];
    }
    // Permission was revoked while app is running (transition from enabled to disabled)
    else if (self.wasAccessibilityEnabled && !isEnabled) {
        NSLog(@"[Accessibility] CRITICAL - Permission REVOKED while running!");
        [self handleAccessibilityRevoked];
    }
    
    // Update state
    self.wasAccessibilityEnabled = isEnabled;
}

- (void)performAccessibilityGrantedRestart {
    NSLog(@"[Accessibility] Permission granted - Initializing event tap...");
    
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
            
            // Update menu bar to normal state
            [self fillDataWithAnimation:YES];
            
            // Show UI if requested
            NSInteger showui = [[NSUserDefaults standardUserDefaults] integerForKey:@"ShowUIOnStartup"];
            if (showui == 1) {
                [self onControlPanelSelected];
            }
        }
        [self setQuickConvertString];
    });
}

- (void)handleAccessibilityRevoked {
    // CRITICAL: Stop event tap immediately to prevent system freeze
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        if ([PHTVManager isInited]) {
            NSLog(@"🛑 Stopping event tap to prevent system freeze...");
            [PHTVManager stopEventTap];
        }
    });
    
    // Show alert on main thread
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
    if (MJAccessibilityIsEnabled()) {
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

    // Initialize re-entry guards
    _isUpdatingLanguage = NO;
    _isUpdatingInputType = NO;
    _isUpdatingCodeTable = NO;

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
    
    if (vSwitchKeyStatus & 0x8000) {
        // Delay beep to ensure it's played after app initialization
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSBeep();
        });
    }

    // Initialize SwiftUI integration
    [self setupSwiftUIBridge];
    
    // Load existing macros from UserDefaults to binary format (macroData)
    [self loadExistingMacros];
    
    // Observe Dark Mode changes
    [self observeAppearanceChanges];
    
    // check if user granted Accessabilty permission
    if (!MJAccessibilityIsEnabled()) {
        [self askPermission];
        [self startAccessibilityMonitoring];
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
            
            NSInteger showui = [[NSUserDefaults standardUserDefaults] integerForKey:@"ShowUIOnStartup"];
            if (showui == 1) {
                // Show settings via SwiftUI notification
                [[NSNotificationCenter defaultCenter] postNotificationName:@"ShowSettings" object:nil];
            }
        }
        [self setQuickConvertString];
    });
    
    //load default config if is first launch
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"NonFirstTime"] == 0) {
        [self loadDefaultConfig];
    }
    [[NSUserDefaults standardUserDefaults] setInteger:1 forKey:@"NonFirstTime"];
    
    //correct run on startup
    NSInteger val = [[NSUserDefaults standardUserDefaults] integerForKey:@"RunOnStartup"];
    [appDelegate setRunOnStartup:val];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    [self onControlPanelSelected];
    return YES;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

#pragma mark - SwiftUI Bridge

- (void)setupSwiftUIBridge {
    // AppState loads its own settings from UserDefaults in init()
    // No need to sync here - both backend and SwiftUI read from same source
    // [self syncStateToSwiftUI];  // Removed to prevent race conditions

    // Setup notification observers for SwiftUI integration
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onShowSettings:)
                                                 name:@"ShowSettings"
                                               object:nil];
    
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
                                             selector:@selector(handleCheckForUpdates:)
                                                 name:@"CheckForUpdates"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleSettingsReset:)
                                                 name:@"SettingsReset"
                                               object:nil];
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
    // Reload settings from UserDefaults when SwiftUI changes them
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    vCheckSpelling = (int)[defaults integerForKey:@"Spelling"];
    vUseModernOrthography = (int)[defaults integerForKey:@"ModernOrthography"];
    vQuickTelex = (int)[defaults integerForKey:@"QuickTelex"];
    vUseMacro = (int)[defaults integerForKey:@"UseMacro"];
    vUseMacroInEnglishMode = (int)[defaults integerForKey:@"UseMacroInEnglishMode"];
    vAutoCapsMacro = (int)[defaults integerForKey:@"vAutoCapsMacro"];
    vUseSmartSwitchKey = (int)[defaults integerForKey:@"UseSmartSwitchKey"];
    vUpperCaseFirstChar = (int)[defaults integerForKey:@"UpperCaseFirstChar"];
    vAllowConsonantZFWJ = (int)[defaults integerForKey:@"vAllowConsonantZFWJ"];
    vQuickStartConsonant = (int)[defaults integerForKey:@"vQuickStartConsonant"];
    vQuickEndConsonant = (int)[defaults integerForKey:@"vQuickEndConsonant"];
    vRememberCode = (int)[defaults integerForKey:@"vRememberCode"];
    vFixChromiumBrowser = (int)[defaults integerForKey:@"vFixChromiumBrowser"];
    vPerformLayoutCompat = (int)[defaults integerForKey:@"vPerformLayoutCompat"];
    vShowIconOnDock = (int)[defaults integerForKey:@"vShowIconOnDock"];
    
    // Memory barrier to ensure event tap thread sees new values immediately
    __sync_synchronize();
    
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
    
    // Get AppState from Swift at runtime
    // Using dynamic lookup to avoid needing to import generated Swift header
    Class appStateClass = NSClassFromString(@"PHTV.AppState");
    if (!appStateClass) {
        NSLog(@"Warning: AppState class not found");
        return;
    }
    
    // Get shared instance
    id appState = [appStateClass performSelector:@selector(shared)];
    if (!appState) {
        NSLog(@"Warning: AppState.shared not found");
        return;
    }
    
    // Use KVC to set properties (safer than direct Objective-C calls to Swift classes)
    [appState setValue:@(vCheckSpelling == 1) forKey:@"checkSpelling"];
    [appState setValue:@(vUseModernOrthography == 1) forKey:@"useModernOrthography"];
    [appState setValue:@(vQuickTelex == 1) forKey:@"quickTelex"];
    [appState setValue:@(vUseMacro == 1) forKey:@"useMacro"];
    [appState setValue:@(vUseMacroInEnglishMode == 1) forKey:@"useMacroInEnglishMode"];
    [appState setValue:@(vAutoCapsMacro == 1) forKey:@"autoCapsMacro"];
    [appState setValue:@(vUseSmartSwitchKey == 1) forKey:@"useSmartSwitchKey"];
    [appState setValue:@(vUpperCaseFirstChar == 1) forKey:@"upperCaseFirstChar"];
    [appState setValue:@(vAllowConsonantZFWJ == 1) forKey:@"allowConsonantZFWJ"];
    [appState setValue:@(vQuickStartConsonant == 1) forKey:@"quickStartConsonant"];
    [appState setValue:@(vQuickEndConsonant == 1) forKey:@"quickEndConsonant"];
    [appState setValue:@(vRememberCode == 1) forKey:@"rememberCode"];
    [appState setValue:@(vShowIconOnDock == 1) forKey:@"showIconOnDock"];
    [appState setValue:@(vFixChromiumBrowser == 1) forKey:@"fixChromiumBrowser"];
    [appState setValue:@(vPerformLayoutCompat == 1) forKey:@"performLayoutCompat"];
    [appState setValue:@(vTempOffPHTV == 0) forKey:@"isEnabled"];
}

- (void)handleMacrosUpdated:(NSNotification *)notification {
    // Reload macros from UserDefaults and rebuild macro map
    NSLog(@"========================================");
    NSLog(@"[AppDelegate] handleMacrosUpdated CALLED!");
    NSLog(@"========================================");
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSData *macroListData = [defaults dataForKey:@"macroList"];
    
    NSLog(@"[AppDelegate] Reading from UserDefaults...");
    NSLog(@"[AppDelegate] macroList exists: %@", macroListData ? @"YES" : @"NO");
    if (macroListData) {
        NSLog(@"[AppDelegate] macroList size: %ld bytes", (long)[macroListData length]);
    }
    
    if (macroListData && macroListData.length > 0) {
        // Parse JSON and convert to binary format for C++ engine
        NSError *error = nil;
        NSMutableArray *macros = [NSJSONSerialization JSONObjectWithData:macroListData 
                                                                   options:NSJSONReadingMutableContainers 
                                                                     error:&error];
        
        if (error || !macros) {
            NSLog(@"[AppDelegate] ERROR: Failed to parse macro list: %@", error);
            return;
        }
        
        NSLog(@"[AppDelegate] Converting %lu macros to binary format", (unsigned long)[macros count]);
        
        // Convert JSON macros to binary format and save
        NSMutableData *binaryData = [NSMutableData data];
        uint16_t macroCount = (uint16_t)[macros count];
        [binaryData appendBytes:&macroCount length:2];
        
        NSLog(@"[AppDelegate] Binary header: count=%u (2 bytes)", macroCount);
        
        for (NSDictionary *macro in macros) {
            NSString *shortcut = macro[@"shortcut"] ?: @"";
            NSString *expansion = macro[@"expansion"] ?: @"";
            
            NSLog(@"  - Adding macro: '%@' -> '%@'", shortcut, expansion);
            
            uint8_t shortcutLen = (uint8_t)[shortcut lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
            [binaryData appendBytes:&shortcutLen length:1];
            [binaryData appendData:[shortcut dataUsingEncoding:NSUTF8StringEncoding]];
            
            uint16_t expansionLen = (uint16_t)[expansion lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
            [binaryData appendBytes:&expansionLen length:2];
            [binaryData appendData:[expansion dataUsingEncoding:NSUTF8StringEncoding]];
            
            NSLog(@"    Encoded: shortcut_len=%u, expansion_len=%u", shortcutLen, expansionLen);
        }
        
        // Save to "macroData" for C++ engine to load
        [defaults setObject:binaryData forKey:@"macroData"];
        [defaults synchronize];
        
        NSLog(@"[AppDelegate] Saved binary data: %ld bytes to UserDefaults", (long)[binaryData length]);
        
        // Reload macro map in C++ engine
        NSLog(@"[AppDelegate] Calling initMacroMap(%ld bytes)...", (long)[binaryData length]);
        initMacroMap((const unsigned char*)[binaryData bytes], (int)[binaryData length]);
        NSLog(@"[AppDelegate] initMacroMap call completed");
        
        NSLog(@"[AppDelegate] Macros reloaded in C++ engine: %lu macros", (unsigned long)[macros count]);
    } else {
        // macroList is empty or missing - clear all macros
        NSLog(@"[AppDelegate] macroList is empty - clearing all macros");
        
        // Remove macroData to keep in sync with empty macroList
        [defaults removeObjectForKey:@"macroData"];
        [defaults synchronize];
        
        // Clear macros from C++ engine
        NSMutableData *emptyData = [NSMutableData data];
        uint16_t macroCount = 0;
        [emptyData appendBytes:&macroCount length:2];
        NSLog(@"[AppDelegate] Calling initMacroMap with empty data (0 bytes)...");
        initMacroMap((const unsigned char*)[emptyData bytes], (int)[emptyData length]);
        NSLog(@"[AppDelegate] initMacroMap call completed");
        
        NSLog(@"[AppDelegate] Cleared all macros from C++ engine");
    }
}

- (void)loadExistingMacros {
    // On app startup, load macros from macroList (the source of truth)
    // Always convert macroList to binary macroData to ensure they stay in sync
    NSLog(@"========================================");
    NSLog(@"[AppDelegate.loadExistingMacros] STARTUP MACRO LOADING");
    NSLog(@"========================================");
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSData *macroListData = [defaults dataForKey:@"macroList"];
    
    NSLog(@"[AppDelegate.loadExistingMacros] Startup check: macroList=%@", 
          macroListData ? @"exists" : @"missing");
    if (macroListData) {
        NSLog(@"[AppDelegate.loadExistingMacros] macroList size: %ld bytes", (long)[macroListData length]);
    }
    
    // Always process macroList if it exists
    if (macroListData) {
        NSLog(@"[AppDelegate.loadExistingMacros] Converting macroList (%ld bytes) to macroData...", (long)[macroListData length]);
        
        // Parse JSON directly and convert to binary format
        NSError *error = nil;
        NSMutableArray *macros = [NSJSONSerialization JSONObjectWithData:macroListData 
                                                                   options:NSJSONReadingMutableContainers 
                                                                     error:&error];
        
        if (error || !macros) {
            NSLog(@"[AppDelegate.loadExistingMacros] ERROR: Failed to parse macro list on startup: %@", error);
            return;
        }
        
        NSLog(@"[AppDelegate.loadExistingMacros] Found %lu macros in macroList", (unsigned long)[macros count]);
        
        // Convert JSON macros to binary format and save
        NSMutableData *binaryData = [NSMutableData data];
        uint16_t macroCount = (uint16_t)[macros count];
        [binaryData appendBytes:&macroCount length:2];
        
        for (NSDictionary *macro in macros) {
            NSString *shortcut = macro[@"shortcut"] ?: @"";
            NSString *expansion = macro[@"expansion"] ?: @"";
            
            NSLog(@"  - Converting: %@ -> %@", shortcut, expansion);
            
            uint8_t shortcutLen = (uint8_t)[shortcut lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
            [binaryData appendBytes:&shortcutLen length:1];
            [binaryData appendData:[shortcut dataUsingEncoding:NSUTF8StringEncoding]];
            
            uint16_t expansionLen = (uint16_t)[expansion lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
            [binaryData appendBytes:&expansionLen length:2];
            [binaryData appendData:[expansion dataUsingEncoding:NSUTF8StringEncoding]];
        }
        
        // Save to "macroData" for C++ engine to load
        [defaults setObject:binaryData forKey:@"macroData"];
        [defaults synchronize];
        
        NSLog(@"[AppDelegate.loadExistingMacros] Saved binary data: %ld bytes", (long)[binaryData length]);
        
        // Reload macro map in C++ engine
        initMacroMap((const unsigned char*)[binaryData bytes], (int)[binaryData length]);
        
        NSLog(@"[AppDelegate.loadExistingMacros] Macros converted and loaded: %lu macros", (unsigned long)[macros count]);
    } else {
        // No macroList exists - clear all macros in C++ engine
        NSLog(@"[AppDelegate.loadExistingMacros] No macroList found - clearing all macros");
        
        // Create empty binary data (just the count = 0)
        NSMutableData *emptyData = [NSMutableData data];
        uint16_t macroCount = 0;
        [emptyData appendBytes:&macroCount length:2];
        
        // Clear macroData from UserDefaults to keep them in sync
        [defaults removeObjectForKey:@"macroData"];
        [defaults synchronize];
        
        // Clear macros from C++ engine
        initMacroMap((const unsigned char*)[emptyData bytes], (int)[emptyData length]);
        
        NSLog(@"[AppDelegate.loadExistingMacros] Cleared all macros from C++ engine");
    }
}

- (void)handleCheckForUpdates:(NSNotification *)notification {
    // Check for updates from GitHub API
    NSString *currentVersion = [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
    
    NSLog(@"[Update Check] ========================================");
    NSLog(@"[Update Check] Starting update check...");
    NSLog(@"[Update Check] Current version: %@", currentVersion);
    
    // Fetch latest release from GitHub API
    NSURL *url = [NSURL URLWithString:@"https://api.github.com/repos/PhamHungTien/PHTV/releases/latest"];
    NSLog(@"[Update Check] Fetching from URL: %@", url);
    
    NSURLRequest *request = [NSURLRequest requestWithURL:url 
                                              cachePolicy:NSURLRequestReloadIgnoringLocalCacheData 
                                          timeoutInterval:15.0];
    
    // Create configuration to allow HTTP/HTTPS and ensure proper timeout
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = 15.0;
    config.timeoutIntervalForResource = 30.0;
    config.waitsForConnectivity = YES;
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    
    NSLog(@"[Update Check] Starting network request...");
    
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSLog(@"[Update Check] Network request completed");
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSDictionary *responseDict = nil;
            
            // Check HTTP response status
            if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                NSLog(@"[Update Check] HTTP Status Code: %ld", (long)httpResponse.statusCode);
                
                if (httpResponse.statusCode != 200) {
                    NSLog(@"[Update Check] ERROR: HTTP Status %ld", (long)httpResponse.statusCode);
                    responseDict = @{
                        @"message": [NSString stringWithFormat:@"Lỗi GitHub API (Status %ld)", (long)httpResponse.statusCode],
                        @"isError": @YES,
                        @"updateAvailable": @NO
                    };
                }
            }
            
            if (error) {
                NSLog(@"[Update Check] ERROR: Network request failed");
                NSLog(@"[Update Check] Error Code: %ld", (long)error.code);
                NSLog(@"[Update Check] Error Domain: %@", error.domain);
                NSLog(@"[Update Check] Error Description: %@", error.localizedDescription);
                NSLog(@"[Update Check] Error Details: %@", error.userInfo);
                
                // Distinguish between different error types
                NSString *errorMsg = @"Không thể kết nối để kiểm tra cập nhật";
                
                if (error.code == NSURLErrorTimedOut || error.code == NSURLErrorNetworkConnectionLost) {
                    errorMsg = @"Kết nối bị timeout. Vui lòng kiểm tra internet.";
                } else if (error.code == NSURLErrorNotConnectedToInternet) {
                    errorMsg = @"Không có kết nối internet";
                } else if (error.code == NSURLErrorDNSLookupFailed) {
                    errorMsg = @"Không thể kết nối DNS. Vui lòng kiểm tra internet.";
                }
                
                responseDict = @{
                    @"message": errorMsg,
                    @"isError": @YES,
                    @"updateAvailable": @NO
                };
            } else if (!data) {
                NSLog(@"[Update Check] ERROR: No data received from GitHub API");
                responseDict = @{
                    @"message": @"Lỗi: Không nhận được dữ liệu từ GitHub",
                    @"isError": @YES,
                    @"updateAvailable": @NO
                };
            } else if (!responseDict) {  // Only parse if no error encountered
                NSLog(@"[Update Check] Parsing JSON response (%lu bytes)...", (unsigned long)data.length);
                
                // Parse JSON response
                NSError *parseError = nil;
                NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
                
                if (parseError) {
                    NSLog(@"[Update Check] ERROR: Failed to parse GitHub response: %@", parseError);
                    responseDict = @{
                        @"message": @"Lỗi: Không thể phân tích phản hồi từ GitHub",
                        @"isError": @YES,
                        @"updateAvailable": @NO
                    };
                } else if (!jsonResponse || ![jsonResponse isKindOfClass:[NSDictionary class]]) {
                    NSLog(@"[Update Check] ERROR: Invalid GitHub response format");
                    NSLog(@"[Update Check] Response type: %@", NSStringFromClass([jsonResponse class]));
                    responseDict = @{
                        @"message": @"Lỗi: Phản hồi từ GitHub không hợp lệ",
                        @"isError": @YES,
                        @"updateAvailable": @NO
                    };
                } else if (jsonResponse[@"message"] && [jsonResponse[@"message"] isKindOfClass:[NSString class]]) {
                    // GitHub API error (e.g., rate limit)
                    NSLog(@"[Update Check] GitHub API Error: %@", jsonResponse[@"message"]);
                    responseDict = @{
                        @"message": [NSString stringWithFormat:@"Lỗi GitHub API: %@", jsonResponse[@"message"]],
                        @"isError": @YES,
                        @"updateAvailable": @NO
                    };
                } else {
                    // Extract version from tag_name (e.g., "v1.0.0" -> "1.0.0")
                    NSString *tagName = jsonResponse[@"tag_name"];
                    NSString *latestVersion = tagName;
                    
                    NSLog(@"[Update Check] Tag name from GitHub: %@", tagName);
                    
                    // Remove 'v' prefix if present
                    if ([latestVersion hasPrefix:@"v"]) {
                        latestVersion = [latestVersion substringFromIndex:1];
                    }
                    
                    NSLog(@"[Update Check] Latest version: %@", latestVersion);
                    
                    // Compare versions
                    NSComparisonResult comparison = [currentVersion compare:latestVersion options:NSNumericSearch];
                    NSLog(@"[Update Check] Version comparison result: %ld", (long)comparison);
                    
                    if (comparison == NSOrderedAscending) {
                        // Current version is older than latest
                        NSString *releaseNotes = jsonResponse[@"name"] ?: @"";
                        responseDict = @{
                            @"message": [NSString stringWithFormat:@"Phiên bản mới %@ có sẵn.\n\n%@", latestVersion, releaseNotes],
                            @"isError": @NO,
                            @"updateAvailable": @YES,
                            @"latestVersion": latestVersion,
                            @"downloadUrl": @"https://github.com/PhamHungTien/PHTV/releases/latest"
                        };
                        NSLog(@"[Update Check] Update available: %@", latestVersion);
                    } else {
                        // Current version is up to date
                        responseDict = @{
                            @"message": [NSString stringWithFormat:@"Phiên bản hiện tại (%@) là mới nhất", currentVersion],
                            @"isError": @NO,
                            @"updateAvailable": @NO
                        };
                        NSLog(@"[Update Check] App is up to date");
                    }
                }
            }
            
            NSLog(@"[Update Check] Posting response: %@", responseDict[@"message"]);
            NSLog(@"[Update Check] ========================================");
            
            // Post response notification
            [[NSNotificationCenter defaultCenter] postNotificationName:@"CheckForUpdatesResponse"
                                                                object:responseDict];
        });
    }];
    
    [dataTask resume];
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

- (void)onShowSettings:(NSNotification *)notification {
    [self onControlPanelSelected];
}

- (void)onShowMacroTab:(NSNotification *)notification {
    [self onControlPanelSelected];
}

- (void)onShowAboutTab:(NSNotification *)notification {
    [self onAboutSelected];
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
    vShowIconOnDock = 0; [defaults setInteger:vShowIconOnDock forKey:@"vShowIconOnDock"];
    vFixChromiumBrowser = 0; [defaults setInteger:vFixChromiumBrowser forKey:@"vFixChromiumBrowser"];
    vPerformLayoutCompat = 0; [defaults setInteger:vPerformLayoutCompat forKey:@"vPerformLayoutCompat"];

    [defaults setInteger:1 forKey:@"GrayIcon"];
    [defaults setInteger:1 forKey:@"RunOnStartup"];
    
    // Reset macro list to empty
    [defaults removeObjectForKey:@"macroList"];
    [defaults removeObjectForKey:@"macroData"];
    
    // Clear macro map in C++ engine
    initMacroMap((const unsigned char*)"", 0);
    
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
    if (!statusFont) {
        statusFont = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightSemibold];
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

    // 5. Notify engine (async is OK since state is reset) - only if RememberCode enabled
    if (vRememberCode) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            OnTableCodeChange();
        });
    }

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
    // Show SwiftUI Settings window via notification
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

            // Notify SwiftUI
            [[NSNotificationCenter defaultCenter] postNotificationName:@"LanguageChangedFromBackend" object:@(vLanguage)];
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

            // Notify SwiftUI
            [[NSNotificationCenter defaultCenter] postNotificationName:@"LanguageChangedFromBackend" object:@(vLanguage)];
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
}
@end
