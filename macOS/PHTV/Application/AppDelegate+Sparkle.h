//
//  AppDelegate+Sparkle.h
//  PHTV
//
//  Extracted Sparkle integration from AppDelegate for lower coupling.
//

#ifndef AppDelegate_Sparkle_h
#define AppDelegate_Sparkle_h

#import "AppDelegate.h"

@interface AppDelegate (Sparkle)

- (void)registerSparkleObservers;
- (void)handleSparkleManualCheck:(NSNotification *)notification;
- (void)handleSparkleUpdateFound:(NSNotification *)notification;
- (void)handleSparkleNoUpdate:(NSNotification *)notification;
- (void)handleUpdateFrequencyChanged:(NSNotification *)notification;
- (void)handleSparkleInstallUpdate:(NSNotification *)notification;

@end

#endif /* AppDelegate_Sparkle_h */
