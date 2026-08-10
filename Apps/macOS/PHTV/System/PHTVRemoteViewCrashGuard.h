//
//  PHTVRemoteViewCrashGuard.h
//  PHTV
//
//  Temporary compatibility guard for a macOS 27 AppKit/ViewBridge regression.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PHTVRemoteViewCrashGuard : NSObject

/// Installs the guard once when running on the affected macOS generation.
+ (void)installIfNeeded;

/// Exposed so the status-item lifecycle can avoid unnecessary scene churn.
+ (BOOL)isInstalled;

/// Pure version check used by tests and by the installer.
+ (BOOL)shouldInstallForMajorVersion:(NSInteger)majorVersion;

/// Number of matching AppKit exceptions suppressed during this process.
+ (uint64_t)suppressedExceptionCount;

@end

NS_ASSUME_NONNULL_END
