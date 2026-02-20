//
//  PHTVCoreBridge.h
//  PHTV
//
//  C symbols exported by PHTV.mm for Swift/ObjC callers.
//

#ifndef PHTVCoreBridge_h
#define PHTVCoreBridge_h

#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>

#ifdef __cplusplus
extern "C" {
#endif

NSString * _Nullable ConvertUtil(NSString * _Nonnull str);
void PHTVInit(void);
CGEventRef _Nullable PHTVCallback(CGEventTapProxy _Nullable proxy,
                                  CGEventType type,
                                  CGEventRef _Nonnull event,
                                  void * _Nullable refcon);
NSString * _Nonnull PHTVBuildDateString(void);
void PHTVSyncSpellCheckingState(void);
void PHTVSetConvertToolOptions(BOOL dontAlertWhenCompleted,
                               BOOL toAllCaps,
                               BOOL toAllNonCaps,
                               BOOL toCapsFirstLetter,
                               BOOL toCapsEachWord,
                               BOOL removeMark,
                               int fromCode,
                               int toCode,
                               int hotKey);
int PHTVDefaultConvertToolHotKey(void);
void PHTVResetConvertToolOptions(void);
void PHTVNormalizeConvertToolOptions(void);
NSData * _Nonnull PHTVSmartSwitchSerializedData(void);
int PHTVSmartSwitchNotFound(void);
int PHTVSmartSwitchEncodeState(int inputMethod, int codeTable);
int PHTVSmartSwitchDecodeInputMethod(int state);
int PHTVSmartSwitchDecodeCodeTable(int state);
int PHTVSmartSwitchGetAppState(NSString * _Nonnull bundleId, int defaultInputState);
void PHTVSmartSwitchSetAppState(NSString * _Nonnull bundleId, int inputState);
BOOL PHTVGetSafeMode(void);
void PHTVSetSafeMode(BOOL enabled);
BOOL PHTVRunAccessibilitySmokeTest(void);
void RequestNewSession(void);
void InvalidateLayoutCache(void);
void OnInputMethodChanged(void);
void OnTableCodeChange(void);
void OnActiveAppChanged(void);
int PHTVGetCurrentLanguage(void);
void PHTVSetCurrentLanguage(int language);
int PHTVGetCurrentInputType(void);
void PHTVSetCurrentInputType(int inputType);
int PHTVGetCurrentCodeTable(void);
void PHTVSetCurrentCodeTable(int codeTable);
BOOL PHTVIsSmartSwitchKeyEnabled(void);
BOOL PHTVIsSendKeyStepByStepEnabled(void);
void PHTVSetSendKeyStepByStepEnabled(BOOL enabled);
void PHTVSetUpperCaseExcludedForCurrentApp(BOOL excluded);
int PHTVGetSwitchKeyStatus(void);
void PHTVSetSwitchKeyStatus(int status);
int PHTVGetCheckSpelling(void);
void PHTVSetCheckSpelling(int value);
int PHTVGetAllowConsonantZFWJ(void);
void PHTVSetAllowConsonantZFWJ(int value);
int PHTVGetUseModernOrthography(void);
void PHTVSetUseModernOrthography(int value);
int PHTVGetQuickTelex(void);
void PHTVSetQuickTelex(int value);
int PHTVGetUpperCaseFirstChar(void);
void PHTVSetUpperCaseFirstChar(int value);
int PHTVGetAutoRestoreEnglishWord(void);
void PHTVSetAutoRestoreEnglishWord(int value);
void PHTVSetShowIconOnDock(BOOL visible);
int PHTVGetUseMacro(void);
int PHTVGetUseMacroInEnglishMode(void);
int PHTVGetAutoCapsMacro(void);
int PHTVGetQuickStartConsonant(void);
int PHTVGetQuickEndConsonant(void);
int PHTVGetRememberCode(void);
int PHTVGetPerformLayoutCompat(void);
int PHTVGetShowIconOnDock(void);
int PHTVGetRestoreOnEscape(void);
int PHTVGetCustomEscapeKey(void);
int PHTVGetPauseKeyEnabled(void);
int PHTVGetPauseKey(void);
int PHTVGetEnableEmojiHotkey(void);
int PHTVGetEmojiHotkeyModifiers(void);
int PHTVGetEmojiHotkeyKeyCode(void);
void PHTVSetEmojiHotkeySettings(int enabled, int modifiers, int keyCode);
int PHTVGetFreeMark(void);
void PHTVSetFreeMark(int value);
void PHTVSetUseMacro(int value);
void PHTVSetUseMacroInEnglishMode(int value);
void PHTVSetAutoCapsMacro(int value);
void PHTVSetUseSmartSwitchKey(BOOL enabled);
void PHTVSetQuickStartConsonant(int value);
void PHTVSetQuickEndConsonant(int value);
void PHTVSetRememberCode(int value);
void PHTVSetPerformLayoutCompat(int value);
void PHTVSetRestoreOnEscape(int value);
void PHTVSetCustomEscapeKey(int value);
void PHTVSetPauseKeyEnabled(int value);
void PHTVSetPauseKey(int value);
void PHTVSetFixRecommendBrowser(int value);
void PHTVSetTempOffSpelling(int value);
void PHTVSetOtherLanguage(int value);
void PHTVSetTempOffPHTV(int value);
int PHTVDefaultSwitchHotkeyStatus(void);
int PHTVDefaultPauseKey(void);
int PHTVGetOtherLanguage(void);

#ifdef __cplusplus
}
#endif

#endif /* PHTVCoreBridge_h */
