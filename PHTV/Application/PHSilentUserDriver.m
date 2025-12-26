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

@end
