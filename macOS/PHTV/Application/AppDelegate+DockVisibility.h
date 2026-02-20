//
//  AppDelegate+DockVisibility.h
//  PHTV
//
//  Dock icon and Settings window visibility flow extracted from AppDelegate.
//

#ifndef AppDelegate_DockVisibility_h
#define AppDelegate_DockVisibility_h

#import "AppDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface AppDelegate (DockVisibility)
- (NSWindow * _Nullable)currentSettingsWindow;
- (BOOL)isSettingsWindowVisible;
- (void)handleShowDockIconNotification:(NSNotification * _Nullable)notification;
- (void)setDockIconVisible:(BOOL)visible;
- (void)showIcon:(BOOL)onDock;
@end

NS_ASSUME_NONNULL_END

#endif /* AppDelegate_DockVisibility_h */
