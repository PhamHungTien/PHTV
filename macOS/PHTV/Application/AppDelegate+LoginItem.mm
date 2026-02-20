//
//  AppDelegate+LoginItem.mm
//  PHTV
//
//  Launch at Login lifecycle extracted from AppDelegate.
//

#import "AppDelegate+LoginItem.h"
#import <ServiceManagement/ServiceManagement.h>

static NSString *const PHTVDefaultsKeyRunOnStartup = @"RunOnStartup";
static NSString *const PHTVDefaultsKeyRunOnStartupLegacy = @"PHTV_RunOnStartup";

static NSString *const PHTVNotificationRunOnStartupChanged = @"RunOnStartupChanged";
static NSString *const PHTVNotificationUserInfoEnabledKey = @"enabled";

@implementation AppDelegate (LoginItem)

- (void)syncRunOnStartupStatusWithFirstLaunch:(BOOL)isFirstLaunch {
    // CRITICAL FIX: Sync Launch at Login with actual SMAppService status.
    // This ensures UserDefaults matches reality after app restart.
    if (@available(macOS 13.0, *)) {
        SMAppService *appService = [SMAppService mainAppService];
        SMAppServiceStatus actualStatus = appService.status;
        BOOL actuallyEnabled = (actualStatus == SMAppServiceStatusEnabled);

        NSInteger savedValue = [[NSUserDefaults standardUserDefaults] integerForKey:PHTVDefaultsKeyRunOnStartup];
        BOOL savedEnabled = (savedValue == 1);

        NSLog(@"[LoginItem] Startup sync - Actual: %d, Saved: %d, Status: %ld",
              actuallyEnabled, savedEnabled, (long)actualStatus);

        if (isFirstLaunch) {
            NSLog(@"[LoginItem] First launch detected - enabling Launch at Login");
            [self setRunOnStartup:YES];
        } else if (actuallyEnabled != savedEnabled) {
            if (savedEnabled && !actuallyEnabled) {
                NSLog(@"[LoginItem] ⚠️ User enabled but SMAppService is disabled - syncing UI to OFF");
                NSLog(@"[LoginItem] Possible causes: code signature, system policy, or macOS disabled it");

                [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:PHTVDefaultsKeyRunOnStartup];
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:PHTVDefaultsKeyRunOnStartupLegacy];

                [[NSNotificationCenter defaultCenter] postNotificationName:PHTVNotificationRunOnStartupChanged
                                                                    object:nil
                                                                  userInfo:@{PHTVNotificationUserInfoEnabledKey: @(NO)}];
            } else if (!savedEnabled && actuallyEnabled) {
                NSLog(@"[LoginItem] User disabled but SMAppService still enabled - disabling");
                [self setRunOnStartup:NO];
            }
        } else {
            NSLog(@"[LoginItem] ✅ Status consistent: %@", actuallyEnabled ? @"ENABLED" : @"DISABLED");
        }
    } else {
        NSInteger val = [[NSUserDefaults standardUserDefaults] integerForKey:PHTVDefaultsKeyRunOnStartup];
        [self setRunOnStartup:val];
    }
}

