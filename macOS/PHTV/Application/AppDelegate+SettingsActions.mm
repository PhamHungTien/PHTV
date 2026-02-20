//
//  AppDelegate+SettingsActions.mm
//  PHTV
//
//  Menu-based settings toggles extracted from AppDelegate.
//

#import "AppDelegate+SettingsActions.h"
#import "AppDelegate+StatusBarMenu.h"
#include "../Core/Engine/Engine.h"

static NSString *const PHTVDefaultsKeySpelling = @"Spelling";
static NSString *const PHTVDefaultsKeyAllowConsonantZFWJ = @"vAllowConsonantZFWJ";
static NSString *const PHTVDefaultsKeyModernOrthography = @"ModernOrthography";
static NSString *const PHTVDefaultsKeyQuickTelex = @"QuickTelex";
static NSString *const PHTVDefaultsKeyUpperCaseFirstChar = @"UpperCaseFirstChar";
static NSString *const PHTVDefaultsKeyAutoRestoreEnglishWord = @"vAutoRestoreEnglishWord";

static NSString *const PHTVNotificationSettingsChanged = @"PHTVSettingsChanged";

extern volatile int vCheckSpelling;
extern volatile int vAllowConsonantZFWJ;
extern volatile int vUseModernOrthography;
extern volatile int vQuickTelex;
extern volatile int vUpperCaseFirstChar;
extern volatile int vAutoRestoreEnglishWord;

#ifdef __cplusplus
extern "C" {
#endif
void RequestNewSession(void);
#ifdef __cplusplus
}
#endif

@implementation AppDelegate (SettingsActions)

- (void)toggleSpellCheck:(id)sender {
    vCheckSpelling = !vCheckSpelling;
    __sync_synchronize();

    [[NSUserDefaults standardUserDefaults] setInteger:vCheckSpelling forKey:PHTVDefaultsKeySpelling];

    // Keep engine spelling mode in sync before session reset.
    vSetCheckSpelling();
    RequestNewSession();
    [self fillData];
    [[NSNotificationCenter defaultCenter] postNotificationName:PHTVNotificationSettingsChanged object:nil];
}

- (void)toggleAllowConsonantZFWJ:(id)sender {
    vAllowConsonantZFWJ = !vAllowConsonantZFWJ;
    __sync_synchronize();

    [[NSUserDefaults standardUserDefaults] setInteger:vAllowConsonantZFWJ forKey:PHTVDefaultsKeyAllowConsonantZFWJ];

    RequestNewSession();
    [self fillData];
    [[NSNotificationCenter defaultCenter] postNotificationName:PHTVNotificationSettingsChanged object:nil];
}

- (void)toggleModernOrthography:(id)sender {
    vUseModernOrthography = !vUseModernOrthography;
    __sync_synchronize();

    [[NSUserDefaults standardUserDefaults] setInteger:vUseModernOrthography forKey:PHTVDefaultsKeyModernOrthography];

    RequestNewSession();
    [self fillData];
    [[NSNotificationCenter defaultCenter] postNotificationName:PHTVNotificationSettingsChanged object:nil];
}

- (void)toggleQuickTelex:(id)sender {
    vQuickTelex = !vQuickTelex;
    __sync_synchronize();

    [[NSUserDefaults standardUserDefaults] setInteger:vQuickTelex forKey:PHTVDefaultsKeyQuickTelex];

    RequestNewSession();
    [self fillData];
    [[NSNotificationCenter defaultCenter] postNotificationName:PHTVNotificationSettingsChanged object:nil];
}

- (void)toggleUpperCaseFirstChar:(id)sender {
    vUpperCaseFirstChar = !vUpperCaseFirstChar;
    __sync_synchronize();

    [[NSUserDefaults standardUserDefaults] setInteger:vUpperCaseFirstChar forKey:PHTVDefaultsKeyUpperCaseFirstChar];

    RequestNewSession();
    [self fillData];
    [[NSNotificationCenter defaultCenter] postNotificationName:PHTVNotificationSettingsChanged object:nil];
}

- (void)toggleAutoRestoreEnglishWord:(id)sender {
    vAutoRestoreEnglishWord = !vAutoRestoreEnglishWord;
    __sync_synchronize();

    [[NSUserDefaults standardUserDefaults] setInteger:vAutoRestoreEnglishWord forKey:PHTVDefaultsKeyAutoRestoreEnglishWord];

    RequestNewSession();
    [self fillData];
    [[NSNotificationCenter defaultCenter] postNotificationName:PHTVNotificationSettingsChanged object:nil];
}

@end
