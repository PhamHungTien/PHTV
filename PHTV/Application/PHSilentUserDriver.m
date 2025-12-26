//
//  PHSilentUserDriver.m
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import "PHSilentUserDriver.h"

@implementation PHSilentUserDriver

/// Override to suppress "no update found" alert
/// This method is called when user manually checks for updates and none are available
- (void)showUpdateNotFoundWithError:(NSError *)error acknowledgement:(void (^)(void))acknowledgement {
    NSLog(@"[PHSilentUserDriver] Update not found - silently acknowledging (no alert shown)");

    // Simply acknowledge without showing any UI
    // This prevents the annoying "You're up to date" dialog
    if (acknowledgement) {
        acknowledgement();
    }
}

/// Override to suppress appcast load error alerts
/// This method is called when appcast.xml cannot be loaded (network error, 404, etc)
- (void)showUpdaterError:(NSError *)error acknowledgement:(void (^)(void))acknowledgement {
    NSLog(@"[PHSilentUserDriver] Updater error suppressed: %@ (Code: %ld)", error.localizedDescription, (long)error.code);

    // Silently handle common network errors (no internet, 404, timeout, etc)
    // Only log for debugging, don't show annoying alerts to user

    // Common error codes to suppress:
    // - NSURLErrorNotConnectedToInternet (-1009)
    // - NSURLErrorTimedOut (-1001)
    // - NSURLErrorCannotFindHost (-1003)
    // - HTTP 404 errors

    if (acknowledgement) {
        acknowledgement();
    }
}

/// Override to suppress general update alerts
- (void)showUpdateAlert:(SPUUserUpdateChoice *)updateChoice
              forUpdate:(SUAppcastItem *)updateItem
                  state:(SPUUserUpdateState *)state
        acknowledgement:(void (^)(void))acknowledgement {
    NSLog(@"[PHSilentUserDriver] Showing custom update UI instead of default alert");

    // Let SparkleManager handle showing custom UI via notifications
    // Don't show default Sparkle alerts

    if (acknowledgement) {
        acknowledgement();
    }
}

@end
