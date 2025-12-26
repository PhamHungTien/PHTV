//
//  PHSilentUserDriver.h
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import <Sparkle/Sparkle.h>

NS_ASSUME_NONNULL_BEGIN

/// Custom user driver that suppresses the "no update found" alert
/// while keeping all other Sparkle UI behaviors intact
@interface PHSilentUserDriver : SPUStandardUserDriver

@end

NS_ASSUME_NONNULL_END
