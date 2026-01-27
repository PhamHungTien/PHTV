//
//  MJAccessibilityUtils.h
//  PHTV
//
//  Modified by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//
//  Source: https://github.com/Hammerspoon/hammerspoon/blob/master/Hammerspoon/MJAccessibilityUtils.h
//  License: MIT

#ifndef MJAccessibilityUtils_h

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif
    BOOL MJAccessibilityIsEnabled(void);
    void MJAccessibilityOpenPanel(void);
#ifdef __cplusplus
}
#endif

#define MJAccessibilityUtils_h


#endif /* MJAccessibilityUtils_h */
