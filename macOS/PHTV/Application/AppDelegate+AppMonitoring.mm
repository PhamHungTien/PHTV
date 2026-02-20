//
//  AppDelegate+AppMonitoring.mm
//  PHTV
//
//  Active-app monitoring and app-specific runtime behaviors extracted from AppDelegate.
//

#import "AppDelegate+AppMonitoring.h"
#import "AppDelegate+InputState.h"
#import "AppDelegate+MacroData.h"
#import "AppDelegate+Private.h"
#import "AppDelegate+Sparkle.h"
#import "AppDelegate+StatusBarMenu.h"
#import "../SystemBridge/PHTVManager.h"
#import "PHTV-Swift.h"

static NSString *const PHTVDefaultsKeyInputMethod = @"InputMethod";
static NSString *const PHTVDefaultsKeyExcludedApps = @"ExcludedApps";
static NSString *const PHTVDefaultsKeySendKeyStepByStepApps = @"SendKeyStepByStepApps";
static NSString *const PHTVDefaultsKeyUpperCaseExcludedApps = @"UpperCaseExcludedApps";
static NSString *const PHTVDefaultsKeySendKeyStepByStep = @"SendKeyStepByStep";

static NSString *const PHTVNotificationInputMethodChanged = @"InputMethodChanged";
static NSString *const PHTVNotificationCodeTableChanged = @"CodeTableChanged";
static NSString *const PHTVNotificationHotkeyChanged = @"HotkeyChanged";
static NSString *const PHTVNotificationEmojiHotkeySettingsChanged = @"EmojiHotkeySettingsChanged";
static NSString *const PHTVNotificationLanguageChangedFromSwiftUI = @"LanguageChangedFromSwiftUI";
static NSString *const PHTVNotificationSettingsChanged = @"PHTVSettingsChanged";
static NSString *const PHTVNotificationMacrosUpdated = @"MacrosUpdated";
static NSString *const PHTVNotificationExcludedAppsChanged = @"ExcludedAppsChanged";
static NSString *const PHTVNotificationSendKeyStepByStepAppsChanged = @"SendKeyStepByStepAppsChanged";
static NSString *const PHTVNotificationUpperCaseExcludedAppsChanged = @"UpperCaseExcludedAppsChanged";
static NSString *const PHTVNotificationMenuBarIconSizeChanged = @"MenuBarIconSizeChanged";
static NSString *const PHTVNotificationLanguageChangedFromExcludedApp = @"LanguageChangedFromExcludedApp";
static NSString *const PHTVNotificationTCCDatabaseChanged = @"TCCDatabaseChanged";
static const uint64_t PHTVSpotlightInvalidationDedupMs = 30;

extern volatile int vLanguage;
extern volatile int vUseSmartSwitchKey;
extern volatile int vSendKeyStepByStep;
extern volatile int vUpperCaseExcludedForCurrentApp;

#ifdef __cplusplus
extern "C" {
#endif
void OnActiveAppChanged(void);
void RequestNewSession(void);
#ifdef __cplusplus
}
#endif

static NSArray<NSDictionary *> * _Nullable PHTVDecodeAppList(NSData * _Nullable data) {
    if (data.length == 0) {
        return nil;
    }

    NSError *error = nil;
    id decoded = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error || ![decoded isKindOfClass:[NSArray class]]) {
        return nil;
    }

    return (NSArray<NSDictionary *> *)decoded;
}

static BOOL PHTVListContainsBundleIdentifier(NSArray<NSDictionary *> * _Nullable appList,
                                             NSString *bundleIdentifier) {
    if (bundleIdentifier.length == 0 || appList.count == 0) {
        return NO;
    }

    for (id entry in appList) {
        if (![entry isKindOfClass:[NSDictionary class]]) {
            continue;
        }

        NSString *candidate = ((NSDictionary *)entry)[@"bundleIdentifier"];
        if ([candidate isKindOfClass:[NSString class]] && [bundleIdentifier isEqualToString:candidate]) {
            return YES;
        }
    }

    return NO;
}

@implementation AppDelegate (AppMonitoring)

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

- (void)handleUpperCaseExcludedAppsChanged:(NSNotification *)notification {
    // Re-evaluate current app against the updated upper case excluded list.
    NSRunningApplication *frontmost = [[NSWorkspace sharedWorkspace] frontmostApplication];
    if (frontmost.bundleIdentifier.length > 0) {
        [self checkUpperCaseExcludedApp:frontmost.bundleIdentifier];
    }
}

#pragma mark - Active App Notifications

- (void)receiveWakeNote:(NSNotification *)note {
    // Force stop/start on wake to ensure fresh connection to Window Server.
    // This fixes issues where event tap dies during sleep or Mach port becomes invalid.
    [PHTVManager stopEventTap];
    [PHTVManager initEventTap];
}

- (void)receiveSleepNote:(NSNotification *)note {
    [PHTVManager stopEventTap];
}

- (void)receiveActiveSpaceChanged:(NSNotification *)note {
    RequestNewSession();
}

