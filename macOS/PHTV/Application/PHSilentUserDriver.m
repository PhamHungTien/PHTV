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
        // Auto-install is now always enabled for all users.
        NSLog(@"[PHSilentUserDriver] Initialized - silent auto-install: ON");
    }
    return self;
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

    NSLog(@"[PHSilentUserDriver] Silent auto-install enabled - installing update automatically");
    reply(SPUUserUpdateChoiceInstall);
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
    NSLog(@"[PHSilentUserDriver] Auto-installing and relaunching");
    reply(SPUUserUpdateChoiceInstall);
}

/// Called when update has been installed and app will relaunch
- (void)showUpdateInstalledAndRelaunched:(BOOL)relaunched acknowledgement:(void (^)(void))acknowledgement {
    NSLog(@"[PHSilentUserDriver] Update installed (relaunched: %@)", relaunched ? @"YES" : @"NO");
    if (acknowledgement) {
        acknowledgement();
    }
}

@end
