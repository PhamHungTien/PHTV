//
//  PHTVCacheStateService.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation
import Darwin

@objcMembers
final class PHTVCacheStateService: NSObject {
    nonisolated(unsafe) private static var spotlightLock = NSLock()
    nonisolated(unsafe) private static var _cachedSpotlightActive = false
    nonisolated(unsafe) private static var _lastSpotlightCheckTime: UInt64 = 0
    nonisolated(unsafe) private static var _cachedFocusedPID: Int32 = 0
    nonisolated(unsafe) private static var _cachedFocusedBundleId: String?
    nonisolated(unsafe) private static var _lastSpotlightInvalidationTime: UInt64 = 0

    nonisolated(unsafe) private static var layoutLock = NSLock()
    nonisolated(unsafe) private static var layoutCache = Array<UInt16>(repeating: 0, count: 256)
    nonisolated(unsafe) private static var layoutCacheValid = false

    // MARK: - Spotlight Cache

    @objc class func cachedSpotlightActive() -> Bool {
        spotlightLock.lock()
        defer { spotlightLock.unlock() }
        return _cachedSpotlightActive
    }

    @objc class func cachedFocusedPID() -> Int32 {
        spotlightLock.lock()
        defer { spotlightLock.unlock() }
        return _cachedFocusedPID
    }

    @objc class func cachedFocusedBundleId() -> String? {
        spotlightLock.lock()
        defer { spotlightLock.unlock() }
        return _cachedFocusedBundleId
    }

    @objc class func lastSpotlightCheckTime() -> UInt64 {
        spotlightLock.lock()
        defer { spotlightLock.unlock() }
        return _lastSpotlightCheckTime
    }

    @objc class func lastSpotlightInvalidationTime() -> UInt64 {
        spotlightLock.lock()
        defer { spotlightLock.unlock() }
        return _lastSpotlightInvalidationTime
    }

    @objc class func updateSpotlightCache(_ isActive: Bool, pid: Int32, bundleId: String?) {
        spotlightLock.lock()
        defer { spotlightLock.unlock() }
        _cachedSpotlightActive = isActive
        _lastSpotlightCheckTime = mach_absolute_time()
        _cachedFocusedPID = pid
        _cachedFocusedBundleId = bundleId
    }

    // Returns:
    // 0 = skipped (dedup window)
    // 1 = invalidated (already inactive)
    // 2 = invalidated (was active)
    @objc class func invalidateSpotlightCache(dedupWindowMs: UInt64) -> Int {
        let now = mach_absolute_time()

        spotlightLock.lock()
        defer { spotlightLock.unlock() }

        let elapsedSinceLastInvalidationMs = (_lastSpotlightInvalidationTime > 0)
            ? PHTVTimingService.machTimeToMs(now - _lastSpotlightInvalidationTime)
            : UInt64.max

        let alreadyInvalid = (!_cachedSpotlightActive &&
                              _cachedFocusedPID == 0 &&
                              _cachedFocusedBundleId == nil)
        if alreadyInvalid && elapsedSinceLastInvalidationMs < dedupWindowMs {
            return 0
        }

        let wasActive = _cachedSpotlightActive
        _cachedSpotlightActive = false
        _lastSpotlightCheckTime = 0
        _cachedFocusedPID = 0
        _cachedFocusedBundleId = nil
        _lastSpotlightInvalidationTime = now

        return wasActive ? 2 : 1
    }

    // MARK: - Layout Cache

    @objc class func cachedLayoutConversion(_ keycode: UInt16) -> UInt16 {
        let index = Int(keycode)
        guard index < 256 else { return 0 }

        layoutLock.lock()
        defer { layoutLock.unlock() }
        return layoutCache[index]
    }

    @objc class func setCachedLayoutConversion(_ keycode: UInt16, result: UInt16) {
        let index = Int(keycode)
        guard index < 256 else { return }

        layoutLock.lock()
        layoutCache[index] = result
        layoutCacheValid = true
        layoutLock.unlock()
    }

    @objc class func invalidateLayoutCache() {
        layoutLock.lock()
        layoutCache = Array<UInt16>(repeating: 0, count: 256)
        layoutCacheValid = false
        layoutLock.unlock()
    }

    @objc class func isLayoutCacheValid() -> Bool {
        layoutLock.lock()
        defer { layoutLock.unlock() }
        return layoutCacheValid
    }
}
