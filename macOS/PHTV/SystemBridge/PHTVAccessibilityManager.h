//
//  PHTVAccessibilityManager.h
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#ifndef PHTVAccessibilityManager_h
#define PHTVAccessibilityManager_h

#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>

@interface PHTVAccessibilityManager : NSObject

// Initialization
+ (void)initialize;

// AX Text Replacement
+ (BOOL)replaceFocusedTextViaAX:(NSInteger)backspaceCount insertText:(NSString*)insertText;
+ (BOOL)replaceFocusedTextViaAX:(NSInteger)backspaceCount insertText:(NSString*)insertText verify:(BOOL)verify;
+ (void)invalidateAddressBarCache;
+ (BOOL)isFocusedElementAddressBar;
+ (BOOL)isTerminalPanelFocused;
+ (BOOL)isNotionCodeBlock;

// Safe Mode
+ (BOOL)isSafeModeEnabled;
+ (void)setSafeModeEnabled:(BOOL)enabled;

// AX Error Logging
+ (void)logAXError:(AXError)error operation:(const char*)operation;

// Permission UI
+ (void)openAccessibilityPreferences;

@end

#endif /* PHTVAccessibilityManager_h */
