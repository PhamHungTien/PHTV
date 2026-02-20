//
//  AppDelegate+MacroData.h
//  PHTV
//
//  Macro synchronization and dictionary bootstrap extracted from AppDelegate.
//

#ifndef AppDelegate_MacroData_h
#define AppDelegate_MacroData_h

#import "AppDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface AppDelegate (MacroData)

- (void)loadExistingMacros;
- (void)initEnglishWordDictionary;
- (void)syncCustomDictionaryFromUserDefaults;
- (void)handleMacrosUpdated:(NSNotification * _Nullable)notification;
- (void)handleCustomDictionaryUpdated:(NSNotification * _Nullable)notification;

@end

NS_ASSUME_NONNULL_END

#endif /* AppDelegate_MacroData_h */
