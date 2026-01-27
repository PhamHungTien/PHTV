//
//  MJAccessibilityUtils.m
//  PHTV
//
//  Modified by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//
//  Source: https://github.com/Hammerspoon/hammerspoon/blob/master/Hammerspoon/MJAccessibilityUtils.m
//  License: MIT


#import "MJAccessibilityUtils.h"
#import "../../Managers/PHTVManager.h"
#import <AppKit/AppKit.h>
// #import "HSLogger.h"

extern Boolean AXAPIEnabled(void);
extern Boolean AXIsProcessTrustedWithOptions(CFDictionaryRef options) __attribute__((weak_import));
extern CFStringRef kAXTrustedCheckOptionPrompt __attribute__((weak_import));


BOOL MJAccessibilityIsEnabled(void) {
    // CRITICAL FIX: Use PHTVManager's test tap check
    // AXIsProcessTrusted() is unreliable and can return YES even when permission is broken
    return [PHTVManager canCreateEventTap];
}

void MJAccessibilityOpenPanel(void) {
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
