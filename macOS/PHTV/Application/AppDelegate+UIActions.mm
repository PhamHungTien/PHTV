//
//  AppDelegate+UIActions.mm
//  PHTV
//
//  UI/menu actions extracted from AppDelegate.
//

#import "AppDelegate+UIActions.h"
#import "AppDelegate+DockVisibility.h"
#import "AppDelegate+InputState.h"
#import "../SystemBridge/PHTVManager.h"
#import "PHTV-Swift.h"
#include "../Core/Engine/Engine.h"

static NSString *const PHTVDefaultsKeyNonFirstTime = @"NonFirstTime";
static NSString *const PHTVNotificationSettingsResetComplete = @"SettingsResetComplete";
static NSString *const PHTVNotificationShowSettings = @"ShowSettings";
static NSString *const PHTVNotificationShowMacroTab = @"ShowMacroTab";
static NSString *const PHTVNotificationShowAboutTab = @"ShowAboutTab";

@implementation AppDelegate (UIActions)

- (void)handleSettingsReset:(NSNotification *)notification {
    // Settings have been reset, post confirmation to UI
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:PHTVNotificationSettingsResetComplete object:nil];

        #ifdef DEBUG
        NSLog(@"[Settings Reset] Reset complete, UI will refresh");
        #endif
    });
}

- (void)onShowMacroTab:(NSNotification *)notification {
    // First open settings window, then switch to macro tab
    [self onControlPanelSelected];
}

- (void)onShowAboutTab:(NSNotification *)notification {
    // First open settings window
    [self onControlPanelSelected];
}

- (void)onQuickConvert {
    if ([PHTVManager quickConvert]) {
        if (!gConvertToolOptions.dontAlertWhenCompleted) {
            [PHTVManager showMessage:nil
                             message:@"Chuyển mã thành công!"
                              subMsg:@"Kết quả đã được lưu trong clipboard."];
        }
    } else {
        [PHTVManager showMessage:nil
                         message:@"Không có dữ liệu trong clipboard!"
                          subMsg:@"Hãy sao chép một đoạn text để chuyển đổi!"];
    }
}

- (void)onEmojiHotkeyTriggered {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            [EmojiHotkeyBridge openEmojiPicker];
        } @catch (NSException *exception) {
            NSLog(@"[EmojiHotkey] failed to open picker: %@", exception);
        }
    });
}

- (void)onControlPanelSelected {
    // Show dock icon when opening settings
    [self setDockIconVisible:YES];

    // Mark that user has opened settings, so defaults won't overwrite their changes
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults integerForKey:PHTVDefaultsKeyNonFirstTime] == 0) {
        [defaults setInteger:1 forKey:PHTVDefaultsKeyNonFirstTime];
        NSLog(@"Marking NonFirstTime after user opened settings");
    }

    // Post notification - SettingsWindowManager in Swift will handle it
    NSLog(@"[AppDelegate] Posting ShowSettings notification");
    [[NSNotificationCenter defaultCenter] postNotificationName:PHTVNotificationShowSettings object:nil];
}

- (void)onMacroSelected {
    // Show SwiftUI Macro tab
    [[NSNotificationCenter defaultCenter] postNotificationName:PHTVNotificationShowMacroTab object:nil];
}

- (void)onAboutSelected {
    // Show SwiftUI About tab
    [[NSNotificationCenter defaultCenter] postNotificationName:PHTVNotificationShowAboutTab object:nil];
}

- (void)onSwitchLanguage {
    [self onInputMethodSelected];
}

@end
