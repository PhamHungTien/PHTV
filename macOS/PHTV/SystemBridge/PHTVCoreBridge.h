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

#ifdef __cplusplus
}
#endif

#endif /* PHTVCoreBridge_h */
