//
//  AppDelegate+PermissionFlow.h
//  PHTV
//
//  Accessibility permission flow extracted from AppDelegate.
//

#ifndef AppDelegate_PermissionFlow_h
#define AppDelegate_PermissionFlow_h

#import "AppDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface AppDelegate (PermissionFlow)

- (void)askPermission;

@end

NS_ASSUME_NONNULL_END

#endif /* AppDelegate_PermissionFlow_h */
