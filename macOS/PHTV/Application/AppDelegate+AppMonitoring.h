//
//  AppDelegate+AppMonitoring.h
//  PHTV
//
//  Active-app monitoring and per-app behavior rules extracted from AppDelegate.
//

#ifndef AppDelegate_AppMonitoring_h
#define AppDelegate_AppMonitoring_h

#import "AppDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface AppDelegate (AppMonitoring)
- (void)registerSupportedNotification;

- (void)handleExcludedAppsChanged:(NSNotification *)notification;
- (void)handleSendKeyStepByStepAppsChanged:(NSNotification *)notification;
- (void)handleUpperCaseExcludedAppsChanged:(NSNotification *)notification;

- (void)receiveWakeNote:(NSNotification *)note;
- (void)receiveSleepNote:(NSNotification *)note;
- (void)receiveActiveSpaceChanged:(NSNotification *)note;
- (void)activeAppChanged:(NSNotification *)note;

- (void)checkExcludedApp:(NSString *)bundleIdentifier;
- (void)checkSendKeyStepByStepApp:(NSString *)bundleIdentifier;
- (void)checkUpperCaseExcludedApp:(NSString *)bundleIdentifier;
@end

NS_ASSUME_NONNULL_END

#endif /* AppDelegate_AppMonitoring_h */
