//
//  PHTVAccessibilityManager.mm
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import "PHTVAccessibilityManager.h"
#import "PHTVAppDetectionManager.h"
#import "PHTV-Swift.h"
#import <AppKit/AppKit.h>
#import "PHTVManager.h"
#import <os/log.h>
#import <mach/mach_time.h>
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
NSString* getFocusedAppBundleId(void);
#ifdef __cplusplus
}
#endif

static BOOL _lastAddressBarResult = NO;
static uint64_t _lastAddressBarCheckTime = 0;

static NSString *PHTVGetFocusedWindowTitleForFrontmostApp(void) {
    if (__atomic_load_n(&vSafeMode, __ATOMIC_RELAXED)) return nil;
    NSRunningApplication *frontmost = [[NSWorkspace sharedWorkspace] frontmostApplication];
    if (!frontmost) return nil;

    AXUIElementRef appEl = AXUIElementCreateApplication(frontmost.processIdentifier);
    if (!appEl) return nil;

    NSString *title = nil;
    CFTypeRef focusedWindow = NULL;
    if (AXUIElementCopyAttributeValue(appEl, kAXFocusedWindowAttribute, &focusedWindow) == kAXErrorSuccess &&
        focusedWindow != NULL) {
        CFTypeRef titleRef = NULL;
        if (AXUIElementCopyAttributeValue((AXUIElementRef)focusedWindow, kAXTitleAttribute, &titleRef) == kAXErrorSuccess) {
            if (titleRef && CFGetTypeID(titleRef) == CFStringGetTypeID()) {
                title = [(__bridge NSString *)titleRef copy];
            }
            if (titleRef) CFRelease(titleRef);
        }
        CFRelease(focusedWindow);
    }
    CFRelease(appEl);
    return title;
}

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
    _lastAddressBarCheckTime = 0;
    _lastAddressBarResult = NO;
}

