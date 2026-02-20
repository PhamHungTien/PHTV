//
//  AppDelegate+LoginItem.h
//  PHTV
//
//  Launch at Login lifecycle extracted from AppDelegate.
//

#ifndef AppDelegate_LoginItem_h
#define AppDelegate_LoginItem_h

#import "AppDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface AppDelegate (LoginItem)

- (void)syncRunOnStartupStatusWithFirstLaunch:(BOOL)isFirstLaunch;
- (void)setRunOnStartup:(BOOL)val;
- (void)toggleStartupItem:(NSMenuItem *)sender;

@end

NS_ASSUME_NONNULL_END

#endif /* AppDelegate_LoginItem_h */
