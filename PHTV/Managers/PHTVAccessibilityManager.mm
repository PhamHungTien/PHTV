//
//  PHTVAccessibilityManager.mm
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import "PHTVAccessibilityManager.h"
#import "PHTVAppDetectionManager.h"

// Safe Mode variable (moved from PHTV.mm)
static BOOL _vSafeMode = NO;

@implementation PHTVAccessibilityManager

#pragma mark - Initialization

+ (void)initialize {
    if (self == [PHTVAccessibilityManager class]) {
        // Load Safe Mode from user defaults
        _vSafeMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"SafeMode"];
    }
}

#pragma mark - AX Text Replacement

+ (BOOL)replaceFocusedTextViaAX:(NSInteger)backspaceCount insertText:(NSString*)insertText {
    // Placeholder - will be implemented when extracting 130-line function from PHTV.mm
    if (_vSafeMode) {
        return NO; // Skip AX API in Safe Mode
    }
    return NO;
}

#pragma mark - AX Session Recovery

+ (void)tryToRestoreSessionFromAX {
    // Placeholder - will be implemented when extracting from PHTV.mm
}

#pragma mark - Safe Mode

+ (BOOL)isSafeModeEnabled {
    return _vSafeMode;
}

+ (void)setSafeModeEnabled:(BOOL)enabled {
    _vSafeMode = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:@"SafeMode"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    if (enabled) {
        NSLog(@"[SafeMode] ENABLED - Accessibility API calls will be skipped");
    } else {
        NSLog(@"[SafeMode] DISABLED - Normal Accessibility API calls");
    }
}

#pragma mark - AX Error Logging

+ (void)logAXError:(AXError)error operation:(const char*)operation {
    if (error != kAXErrorSuccess) {
        NSLog(@"[AX Error] %s failed with error: %d", operation, error);
    }
}

@end
