//
//  AppDelegate+RuntimeSettings.mm
//  PHTV
//
//  Runtime engine/settings bootstrap extracted from AppDelegate.
//

#import "AppDelegate+RuntimeSettings.h"
#import "AppDelegate+Private.h"
#import "PHTVSettingsRuntime.h"

static NSString *const PHTVDefaultsKeyInputMethod = @"InputMethod";
static NSString *const PHTVDefaultsKeyInputType = @"InputType";
static NSString *const PHTVDefaultsKeyCodeTable = @"CodeTable";
static NSString *const PHTVDefaultsKeySwitchKeyStatus = @"SwitchKeyStatus";
static NSString *const PHTVDefaultsKeyAllowConsonantZFWJ = @"vAllowConsonantZFWJ";
static NSString *const PHTVDefaultsKeyModernOrthography = @"ModernOrthography";
static NSString *const PHTVDefaultsKeyQuickTelex = @"QuickTelex";
static NSString *const PHTVDefaultsKeyUpperCaseFirstChar = @"UpperCaseFirstChar";
static NSString *const PHTVDefaultsKeyAutoRestoreEnglishWord = @"vAutoRestoreEnglishWord";
static NSString *const PHTVDefaultsKeyShowIconOnDock = @"vShowIconOnDock";
static NSString *const PHTVDefaultsKeySendKeyStepByStep = @"SendKeyStepByStep";

extern volatile int vLanguage;
extern volatile int vInputType;
extern int vFreeMark;
extern volatile int vCodeTable;
extern volatile int vUseModernOrthography;
extern volatile int vQuickTelex;
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
extern volatile int vSwitchKeyStatus;
extern volatile int vEnableEmojiHotkey;
extern volatile int vEmojiHotkeyModifiers;
extern volatile int vEmojiHotkeyKeyCode;
extern int vShowIconOnDock;

@implementation AppDelegate (RuntimeSettings)

- (void)loadRuntimeSettingsFromUserDefaults {
    // Load ALL settings from UserDefaults BEFORE initializing event tap.
    // This ensures settings persist across restart/wake from sleep.
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    // Core input settings - CRITICAL for persistence across restart/wake.
    vLanguage = PHTVReadIntWithFallback(defaults, PHTVDefaultsKeyInputMethod, vLanguage);
    vInputType = PHTVReadIntWithFallback(defaults, PHTVDefaultsKeyInputType, vInputType);
    vCodeTable = PHTVReadIntWithFallback(defaults, PHTVDefaultsKeyCodeTable, vCodeTable);
    NSLog(@"[AppDelegate] Loaded core settings: language=%d, inputType=%d, codeTable=%d", vLanguage, vInputType, vCodeTable);

    // Spelling and orthography settings.
    // NOTE: vCheckSpelling already loaded in initEnglishWordDictionary() for early initialization.
    vUseModernOrthography = PHTVReadIntWithFallback(defaults, PHTVDefaultsKeyModernOrthography, vUseModernOrthography);
    vQuickTelex = PHTVReadIntWithFallback(defaults, PHTVDefaultsKeyQuickTelex, vQuickTelex);
    vFreeMark = PHTVReadIntWithFallback(defaults, @"FreeMark", vFreeMark);

    // Macro settings.
    vUseMacro = PHTVReadIntWithFallback(defaults, @"UseMacro", vUseMacro);
    vUseMacroInEnglishMode = PHTVReadIntWithFallback(defaults, @"UseMacroInEnglishMode", vUseMacroInEnglishMode);
    vAutoCapsMacro = PHTVReadIntWithFallback(defaults, @"vAutoCapsMacro", vAutoCapsMacro);

    // Typing behavior settings.
    vSendKeyStepByStep = PHTVReadIntWithFallback(defaults, PHTVDefaultsKeySendKeyStepByStep, vSendKeyStepByStep);
    vUseSmartSwitchKey = PHTVReadIntWithFallback(defaults, @"UseSmartSwitchKey", vUseSmartSwitchKey);
    vUpperCaseFirstChar = PHTVReadIntWithFallback(defaults, PHTVDefaultsKeyUpperCaseFirstChar, vUpperCaseFirstChar);
    vAllowConsonantZFWJ = PHTVReadIntWithFallback(defaults, PHTVDefaultsKeyAllowConsonantZFWJ, 1);
    vQuickStartConsonant = PHTVReadIntWithFallback(defaults, @"vQuickStartConsonant", vQuickStartConsonant);
    vQuickEndConsonant = PHTVReadIntWithFallback(defaults, @"vQuickEndConsonant", vQuickEndConsonant);
    vRememberCode = PHTVReadIntWithFallback(defaults, @"vRememberCode", vRememberCode);
    vPerformLayoutCompat = PHTVReadIntWithFallback(defaults, @"vPerformLayoutCompat", vPerformLayoutCompat);

    // Restore to raw keys settings.
    vRestoreOnEscape = PHTVReadIntWithFallback(defaults, @"vRestoreOnEscape", vRestoreOnEscape);
    vCustomEscapeKey = PHTVReadIntWithFallback(defaults, @"vCustomEscapeKey", vCustomEscapeKey);

    // Pause key settings.
    vPauseKeyEnabled = PHTVReadIntWithFallback(defaults, @"vPauseKeyEnabled", vPauseKeyEnabled);
    vPauseKey = PHTVReadIntWithFallback(defaults, @"vPauseKey", vPauseKey);

    // Auto restore English word.
    vAutoRestoreEnglishWord = PHTVReadIntWithFallback(defaults, PHTVDefaultsKeyAutoRestoreEnglishWord, vAutoRestoreEnglishWord);

    // UI settings.
    vShowIconOnDock = PHTVReadIntWithFallback(defaults, PHTVDefaultsKeyShowIconOnDock, vShowIconOnDock);

    // Hotkey settings.
    NSInteger savedHotkey = [defaults integerForKey:PHTVDefaultsKeySwitchKeyStatus];
    if (savedHotkey != 0) {
        vSwitchKeyStatus = (int)savedHotkey;
        NSLog(@"[AppDelegate] Loaded hotkey from UserDefaults: 0x%X", vSwitchKeyStatus);
    } else {
        NSLog(@"[AppDelegate] No saved hotkey found, using default: 0x%X", vSwitchKeyStatus);
    }

    // Emoji picker hotkey settings.
    PHTVLoadEmojiHotkeySettings(defaults, &vEnableEmojiHotkey, &vEmojiHotkeyModifiers, &vEmojiHotkeyKeyCode);

    self.lastSettingsChangeToken = PHTVComputeSettingsToken(defaults);
    NSLog(@"[AppDelegate] All settings loaded from UserDefaults");

    // Memory barrier to ensure event tap thread sees all values.
    __sync_synchronize();
}

@end