- (void)activeAppChanged:(NSNotification *)note {
    NSRunningApplication *activeApp = [[note userInfo] objectForKey:NSWorkspaceApplicationKey];
    NSString *bundleId = activeApp.bundleIdentifier;

    // CRITICAL: Update focus cache immediately to prevent race conditions in smart switch logic.
    // This ensures that OnActiveAppChanged and other background tasks see the correct app.
    if (bundleId) {
        [PHTVCacheStateService updateSpotlightCache:NO pid:0 bundleId:bundleId];
    }

    // CRITICAL FIX: Handle exclusion logic BEFORE smart switch logic.
    // This ensures that if we are leaving an excluded app (which forced English mode),
    // the global vLanguage is restored to its proper value BEFORE smart switch
    // logic decides what to save or load for the new app.
    if (bundleId) {
        [self checkExcludedApp:bundleId];
    }

    // Handle smart switch logic only for non-excluded apps.
    if (!self.isInExcludedApp && vUseSmartSwitchKey && [PHTVManager isInited]) {
        OnActiveAppChanged();
    }

    // Invalidate Spotlight cache on app switch to ensure fresh detection.
    __unused NSInteger cacheStatus = [PHTVCacheStateService
        invalidateSpotlightCacheWithDedupWindowMs:PHTVSpotlightInvalidationDedupMs];

    // Check other app-specific behaviors.
    if (bundleId) {
        [self checkSendKeyStepByStepApp:bundleId];
        [self checkUpperCaseExcludedApp:bundleId];
    }
}

- (void)checkExcludedApp:(NSString *)bundleIdentifier {
    // Skip if bundle ID is nil or same as previous app.
    if (bundleIdentifier.length == 0 || [bundleIdentifier isEqualToString:self.previousBundleIdentifier]) {
        return;
    }

    NSArray<NSDictionary *> *excludedApps = PHTVDecodeAppList(
        [[NSUserDefaults standardUserDefaults] dataForKey:PHTVDefaultsKeyExcludedApps]
    );
    BOOL isExcluded = PHTVListContainsBundleIdentifier(excludedApps, bundleIdentifier);

    // Handle state transition.
    if (isExcluded && !self.isInExcludedApp) {
        // Entering an excluded app - save current language and switch to English.
        self.savedLanguageBeforeExclusion = vLanguage;
        self.isInExcludedApp = YES;

        if (vLanguage == 1) {
            vLanguage = 0;
            [[NSUserDefaults standardUserDefaults] setInteger:vLanguage forKey:PHTVDefaultsKeyInputMethod];

            // CRITICAL: Reset engine session when forcing mode change.
            RequestNewSession();
            [self fillData];

            NSLog(@"[ExcludedApp] Entered excluded app '%@' - switched to English (saved state: Vietnamese)", bundleIdentifier);

            // Notify SwiftUI (use special notification to avoid beep sound).
            [[NSNotificationCenter defaultCenter] postNotificationName:PHTVNotificationLanguageChangedFromExcludedApp
                                                                object:@(vLanguage)];
        } else {
            NSLog(@"[ExcludedApp] Entered excluded app '%@' - already in English (saved state: English)", bundleIdentifier);
        }
    } else if (!isExcluded && self.isInExcludedApp) {
        // Leaving an excluded app - restore previous language state.
        self.isInExcludedApp = NO;

        if (self.savedLanguageBeforeExclusion == 1 && vLanguage == 0) {
            vLanguage = 1;
            [[NSUserDefaults standardUserDefaults] setInteger:vLanguage forKey:PHTVDefaultsKeyInputMethod];

            // CRITICAL: Reset engine session when restoring mode.
            RequestNewSession();
            [self fillData];

            NSLog(@"[ExcludedApp] Left excluded app, switched to '%@' - restored Vietnamese mode", bundleIdentifier);

            // Notify SwiftUI (use special notification to avoid beep sound).
            [[NSNotificationCenter defaultCenter] postNotificationName:PHTVNotificationLanguageChangedFromExcludedApp
                                                                object:@(vLanguage)];
        } else {
            NSLog(@"[ExcludedApp] Left excluded app, switched to '%@' - staying in English", bundleIdentifier);
        }
    } else if (isExcluded && self.isInExcludedApp) {
        // Moving between excluded apps - stay in English.
        NSLog(@"[ExcludedApp] Moved from excluded app to another excluded app '%@' - staying in English", bundleIdentifier);
    }

    self.previousBundleIdentifier = bundleIdentifier;
}