+ (BOOL)isNotionCodeBlock {
    if (vSafeMode) return NO;

    AXUIElementRef systemWide = AXUIElementCreateSystemWide();
    AXUIElementRef focusedElement = NULL;
    BOOL isCodeBlock = NO;

    if (AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute, (CFTypeRef *)&focusedElement) == kAXErrorSuccess) {
        NSArray *attributesToCheck = @[(__bridge NSString *)kAXRoleDescriptionAttribute,
                                       (__bridge NSString *)kAXDescriptionAttribute,
                                       (__bridge NSString *)kAXHelpAttribute];

        // Check focused element
        for (NSString *attr in attributesToCheck) {
            CFTypeRef valueRef = NULL;
            if (AXUIElementCopyAttributeValue(focusedElement, (__bridge CFStringRef)attr, &valueRef) == kAXErrorSuccess) {
                if (valueRef && CFGetTypeID(valueRef) == CFStringGetTypeID()) {
                    NSString *value = (__bridge NSString *)valueRef;
                    if ([value rangeOfString:@"code" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                        isCodeBlock = YES;
                    }
                }
                if (valueRef) CFRelease(valueRef);
            }
            if (isCodeBlock) break;
        }

        // Check Parent (Code Blocks in Notion are often containers)
        if (!isCodeBlock) {
            AXUIElementRef parent = NULL;
            if (AXUIElementCopyAttributeValue(focusedElement, kAXParentAttribute, (CFTypeRef *)&parent) == kAXErrorSuccess) {
                for (NSString *attr in attributesToCheck) {
                    CFTypeRef valueRef = NULL;
                    if (AXUIElementCopyAttributeValue(parent, (__bridge CFStringRef)attr, &valueRef) == kAXErrorSuccess) {
                        if (valueRef && CFGetTypeID(valueRef) == CFStringGetTypeID()) {
                            NSString *value = (__bridge NSString *)valueRef;
                            if ([value rangeOfString:@"code" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                                isCodeBlock = YES;
                            }
                        }
                        if (valueRef) CFRelease(valueRef);
                    }
                    if (isCodeBlock) break;
                }
                CFRelease(parent);
            }
        }

        CFRelease(focusedElement);
    }
    CFRelease(systemWide);
    return isCodeBlock;
}

+ (BOOL)isTerminalPanelFocused {
    if (vSafeMode) return NO;

    static BOOL lastResult = NO;
    static uint64_t lastCheckTime = 0;

    uint64_t now = mach_absolute_time();
    uint64_t elapsed_ms = [PHTVTimingService machTimeToMs:(now - lastCheckTime)];
    if (lastCheckTime != 0 && elapsed_ms < 50) {
        return lastResult;
    }

    AXUIElementRef systemWide = AXUIElementCreateSystemWide();
    AXUIElementRef focusedElement = NULL;
    BOOL isTerminalPanel = NO;

    if (AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute, (CFTypeRef *)&focusedElement) == kAXErrorSuccess &&
        focusedElement != NULL) {
        NSArray *attributesToCheck = @[(__bridge NSString *)kAXDescriptionAttribute,
                                       (__bridge NSString *)kAXRoleDescriptionAttribute,
                                       (__bridge NSString *)kAXHelpAttribute,
                                       (__bridge NSString *)kAXTitleAttribute,
                                       @"AXIdentifier",
                                       (__bridge NSString *)kAXRoleAttribute,
                                       (__bridge NSString *)kAXSubroleAttribute];

        NSString *bundleId = getFocusedAppBundleId();
        BOOL isIDE = [PHTVAppDetectionManager isIDEApp:bundleId];
        NSString *windowTitle = nil;
        if (isIDE) {
            windowTitle = PHTVGetFocusedWindowTitleForFrontmostApp();
        }

        // Check focused element and parent levels (IDE terminals often live in container)
        AXUIElementRef current = focusedElement;
        for (int level = 0; level < 8 && current != NULL; level++) {
            for (NSString *attr in attributesToCheck) {
                CFTypeRef valueRef = NULL;
                if (AXUIElementCopyAttributeValue(current, (__bridge CFStringRef)attr, &valueRef) == kAXErrorSuccess) {
                    if (valueRef && CFGetTypeID(valueRef) == CFStringGetTypeID()) {
                        NSString *value = (__bridge NSString *)valueRef;
                        if ([PHTVAppDetectionManager containsTerminalKeyword:value]) {
                            isTerminalPanel = YES;
                        }
                        if (isIDE && !isTerminalPanel &&
                            ([value isEqualToString:@"AXTextArea"] || [value isEqualToString:@"AXGroup"] || [value isEqualToString:@"AXScrollArea"])) {
                            if ([PHTVAppDetectionManager containsTerminalKeyword:windowTitle]) {
                                isTerminalPanel = YES;
                            }
                        }
                    }
                    if (valueRef) CFRelease(valueRef);
                }
                if (isTerminalPanel) {
                    break;
                }
            }
            if (isTerminalPanel) {
                break;
            }
            AXUIElementRef parent = NULL;
            if (AXUIElementCopyAttributeValue(current, kAXParentAttribute, (CFTypeRef *)&parent) != kAXErrorSuccess ||
                parent == NULL) {
                break;
            }
            if (current != focusedElement) {
                CFRelease(current);
            }
            current = parent;
        }

        if (current != NULL && current != focusedElement) {
            CFRelease(current);
        }
        CFRelease(focusedElement);
    }
    CFRelease(systemWide);

    if (!isTerminalPanel) {
        NSString *bundleId = getFocusedAppBundleId();
        if ([PHTVAppDetectionManager isIDEApp:bundleId]) {
            NSString *windowTitle = PHTVGetFocusedWindowTitleForFrontmostApp();
            if ([PHTVAppDetectionManager containsTerminalKeyword:windowTitle]) {
                isTerminalPanel = YES;
            }
        }
    }

    lastResult = isTerminalPanel;
    lastCheckTime = now;
    return isTerminalPanel;
}

