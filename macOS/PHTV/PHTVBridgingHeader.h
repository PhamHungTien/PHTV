//
//  PHTVBridgingHeader.h
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#ifndef PHTVBridgingHeader_h
#define PHTVBridgingHeader_h

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

// Application
#import "Application/AppDelegate.h"
#import "Application/AppDelegate+DockVisibility.h"
#import "Application/AppDelegate+InputState.h"
#import "Application/AppDelegate+LoginItem.h"
#import "Application/AppDelegate+Private.h"
#import "Application/AppDelegate+StatusBarMenu.h"

// Global AppDelegate instance (defined in AppDelegate.mm)
// Note: Accessed on main thread only, safe despite concurrency warning
extern AppDelegate* _Nullable appDelegate;

// SystemBridge
#import "SystemBridge/PHTVManager.h"
#import "SystemBridge/PHTVEngineDataBridge.h"
#import "SystemBridge/PHTVCoreBridge.h"

#endif /* PHTVBridgingHeader_h */
