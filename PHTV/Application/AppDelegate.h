//
//  AppDelegate.h
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define PHTV_BUNDLE @"com.phamhungtien.phtv"

@interface AppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate>

-(void)onImputMethodChanged:(BOOL)willNotify;
-(void)onInputMethodSelected;

-(void)askPermission;

-(void)onInputTypeSelectedIndex:(int)index;
-(void)onCodeTableChanged:(int)index;
-(void)fillData;  // Update UI status bar and menu items

-(void)setRunOnStartup:(BOOL)val;
-(void)loadDefaultConfig;

-(void)setGrayIcon:(BOOL)val;

-(void)onMacroSelected;
-(void)onQuickConvert;
-(void)setQuickConvertString;

-(void)showIconOnDock:(BOOL)val;
-(void)showIcon:(BOOL)onDock;

// Accessibility monitoring methods
- (void)startAccessibilityMonitoring;
- (void)stopAccessibilityMonitoring;
- (void)checkAccessibilityStatus;
- (void)handleAccessibilityRevoked;
- (void)setupSwiftUIBridge;
- (void)loadExistingMacros;
- (void)handleCheckForUpdates:(NSNotification *)notification;
- (void)handleSettingsReset:(NSNotification *)notification;

@end

