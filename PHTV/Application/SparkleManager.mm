//
//  SparkleManager.mm
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import "SparkleManager.h"

@interface SparkleManager ()
@property (nonatomic, strong) SPUStandardUpdaterController *updaterController;
@property (nonatomic, assign) BOOL betaChannelEnabled;
@end

@implementation SparkleManager

+ (instancetype)shared {
    static SparkleManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SparkleManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // Initialize Sparkle with delegate
        _updaterController = [[SPUStandardUpdaterController alloc]
            initWithStartingUpdater:YES
            updaterDelegate:self
            userDriverDelegate:self];

        // Load preferences
        _betaChannelEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"SUEnableBetaChannel"];

        NSLog(@"[Sparkle] Initialized - Beta channel: %@", _betaChannelEnabled ? @"ON" : @"OFF");
    }
    return self;
}

- (void)checkForUpdatesWithFeedback {
    NSLog(@"[Sparkle] User-initiated update check (with feedback)");
    // Pass self as sender so Sparkle knows this is user-initiated
    // This will show "You're up to date!" dialog when no update found
    [self.updaterController checkForUpdates:self];
}

- (void)checkForUpdates {
    NSLog(@"[Sparkle] Background update check (silent)");
    [self.updaterController checkForUpdates:nil];
}

- (void)setUpdateCheckInterval:(NSTimeInterval)interval {
    NSLog(@"[Sparkle] Update interval set to %.0f seconds", interval);
    [[NSUserDefaults standardUserDefaults] setDouble:interval forKey:@"SUScheduledCheckInterval"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setBetaChannelEnabled:(BOOL)enabled {
    NSLog(@"[Sparkle] Beta channel %@", enabled ? @"ENABLED" : @"DISABLED");
    _betaChannelEnabled = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:@"SUEnableBetaChannel"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - SPUUpdaterDelegate

- (nullable NSString *)feedURLStringForUpdater:(SPUUpdater *)updater {
    if (self.betaChannelEnabled) {
        NSLog(@"[Sparkle] Using BETA feed");
        return @"https://phamhungtien.github.io/PHTV/appcast-beta.xml";
    }
    NSLog(@"[Sparkle] Using STABLE feed");
    return nil; // Use Info.plist value
}

- (void)updater:(SPUUpdater *)updater didFindValidUpdate:(SUAppcastItem *)item {
    NSLog(@"[Sparkle] Update found: %@ (%@)", item.displayVersionString, item.versionString);

    // Notify SwiftUI
    NSDictionary *info = @{
        @"version": item.displayVersionString ?: @"",
        @"releaseNotes": item.itemDescription ?: @"",
        @"downloadURL": item.fileURL.absoluteString ?: @""
    };

    [[NSNotificationCenter defaultCenter] postNotificationName:@"SparkleUpdateFound" object:info];
}

- (void)updaterDidNotFindUpdate:(SPUUpdater *)updater {
    NSLog(@"[Sparkle] No updates available");
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SparkleNoUpdateFound" object:nil];
}

- (void)updater:(SPUUpdater *)updater didFinishLoadingAppcast:(SUAppcast *)appcast {
    NSLog(@"[Sparkle] Appcast loaded: %lu items", (unsigned long)appcast.items.count);
}

- (void)updater:(SPUUpdater *)updater failedToDownloadUpdate:(SUAppcastItem *)item error:(NSError *)error {
    NSLog(@"[Sparkle] Failed to download update: %@", error.localizedDescription);

    NSDictionary *info = @{
        @"message": [NSString stringWithFormat:@"Lỗi tải bản cập nhật: %@", error.localizedDescription],
        @"isError": @YES,
        @"updateAvailable": @NO
    };

    [[NSNotificationCenter defaultCenter] postNotificationName:@"CheckForUpdatesResponse" object:info];
}

- (void)updater:(SPUUpdater *)updater willInstallUpdate:(SUAppcastItem *)item {
    NSLog(@"[Sparkle] Will install update: %@", item.displayVersionString);
}

#pragma mark - SPUStandardUserDriverDelegate

- (void)standardUserDriverWillHandleShowingUpdate:(BOOL)handleShowingUpdate
                                        forUpdate:(SUAppcastItem *)update
                                            state:(SPUUserUpdateState *)state {
    // Intercept to show custom update banner
    NSLog(@"[Sparkle] Showing custom update UI for: %@", update.displayVersionString);

    NSDictionary *info = @{
        @"version": update.displayVersionString ?: @"",
        @"releaseNotes": update.itemDescription ?: @"",
        @"downloadURL": update.fileURL.absoluteString ?: @""
    };

    [[NSNotificationCenter defaultCenter] postNotificationName:@"SparkleShowUpdateBanner" object:info];
}

- (void)standardUserDriverDidReceiveUserAttention:(SPUStandardUserDriver *)userDriver {
    NSLog(@"[Sparkle] User attention received");
}

@end
