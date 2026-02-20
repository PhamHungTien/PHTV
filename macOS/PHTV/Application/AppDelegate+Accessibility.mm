//
//  AppDelegate+Accessibility.mm
//  PHTV
//
//  Accessibility lifecycle extracted from AppDelegate to reduce coupling.
//

#import "AppDelegate+Accessibility.h"
#import "AppDelegate+Private.h"
#import "AppDelegate+UIActions.h"
#import "../SystemBridge/PHTVManager.h"
#import "PHTV-Swift.h"
#include <unistd.h>

@implementation AppDelegate (Accessibility)

- (void)startAccessibilityMonitoring {
    [self startAccessibilityMonitoringWithInterval:[self currentMonitoringInterval] resetState:YES];
}

// Start monitoring with specific interval
- (void)startAccessibilityMonitoringWithInterval:(NSTimeInterval)interval {
    // Default: reset state (for backward compatibility)
    [self startAccessibilityMonitoringWithInterval:interval resetState:YES];
}

// Start monitoring with specific interval, optionally resetting state
- (void)startAccessibilityMonitoringWithInterval:(NSTimeInterval)interval resetState:(BOOL)resetState {
    // Stop existing timer if any
    [self stopAccessibilityMonitoring];

    // CRITICAL: Uses test event tap creation - ONLY reliable method (Apple recommended)
    // MJAccessibilityIsEnabled() returns TRUE even when permission is revoked!
    // Dynamic interval: 1.0s when waiting for permission, 20s when granted (lower overhead)
    self.accessibilityMonitor = [NSTimer scheduledTimerWithTimeInterval:interval
                                                                  target:self
                                                                selector:@selector(checkAccessibilityStatus)
                                                                userInfo:nil
                                                                 repeats:YES];
    if (@available(macOS 10.12, *)) {
        // Small tolerance reduces wakeups while keeping fast detection
        self.accessibilityMonitor.tolerance = interval * 0.2;
    }

    // ONLY set initial state on first start, NOT when just changing interval
    // This fixes the bug where permission grant detection fails because state is reset mid-check
    if (resetState) {
        self.wasAccessibilityEnabled = [PHTVManager canCreateEventTap];
    }

    NSLog(@"[Accessibility] Started monitoring via test event tap (interval: %.1fs, resetState: %@)", interval, resetState ? @"YES" : @"NO");
}

// Get appropriate monitoring interval based on current permission state
- (NSTimeInterval)currentMonitoringInterval {
    // When waiting for permission: check every 1.0 seconds
    // When permission granted: check every 20 seconds to reduce overhead
    return self.wasAccessibilityEnabled ? 20.0 : 1.0;
}

- (void)stopAccessibilityMonitoring {
    if (self.accessibilityMonitor) {
        [self.accessibilityMonitor invalidate];
        self.accessibilityMonitor = nil;
#ifdef DEBUG
        NSLog(@"[Accessibility] Stopped monitoring");
#endif
    }
}

- (void)startHealthCheckMonitoring {
    [self stopHealthCheckMonitoring];
    // Lower frequency monitoring to reduce wakeups while keeping idle recovery
    // Event-based checks handle active typing; timer covers idle periods
    self.healthCheckTimer = [NSTimer scheduledTimerWithTimeInterval:10.0
                                                              target:self
                                                            selector:@selector(runHealthCheck)
                                                            userInfo:nil
                                                             repeats:YES];
    if (@available(macOS 10.12, *)) {
        self.healthCheckTimer.tolerance = 1.0;
    }
}

- (void)stopHealthCheckMonitoring {
    if (self.healthCheckTimer) {
        [self.healthCheckTimer invalidate];
        self.healthCheckTimer = nil;
    }
}

- (void)runHealthCheck {
    // Skip checks if accessibility permission is missing; restart flow will handle it
    // Use test tap - reliable check (MJAccessibilityIsEnabled is unreliable)
    if (![PHTVManager canCreateEventTap]) {
        return;
    }
    [PHTVManager ensureEventTapAlive];
}

