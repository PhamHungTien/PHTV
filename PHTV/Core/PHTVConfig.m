//
//  PHTVConfig.m
//  PHTV - Vietnamese Input Method
//
//  Created by Phạm Hùng Tiến on 2026
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import "PHTVConfig.h"

// Configuration keys - centralized and type-safe
static NSString * const kPHTVInputMethodKey = @"PHTV_InputMethod";
static NSString * const kPHTVInputTypeKey = @"PHTV_InputType";
static NSString * const kPHTVCodeTableKey = @"PHTV_CodeTable";
static NSString * const kPHTVFreeMarkKey = @"PHTV_FreeMark";
static NSString * const kPHTVModernOrthographyKey = @"PHTV_ModernOrthography";
static NSString * const kPHTVSpellCheckKey = @"PHTV_SpellCheck";
static NSString * const kPHTVQuickTelexKey = @"PHTV_QuickTelex";
static NSString * const kPHTVRestoreInvalidKey = @"PHTV_RestoreInvalid";
static NSString * const kPHTVSwitchKeyKey = @"PHTV_SwitchKey";
static NSString * const kPHTVGrayIconKey = @"PHTV_GrayIcon";
static NSString * const kPHTVShowDockKey = @"PHTV_ShowDock";
static NSString * const kPHTVRunOnStartupKey = @"PHTV_RunOnStartup";

@implementation PHTVConfig

#pragma mark - Singleton

+ (instancetype)shared {
    static PHTVConfig *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self loadFromUserDefaults];
    }
    return self;
}

#pragma mark - Load/Save

- (void)loadFromUserDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Core settings
    self.inputMethod = (PHTVInputMethod)[defaults integerForKey:kPHTVInputMethodKey];
    self.inputType = (PHTVInputType)[defaults integerForKey:kPHTVInputTypeKey];
    self.codeTable = (PHTVCodeTable)[defaults integerForKey:kPHTVCodeTableKey];
    
    // Features
    self.freeMarkEnabled = [defaults boolForKey:kPHTVFreeMarkKey];
    self.modernOrthographyEnabled = [defaults boolForKey:kPHTVModernOrthographyKey];
    self.spellCheckEnabled = [defaults boolForKey:kPHTVSpellCheckKey];
    self.quickTelexEnabled = [defaults boolForKey:kPHTVQuickTelexKey];
    self.restoreOnInvalidWordEnabled = [defaults boolForKey:kPHTVRestoreInvalidKey];
    
    // UI
    self.grayIconEnabled = [defaults boolForKey:kPHTVGrayIconKey];
    self.showIconOnDockEnabled = [defaults boolForKey:kPHTVShowDockKey];
    self.runOnStartupEnabled = [defaults boolForKey:kPHTVRunOnStartupKey];
    
    // Advanced
    self.switchKeyStatus = (int)[defaults integerForKey:kPHTVSwitchKeyKey];
    if (self.switchKeyStatus == 0) {
        self.switchKeyStatus = 0x1FC; // Default: Command+Shift+V
    }
}

- (void)saveToUserDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    [defaults setInteger:self.inputMethod forKey:kPHTVInputMethodKey];
    [defaults setInteger:self.inputType forKey:kPHTVInputTypeKey];
    [defaults setInteger:self.codeTable forKey:kPHTVCodeTableKey];
    [defaults setBool:self.freeMarkEnabled forKey:kPHTVFreeMarkKey];
    [defaults setBool:self.modernOrthographyEnabled forKey:kPHTVModernOrthographyKey];
    [defaults setBool:self.spellCheckEnabled forKey:kPHTVSpellCheckKey];
    [defaults setBool:self.quickTelexEnabled forKey:kPHTVQuickTelexKey];
    [defaults setBool:self.restoreOnInvalidWordEnabled forKey:kPHTVRestoreInvalidKey];
    [defaults setBool:self.grayIconEnabled forKey:kPHTVGrayIconKey];
    [defaults setBool:self.showIconOnDockEnabled forKey:kPHTVShowDockKey];
    [defaults setBool:self.runOnStartupEnabled forKey:kPHTVRunOnStartupKey];
    [defaults setInteger:self.switchKeyStatus forKey:kPHTVSwitchKeyKey];
    
    [defaults synchronize];
}

- (void)resetToDefaults {
    self.inputMethod = PHTVInputMethodVietnamese;
    self.inputType = PHTVInputTypeTelex;
    self.codeTable = PHTVCodeTableUnicode;
    self.freeMarkEnabled = NO;
    self.modernOrthographyEnabled = YES;
    self.spellCheckEnabled = YES;
    self.quickTelexEnabled = YES;
    self.restoreOnInvalidWordEnabled = YES;
    self.grayIconEnabled = NO;
    self.showIconOnDockEnabled = NO;
    self.runOnStartupEnabled = YES;
    self.switchKeyStatus = 0x1FC;
    
    [self saveToUserDefaults];
}

- (NSDictionary *)exportSettings {
    return @{
        @"inputMethod": @(self.inputMethod),
        @"inputType": @(self.inputType),
        @"codeTable": @(self.codeTable),
        @"features": @{
            @"freeMark": @(self.freeMarkEnabled),
            @"modernOrthography": @(self.modernOrthographyEnabled),
            @"spellCheck": @(self.spellCheckEnabled),
            @"quickTelex": @(self.quickTelexEnabled)
        }
    };
}

- (void)importSettings:(NSDictionary *)settings {
    if (settings[@"inputMethod"]) {
        self.inputMethod = [settings[@"inputMethod"] intValue];
    }
    if (settings[@"inputType"]) {
        self.inputType = [settings[@"inputType"] intValue];
    }
    // Import other settings...
    [self saveToUserDefaults];
}

@end
