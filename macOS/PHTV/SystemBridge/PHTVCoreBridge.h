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

#ifdef __cplusplus
}
#endif

#endif /* PHTVCoreBridge_h */
