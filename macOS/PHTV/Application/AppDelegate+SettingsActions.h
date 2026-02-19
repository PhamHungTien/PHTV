//
//  AppDelegate+SettingsActions.h
//  PHTV
//
//  Menu-based settings toggles extracted from AppDelegate.
//

#ifndef AppDelegate_SettingsActions_h
#define AppDelegate_SettingsActions_h

#import "AppDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface AppDelegate (SettingsActions)
- (void)toggleSpellCheck:(id)sender;
- (void)toggleAllowConsonantZFWJ:(id)sender;
- (void)toggleModernOrthography:(id)sender;
- (void)toggleQuickTelex:(id)sender;
- (void)toggleUpperCaseFirstChar:(id)sender;
- (void)toggleAutoRestoreEnglishWord:(id)sender;
@end

NS_ASSUME_NONNULL_END

#endif /* AppDelegate_SettingsActions_h */
