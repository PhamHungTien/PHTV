//
//  AppDelegate+UIActions.h
//  PHTV
//
//  UI/menu actions extracted from AppDelegate.
//

#ifndef AppDelegate_UIActions_h
#define AppDelegate_UIActions_h

#import "AppDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface AppDelegate (UIActions)

- (void)handleSettingsReset:(NSNotification * _Nullable)notification;
- (void)onShowMacroTab:(NSNotification * _Nullable)notification;
- (void)onShowAboutTab:(NSNotification * _Nullable)notification;

- (void)onQuickConvert;
- (void)onEmojiHotkeyTriggered;

- (void)onControlPanelSelected;
- (void)onMacroSelected;
- (void)onAboutSelected;
- (void)onSwitchLanguage;

@end

NS_ASSUME_NONNULL_END

#endif /* AppDelegate_UIActions_h */
