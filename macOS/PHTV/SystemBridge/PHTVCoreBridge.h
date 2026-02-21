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
