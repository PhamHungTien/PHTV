//
//  PHTVManager+SwiftBridgePrivate.h
//  PHTV
//
//  Private selector declarations implemented in Swift bridge extensions.
//

#ifndef PHTVManager_SwiftBridgePrivate_h
#define PHTVManager_SwiftBridgePrivate_h

#import "PHTVManager.h"

@interface PHTVManager (PHTVSystemServicesBridge)

+(BOOL)phtv_isTCCEntryCorrupt;
+(BOOL)phtv_autoFixTCCEntryWithError:(NSError **)error;
+(void)phtv_restartTCCDaemon;
+(void)phtv_startTCCNotificationListener;
+(void)phtv_stopTCCNotificationListener;
+(NSArray *)phtv_getTableCodes;
+(NSString *)phtv_getApplicationSupportFolder;
+(NSString *)phtv_getBinaryArchitectures;
+(NSString *)phtv_getBinaryHash;
+(BOOL)phtv_hasBinaryChangedSinceLastRun;
+(BOOL)phtv_checkBinaryIntegrity;
+(BOOL)phtv_quickConvert;
+(BOOL)phtv_isSafeModeEnabled;
+(void)phtv_setSafeModeEnabled:(BOOL)enabled;
+(void)phtv_clearAXTestFlag;
+(void)phtv_requestNewSession;
+(void)phtv_invalidateLayoutCache;
+(void)phtv_notifyInputMethodChanged;
+(void)phtv_notifyTableCodeChanged;
+(void)phtv_notifyActiveAppChanged;
+(int)phtv_currentLanguage;
+(void)phtv_setCurrentLanguage:(int)language;
+(int)phtv_otherLanguageMode;
+(int)phtv_currentInputType;
+(void)phtv_setCurrentInputType:(int)inputType;
+(int)phtv_currentCodeTable;
+(void)phtv_setCurrentCodeTable:(int)codeTable;
+(BOOL)phtv_isSmartSwitchKeyEnabled;
+(BOOL)phtv_isSendKeyStepByStepEnabled;
+(void)phtv_setSendKeyStepByStepEnabled:(BOOL)enabled;
+(void)phtv_setUpperCaseExcludedForCurrentApp:(BOOL)excluded;
+(int)phtv_currentSwitchKeyStatus;
+(void)phtv_setSwitchKeyStatus:(int)status;
+(void)phtv_setDockIconRuntimeVisible:(BOOL)visible;
+(int)phtv_toggleSpellCheckSetting;
+(int)phtv_toggleAllowConsonantZFWJSetting;
+(int)phtv_toggleModernOrthographySetting;
+(int)phtv_toggleQuickTelexSetting;
+(int)phtv_toggleUpperCaseFirstCharSetting;
+(int)phtv_toggleAutoRestoreEnglishWordSetting;
+(NSDictionary<NSString *, NSNumber *> *)phtv_runtimeSettingsSnapshot;
+(void)phtv_loadEmojiHotkeySettingsFromDefaults;
+(NSUInteger)phtv_loadRuntimeSettingsFromUserDefaults;
+(void)phtv_loadDefaultConfig;

@end

#endif /* PHTVManager_SwiftBridgePrivate_h */
