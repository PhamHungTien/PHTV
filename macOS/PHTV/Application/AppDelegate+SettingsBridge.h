//
//  AppDelegate+SettingsBridge.h
//  PHTV
//
//  SwiftUI bridge and live settings synchronization extracted from AppDelegate.
//

#ifndef AppDelegate_SettingsBridge_h
#define AppDelegate_SettingsBridge_h

#import "AppDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface AppDelegate (SettingsBridge)

- (void)setupSwiftUIBridge;
- (void)handleMenuBarIconSizeChanged:(NSNotification * _Nullable)notification;
- (void)handleHotkeyChanged:(NSNotification * _Nullable)notification;
- (void)handleEmojiHotkeySettingsChanged:(NSNotification * _Nullable)notification;
- (void)handleTCCDatabaseChanged:(NSNotification * _Nullable)notification;
- (void)handleSettingsChanged:(NSNotification * _Nullable)notification;
- (void)handleUserDefaultsDidChange:(NSNotification * _Nullable)notification;

@end

NS_ASSUME_NONNULL_END

#endif /* AppDelegate_SettingsBridge_h */