-(void)setRunOnStartup:(BOOL)val {
    // Use SMAppService for macOS 13+ (application target is macOS 13+).
    SMAppService *appService = [SMAppService mainAppService];
    NSError *error = nil;
    BOOL actualSuccess = NO;  // Track actual registration result.

    NSLog(@"[LoginItem] Current SMAppService status: %ld", (long)appService.status);

    if (val) {
        if (appService.status != SMAppServiceStatusEnabled) {
            NSBundle *bundle = [NSBundle mainBundle];
            NSString *bundlePath = bundle.bundlePath;

            NSTask *verifyTask = [[NSTask alloc] init];
            verifyTask.launchPath = @"/usr/bin/codesign";
            verifyTask.arguments = @[@"--verify", @"--deep", @"--strict", bundlePath];

            NSPipe *pipe = [NSPipe pipe];
            verifyTask.standardError = pipe;

            @try {
                [verifyTask launch];
                [verifyTask waitUntilExit];

                int status = verifyTask.terminationStatus;
                if (status != 0) {
                    NSData *errorData = [[pipe fileHandleForReading] readDataToEndOfFile];
                    NSString *errorString = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding];
                    NSLog(@"⚠️ [LoginItem] Code signature verification failed: %@", errorString);
                    NSLog(@"⚠️ [LoginItem] SMAppService may reject unsigned/ad-hoc signed apps");
                } else {
                    NSLog(@"✅ [LoginItem] Code signature verified");
                }
            } @catch (NSException *exception) {
                NSLog(@"⚠️ [LoginItem] Failed to verify code signature: %@", exception);
            }

            BOOL success = [appService registerAndReturnError:&error];
            if (success) {
                NSLog(@"✅ [LoginItem] Registered with SMAppService");
                actualSuccess = YES;
            } else {
                NSLog(@"❌ [LoginItem] Failed to register with SMAppService");
                NSLog(@"   Error: %@", error.localizedDescription);
                NSLog(@"   Error Domain: %@", error.domain);
                NSLog(@"   Error Code: %ld", (long)error.code);

                if (error.userInfo) {
                    NSLog(@"   Error UserInfo: %@", error.userInfo);
                }

                if ([error.domain isEqualToString:@"SMAppServiceErrorDomain"]) {
                    switch (error.code) {
                        case 1: { // kSMAppServiceErrorAlreadyRegistered
                            NSLog(@"   → App already registered (stale state). Trying to unregister first...");
                            [appService unregisterAndReturnError:nil];
                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                                           dispatch_get_main_queue(), ^{
                                NSError *retryError = nil;
                                if ([appService registerAndReturnError:&retryError]) {
                                    NSLog(@"✅ [LoginItem] Registration succeeded on retry");

                                    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:PHTVDefaultsKeyRunOnStartupLegacy];
                                    [[NSUserDefaults standardUserDefaults] setInteger:1 forKey:PHTVDefaultsKeyRunOnStartup];

                                    [[NSNotificationCenter defaultCenter] postNotificationName:PHTVNotificationRunOnStartupChanged
                                                                                        object:nil
                                                                                      userInfo:@{PHTVNotificationUserInfoEnabledKey: @(YES)}];
                                } else {
                                    NSLog(@"❌ [LoginItem] Registration still failed: %@", retryError.localizedDescription);

                                    [[NSNotificationCenter defaultCenter] postNotificationName:PHTVNotificationRunOnStartupChanged
                                                                                        object:nil
                                                                                      userInfo:@{PHTVNotificationUserInfoEnabledKey: @(NO)}];
                                }
                            });
                            return;
                        }
                        case 2: { // kSMAppServiceErrorInvalidSignature
                            NSLog(@"   → Invalid code signature. App must be properly signed with Developer ID");
                            NSLog(@"   → Ad-hoc signed apps (for development) are NOT supported by SMAppService");
                            NSLog(@"   → Solution: Sign with Apple Developer ID certificate or use notarization");
                            break;
                        }
                        case 3: { // kSMAppServiceErrorInvalidPlist
                            NSLog(@"   → Invalid Info.plist configuration");
                            break;
                        }
                        default: {
                            NSLog(@"   → Unknown SMAppService error");
                            break;
                        }
                    }
                }

                actualSuccess = NO;
            }
        } else {
            NSLog(@"ℹ️ [LoginItem] Already enabled, skipping registration");
            actualSuccess = YES;
        }
    } else {
        if (appService.status == SMAppServiceStatusEnabled) {
            BOOL success = [appService unregisterAndReturnError:&error];
            if (success) {
                NSLog(@"✅ [LoginItem] Unregistered from SMAppService");
                actualSuccess = YES;
            } else {
                NSLog(@"❌ [LoginItem] Failed to unregister: %@", error.localizedDescription);
                NSLog(@"   Error Domain: %@, Code: %ld", error.domain, (long)error.code);
                actualSuccess = NO;
            }
        } else {
            NSLog(@"ℹ️ [LoginItem] Already disabled, skipping unregistration");
            actualSuccess = YES;
        }
    }

    if (actualSuccess) {
        [[NSUserDefaults standardUserDefaults] setBool:val forKey:PHTVDefaultsKeyRunOnStartupLegacy];
        [[NSUserDefaults standardUserDefaults] setInteger:(val ? 1 : 0) forKey:PHTVDefaultsKeyRunOnStartup];

        [[NSNotificationCenter defaultCenter] postNotificationName:PHTVNotificationRunOnStartupChanged
                                                            object:nil
                                                          userInfo:@{PHTVNotificationUserInfoEnabledKey: @(val)}];

        NSLog(@"[LoginItem] ✅ Launch at Login %@ - UserDefaults saved and UI notified", val ? @"ENABLED" : @"DISABLED");
    } else {
        NSLog(@"[LoginItem] ❌ Operation failed - reverting toggle to %@", val ? @"OFF" : @"ON");

        [[NSNotificationCenter defaultCenter] postNotificationName:PHTVNotificationRunOnStartupChanged
                                                            object:nil
                                                          userInfo:@{PHTVNotificationUserInfoEnabledKey: @(!val)}];
    }
}

- (void)toggleStartupItem:(NSMenuItem *)sender {
    NSInteger currentValue = [[NSUserDefaults standardUserDefaults] integerForKey:PHTVDefaultsKeyRunOnStartup];
    BOOL newValue = !currentValue;

    [self setRunOnStartup:newValue];
    [self fillData];

    NSString *message = newValue
        ? @"✅ PHTV sẽ tự động khởi động cùng hệ thống"
        : @"❌ Đã tắt khởi động cùng hệ thống";
    NSLog(@"%@", message);
}

@end
