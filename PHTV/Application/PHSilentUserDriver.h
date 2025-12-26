//
//  PHSilentUserDriver.h
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import <Sparkle/Sparkle.h>

NS_ASSUME_NONNULL_BEGIN

/// Custom user driver that suppresses annoying update-related alerts:
/// - "No update found" alerts when already up-to-date
/// - Appcast load errors (network errors, 404, timeout, etc)
/// - Default Sparkle UI dialogs
///
/// This provides a silent, non-intrusive update checking experience
/// while still notifying users when actual updates are available.
@interface PHSilentUserDriver : SPUStandardUserDriver

@end

NS_ASSUME_NONNULL_END