- (void)checkAccessibilityStatus {
    // CRITICAL: Use test event tap creation - ONLY reliable way to check permission
    // MJAccessibilityIsEnabled() returns TRUE even after user removes app from list
    BOOL isEnabled = [PHTVManager canCreateEventTap];

    // Only log and notify when status CHANGES (reduce console spam and CPU)
    BOOL statusChanged = (self.wasAccessibilityEnabled != isEnabled);

    if (statusChanged) {
        NSLog(@"[Accessibility] Status CHANGED: was=%@, now=%@",
              self.wasAccessibilityEnabled ? @"YES" : @"NO",
              isEnabled ? @"YES" : @"NO");

        // Notify SwiftUI only on change
        [[NSNotificationCenter defaultCenter] postNotificationName:@"AccessibilityStatusChanged"
                                                            object:@(isEnabled)];

        // IMPORTANT: Restart timer with appropriate interval based on new permission state
        // When permission granted: switch to 20s interval (low overhead)
        // When permission revoked: switch to 1.0s interval
        // CRITICAL: resetState:NO to preserve wasAccessibilityEnabled for transition detection below
        NSTimeInterval newInterval = isEnabled ? 20.0 : 1.0;
        NSLog(@"[Accessibility] Adjusting monitoring interval to %.1fs", newInterval);
        [self startAccessibilityMonitoringWithInterval:newInterval resetState:NO];
    }

    // Permission was just granted (transition from disabled to enabled)
    if (!self.wasAccessibilityEnabled && isEnabled) {
        NSLog(@"[Accessibility] ✅ Permission GRANTED (via test tap) - Initializing...");
        self.accessibilityStableCount = 0;
        [self performAccessibilityGrantedRestart];
    }
    // Permission was revoked while app is running (transition from enabled to disabled)
    else if (self.wasAccessibilityEnabled && !isEnabled) {
        NSLog(@"[Accessibility] 🛑 CRITICAL - Permission REVOKED (test tap failed)!");
        self.accessibilityStableCount = 0;
        [self handleAccessibilityRevoked];
    }
    else if (isEnabled) {
        // Permission stable - increment counter
        self.accessibilityStableCount++;
    }

    // Update state
    self.wasAccessibilityEnabled = isEnabled;
}

- (void)performAccessibilityGrantedRestart {
    NSLog(@"[Accessibility] Permission granted - Initializing event tap...");

    // Save current version to track successful permission grant
    NSString *currentVersion = [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
    [[NSUserDefaults standardUserDefaults] setObject:currentVersion forKey:@"LastRunVersion"];

    // Stop monitoring (permission granted)
    [self stopAccessibilityMonitoring];

    // Invalidate permission cache to ensure fresh check
    [PHTVManager invalidatePermissionCache];

    // Initialize event tap with retry mechanism
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL initSuccess = NO;

        // Try up to 3 times with delays to handle TCC propagation
        for (int attempt = 1; attempt <= 3; attempt++) {
            NSLog(@"[EventTap] Init attempt %d/3", attempt);

            if ([PHTVManager initEventTap]) {
                NSLog(@"[EventTap] Initialized successfully on attempt %d - App ready!", attempt);
                initSuccess = YES;
                break;
            }

            if (attempt < 3) {
                // Wait progressively longer between attempts
                usleep(100000 * attempt);  // 100ms, 200ms

                // Force permission recheck
                [PHTVManager invalidatePermissionCache];
            }
        }

        if (!initSuccess) {
            NSLog(@"[EventTap] Failed to initialize after 3 attempts");

            // Show alert suggesting relaunch
            NSAlert *alert = [[NSAlert alloc] init];
            [alert setMessageText:@"🔄 Cần khởi động lại ứng dụng"];
            [alert setInformativeText:@"PHTV đã nhận quyền nhưng cần khởi động lại để quyền có hiệu lực.\n\nBạn có muốn khởi động lại ngay không?"];
            [alert addButtonWithTitle:@"Khởi động lại ngay"];
            [alert addButtonWithTitle:@"Để sau"];
            [alert setAlertStyle:NSAlertStyleInformational];

            NSModalResponse response = [alert runModal];
            if (response == NSAlertFirstButtonReturn) {
                [self relaunchAppAfterPermissionGrant];
            } else {
                [self onControlPanelSelected];
            }
        } else {
            // Success - start normal operation

            // Start monitoring for permission revocation
            [self startAccessibilityMonitoring];
            [self startHealthCheckMonitoring];

            // Start TCC notification listener
            [PHTVManager startTCCNotificationListener];

            // Update menu bar to normal state
            [self fillDataWithAnimation:YES];

            // Show UI if requested
            NSInteger showui = [[NSUserDefaults standardUserDefaults] integerForKey:@"ShowUIOnStartup"];
            if (showui == 1) {
                [self onControlPanelSelected];
            }

            // Clear first-launch relaunch flag - we now initialize immediately without restart
            if (self.needsRelaunchAfterPermission) {
                self.needsRelaunchAfterPermission = NO;
                NSLog(@"[Accessibility] Initialized successfully - skipping forced relaunch");
            }
        }
        [self setQuickConvertString];
    });
}

