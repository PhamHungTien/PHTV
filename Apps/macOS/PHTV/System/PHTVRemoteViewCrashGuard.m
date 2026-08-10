//
//  PHTVRemoteViewCrashGuard.m
//  PHTV
//

#import "PHTVRemoteViewCrashGuard.h"

#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import <os/log.h>
#import <stdatomic.h>

typedef void (*PHTVRemoteViewOrderOnScreenIMP)(id, SEL, id);

static PHTVRemoteViewOrderOnScreenIMP phtvOriginalRemoteViewOrderOnScreen = NULL;
static atomic_bool phtvRemoteViewGuardInstalled = false;
static atomic_uint_fast64_t phtvRemoteViewSuppressedExceptionCount = 0;

static BOOL PHTVShouldSuppressRemoteViewException(NSException *exception) {
    // Keep the escape hatch deliberately narrow: only the internal-consistency
    // exception thrown from the one intercepted NSRemoteView method is ignored.
    // Every other Objective-C exception is rethrown unchanged.
    return [exception.name isEqualToString:NSInternalInconsistencyException];
}

static void PHTVRemoteViewContainingWindowWillOrderOnScreen(id object, SEL selector, id notification) {
    @try {
        phtvOriginalRemoteViewOrderOnScreen(object, selector, notification);
    } @catch (NSException *exception) {
        if (!PHTVShouldSuppressRemoteViewException(exception)) {
            @throw;
        }

        uint64_t count = atomic_fetch_add_explicit(
            &phtvRemoteViewSuppressedExceptionCount,
            1,
            memory_order_relaxed
        ) + 1;
        os_log_error(
            OS_LOG_DEFAULT,
            "[RemoteViewGuard] Suppressed macOS 27 NSRemoteView inconsistency (%{public}llu): %{public}@",
            (unsigned long long)count,
            exception.reason ?: @"No reason supplied"
        );
    }
}

@implementation PHTVRemoteViewCrashGuard

+ (BOOL)shouldInstallForMajorVersion:(NSInteger)majorVersion {
    return majorVersion == 27;
}

+ (void)installIfNeeded {
    NSInteger majorVersion = NSProcessInfo.processInfo.operatingSystemVersion.majorVersion;
    if (![self shouldInstallForMajorVersion:majorVersion]) {
        return;
    }

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class remoteViewClass = NSClassFromString(@"NSRemoteView");
        SEL selector = NSSelectorFromString(@"containingWindowWillOrderOnScreen:");
        Method method = remoteViewClass == Nil
            ? NULL
            : class_getInstanceMethod(remoteViewClass, selector);

        if (method == NULL) {
            os_log_info(OS_LOG_DEFAULT, "[RemoteViewGuard] Affected AppKit entry point is unavailable");
            return;
        }

        IMP original = method_getImplementation(method);
        if (original == NULL) {
            os_log_error(OS_LOG_DEFAULT, "[RemoteViewGuard] Could not install AppKit compatibility guard");
            return;
        }

        phtvOriginalRemoteViewOrderOnScreen = (PHTVRemoteViewOrderOnScreenIMP)original;
        method_setImplementation(method, (IMP)PHTVRemoteViewContainingWindowWillOrderOnScreen);
        atomic_store_explicit(&phtvRemoteViewGuardInstalled, true, memory_order_release);
        os_log_info(OS_LOG_DEFAULT, "[RemoteViewGuard] Installed macOS 27 AppKit compatibility guard");
    });
}

+ (BOOL)isInstalled {
    return atomic_load_explicit(&phtvRemoteViewGuardInstalled, memory_order_acquire);
}

+ (uint64_t)suppressedExceptionCount {
    return atomic_load_explicit(
        &phtvRemoteViewSuppressedExceptionCount,
        memory_order_relaxed
    );
}

@end
