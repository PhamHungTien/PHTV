//
//  AppDelegate+Defaults.mm
//  PHTV
//
//  Default configuration bootstrap extracted from AppDelegate.
//

#import "AppDelegate+Defaults.h"
#import "AppDelegate+StatusBarMenu.h"
#include "../Core/Engine/Engine.h"
#include "../Core/PHTVConstants.h"

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
static NSString *const PHTVDefaultsKeySendKeyStepByStep = @"SendKeyStepByStep";

extern volatile int vSendKeyStepByStep;
extern int vShowIconOnDock;
extern volatile int vPerformLayoutCompat;

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

@implementation AppDelegate (Defaults)

- (void)loadDefaultConfig {
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

- (void)setGrayIcon:(BOOL)val {
    (void)val;
    [self fillData];
}

@end