- (void)relaunchAppAfterPermissionGrant {
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    if (bundlePath.length == 0) {
        NSLog(@"[Accessibility] Relaunch skipped: bundle path missing");
        return;
    }

    NSURL *bundleURL = [NSURL fileURLWithPath:bundlePath];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (@available(macOS 10.15, *)) {
            NSWorkspaceOpenConfiguration *config = [NSWorkspaceOpenConfiguration configuration];
            [[NSWorkspace sharedWorkspace] openApplicationAtURL:bundleURL
                                                  configuration:config
                                              completionHandler:^(NSRunningApplication * _Nullable app, NSError * _Nullable error) {
                if (error) {
                    NSLog(@"[Accessibility] Relaunch failed: %@", error.localizedDescription ?: @"unknown error");
                    return;
                }
                NSLog(@"[Accessibility] Relaunching app to finalize permission");
                [NSApp terminate:nil];
            }];
        } else {
            // Fallback for older macOS versions
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            NSError *error = nil;
            NSRunningApplication *app = [[NSWorkspace sharedWorkspace] launchApplicationAtURL:bundleURL
                                                                                      options:NSWorkspaceLaunchDefault
                                                                                configuration:@{}
                                                                                        error:&error];
#pragma clang diagnostic pop
            if (!app) {
                NSLog(@"[Accessibility] Relaunch failed: %@", error.localizedDescription ?: @"unknown error");
                return;
            }
            NSLog(@"[Accessibility] Relaunching app to finalize permission");
            [NSApp terminate:nil];
        }
    });
}

- (void)handleAccessibilityRevoked {
    // CRITICAL: Stop event tap IMMEDIATELY on MAIN THREAD to prevent system freeze
    // CFRunLoopRemoveSource MUST be called on the same thread it was added (main thread)
    if ([PHTVManager isInited]) {
        NSLog(@"🛑 CRITICAL: Accessibility revoked! Stopping event tap immediately...");
        [PHTVManager stopEventTap];
    }

    // Show alert
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"⚠️  Quyền trợ năng đã bị tắt!"];
        [alert setInformativeText:@"PHTV cần quyền trợ năng để hoạt động.\n\nỨng dụng sẽ tự động hoạt động lại khi bạn cấp quyền."];
        [alert setAlertStyle:NSAlertStyleWarning];
        [alert addButtonWithTitle:@"Mở cài đặt"];
        [alert addButtonWithTitle:@"Đóng"];

        NSModalResponse response = [alert runModal];
        if (response == NSAlertFirstButtonReturn) {
            [PHTVAccessibilityService openAccessibilityPreferences];

            // Invalidate cache for fresh permission check
            [PHTVManager invalidatePermissionCache];
            NSLog(@"[Accessibility] User opening System Settings to re-grant");
        }

        // Update menu bar to show disabled state
        if (self.statusItem && self.statusItem.button) {
            NSFont *statusFont = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightSemibold];
            NSDictionary *attributes = @{
                NSFontAttributeName: statusFont,
                NSForegroundColorAttributeName: [NSColor systemRedColor]
            };
            NSAttributedString *title = [[NSAttributedString alloc] initWithString:@"⚠️" attributes:attributes];
            self.statusItem.button.attributedTitle = title;
        }
    });

    // Attempt automatic TCC repair if the app vanished from the Accessibility list
    [self attemptAutomaticTCCRepairIfNeeded];
}

