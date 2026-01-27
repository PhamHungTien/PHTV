//
//  SparkleManager.h
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Sparkle/Sparkle.h>

NS_ASSUME_NONNULL_BEGIN

@interface SparkleManager : NSObject <SPUUpdaterDelegate, SPUStandardUserDriverDelegate>

@property (nonatomic, strong, readonly) SPUUpdater *updater;

+ (instancetype)shared;

/// Manually trigger update check (user-initiated, shows feedback)
- (void)checkForUpdatesWithFeedback;

/// Background update check (silent)
- (void)checkForUpdates;

/// Configure update check interval in seconds
- (void)setUpdateCheckInterval:(NSTimeInterval)interval;

/// Enable or disable beta channel
- (void)setBetaChannelEnabled:(BOOL)enabled;

// installUpdateSilently removed - auto-install is now handled directly by PHSilentUserDriver

@end

NS_ASSUME_NONNULL_END
