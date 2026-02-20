//
//  PHTVTimingService.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation
import Darwin

@objcMembers
final class PHTVTimingService: NSObject {
    private static let timebaseInfo: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t(numer: 0, denom: 0)
        mach_timebase_info(&info)
        return info
    }()

    @objc class func machTimeToMs(_ machTime: UInt64) -> UInt64 {
        let timebase = timebaseInfo
        return (machTime * UInt64(timebase.numer)) / (UInt64(timebase.denom) * 1_000_000)
    }

    @objc class func machTimeToUs(_ machTime: UInt64) -> UInt64 {
        let timebase = timebaseInfo
        return (machTime * UInt64(timebase.numer)) / (UInt64(timebase.denom) * 1_000)
    }

    // Intentionally kept as no-op to preserve current behavior.
    @objc class func spotlightTinyDelay() {
    }

    @objc class func delayMicroseconds(_ microseconds: UInt64) {
        guard microseconds > 0 else { return }
        let capped = min(microseconds, UInt64(useconds_t.max))
        usleep(useconds_t(capped))
    }
}
