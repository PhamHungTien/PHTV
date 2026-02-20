//
//  AppDelegate.m
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import "AppDelegate.h"
// Keep this import here so Objective-C runtime synthesizes private property accessors
// (e.g. setUpdateQueue:) used by Swift lifecycle/category extensions.
#import "AppDelegate+Private.h"

AppDelegate* appDelegate;

extern "C" {
    AppDelegate* _Nullable GetAppDelegateInstance(void) {
        return appDelegate;
    }

    void SetAppDelegateInstance(AppDelegate* _Nullable instance) {
        appDelegate = instance;
    }
}

@implementation AppDelegate

@end
