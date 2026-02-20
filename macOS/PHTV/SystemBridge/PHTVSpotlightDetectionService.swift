//
//  PHTVSpotlightDetectionService.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation
import Darwin

@objcMembers
final class PHTVSpotlightDetectionService: NSObject {
    private static let externalDeleteResetThresholdMs: UInt64 = 30_000
    private static let searchKeywords: [String] = [
        "search",
        "tìm kiếm",
        "tìm",
        "filter",
        "lọc"
    ]

    nonisolated(unsafe) private static var externalDeleteDetected = false
    nonisolated(unsafe) private static var lastExternalDeleteTime: UInt64 = 0
    nonisolated(unsafe) private static var externalDeleteCount = 0

    nonisolated(unsafe) private static var lock = NSLock()

    @objc class func containsSearchKeyword(_ value: String?) -> Bool {
        guard let lower = value?.lowercased(), !lower.isEmpty else {
            return false
        }
        for keyword in searchKeywords where lower.contains(keyword) {
            return true
        }
        return false
    }

    @objc class func trackExternalDelete() {
        let now = mach_absolute_time()
        lock.lock()
        defer { lock.unlock() }

        if lastExternalDeleteTime != 0 {
            let elapsedMs = PHTVTimingService.machTimeToMs(now - lastExternalDeleteTime)
            if elapsedMs > externalDeleteResetThresholdMs {
                externalDeleteCount = 0
            }
        }

        lastExternalDeleteTime = now
        externalDeleteCount += 1
        externalDeleteDetected = true
    }

    @objc class func hasRecentExternalDeletes() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return externalDeleteDetected
    }

    @objc class func externalDeleteCountValue() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return externalDeleteCount
    }

    @objc class func resetExternalDeleteTracking() {
        lock.lock()
        defer { lock.unlock() }
        externalDeleteDetected = false
        lastExternalDeleteTime = 0
        externalDeleteCount = 0
    }
}
