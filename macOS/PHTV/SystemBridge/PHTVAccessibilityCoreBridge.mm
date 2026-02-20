//
//  PHTVAccessibilityCoreBridge.mm
//  PHTV
//
//  C bridge helpers for Accessibility startup checks.
//

#import "PHTVCoreBridge.h"

extern "C" BOOL PHTVRunAccessibilitySmokeTest(void) {
    @try {
        AXUIElementRef testSystemWide = AXUIElementCreateSystemWide();
        if (testSystemWide != NULL) {
            CFRelease(testSystemWide);
        }
        return YES;
    }
    @catch (NSException *exception) {
        return NO;
    }
}
