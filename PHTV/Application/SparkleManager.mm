//
//  SparkleManager.mm
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import "SparkleManager.h"
#import "PHSilentUserDriver.h"

@interface SparkleManager ()
@property (nonatomic, strong) SPUUpdater *updater;
@property (nonatomic, strong) PHSilentUserDriver *customUserDriver;
@property (nonatomic, assign) BOOL betaChannelEnabled;
@property (nonatomic, assign) BOOL isManualCheck;  // Track if this is a user-initiated check
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
        // Create custom user driver that suppresses "no update found" alert
        _customUserDriver = [[PHSilentUserDriver alloc] initWithHostBundle:[NSBundle mainBundle]
                                                                  delegate:self];

        // Initialize SPUUpdater directly with custom user driver
        // This allows us to suppress the "no update found" alert
        _updater = [[SPUUpdater alloc] initWithHostBundle:[NSBundle mainBundle]
                                        applicationBundle:[NSBundle mainBundle]
                                               userDriver:_customUserDriver
                                                 delegate:self];

        // Start the updater
        NSError *error = nil;
        if (![_updater startUpdater:&error]) {
            NSLog(@"[Sparkle] Failed to start updater: %@", error);
        }

        // Load preferences
        _betaChannelEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"SUEnableBetaChannel"];

        NSLog(@"[Sparkle] Initialized with PHSilentUserDriver - Beta channel: %@", _betaChannelEnabled ? @"ON" : @"OFF");
    }
    return self;
}

- (void)checkForUpdatesWithFeedback {
    NSLog(@"[Sparkle] User-initiated update check (with feedback)");
    self.isManualCheck = YES;
    // Custom user driver will suppress "no update found" alert
    [self.updater checkForUpdates];
}

- (void)checkForUpdates {
    NSLog(@"[Sparkle] Background update check (silent)");
    self.isManualCheck = NO;
    [self.updater checkForUpdatesInBackground];
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
    NSLog(@"[Sparkle] didFindValidUpdate - itemDescription length: %lu", (unsigned long)[item.itemDescription length]);

    // Notify SwiftUI - always notify when update is found
    NSDictionary *info = @{
        @"version": item.displayVersionString ?: @"",
        @"releaseNotes": item.itemDescription ?: @"",
        @"downloadURL": item.fileURL.absoluteString ?: @""
    };

    [[NSNotificationCenter defaultCenter] postNotificationName:@"SparkleUpdateFound" object:info];

    // Reset flag after check
    self.isManualCheck = NO;
}

- (void)updaterDidNotFindUpdate:(SPUUpdater *)updater {
    NSLog(@"[Sparkle] No updates available (manual check: %@)", self.isManualCheck ? @"YES" : @"NO");

    // Only show "up to date" message for manual checks
    if (self.isManualCheck) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SparkleNoUpdateFound" object:nil];
    }
    // Silent for background checks - no notification

    // Reset flag after check
    self.isManualCheck = NO;
}

- (void)updater:(SPUUpdater *)updater didFinishLoadingAppcast:(SUAppcast *)appcast {
    NSLog(@"[Sparkle] Appcast loaded: %lu items", (unsigned long)appcast.items.count);
}

- (void)updater:(SPUUpdater *)updater failedToDownloadUpdate:(SUAppcastItem *)item error:(NSError *)error {
    NSLog(@"[Sparkle] Failed to download update: %@ (manual check: %@)", error.localizedDescription, self.isManualCheck ? @"YES" : @"NO");

    // Only show error to user if this was a manual check
    if (self.isManualCheck) {
        NSDictionary *info = @{
            @"message": [NSString stringWithFormat:@"Lỗi tải bản cập nhật: %@", error.localizedDescription],
            @"isError": @YES,
            @"updateAvailable": @NO
        };

        [[NSNotificationCenter defaultCenter] postNotificationName:@"CheckForUpdatesResponse" object:info];
    }

    // Reset flag after check
    self.isManualCheck = NO;
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
    NSString *releaseNotes = update.itemDescription ?: @"";
    NSLog(@"[Sparkle] Release notes length: %lu", (unsigned long)[releaseNotes length]);
    if (releaseNotes.length > 0) {
        NSLog(@"[Sparkle] Release notes preview: %@", [releaseNotes substringToIndex:MIN(200, releaseNotes.length)]);
    } else {
        NSLog(@"[Sparkle] Release notes: EMPTY");
    }

    NSDictionary *info = @{
        @"version": update.displayVersionString ?: @"",
        @"releaseNotes": update.itemDescription ?: @"",
        @"downloadURL": update.fileURL.absoluteString ?: @""
    };

    [[NSNotificationCenter defaultCenter] postNotificationName:@"SparkleShowUpdateBanner" object:info];

    // Reset flag after showing update
    self.isManualCheck = NO;
}

- (void)standardUserDriverDidReceiveUserAttention:(SPUStandardUserDriver *)userDriver {
    NSLog(@"[Sparkle] User attention received");
}

@end
