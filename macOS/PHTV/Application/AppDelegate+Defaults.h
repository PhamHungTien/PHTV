//
//  AppDelegate+Defaults.h
//  PHTV
//
//  Default configuration bootstrap extracted from AppDelegate.
//

#ifndef AppDelegate_Defaults_h
#define AppDelegate_Defaults_h

#import "AppDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface AppDelegate (Defaults)

- (void)loadDefaultConfig;
- (void)setGrayIcon:(BOOL)val;

@end

NS_ASSUME_NONNULL_END

#endif /* AppDelegate_Defaults_h */
