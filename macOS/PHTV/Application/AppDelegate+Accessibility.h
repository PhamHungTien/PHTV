//
//  AppDelegate+Accessibility.h
//  PHTV
//

#ifndef AppDelegate_Accessibility_h
#define AppDelegate_Accessibility_h

#import "AppDelegate.h"

@interface AppDelegate (Accessibility)

- (void)startAccessibilityMonitoring;
- (void)startAccessibilityMonitoringWithInterval:(NSTimeInterval)interval;
- (void)startAccessibilityMonitoringWithInterval:(NSTimeInterval)interval resetState:(BOOL)resetState;
- (NSTimeInterval)currentMonitoringInterval;
- (void)stopAccessibilityMonitoring;
- (void)startHealthCheckMonitoring;
- (void)stopHealthCheckMonitoring;
- (void)runHealthCheck;
- (void)checkAccessibilityStatus;
- (void)performAccessibilityGrantedRestart;
- (void)relaunchAppAfterPermissionGrant;
- (void)handleAccessibilityRevoked;
- (void)attemptAutomaticTCCRepairIfNeeded;
- (void)handleAccessibilityNeedsRelaunch;
- (void)checkAccessibilityAndRestart;

@end

#endif /* AppDelegate_Accessibility_h */
