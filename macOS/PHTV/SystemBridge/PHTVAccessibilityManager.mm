//
//  PHTVAccessibilityManager.mm
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import "PHTVAccessibilityManager.h"
#import "PHTV-Swift.h"
#import <AppKit/AppKit.h>

// External declarations for AX
extern Boolean AXIsProcessTrustedWithOptions(CFDictionaryRef options) __attribute__((weak_import));
extern CFStringRef kAXTrustedCheckOptionPrompt __attribute__((weak_import));

#ifdef __cplusplus
extern "C" {
#endif
extern BOOL vSafeMode;
#ifdef __cplusplus
}
#endif

@implementation PHTVAccessibilityManager

#pragma mark - Initialization

+ (void)initialize {
    if (self == [PHTVAccessibilityManager class]) {
        // Load Safe Mode from user defaults
        vSafeMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"SafeMode"];
    }
}

#pragma mark - AX Text Replacement

+ (BOOL)replaceFocusedTextViaAX:(NSInteger)backspaceCount insertText:(NSString*)insertText {
    if (vSafeMode) return NO;
    return [PHTVAccessibilityService replaceFocusedTextViaAX:backspaceCount insertText:insertText];
}

+ (BOOL)replaceFocusedTextViaAX:(NSInteger)backspaceCount insertText:(NSString*)insertText verify:(BOOL)verify {
    // Safe Mode: Skip AX API calls entirely
    if (vSafeMode) return NO;
    return [PHTVAccessibilityService replaceFocusedTextViaAX:backspaceCount
                                                  insertText:insertText
                                                      verify:verify];
}

#pragma mark - AX Context Detection

+ (void)invalidateAddressBarCache {
    [PHTVAccessibilityService invalidateAddressBarCache];
}

+ (BOOL)isNotionCodeBlock {
    if (vSafeMode) return NO;
    return [PHTVAccessibilityService isNotionCodeBlock];
}

+ (BOOL)isTerminalPanelFocused {
    if (vSafeMode) return NO;
    return [PHTVAccessibilityService isTerminalPanelFocused];
}

+ (BOOL)isFocusedElementAddressBar {
    if (vSafeMode) return NO;
    return [PHTVAccessibilityService isFocusedElementAddressBar];
}

#pragma mark - Safe Mode

+ (BOOL)isSafeModeEnabled {
    return vSafeMode;
}

+ (void)setSafeModeEnabled:(BOOL)enabled {
    vSafeMode = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:@"SafeMode"];

    if (enabled) {
        NSLog(@"[SafeMode] ENABLED - Accessibility API calls will be skipped");
    } else {
        NSLog(@"[SafeMode] DISABLED - Normal Accessibility API calls");
    }
}

#pragma mark - Permission UI

+ (void)openAccessibilityPreferences {
    // 1. Trigger system prompt to register app in TCC database
    // This is required so the app appears in the list
    if (AXIsProcessTrustedWithOptions != NULL) {
        NSDictionary *options = @{(__bridge id)kAXTrustedCheckOptionPrompt: @YES};
        AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
    }

    // 2. Open System Settings directly to Privacy & Security -> Accessibility
    // This helps the user find the setting quickly
    NSURL *url = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"];
    if ([[NSWorkspace sharedWorkspace] openURL:url]) {
        return;
    }

    // Fallback for older macOS (should be covered by openURL, but kept for safety)
    if (AXIsProcessTrustedWithOptions == NULL) {
        static NSString* script = @"tell application \"System Preferences\"\nactivate\nset current pane to pane \"com.apple.preference.universalaccess\"\nend tell";
        [[[NSAppleScript alloc] initWithSource:script] executeAndReturnError:nil];
    }
}

@end