- (void)checkSendKeyStepByStepApp:(NSString *)bundleIdentifier {
    if (bundleIdentifier.length == 0) {
        return;
    }

    NSArray<NSDictionary *> *appList = PHTVDecodeAppList(
        [[NSUserDefaults standardUserDefaults] dataForKey:PHTVDefaultsKeySendKeyStepByStepApps]
    );
    BOOL isInList = PHTVListContainsBundleIdentifier(appList, bundleIdentifier);

    if (isInList && !self.isInSendKeyStepByStepApp) {
        // Entering a send key step by step app - save current state and enable.
        self.savedSendKeyStepByStepBeforeApp = vSendKeyStepByStep;
        self.isInSendKeyStepByStepApp = YES;

        if (!vSendKeyStepByStep) {
            vSendKeyStepByStep = YES;
            [[NSUserDefaults standardUserDefaults] setBool:vSendKeyStepByStep forKey:PHTVDefaultsKeySendKeyStepByStep];

            NSLog(@"[SendKeyStepByStepApp] Entered app '%@' - enabled send key step by step", bundleIdentifier);
        } else {
            NSLog(@"[SendKeyStepByStepApp] Entered app '%@' - already enabled", bundleIdentifier);
        }
    } else if (!isInList && self.isInSendKeyStepByStepApp) {
        // Leaving a send key step by step app - restore previous state.
        self.isInSendKeyStepByStepApp = NO;

        if (!self.savedSendKeyStepByStepBeforeApp && vSendKeyStepByStep) {
            vSendKeyStepByStep = NO;
            [[NSUserDefaults standardUserDefaults] setBool:vSendKeyStepByStep forKey:PHTVDefaultsKeySendKeyStepByStep];

            NSLog(@"[SendKeyStepByStepApp] Left app '%@' - disabled send key step by step", bundleIdentifier);
        } else {
            NSLog(@"[SendKeyStepByStepApp] Left app '%@' - keeping send key step by step state", bundleIdentifier);
        }
    } else if (isInList && self.isInSendKeyStepByStepApp) {
        // Moving between apps in the list - stay enabled.
        NSLog(@"[SendKeyStepByStepApp] Moved to another app in list '%@' - keeping enabled", bundleIdentifier);
    }
}

- (void)checkUpperCaseExcludedApp:(NSString *)bundleIdentifier {
    if (bundleIdentifier.length == 0) {
        return;
    }

    NSArray<NSDictionary *> *appList = PHTVDecodeAppList(
        [[NSUserDefaults standardUserDefaults] dataForKey:PHTVDefaultsKeyUpperCaseExcludedApps]
    );
    BOOL isExcluded = PHTVListContainsBundleIdentifier(appList, bundleIdentifier);

    // Set the global flag.
    vUpperCaseExcludedForCurrentApp = isExcluded ? 1 : 0;

    if (isExcluded) {
        NSLog(@"[UpperCaseExcludedApp] App '%@' is excluded from uppercase first char", bundleIdentifier);
    }
}

#pragma mark - Notification Registration

- (void)registerSupportedNotification {
#if DEBUG
    NSLog(@"[AppMonitoring] registerSupportedNotification registering observers");
#endif

    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                           selector:@selector(receiveWakeNote:)
                                                               name:NSWorkspaceDidWakeNotification
                                                             object:nil];

    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                           selector:@selector(receiveSleepNote:)
                                                               name:NSWorkspaceWillSleepNotification
                                                             object:nil];

    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                           selector:@selector(receiveActiveSpaceChanged:)
                                                               name:NSWorkspaceActiveSpaceDidChangeNotification
                                                             object:nil];

    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                           selector:@selector(activeAppChanged:)
                                                               name:NSWorkspaceDidActivateApplicationNotification
                                                             object:nil];

    // Listen for SwiftUI setting changes (hot-reload without restart).
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onInputMethodChangedFromSwiftUI:)
                                                 name:PHTVNotificationInputMethodChanged
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onCodeTableChangedFromSwiftUI:)
                                                 name:PHTVNotificationCodeTableChanged
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleHotkeyChanged:)
                                                 name:PHTVNotificationHotkeyChanged
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleEmojiHotkeySettingsChanged:)
                                                 name:PHTVNotificationEmojiHotkeySettingsChanged
                                               object:nil];

    // Listen for TCC database changes (posted by PHTVManager).
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleTCCDatabaseChanged:)
                                                 name:PHTVNotificationTCCDatabaseChanged
                                               object:nil];

    // Also observe the full set of SwiftUI-driven live settings.
    // Some builds/flows rely on registerSupportedNotification rather than setupSwiftUIBridge.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleSettingsChanged:)
                                                 name:PHTVNotificationSettingsChanged
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleMacrosUpdated:)
                                                 name:PHTVNotificationMacrosUpdated
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleExcludedAppsChanged:)
                                                 name:PHTVNotificationExcludedAppsChanged
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleSendKeyStepByStepAppsChanged:)
                                                 name:PHTVNotificationSendKeyStepByStepAppsChanged
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleUpperCaseExcludedAppsChanged:)
                                                 name:PHTVNotificationUpperCaseExcludedAppsChanged
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleMenuBarIconSizeChanged:)
                                                 name:PHTVNotificationMenuBarIconSizeChanged
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleLanguageChangedFromSwiftUI:)
                                                 name:PHTVNotificationLanguageChangedFromSwiftUI
                                               object:nil];

    // Apply live updates when defaults are changed outside SwiftUI.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleUserDefaultsDidChange:)
                                                 name:NSUserDefaultsDidChangeNotification
                                               object:nil];

    [self registerSparkleObservers];
}

@end
