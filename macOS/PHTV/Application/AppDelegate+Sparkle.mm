//
//  AppDelegate+Sparkle.mm
//  PHTV
//
//  Extracted Sparkle integration from AppDelegate for lower coupling.
//

#import "AppDelegate+Sparkle.h"
#import "SparkleManager.h"

@implementation AppDelegate (Sparkle)

- (void)registerSparkleObservers {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

    [center addObserver:self
               selector:@selector(handleSparkleManualCheck:)
                   name:@"SparkleManualCheck"
                 object:nil];

    [center addObserver:self
               selector:@selector(handleSparkleUpdateFound:)
                   name:@"SparkleUpdateFound"
                 object:nil];

    // Show "up to date" alert only for manual checks.
    [center addObserver:self
               selector:@selector(handleSparkleNoUpdate:)
                   name:@"SparkleNoUpdateFound"
                 object:nil];

    [center addObserver:self
               selector:@selector(handleUpdateFrequencyChanged:)
                   name:@"UpdateCheckFrequencyChanged"
                 object:nil];

    [center addObserver:self
               selector:@selector(handleSparkleInstallUpdate:)
                   name:@"SparkleInstallUpdate"
                 object:nil];
}

- (void)handleSparkleManualCheck:(NSNotification *)notification {
    (void)notification;
    NSLog(@"[Sparkle] Manual check requested from UI");
    [[SparkleManager shared] checkForUpdatesWithFeedback];
}

- (void)handleSparkleUpdateFound:(NSNotification *)notification {
    NSDictionary *updateInfo = notification.object;

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"CheckForUpdatesResponse"
                                                            object:@{
            @"message": [NSString stringWithFormat:@"Phiên bản mới %@ có sẵn", updateInfo[@"version"]],
            @"isError": @NO,
            @"updateAvailable": @YES,
            @"latestVersion": updateInfo[@"version"],
            @"downloadUrl": updateInfo[@"downloadURL"],
            @"releaseNotes": updateInfo[@"releaseNotes"]
        }];
    });
}

- (void)handleSparkleNoUpdate:(NSNotification *)notification {
    (void)notification;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *currentVersion = [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];

        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Đã cập nhật"];
        [alert setInformativeText:[NSString stringWithFormat:@"Bạn đang sử dụng phiên bản mới nhất của PHTV (%@).", currentVersion]];
        [alert addButtonWithTitle:@"OK"];
        [alert setAlertStyle:NSAlertStyleInformational];
        [alert runModal];
    });
}

- (void)handleUpdateFrequencyChanged:(NSNotification *)notification {
    NSNumber *interval = notification.object;
    if (![interval isKindOfClass:[NSNumber class]]) {
        return;
    }

    NSLog(@"[Sparkle] Update frequency changed to: %.0f seconds", [interval doubleValue]);
    [[SparkleManager shared] setUpdateCheckInterval:[interval doubleValue]];
}

- (void)handleSparkleInstallUpdate:(NSNotification *)notification {
    (void)notification;
    NSLog(@"[Sparkle] Install update requested from custom banner");
    [[SparkleManager shared] checkForUpdatesWithFeedback];
}

@end
