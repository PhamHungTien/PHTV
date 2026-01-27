//
//  PHSilentUserDriver.h
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import <Sparkle/Sparkle.h>

NS_ASSUME_NONNULL_BEGIN

/// Custom user driver for Sparkle 2.x that provides:
/// - Silent auto-install when enabled (no UI)
/// - Suppresses "no update found" alerts
/// - Suppresses appcast load errors
///
/// This provides a seamless, non-intrusive update experience.
@interface PHSilentUserDriver : SPUStandardUserDriver

/// Enable/disable silent auto-install mode
/// When enabled, updates are installed automatically without user interaction
@property (nonatomic, assign) BOOL silentAutoInstallEnabled;

@end

NS_ASSUME_NONNULL_END
