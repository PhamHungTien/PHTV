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
/// - Silent auto-install (always on, no UI toggle)
/// - Suppresses "no update found" alerts
/// - Suppresses appcast load errors
///
/// This provides a seamless, non-intrusive update experience.
@interface PHSilentUserDriver : SPUStandardUserDriver

@end

NS_ASSUME_NONNULL_END
