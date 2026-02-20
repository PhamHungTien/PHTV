//
//  PHTVCoreBridge.h
//  PHTV
//
//  C symbols exported by PHTV.mm for Swift/ObjC callers.
//

#ifndef PHTVCoreBridge_h
#define PHTVCoreBridge_h

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

NSString * _Nullable ConvertUtil(NSString * _Nonnull str);
BOOL PHTVGetSafeMode(void);
void PHTVSetSafeMode(BOOL enabled);
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

#ifdef __cplusplus
}
#endif

#endif /* PHTVCoreBridge_h */
