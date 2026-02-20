//
//  PHTVAccessibilityManager.mm
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import "PHTVAccessibilityManager.h"
#import "PHTV-Swift.h"
#import <AppKit/AppKit.h>
#import "PHTVManager.h"
#import <unistd.h>

// External declarations for AX
extern Boolean AXIsProcessTrustedWithOptions(CFDictionaryRef options) __attribute__((weak_import));
extern CFStringRef kAXTrustedCheckOptionPrompt __attribute__((weak_import));

// AXValueType constant name differs across SDK versions.
#if defined(kAXValueTypeCFRange)
    #define PHTV_AXVALUE_CFRANGE_TYPE kAXValueTypeCFRange
#elif defined(kAXValueCFRangeType)
    #define PHTV_AXVALUE_CFRANGE_TYPE kAXValueCFRangeType
#else
    // Fallback for older SDKs where the CFRange constant isn't exposed.
    #define PHTV_AXVALUE_CFRANGE_TYPE ((AXValueType)4)
#endif

#ifdef __cplusplus
extern "C" {
#endif
extern BOOL vSafeMode;
#ifdef __cplusplus
}
#endif

@implementation PHTVAccessibilityManager

#pragma mark - Initialization

+ (void)initialize {
    if (self == [PHTVAccessibilityManager class]) {
        // Load Safe Mode from user defaults
        vSafeMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"SafeMode"];
    }
}

#pragma mark - AX Text Replacement

+ (BOOL)replaceFocusedTextViaAX:(NSInteger)backspaceCount insertText:(NSString*)insertText {
    return [self replaceFocusedTextViaAX:backspaceCount insertText:insertText verify:NO];
}

+ (BOOL)replaceFocusedTextViaAX:(NSInteger)backspaceCount insertText:(NSString*)insertText verify:(BOOL)verify {
    // Safe Mode: Skip AX API calls entirely
    if (vSafeMode) {
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
    NSInteger start = caretLocation;
    NSInteger len = 0;
    BOOL selectionAtEnd = (selectedLength > 0 && caretLocation + selectedLength == (NSInteger)valueStr.length);

    if (selectedLength > 0 && !selectionAtEnd) {
        // User has highlighted text in-place - replace the selected range only
        start = caretLocation;
        len = selectedLength;
    } else {
        // No selection OR Spotlight autocomplete suffix selection.
        // Always respect backspaceCount to keep IME state consistent.
        NSInteger deleteStart = [PHTVAccessibilityService calculateDeleteStartForAX:valueStr
                                                                       caretLocation:caretLocation
                                                                      backspaceCount:backspaceCount];
        if (selectionAtEnd) {
            start = deleteStart;
            len = (caretLocation - deleteStart) + selectedLength;
        } else {
            start = deleteStart;
            len = caretLocation - deleteStart;
        }
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

    if (verify) {
        // Verify the value actually changed (Spotlight may ignore sets or apply async).
        BOOL verified = NO;
        for (int attempt = 0; attempt < 2; attempt++) {
            CFTypeRef verifyValueRef = NULL;
            AXError verifyError = AXUIElementCopyAttributeValue(focusedElement, kAXValueAttribute, &verifyValueRef);
            NSString *verifyStr = (verifyError == kAXErrorSuccess && verifyValueRef &&
                                   CFGetTypeID(verifyValueRef) == CFStringGetTypeID())
                ? (__bridge NSString *)verifyValueRef : @"";
            if (verifyValueRef) CFRelease(verifyValueRef);
            if (verifyError == kAXErrorSuccess) {
                if ([PHTVAccessibilityService stringEqualCanonicalForAX:verifyStr rhs:newValue]) {
                    verified = YES;
                    break;
                }
                if (selectionAtEnd &&
                    [PHTVAccessibilityService stringHasCanonicalPrefixForAX:verifyStr prefix:newValue]) {
                    verified = YES;
                    break;
                }
            }
            if (attempt == 0) {
                usleep(2000);
            }
        }
        if (!verified) {
            if (valueRef) CFRelease(valueRef);
            CFRelease(focusedElement);
            return NO;
        }
    }

    if (valueRef) CFRelease(valueRef);
    CFRelease(focusedElement);
    return YES;
}

#pragma mark - AX Context Detection

+ (void)invalidateAddressBarCache {
    [PHTVAccessibilityService invalidateAddressBarCache];
}

+ (BOOL)isNotionCodeBlock {
    if (vSafeMode) return NO;
    return [PHTVAccessibilityService isNotionCodeBlock];
}

+ (BOOL)isTerminalPanelFocused {
    if (vSafeMode) return NO;
    return [PHTVAccessibilityService isTerminalPanelFocused];
}

+ (BOOL)isFocusedElementAddressBar {
    if (vSafeMode) return NO;
    return [PHTVAccessibilityService isFocusedElementAddressBar];
}

#pragma mark - Safe Mode

+ (BOOL)isSafeModeEnabled {
    return vSafeMode;
}

+ (void)setSafeModeEnabled:(BOOL)enabled {
    vSafeMode = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:@"SafeMode"];

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

#pragma mark - Permission UI

+ (void)openAccessibilityPreferences {
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

@end
