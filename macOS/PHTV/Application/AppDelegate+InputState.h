//
//  AppDelegate+InputState.h
//  PHTV
//
//  Input state coordination extracted from AppDelegate.
//

#ifndef AppDelegate_InputState_h
#define AppDelegate_InputState_h

#import "AppDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface AppDelegate (InputState)
- (void)onImputMethodChanged:(BOOL)willNotify;
- (void)onInputMethodSelected;
- (void)onInputTypeSelected:(id)sender;
- (void)onInputTypeSelectedIndex:(int)index;
- (void)onCodeSelected:(id)sender;
- (void)onCodeTableChanged:(int)index;
- (void)handleLanguageChangedFromSwiftUI:(NSNotification *)notification;
- (void)handleInputMethodChanged:(NSNotification *)notification;
- (void)handleCodeTableChanged:(NSNotification *)notification;
- (void)onInputMethodChangedFromSwiftUI:(NSNotification *)notification;
- (void)onCodeTableChangedFromSwiftUI:(NSNotification *)notification;
@end

NS_ASSUME_NONNULL_END

#endif /* AppDelegate_InputState_h */