+ (BOOL)isFocusedElementAddressBar {
    if (vSafeMode) return NO;

    uint64_t now = mach_absolute_time();
    uint64_t elapsed_ms = [PHTVTimingService machTimeToMs:(now - _lastAddressBarCheckTime)];

    // Cache valid for 500ms
    if (_lastAddressBarCheckTime > 0 && elapsed_ms < 500) {
        return _lastAddressBarResult;
    }

    BOOL isAddressBar = YES; // Default to YES (Address Bar) for safety
    AXUIElementRef systemWide = AXUIElementCreateSystemWide();
    AXUIElementRef focusedElement = NULL;

    if (AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute, (CFTypeRef *)&focusedElement) == kAXErrorSuccess) {
        // Debug Log: Start inspection
#ifdef DEBUG
        NSLog(@"[AX Debug] Inspecting Focused Element...");
#endif

        // STRATEGY 1: Role-based Identification (Fast & Reliable)
        CFStringRef roleRef = NULL;
        if (AXUIElementCopyAttributeValue(focusedElement, kAXRoleAttribute, (CFTypeRef *)&roleRef) == kAXErrorSuccess) {
            NSString *role = (__bridge NSString *)roleRef;
#ifdef DEBUG
            NSLog(@"[AX Debug] Role: %@", role);
#endif

            if ([role isEqualToString:@"AXTextField"] ||
                [role isEqualToString:@"AXSearchField"] ||
                [role isEqualToString:@"AXComboBox"]) {

#ifdef DEBUG
                NSLog(@"[AX Debug] -> MATCH: Known Input Role. Returning YES.");
#endif

                isAddressBar = YES;
                CFRelease(roleRef);
                CFRelease(focusedElement);
                CFRelease(systemWide);

                _lastAddressBarResult = isAddressBar;
                _lastAddressBarCheckTime = now;
                return YES;
            }
            CFRelease(roleRef);
        }

        // STRATEGY 2: Positive Identification (Keywords)
        BOOL positiveMatch = NO;
        NSArray *attributesToCheck = @[(__bridge NSString *)kAXTitleAttribute,
                                       (__bridge NSString *)kAXDescriptionAttribute,
                                       (__bridge NSString *)kAXRoleDescriptionAttribute,
                                       @"AXIdentifier"];

        for (NSString *attr in attributesToCheck) {
            CFTypeRef valueRef = NULL;
            if (AXUIElementCopyAttributeValue(focusedElement, (__bridge CFStringRef)attr, &valueRef) == kAXErrorSuccess) {
                if (valueRef && CFGetTypeID(valueRef) == CFStringGetTypeID()) {
                    NSString *value = (__bridge NSString *)valueRef;
#ifdef DEBUG
                    NSLog(@"[AX Debug] Checking Attribute %@: %@", attr, value);
#endif

                    if ([value rangeOfString:@"Address" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                        [value rangeOfString:@"Omnibox" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                        [value rangeOfString:@"Location" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                        [value rangeOfString:@"URL" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                        [value rangeOfString:@"Search" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                        [value rangeOfString:@"Địa chỉ" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                        [value rangeOfString:@"Tìm kiếm" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                        positiveMatch = YES;
                    }
                }
                if (valueRef) CFRelease(valueRef);
            }
            if (positiveMatch) break;
        }

        if (positiveMatch) {
#ifdef DEBUG
            NSLog(@"[AX Debug] -> MATCH: Positive Keyword found. Returning YES.");
#endif
            isAddressBar = YES;
        } else {
            // STRATEGY 3: Negative Identification (Web Area)
#ifdef DEBUG
            NSLog(@"[AX Debug] No positive match. Checking Parent Hierarchy for AXWebArea...");
#endif

            BOOL foundWebArea = NO;
            AXUIElementRef currentElement = focusedElement;
            CFRetain(currentElement); // Keep +1 for the loop

            // Walk up up to 12 levels to find AXWebArea
            for (int i = 0; i < 12; i++) {
                AXUIElementRef parent = NULL;
                if (AXUIElementCopyAttributeValue(currentElement, kAXParentAttribute, (CFTypeRef *)&parent) == kAXErrorSuccess) {
                    CFStringRef parentRoleRef = NULL;
                    if (AXUIElementCopyAttributeValue(parent, kAXRoleAttribute, (CFTypeRef *)&parentRoleRef) == kAXErrorSuccess) {
                        NSString *parentRole = (__bridge NSString *)parentRoleRef;
#ifdef DEBUG
                        NSLog(@"[AX Debug] Parent Level %d Role: %@", i + 1, parentRole);
#endif

                        if ([parentRole isEqualToString:@"AXWebArea"]) {
                            foundWebArea = YES;
                            CFRelease(parentRoleRef);
                            CFRelease(parent);
                            break;
                        }
                        CFRelease(parentRoleRef);
                    }

                    CFRelease(currentElement);
                    currentElement = parent; // Move up
                } else {
#ifdef DEBUG
                    NSLog(@"[AX Debug] Parent walk stopped at level %d (No Parent)", i + 1);
#endif
                    break; // No parent
                }
            }
            CFRelease(currentElement);

            if (foundWebArea) {
#ifdef DEBUG
                NSLog(@"[AX Debug] -> Found AXWebArea. It's Content. Returning NO.");
#endif
                isAddressBar = NO;
            } else {
#ifdef DEBUG
                NSLog(@"[AX Debug] -> No AXWebArea found. Assuming Address Bar. Returning YES.");
#endif
                isAddressBar = YES;
            }
        }
        CFRelease(focusedElement);
    } else {
        // AX Failed
#ifdef DEBUG
        NSLog(@"[AX Debug] Failed to get Focused Element. Fallback logic.");
#endif

        if (_lastAddressBarCheckTime > 0 && elapsed_ms < 2000) {
            isAddressBar = _lastAddressBarResult;
        } else {
            isAddressBar = YES;
        }
    }
    CFRelease(systemWide);

    _lastAddressBarResult = isAddressBar;
    _lastAddressBarCheckTime = now;
    return isAddressBar;
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
