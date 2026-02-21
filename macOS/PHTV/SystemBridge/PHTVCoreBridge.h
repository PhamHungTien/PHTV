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
void PHTVSetConvertToolOptions(bool dontAlertWhenCompleted,
                               bool toAllCaps,
                               bool toAllNonCaps,
                               bool toCapsFirstLetter,
                               bool toCapsEachWord,
                               bool removeMark,
                               int fromCode,
                               int toCode,
                               int hotKey);
int PHTVDefaultConvertToolHotKey(void);
void PHTVResetConvertToolOptions(void);
void PHTVNormalizeConvertToolOptions(void);
BOOL PHTVGetSafeMode(void);
void PHTVSetSafeMode(BOOL enabled);
#ifdef __cplusplus
BOOL PHTVRunAccessibilitySmokeTest(void) noexcept;
#else
BOOL PHTVRunAccessibilitySmokeTest(void);
#endif
void RequestNewSession(void);
void InvalidateLayoutCache(void);
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
void PHTVSetShowIconOnDock(bool visible);
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
void PHTVSetUseSmartSwitchKey(bool enabled);
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
