//
//  PHTVHotkeyManager.h
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#ifndef PHTVHotkeyManager_h
#define PHTVHotkeyManager_h

#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>
#import <Carbon/Carbon.h>
#include "../Core/PHTVHotkey.h"

@interface PHTVHotkeyManager : NSObject

// Initialization
+ (void)initialize;

// Hotkey Detection
+ (BOOL)checkHotKey:(int)hotKeyData checkKeyCode:(BOOL)checkKeyCode currentKeycode:(CGKeyCode)keycode currentFlags:(CGEventFlags)flags;
+ (BOOL)hotkeyModifiersAreHeld:(int)hotKeyData currentFlags:(CGEventFlags)flags;
+ (BOOL)isModifierOnlyHotkey:(int)hotKeyData;

// Pause Key Management
+ (BOOL)isPauseKeyPressed;
+ (CGEventFlags)pauseModifierMaskForCurrentPauseKey;
+ (BOOL)isPauseKeyActiveForFlags:(CGEventFlags)flags;
+ (CGEventFlags)stripPauseModifier:(CGEventFlags)flags;
+ (void)handlePauseKeyPressWithFlags:(CGEventFlags)flags;
+ (void)handlePauseKeyReleaseFromFlags:(CGEventFlags)oldFlags toFlags:(CGEventFlags)newFlags;

// Keyboard Layout Compatibility
+ (CGKeyCode)convertEventToKeyboardLayoutCompatKeyCode:(CGEventRef)event fallback:(CGKeyCode)fallback;
+ (int)convertKeyStringToKeyCode:(NSString*)keyString fallback:(CGKeyCode)fallback;
+ (void)invalidateLayoutCache;

@end

#endif /* PHTVHotkeyManager_h */
