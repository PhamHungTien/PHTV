//
//  PHTV-Bridging-Header.h
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#ifndef PHTV_Bridging_Header_h
#define PHTV_Bridging_Header_h

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

// Application
#import "Application/AppDelegate.h"

// Global AppDelegate instance (defined in AppDelegate.mm)
// Note: Accessed on main thread only, safe despite concurrency warning
extern AppDelegate* _Nullable appDelegate;

// Managers
#import "Managers/PHTVManager.h"

// Legacy utilities
#import "Core/Legacy/MJAccessibilityUtils.h"
#import "Application/PHSilentUserDriver.h"

// Core Config
#import "Core/Config/PHTVConfig.h"
#import "Core/Config/PHTVConstants.h"

#endif /* PHTV_Bridging_Header_h */