// Auto-repair flow for corrupted/missing TCC entries (macOS occasionally drops the app from the list)
- (void)attemptAutomaticTCCRepairIfNeeded {
    if (self.isAttemptingTCCRepair || self.didAttemptTCCRepairOnce) {
        return;
    }
    self.isAttemptingTCCRepair = YES;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        BOOL isCorrupt = [PHTVManager isTCCEntryCorrupt];
        if (!isCorrupt) {
            self.isAttemptingTCCRepair = NO;
            return;
        }

        NSLog(@"[Accessibility] ⚠️ TCC entry missing/corrupt - attempting automatic repair");

        NSError *error = nil;
        BOOL fixed = [PHTVManager autoFixTCCEntryWithError:&error];
        if (fixed) {
            NSLog(@"[Accessibility] ✅ TCC auto-repair succeeded, restarting tccd...");
            [PHTVManager restartTCCDaemon];
            [PHTVManager invalidatePermissionCache];

            dispatch_async(dispatch_get_main_queue(), ^{
                // Immediately resume fast monitoring to detect the new permission
                [self startAccessibilityMonitoringWithInterval:0.3 resetState:YES];
            });
        } else {
            NSLog(@"[Accessibility] ❌ TCC auto-repair failed: %@", error.localizedDescription ?: @"unknown error");
        }

        self.didAttemptTCCRepairOnce = YES;
        self.isAttemptingTCCRepair = NO;
    });
}

// Handle when app needs relaunch for permission to take effect
// This is triggered when AXIsProcessTrusted=YES but CGEventTapCreate fails persistently
// This happens because macOS TCC cache is not invalidated for the running process
- (void)handleAccessibilityNeedsRelaunch {
    static BOOL isShowingRelaunchAlert = NO;

    // Prevent showing multiple alerts
    if (isShowingRelaunchAlert) {
        return;
    }

    isShowingRelaunchAlert = YES;
    NSLog(@"[Accessibility] 🔄 Handling relaunch request - permission granted but not effective yet");

    dispatch_async(dispatch_get_main_queue(), ^{
        // First, try to initialize event tap one more time
        // Sometimes it works after a short delay
        if (![PHTVManager isInited]) {
            NSLog(@"[Accessibility] Attempting event tap initialization before relaunch prompt...");
            if ([PHTVManager initEventTap]) {
                NSLog(@"[Accessibility] ✅ Event tap initialized successfully! No relaunch needed.");
                isShowingRelaunchAlert = NO;

                // Update UI and start monitoring
                [self startAccessibilityMonitoring];
                [self startHealthCheckMonitoring];
                [self fillDataWithAnimation:YES];
                return;
            }
        }

        // Event tap still won't initialize - show relaunch prompt
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"🔄 Cần khởi động lại ứng dụng"];
        [alert setInformativeText:@"PHTV đã nhận được quyền trợ năng từ hệ thống, nhưng cần khởi động lại để quyền có hiệu lực.\n\nĐây là yêu cầu bảo mật của macOS. Bạn có muốn khởi động lại ngay không?"];
        [alert setAlertStyle:NSAlertStyleInformational];
        [alert addButtonWithTitle:@"Khởi động lại"];
        [alert addButtonWithTitle:@"Để sau"];

        NSModalResponse response = [alert runModal];
        isShowingRelaunchAlert = NO;

        if (response == NSAlertFirstButtonReturn) {
            NSLog(@"[Accessibility] User requested relaunch to apply permission");
            [self relaunchAppAfterPermissionGrant];
        } else {
            NSLog(@"[Accessibility] User deferred relaunch");
        }
    });
}

- (void)checkAccessibilityAndRestart {
    // Legacy method - kept for compatibility
    // Now handled by checkAccessibilityStatus
    // Use test tap - reliable check (MJAccessibilityIsEnabled is unreliable)
    if ([PHTVManager canCreateEventTap]) {
        [self performAccessibilityGrantedRestart];
    }
}

@end
