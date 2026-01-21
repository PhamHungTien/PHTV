//
//  PHTVAccessibilityManager.mm
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import "PHTVAccessibilityManager.h"
#import "PHTVAppDetectionManager.h"
#import <os/log.h>

// AXValueType constant name differs across SDK versions.
#if defined(kAXValueTypeCFRange)
    #define PHTV_AXVALUE_CFRANGE_TYPE kAXValueTypeCFRange
#elif defined(kAXValueCFRangeType)
    #define PHTV_AXVALUE_CFRANGE_TYPE kAXValueCFRangeType
#else
    // Fallback for older SDKs where the CFRange constant isn't exposed.
    #define PHTV_AXVALUE_CFRANGE_TYPE ((AXValueType)4)
#endif

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
    // Safe Mode: Skip AX API calls entirely
    if (_vSafeMode) {
        return NO;
    }

    if (backspaceCount < 0) backspaceCount = 0;
    if (insertText == nil) insertText = @"";

    AXUIElementRef systemWide = AXUIElementCreateSystemWide();
    AXUIElementRef focusedElement = NULL;
    AXError error = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute, (CFTypeRef *)&focusedElement);
    CFRelease(systemWide);
    if (error != kAXErrorSuccess || focusedElement == NULL) {
        return NO;
    }

    // Read current value
    CFTypeRef valueRef = NULL;
    error = AXUIElementCopyAttributeValue(focusedElement, kAXValueAttribute, &valueRef);
    if (error != kAXErrorSuccess) {
        CFRelease(focusedElement);
        return NO;
    }
    NSString *valueStr = (valueRef && CFGetTypeID(valueRef) == CFStringGetTypeID()) ? (__bridge NSString *)valueRef : @"";

    // Read caret position and selected text range
    CFTypeRef rangeRef = NULL;
    NSInteger caretLocation = (NSInteger)valueStr.length;
    NSInteger selectedLength = 0;
    error = AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextRangeAttribute, &rangeRef);
    if (error == kAXErrorSuccess && rangeRef && CFGetTypeID(rangeRef) == AXValueGetTypeID()) {
        CFRange sel;
        if (AXValueGetValue((AXValueRef)rangeRef, PHTV_AXVALUE_CFRANGE_TYPE, &sel)) {
            caretLocation = (NSInteger)sel.location;
            selectedLength = (NSInteger)sel.length;
        }
    }
    if (rangeRef) CFRelease(rangeRef);

    // Clamp
    if (caretLocation < 0) caretLocation = 0;
    if (caretLocation > (NSInteger)valueStr.length) caretLocation = (NSInteger)valueStr.length;

    // Calculate replacement position
    NSInteger start;

    // If there's selected text, replace it instead of using backspaceCount
    if (selectedLength > 0) {
        // User has highlighted text - replace the selected range
        start = caretLocation;
    } else {
        // No selection - use backspaceCount to calculate how much to delete
        start = caretLocation - backspaceCount;
    }

    if (start < 0) start = 0;

    // Calculate replacement length
    NSInteger len;

    if (selectedLength > 0) {
        // User has selected text - use the selected length
        len = selectedLength;
    } else {
        // No selection - use backspaceCount to calculate deletion length
        if (backspaceCount > 0 && start < caretLocation) {
            NSString *textToDelete = [valueStr substringWithRange:NSMakeRange(start, caretLocation - start)];
            // Get composed form length - this is what engine expects
            NSString *composedText = [textToDelete precomposedStringWithCanonicalMapping];
            NSInteger composedLen = (NSInteger)composedText.length;

            // If composed length differs from backspaceCount, the text in Spotlight
            // may be in decomposed form - recalculate start position
            if (composedLen != backspaceCount && composedLen > 0) {
                // Try to find correct start by counting composed characters backwards
                NSInteger actualStart = caretLocation;
                NSInteger composedCount = 0;
                while (actualStart > 0 && composedCount < backspaceCount) {
                    actualStart--;
                    // Check if this is a base character (not combining mark)
                    unichar c = [valueStr characterAtIndex:actualStart];
                    // Skip combining marks (0x0300-0x036F, 0x1DC0-0x1DFF, etc.)
                    if (!(c >= 0x0300 && c <= 0x036F) &&
                        !(c >= 0x1DC0 && c <= 0x1DFF) &&
                        !(c >= 0x20D0 && c <= 0x20FF) &&
                        !(c >= 0xFE20 && c <= 0xFE2F)) {
                        composedCount++;
                    }
                }
                start = actualStart;
            }
        }

        len = caretLocation - start;
    }

    // Clamp length to valid range
    if (start + len > (NSInteger)valueStr.length) len = (NSInteger)valueStr.length - start;
    if (len < 0) len = 0;

    NSString *newValue = [valueStr stringByReplacingCharactersInRange:NSMakeRange(start, len) withString:insertText];

    // Write new value
    AXError writeError = AXUIElementSetAttributeValue(focusedElement, kAXValueAttribute, (__bridge CFTypeRef)newValue);
    if (writeError != kAXErrorSuccess) {
        [self logAXError:writeError operation:"AXUIElementSetAttributeValue(kAXValueAttribute)"];
        if (valueRef) CFRelease(valueRef);
        CFRelease(focusedElement);
        return NO;
    }

    // Set caret position
    NSInteger newCaret = start + (NSInteger)insertText.length;
    CFRange newSel = CFRangeMake(newCaret, 0);
    AXValueRef newRange = AXValueCreate(PHTV_AXVALUE_CFRANGE_TYPE, &newSel);
    if (newRange) {
        AXUIElementSetAttributeValue(focusedElement, kAXSelectedTextRangeAttribute, newRange);
        CFRelease(newRange);
    }

    if (valueRef) CFRelease(valueRef);
    CFRelease(focusedElement);
    return YES;
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
#ifdef DEBUG
    if (error != kAXErrorSuccess) {
        const char *errorStr = "Unknown";
        switch (error) {
            case kAXErrorFailure: errorStr = "Failure"; break;
            case kAXErrorIllegalArgument: errorStr = "IllegalArgument"; break;
            case kAXErrorInvalidUIElement: errorStr = "InvalidUIElement"; break;
            case kAXErrorInvalidUIElementObserver: errorStr = "InvalidUIElementObserver"; break;
            case kAXErrorCannotComplete: errorStr = "CannotComplete"; break;
            case kAXErrorAttributeUnsupported: errorStr = "AttributeUnsupported"; break;
            case kAXErrorActionUnsupported: errorStr = "ActionUnsupported"; break;
            case kAXErrorNotificationUnsupported: errorStr = "NotificationUnsupported"; break;
            case kAXErrorNotImplemented: errorStr = "NotImplemented"; break;
            case kAXErrorNotificationAlreadyRegistered: errorStr = "NotificationAlreadyRegistered"; break;
            case kAXErrorNotificationNotRegistered: errorStr = "NotificationNotRegistered"; break;
            case kAXErrorAPIDisabled: errorStr = "APIDisabled"; break;
            case kAXErrorNoValue: errorStr = "NoValue"; break;
            case kAXErrorParameterizedAttributeUnsupported: errorStr = "ParameterizedAttributeUnsupported"; break;
            case kAXErrorNotEnoughPrecision: errorStr = "NotEnoughPrecision"; break;
            default: break;
        }
        NSLog(@"[AX] %s failed: %s (code %d)", operation, errorStr, (int)error);
    }
#endif
}

@end
