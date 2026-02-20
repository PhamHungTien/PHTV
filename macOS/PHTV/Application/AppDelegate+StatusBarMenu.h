//
//  AppDelegate+StatusBarMenu.h
//  PHTV
//
//  Status bar menu construction and refresh logic extracted from AppDelegate.
//

#ifndef AppDelegate_StatusBarMenu_h
#define AppDelegate_StatusBarMenu_h

#import "AppDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface AppDelegate (StatusBarMenu)

- (void)createStatusBarMenu;
- (void)fillData;
- (void)fillDataWithAnimation:(BOOL)animated;
- (void)setQuickConvertString;

@end

NS_ASSUME_NONNULL_END

#endif /* AppDelegate_StatusBarMenu_h */
