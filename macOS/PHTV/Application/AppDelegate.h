//
//  AppDelegate.h
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

#define PHTV_BUNDLE @"com.phamhungtien.phtv"

@interface AppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate>

@end

NS_ASSUME_NONNULL_END

#ifdef __cplusplus
extern "C" {
#endif

// Global function to get AppDelegate instance
AppDelegate* _Nullable GetAppDelegateInstance(void);
void SetAppDelegateInstance(AppDelegate* _Nullable instance);

#ifdef __cplusplus
}
#endif
