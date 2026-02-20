//
//  AppDelegate+SettingsBridge.mm
//  PHTV
//
//  SwiftUI bridge and live settings synchronization extracted from AppDelegate.
//

#import "AppDelegate+SettingsBridge.h"
#import "AppDelegate+Accessibility.h"
#import "AppDelegate+DockVisibility.h"
#import "AppDelegate+InputState.h"
#import "AppDelegate+MacroData.h"
#import "AppDelegate+Private.h"
#import "AppDelegate+SettingsActions.h"
#import "AppDelegate+StatusBarMenu.h"
#import "AppDelegate+UIActions.h"
#import "PHTVLiveDebug.h"
#import "PHTVSettingsRuntime.h"
#import "../SystemBridge/PHTVManager.h"
#include "../Core/Engine/Engine.h"

static NSString *const PHTVDefaultsKeySwitchKeyStatus = @"SwitchKeyStatus";
static NSString *const PHTVDefaultsKeySpelling = @"Spelling";
static NSString *const PHTVDefaultsKeyAllowConsonantZFWJ = @"vAllowConsonantZFWJ";
static NSString *const PHTVDefaultsKeyModernOrthography = @"ModernOrthography";
static NSString *const PHTVDefaultsKeyQuickTelex = @"QuickTelex";
static NSString *const PHTVDefaultsKeyUpperCaseFirstChar = @"UpperCaseFirstChar";
static NSString *const PHTVDefaultsKeyAutoRestoreEnglishWord = @"vAutoRestoreEnglishWord";
static NSString *const PHTVDefaultsKeyShowIconOnDock = @"vShowIconOnDock";
static NSString *const PHTVDefaultsKeySendKeyStepByStep = @"SendKeyStepByStep";

static NSString *const PHTVNotificationShowMacroTab = @"ShowMacroTab";
static NSString *const PHTVNotificationShowAboutTab = @"ShowAboutTab";
static NSString *const PHTVNotificationInputMethodChanged = @"InputMethodChanged";
static NSString *const PHTVNotificationCodeTableChanged = @"CodeTableChanged";
static NSString *const PHTVNotificationShowDockIcon = @"PHTVShowDockIcon";
static NSString *const PHTVNotificationCustomDictionaryUpdated = @"CustomDictionaryUpdated";
static NSString *const PHTVNotificationSettingsReset = @"SettingsReset";
static NSString *const PHTVNotificationAccessibilityPermissionLost = @"AccessibilityPermissionLost";
static NSString *const PHTVNotificationAccessibilityNeedsRelaunch = @"AccessibilityNeedsRelaunch";

static int sLastUpperCaseFirstCharSetting = -1;

extern volatile int vCheckSpelling;
extern volatile int vUseModernOrthography;
extern volatile int vQuickTelex;
extern volatile int vSwitchKeyStatus;
extern volatile int vUseMacro;
extern volatile int vUseMacroInEnglishMode;
extern volatile int vAutoCapsMacro;
extern volatile int vSendKeyStepByStep;
extern volatile int vUseSmartSwitchKey;
extern volatile int vUpperCaseFirstChar;
extern volatile int vAllowConsonantZFWJ;
extern volatile int vQuickStartConsonant;
extern volatile int vQuickEndConsonant;
extern volatile int vRememberCode;
extern volatile int vPerformLayoutCompat;
extern volatile int vRestoreOnEscape;
extern volatile int vCustomEscapeKey;
extern volatile int vPauseKeyEnabled;
extern volatile int vPauseKey;
extern volatile int vAutoRestoreEnglishWord;
extern volatile int vEnableEmojiHotkey;
extern volatile int vEmojiHotkeyModifiers;
extern volatile int vEmojiHotkeyKeyCode;
extern int vShowIconOnDock;

#ifdef __cplusplus
extern "C" {
#endif
void RequestNewSession(void);
void OnActiveAppChanged(void);
#ifdef __cplusplus
}
#endif

@implementation AppDelegate (SettingsBridge)

- (void)setupSwiftUIBridge {
    PHTV_LIVE_LOG(@"setupSwiftUIBridge registering observers");
    // AppState loads its own settings from UserDefaults in init().
    // No need to sync here - both backend and SwiftUI read from same source.
    // [self syncStateToSwiftUI];  // Removed to prevent race conditions.

    // Setup notification observers for SwiftUI integration.
    // Note: ShowSettings is handled by SettingsWindowManager in Swift.
    // We only need to handle ShowMacroTab and ShowAboutTab here.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onShowMacroTab:)
                                                 name:PHTVNotificationShowMacroTab
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onShowAboutTab:)
                                                 name:PHTVNotificationShowAboutTab
                                               object:nil];

    // Handle input method and code table changes from SwiftUI.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleInputMethodChanged:)
                                                 name:PHTVNotificationInputMethodChanged
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleCodeTableChanged:)
                                                 name:PHTVNotificationCodeTableChanged
                                               object:nil];

    // Listen for dock icon visibility changes from SwiftUI.
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

    // CRITICAL: Handle immediate accessibility permission loss from event tap callback.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleAccessibilityRevoked)
                                                 name:PHTVNotificationAccessibilityPermissionLost
                                               object:nil];

    // Handle when app needs relaunch for permission to take effect.
    // This is triggered when AXIsProcessTrusted=YES but test tap fails persistently.
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

    // Clamp to keep the menu bar usable.
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

        // Memory barrier to ensure event tap thread sees new value immediately.
        __sync_synchronize();

        [[NSUserDefaults standardUserDefaults] setInteger:vSwitchKeyStatus forKey:PHTVDefaultsKeySwitchKeyStatus];

        // Update UI to reflect hotkey change.
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

    // Memory barrier to ensure event tap thread sees new values immediately.
    __sync_synchronize();

#ifdef DEBUG
    NSLog(@"[SwiftUI] Emoji hotkey changed: enabled=%d modifiers=0x%X keyCode=%d",
          vEnableEmojiHotkey, vEmojiHotkeyModifiers, vEmojiHotkeyKeyCode);
#endif
}

- (void)handleTCCDatabaseChanged:(NSNotification *)notification {
    NSLog(@"[TCC] TCC database change notification received in AppDelegate");
    NSLog(@"[TCC] userInfo: %@", notification.userInfo);

    // Invalidate permission cache to handle the change.
    [PHTVManager invalidatePermissionCache];

    // Force check accessibility status immediately.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                  dispatch_get_main_queue(), ^{
        [self checkAccessibilityStatus];
    });
}

- (void)handleSettingsChanged:(NSNotification *)notification {
    PHTV_LIVE_LOG(@"received PHTVSettingsChanged");
    // Reload settings from UserDefaults when SwiftUI changes them.
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

    // Restore to raw keys (customizable key).
    vRestoreOnEscape = PHTVReadIntWithFallback(defaults, @"vRestoreOnEscape", vRestoreOnEscape);
    vCustomEscapeKey = PHTVReadIntWithFallback(defaults, @"vCustomEscapeKey", vCustomEscapeKey);

    // Pause Vietnamese input when holding a key.
    vPauseKeyEnabled = PHTVReadIntWithFallback(defaults, @"vPauseKeyEnabled", vPauseKeyEnabled);
    vPauseKey = PHTVReadIntWithFallback(defaults, @"vPauseKey", vPauseKey);

    // Auto restore English word feature.
    vAutoRestoreEnglishWord = PHTVReadIntWithFallback(defaults, PHTVDefaultsKeyAutoRestoreEnglishWord, vAutoRestoreEnglishWord);

    // Emoji picker hotkey.
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

    // Hotkey: apply from defaults without writing back (avoid loops).
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
