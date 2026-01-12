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

@interface PHTVHotkeyManager : NSObject

// Initialization
+ (void)initialize;

// Hotkey Detection
+ (CGEventRef)handleHotkeyPress:(CGEventType)type keycode:(CGKeyCode)keycode flags:(CGEventFlags)flags;
+ (BOOL)checkHotKey:(int)hotKeyData checkKeyCode:(BOOL)checkKeyCode currentKeycode:(CGKeyCode)keycode currentFlags:(CGEventFlags)flags;
+ (BOOL)hotkeyModifiersAreHeld:(int)hotKeyData currentFlags:(CGEventFlags)flags;
+ (BOOL)isModifierOnlyHotkey:(int)hotKeyData;

// Language Switching
+ (void)switchLanguage;

// Macro Triggering
+ (void)handleMacro;

// Pause Key Management
+ (BOOL)isPauseKeyPressed;
+ (void)setPauseKeyPressed:(BOOL)pressed;
+ (CGEventFlags)stripPauseModifier:(CGEventFlags)flags;
+ (void)handlePauseKeyPress;
+ (void)handlePauseKeyRelease;

// Keyboard Layout Compatibility
+ (CGKeyCode)convertEventToKeyboardLayoutCompatKeyCode:(CGEventRef)event fallback:(CGKeyCode)fallback;
+ (int)convertKeyStringToKeyCode:(NSString*)keyString fallback:(CGKeyCode)fallback;
+ (void)invalidateLayoutCache;

@end

#endif /* PHTVHotkeyManager_h */
