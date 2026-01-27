//
//  PHSilentUserDriver.m
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import "PHSilentUserDriver.h"

@implementation PHSilentUserDriver

- (instancetype)initWithHostBundle:(NSBundle *)hostBundle delegate:(id<SPUStandardUserDriverDelegate>)delegate {
    self = [super initWithHostBundle:hostBundle delegate:delegate];
    if (self) {
        // Load auto-install setting from UserDefaults
        // Default to YES if not set
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if ([defaults objectForKey:@"vAutoInstallUpdates"] == nil) {
            _silentAutoInstallEnabled = YES;
        } else {
            _silentAutoInstallEnabled = [defaults boolForKey:@"vAutoInstallUpdates"];
        }

        // Observe changes to auto-install setting
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleAutoInstallSettingChanged:)
                                                     name:NSUserDefaultsDidChangeNotification
                                                   object:nil];

        NSLog(@"[PHSilentUserDriver] Initialized - silent auto-install: %@", _silentAutoInstallEnabled ? @"ON" : @"OFF");
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)handleAutoInstallSettingChanged:(NSNotification *)notification {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL newValue = [defaults boolForKey:@"vAutoInstallUpdates"];
    if (newValue != _silentAutoInstallEnabled) {
        _silentAutoInstallEnabled = newValue;
        NSLog(@"[PHSilentUserDriver] Silent auto-install changed to: %@", _silentAutoInstallEnabled ? @"ON" : @"OFF");
    }
}

#pragma mark - SPUUserDriver Protocol Methods (Sparkle 2.x)

/// Called when an update is found
/// This is the main method to handle update installation
- (void)showUpdateFoundWithAppcastItem:(SUAppcastItem *)appcastItem
                                 state:(SPUUserUpdateState *)state
                                 reply:(void (^)(SPUUserUpdateChoice))reply {
    NSLog(@"[PHSilentUserDriver] Update found: %@ (state: %ld, userInitiated: %@)",
          appcastItem.displayVersionString,
          (long)state.stage,
          state.userInitiated ? @"YES" : @"NO");

    // Send notification to SwiftUI for custom banner (if needed for UI feedback)
    NSDictionary *info = @{
        @"version": appcastItem.displayVersionString ?: @"",
        @"releaseNotes": appcastItem.itemDescription ?: @"",
        @"downloadURL": appcastItem.fileURL.absoluteString ?: @""
    };
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SparkleUpdateFound" object:info];

    // If silent auto-install is enabled, immediately install
    if (self.silentAutoInstallEnabled) {
        NSLog(@"[PHSilentUserDriver] Silent auto-install enabled - installing update automatically");
        reply(SPUUserUpdateChoiceInstall);
        return;
    }

    // If not auto-install, show custom update banner via notification
    NSLog(@"[PHSilentUserDriver] Showing custom update UI");
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SparkleShowUpdateBanner" object:info];

    // Dismiss the standard UI since we're using custom UI
    // The user will trigger install via our custom banner
    reply(SPUUserUpdateChoiceDismiss);
}

/// Called when no update is found
/// We suppress this for background checks (handled by SparkleManager.isManualCheck)
- (void)showUpdateNotFoundWithError:(NSError *)error
                    acknowledgement:(void (^)(void))acknowledgement {
    NSLog(@"[PHSilentUserDriver] No update found (error: %@)", error.localizedDescription ?: @"none");

    // Just acknowledge - SparkleManager will handle showing UI for manual checks only
    // This prevents the annoying "You're up to date" dialog for background checks
    if (acknowledgement) {
        acknowledgement();
    }
}

/// Called when there's an updater error (network, appcast parsing, etc)
/// We suppress these silently
- (void)showUpdaterError:(NSError *)error acknowledgement:(void (^)(void))acknowledgement {
    NSLog(@"[PHSilentUserDriver] Updater error suppressed: %@ (code: %ld)",
          error.localizedDescription, (long)error.code);

    // Silently acknowledge errors - don't show annoying alerts
    if (acknowledgement) {
        acknowledgement();
    }
}

/// Called when download starts - we can track progress silently
- (void)showDownloadInitiatedWithCancellation:(void (^)(void))cancellation {
    NSLog(@"[PHSilentUserDriver] Download initiated");
    // Let download proceed without showing UI
    [super showDownloadInitiatedWithCancellation:cancellation];
}

/// Called when extraction/installation is ready
- (void)showReadyToInstallAndRelaunch:(void (^)(SPUUserUpdateChoice))reply {
    NSLog(@"[PHSilentUserDriver] Ready to install and relaunch");

    if (self.silentAutoInstallEnabled) {
        NSLog(@"[PHSilentUserDriver] Auto-installing and relaunching");
        reply(SPUUserUpdateChoiceInstall);
    } else {
        // Show notification that update is ready
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SparkleUpdateReadyToInstall" object:nil];
        // Let user decide via our custom UI
        reply(SPUUserUpdateChoiceDismiss);
    }
}

// showInstallingUpdate removed - deprecated in Sparkle 2.x

/// Called when update has been installed and app will relaunch
- (void)showUpdateInstalledAndRelaunched:(BOOL)relaunched acknowledgement:(void (^)(void))acknowledgement {
    NSLog(@"[PHSilentUserDriver] Update installed (relaunched: %@)", relaunched ? @"YES" : @"NO");
    if (acknowledgement) {
        acknowledgement();
    }
}

@end
