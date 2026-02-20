//
//  AppDelegate+RuntimeSettings.h
//  PHTV
//
//  Runtime engine/settings bootstrap extracted from AppDelegate.
//

#ifndef AppDelegate_RuntimeSettings_h
#define AppDelegate_RuntimeSettings_h

#import "AppDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface AppDelegate (RuntimeSettings)

- (void)loadRuntimeSettingsFromUserDefaults;

@end

NS_ASSUME_NONNULL_END

#endif /* AppDelegate_RuntimeSettings_h */
