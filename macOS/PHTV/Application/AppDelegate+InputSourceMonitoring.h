//
//  AppDelegate+InputSourceMonitoring.h
//  PHTV
//
//  Input source and appearance change monitoring extracted from AppDelegate.
//

#ifndef AppDelegate_InputSourceMonitoring_h
#define AppDelegate_InputSourceMonitoring_h

#import "AppDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface AppDelegate (InputSourceMonitoring)

- (void)observeAppearanceChanges;
- (void)startInputSourceMonitoring;
- (void)stopInputSourceMonitoring;

@end

NS_ASSUME_NONNULL_END

#endif /* AppDelegate_InputSourceMonitoring_h */
