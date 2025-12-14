//
//  PHTVConfig.h
//  PHTV - Vietnamese Input Method
//
//  Created by Phạm Hùng Tiến on 2026
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//
//  Runtime Configuration Manager - Singleton Pattern
//

#ifndef PHTVConfig_h
#define PHTVConfig_h

#import <Foundation/Foundation.h>
#include "PHTVConstants.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Centralized configuration manager for PHTV
 * @author Phạm Hùng Tiến
 * 
 * This class manages all runtime configurations and preferences
 * using a singleton pattern for thread-safe access across the application.
 */
@interface PHTVConfig : NSObject

#pragma mark - Singleton
+ (instancetype)shared;

#pragma mark - Core Settings
@property (nonatomic, assign) PHTVInputMethod inputMethod;
@property (nonatomic, assign) PHTVInputType inputType;
@property (nonatomic, assign) PHTVCodeTable codeTable;

#pragma mark - Feature Toggles
@property (nonatomic, assign) BOOL freeMarkEnabled;
@property (nonatomic, assign) BOOL modernOrthographyEnabled;
@property (nonatomic, assign) BOOL spellCheckEnabled;
@property (nonatomic, assign) BOOL quickTelexEnabled;
@property (nonatomic, assign) BOOL restoreOnInvalidWordEnabled;
@property (nonatomic, assign) BOOL fixBrowserRecommendEnabled;
@property (nonatomic, assign) BOOL macroEnabled;
@property (nonatomic, assign) BOOL macroInEnglishModeEnabled;
@property (nonatomic, assign) BOOL smartSwitchKeyEnabled;
@property (nonatomic, assign) BOOL upperCaseFirstCharEnabled;
@property (nonatomic, assign) BOOL tempDisableSpellCheckEnabled;
@property (nonatomic, assign) BOOL allowConsonantZFWJEnabled;
@property (nonatomic, assign) BOOL quickStartConsonantEnabled;
@property (nonatomic, assign) BOOL quickEndConsonantEnabled;
@property (nonatomic, assign) BOOL rememberCodeTableEnabled;
@property (nonatomic, assign) BOOL autoCapsMacroEnabled;
@property (nonatomic, assign) BOOL sendKeyStepByStepEnabled;
@property (nonatomic, assign) BOOL fixChromiumBrowserEnabled;
@property (nonatomic, assign) BOOL performLayoutCompatEnabled;
@property (nonatomic, assign) BOOL tempDisablePHTVEnabled;
@property (nonatomic, assign) BOOL otherLanguageDetectionEnabled;

#pragma mark - UI Settings
@property (nonatomic, assign) BOOL grayIconEnabled;
@property (nonatomic, assign) BOOL showIconOnDockEnabled;
@property (nonatomic, assign) BOOL showUIOnStartupEnabled;
@property (nonatomic, assign) BOOL runOnStartupEnabled;

#pragma mark - Advanced Settings
@property (nonatomic, assign) int switchKeyStatus;

#pragma mark - Methods
- (void)loadFromUserDefaults;
- (void)saveToUserDefaults;
- (void)resetToDefaults;
- (NSDictionary *)exportSettings;
- (void)importSettings:(NSDictionary *)settings;

@end

NS_ASSUME_NONNULL_END

#endif /* PHTVConfig_h */
