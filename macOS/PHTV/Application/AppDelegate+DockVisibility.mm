//
//  AppDelegate+DockVisibility.mm
//  PHTV
//
//  Dock icon and Settings window lifecycle handling extracted from AppDelegate.
//

#import "AppDelegate+DockVisibility.h"
#import "AppDelegate+Private.h"
#import "PHTV-Swift.h"
#include <stdlib.h>
#include <string.h>

static NSString *const PHTVDefaultsKeyShowIconOnDock = @"vShowIconOnDock";
static NSString *const PHTVDefaultsKeyLiveDebug = @"PHTV_LIVE_DEBUG";
static NSString *const PHTVNotificationUserInfoVisibleKey = @"visible";
static NSString *const PHTVNotificationUserInfoForceFrontKey = @"forceFront";
static const uint64_t PHTVSpotlightInvalidationDedupMs = 30;

#ifdef __cplusplus
extern "C" {
#endif
void RequestNewSession(void);
#ifdef __cplusplus
}
#endif
extern int vShowIconOnDock;

static inline BOOL PHTVDockLiveDebugEnabled(void) {
    const char *env = getenv("PHTV_LIVE_DEBUG");
    if (env != NULL && env[0] != '\0') {
        return strcmp(env, "0") != 0;
    }

    id stored = [[NSUserDefaults standardUserDefaults] objectForKey:PHTVDefaultsKeyLiveDebug];
    if ([stored respondsToSelector:@selector(intValue)]) {
        return [stored intValue] != 0;
    }
    return NO;
}

#define PHTV_DOCK_LOG(fmt, ...) do { \
    if (PHTVDockLiveDebugEnabled()) { \
        NSLog(@"[PHTV Live] " fmt, ##__VA_ARGS__); \
    } \
} while(0)

@implementation AppDelegate (DockVisibility)

- (NSWindow *)currentSettingsWindow {
    for (NSWindow *window in [NSApp windows]) {
        NSString *identifier = window.identifier;
        // SwiftUI settings window id starts with "settings".
        if (identifier && [identifier hasPrefix:@"settings"]) {
            return window;
        }
    }
    return nil;
}

- (BOOL)isSettingsWindowVisible {
    NSWindow *window = [self currentSettingsWindow];
    return window != nil && window.isVisible;
}

- (void)handleShowDockIconNotification:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo ?: @{};
    BOOL desiredDockVisible = [[userInfo objectForKey:PHTVNotificationUserInfoVisibleKey] boolValue];
    BOOL shouldForceFront = [[userInfo objectForKey:PHTVNotificationUserInfoForceFrontKey] boolValue];

    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    BOOL sameAsLastRequest = self.hasLastDockVisibilityRequest &&
                             self.lastDockVisibilityRequest == desiredDockVisible &&
                             self.lastDockForceFrontRequest == shouldForceFront;
    if (sameAsLastRequest && !shouldForceFront &&
        (now - self.lastDockVisibilityRequestTime) < 0.20) {
        return;
    }
    self.hasLastDockVisibilityRequest = YES;
    self.lastDockVisibilityRequest = desiredDockVisible;
    self.lastDockForceFrontRequest = shouldForceFront;
    self.lastDockVisibilityRequestTime = now;

    PHTV_DOCK_LOG(@"handleShowDockIconNotification: visible=%d forceFront=%d",
                  desiredDockVisible, shouldForceFront);

    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL wasSettingsOpen = self.settingsWindowOpen;
        NSWindow *settingsWindow = [self currentSettingsWindow];
        BOOL settingsVisible = settingsWindow != nil && settingsWindow.isVisible;
        self.settingsWindowOpen = settingsVisible;
        BOOL shouldResetSession = wasSettingsOpen && !settingsVisible;

        if (settingsVisible) {
            // Keep regular activation policy while settings exists.
            [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

            if (shouldForceFront) {
                BOOL alreadyFront = NSApp.isActive &&
                    (settingsWindow.isKeyWindow || settingsWindow.isMainWindow);
                if (!alreadyFront) {
                    [NSApp activateIgnoringOtherApps:YES];
                    [settingsWindow makeKeyAndOrderFront:nil];
                    PHTV_DOCK_LOG(@"Brought settings window to front: %@", settingsWindow.identifier);
                }
            } else {
                PHTV_DOCK_LOG(@"Settings window visible; skip force front to avoid reopen loop");
            }
        } else {
            NSApplicationActivationPolicy policy =
                desiredDockVisible ? NSApplicationActivationPolicyRegular : NSApplicationActivationPolicyAccessory;
            [NSApp setActivationPolicy:policy];
            PHTV_DOCK_LOG(@"Dock icon restored to desired visibility: %d", desiredDockVisible);
        }

        // If settings just closed, reset session state to avoid stuck input context.
        if (shouldResetSession) {
            RequestNewSession();
            __unused NSInteger cacheStatus = [PHTVCacheStateService
                invalidateSpotlightCacheWithDedupWindowMs:PHTVSpotlightInvalidationDedupMs];
        }
    });
}

-(void)setDockIconVisible:(BOOL)visible {
    PHTV_DOCK_LOG(@"setDockIconVisible called with: %d", visible);

    // Track whether settings window is open (do not modify user preference key).
    self.settingsWindowOpen = visible;

    dispatch_async(dispatch_get_main_queue(), ^{
        if (visible) {
            [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
            [NSApp activateIgnoringOtherApps:YES];
        } else {
            BOOL userPrefersDock = [[NSUserDefaults standardUserDefaults] boolForKey:PHTVDefaultsKeyShowIconOnDock];
            NSApplicationActivationPolicy policy =
                userPrefersDock ? NSApplicationActivationPolicyRegular : NSApplicationActivationPolicyAccessory;
            [NSApp setActivationPolicy:policy];
        }
    });
}

-(void)showIcon:(BOOL)onDock {
    PHTV_DOCK_LOG(@"showIcon called with onDock: %d", onDock);

    [[NSUserDefaults standardUserDefaults] setBool:onDock forKey:PHTVDefaultsKeyShowIconOnDock];
    vShowIconOnDock = onDock ? 1 : 0;

    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self isSettingsWindowVisible]) {
            [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
            [NSApp activateIgnoringOtherApps:YES];

            for (NSWindow *window in [NSApp windows]) {
                NSString *identifier = window.identifier;
                if (identifier && [identifier hasPrefix:@"settings"]) {
                    [window makeKeyAndOrderFront:nil];
                    [window orderFrontRegardless];
                    break;
                }
            }
            return;
        }

        NSApplicationActivationPolicy policy =
            onDock ? NSApplicationActivationPolicyRegular : NSApplicationActivationPolicyAccessory;
        [NSApp setActivationPolicy: policy];

        if (onDock) {
            [NSApp activateIgnoringOtherApps:YES];
        }
    });
}

@end
