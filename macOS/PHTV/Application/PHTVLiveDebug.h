//
//  PHTVLiveDebug.h
//  PHTV
//
//  Shared live-debug switch and logging macro for Objective-C++ categories.
//

#ifndef PHTVLiveDebug_h
#define PHTVLiveDebug_h

#import <Foundation/Foundation.h>
#include <stdlib.h>
#include <string.h>

static inline BOOL PHTVLiveDebugEnabled(void) {
    static int cachedEnabled = -1;
    if (__builtin_expect(cachedEnabled != -1, 1)) {
        return cachedEnabled == 1;
    }

    const char *env = getenv("PHTV_LIVE_DEBUG");
    if (env != NULL && env[0] != '\0') {
        cachedEnabled = (strcmp(env, "0") != 0) ? 1 : 0;
        return cachedEnabled == 1;
    }

    id stored = [[NSUserDefaults standardUserDefaults] objectForKey:@"PHTV_LIVE_DEBUG"];
    if ([stored respondsToSelector:@selector(intValue)]) {
        cachedEnabled = ([stored intValue] != 0) ? 1 : 0;
        return cachedEnabled == 1;
    }

    cachedEnabled = 0;
    return NO;
}

#define PHTV_LIVE_LOG(fmt, ...) do { \
    if (PHTVLiveDebugEnabled()) { \
        NSLog(@"[PHTV Live] " fmt, ##__VA_ARGS__); \
    } \
} while(0)

#endif /* PHTVLiveDebug_h */
