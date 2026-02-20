//
//  PHTVCacheStateService.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation
import AppKit
import Darwin

@objcMembers
final class PHTVAppCharacteristicsBox: NSObject {
    let isSpotlightLike: Bool
    let needsPrecomposedBatched: Bool
    let needsStepByStep: Bool
    let containsUnicodeCompound: Bool
    let isSafari: Bool

    init(
        isSpotlightLike: Bool,
        needsPrecomposedBatched: Bool,
        needsStepByStep: Bool,
        containsUnicodeCompound: Bool,
        isSafari: Bool
    ) {
        self.isSpotlightLike = isSpotlightLike
        self.needsPrecomposedBatched = needsPrecomposedBatched
        self.needsStepByStep = needsStepByStep
        self.containsUnicodeCompound = containsUnicodeCompound
        self.isSafari = isSafari
    }
}

@objcMembers
final class PHTVCacheStateService: NSObject {
    private static let pidCacheCleanIntervalMs: UInt64 = 60_000
    private static let pidCacheEmptyValue = ""

    nonisolated(unsafe) private static var pidLock = NSLock()
    nonisolated(unsafe) private static var pidBundleCache = [Int32: String]()
    nonisolated(unsafe) private static var lastPidCacheCleanTime: UInt64 = 0

    nonisolated(unsafe) private static var appCharLock = NSLock()
    nonisolated(unsafe) private static var appCharacteristicsCache = [String: PHTVAppCharacteristicsBox]()
    nonisolated(unsafe) private static var _lastCachedBundleId: String?
    nonisolated(unsafe) private static var _lastAppCharCacheInvalidationTime: UInt64 = 0

    nonisolated(unsafe) private static var spotlightLock = NSLock()
    nonisolated(unsafe) private static var _cachedSpotlightActive = false
    nonisolated(unsafe) private static var _lastSpotlightCheckTime: UInt64 = 0
    nonisolated(unsafe) private static var _cachedFocusedPID: Int32 = 0
    nonisolated(unsafe) private static var _cachedFocusedBundleId: String?
    nonisolated(unsafe) private static var _lastSpotlightInvalidationTime: UInt64 = 0

    private static let layoutCacheNoValue: UInt16 = .max
    nonisolated(unsafe) private static var layoutLock = NSLock()
    nonisolated(unsafe) private static var layoutCache = Array<UInt16>(repeating: layoutCacheNoValue, count: 256)
    nonisolated(unsafe) private static var layoutCacheValid = false

    // MARK: - PID Cache

    @objc(bundleIdFromPID:safeMode:)
    class func bundleIdFromPID(_ pid: Int32, safeMode: Bool) -> String? {
        guard pid > 0 else {
            return nil
        }

        let now = mach_absolute_time()
        pidLock.lock()
        if lastPidCacheCleanTime == 0 {
            lastPidCacheCleanTime = now
        }

        let elapsedMs = PHTVTimingService.machTimeToMs(now - lastPidCacheCleanTime)
        if elapsedMs > pidCacheCleanIntervalMs {
            pidBundleCache.removeAll(keepingCapacity: true)
            lastPidCacheCleanTime = now
#if DEBUG
            NSLog("[Cache] PID cache cleared (interval expired)")
#endif
        }

        if let cached = pidBundleCache[pid] {
            pidLock.unlock()
            return cached.isEmpty ? nil : cached
        }
        pidLock.unlock()

        if let app = NSRunningApplication(processIdentifier: pid_t(pid)) {
            let bundleId = app.bundleIdentifier ?? pidCacheEmptyValue
            pidLock.lock()
            pidBundleCache[pid] = bundleId
            pidLock.unlock()
            return bundleId.isEmpty ? nil : bundleId
        }

        if safeMode {
            pidLock.lock()
            pidBundleCache[pid] = pidCacheEmptyValue
            pidLock.unlock()
            return nil
        }

        // PROC_PIDPATHINFO_MAXSIZE macro may be unavailable in Swift import contexts.
        // Keep the same effective size (4 * MAXPATHLEN) used by libproc headers.
        var pathBuffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        if proc_pidpath(pid_t(pid), &pathBuffer, UInt32(pathBuffer.count)) > 0 {
            let path = pathBuffer.withUnsafeBufferPointer { buffer in
                let end = buffer.firstIndex(of: 0) ?? buffer.count
                let utf8Bytes = buffer.prefix(end).map { UInt8(bitPattern: $0) }
                return String(decoding: utf8Bytes, as: UTF8.self)
            }
#if DEBUG
            NSLog("PHTV DEBUG: PID=%d path=%@", pid, path)
#endif
            if path.contains("Spotlight") {
                pidLock.lock()
                pidBundleCache[pid] = "com.apple.Spotlight"
                pidLock.unlock()
                return "com.apple.Spotlight"
            }
            if path.contains("SystemUIServer") {
                pidLock.lock()
                pidBundleCache[pid] = "com.apple.systemuiserver"
                pidLock.unlock()
                return "com.apple.systemuiserver"
            }
            if path.contains("Launchpad") {
                pidLock.lock()
                pidBundleCache[pid] = "com.apple.launchpad.launcher"
                pidLock.unlock()
                return "com.apple.launchpad.launcher"
            }
        }

        pidLock.lock()
        pidBundleCache[pid] = pidCacheEmptyValue
        pidLock.unlock()
        return nil
    }

    @objc class func cleanPIDCacheIfNeeded() {
        let now = mach_absolute_time()
        pidLock.lock()
        defer { pidLock.unlock() }
        guard !pidBundleCache.isEmpty, lastPidCacheCleanTime > 0 else {
            return
        }
        let elapsedMs = PHTVTimingService.machTimeToMs(now - lastPidCacheCleanTime)
        if elapsedMs > pidCacheCleanIntervalMs {
            pidBundleCache.removeAll(keepingCapacity: true)
            lastPidCacheCleanTime = now
        }
    }

    @objc class func invalidatePIDCache() {
        pidLock.lock()
        pidBundleCache.removeAll(keepingCapacity: false)
        lastPidCacheCleanTime = 0
        pidLock.unlock()
    }

    // MARK: - App Characteristics Cache

    @objc(appCharacteristicsForBundleId:)
    class func appCharacteristics(forBundleId bundleId: String?) -> PHTVAppCharacteristicsBox? {
        guard let bundleId, !bundleId.isEmpty else {
            return nil
        }
        appCharLock.lock()
        defer { appCharLock.unlock() }
        return appCharacteristicsCache[bundleId]
    }

    // Returns:
    // 0 = no invalidation
    // 1 = invalidated due to app switch
    // 2 = invalidated due to age (or first use)
    @objc(prepareAppCharacteristicsCacheForBundleId:maxAgeMs:)
    class func prepareAppCharacteristicsCache(forBundleId bundleId: String?, maxAgeMs: UInt64) -> Int {
        guard let bundleId, !bundleId.isEmpty else {
            return 0
        }

        let now = mach_absolute_time()
        appCharLock.lock()
        defer { appCharLock.unlock() }

        var reason = 0
        if let lastBundleId = _lastCachedBundleId, lastBundleId != bundleId {
            reason = 1
        } else if _lastAppCharCacheInvalidationTime == 0 {
            reason = 2
        } else {
            let elapsedMs = PHTVTimingService.machTimeToMs(now - _lastAppCharCacheInvalidationTime)
            if elapsedMs > maxAgeMs {
                reason = 2
            }
        }

        guard reason != 0 else {
            return 0
        }

        appCharacteristicsCache.removeAll(keepingCapacity: false)
        _lastCachedBundleId = bundleId
        _lastAppCharCacheInvalidationTime = now
        return reason
    }

    @objc(setAppCharacteristicsForBundleId:isSpotlightLike:needsPrecomposedBatched:needsStepByStep:containsUnicodeCompound:isSafari:)
    class func setAppCharacteristics(
        forBundleId bundleId: String?,
        isSpotlightLike: Bool,
        needsPrecomposedBatched: Bool,
        needsStepByStep: Bool,
        containsUnicodeCompound: Bool,
        isSafari: Bool
    ) {
        guard let bundleId, !bundleId.isEmpty else {
            return
        }
        let box = PHTVAppCharacteristicsBox(
            isSpotlightLike: isSpotlightLike,
            needsPrecomposedBatched: needsPrecomposedBatched,
            needsStepByStep: needsStepByStep,
            containsUnicodeCompound: containsUnicodeCompound,
            isSafari: isSafari
        )
        appCharLock.lock()
        appCharacteristicsCache[bundleId] = box
        appCharLock.unlock()
    }

    @objc class func invalidateAppCharacteristicsCache() {
        appCharLock.lock()
        appCharacteristicsCache.removeAll(keepingCapacity: false)
        _lastCachedBundleId = nil
        _lastAppCharCacheInvalidationTime = mach_absolute_time()
        appCharLock.unlock()
    }

    @objc class func lastCachedBundleId() -> String? {
        appCharLock.lock()
        defer { appCharLock.unlock() }
        return _lastCachedBundleId
    }

    @objc(setLastCachedBundleId:)
    class func setLastCachedBundleId(_ bundleId: String?) {
        appCharLock.lock()
        _lastCachedBundleId = bundleId
        appCharLock.unlock()
    }

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
        guard index < 256 else { return layoutCacheNoValue }

        layoutLock.lock()
        defer { layoutLock.unlock() }
        guard layoutCacheValid else { return layoutCacheNoValue }
        return layoutCache[index]
    }

    @objc class func setCachedLayoutConversion(_ keycode: UInt16, result: UInt16) {
        let index = Int(keycode)
        guard index < 256 else { return }

        layoutLock.lock()
        if !layoutCacheValid {
            layoutCache = Array<UInt16>(repeating: layoutCacheNoValue, count: 256)
            layoutCacheValid = true
        }
        layoutCache[index] = result
        layoutLock.unlock()
    }

    @objc class func invalidateLayoutCache() {
        layoutLock.lock()
        layoutCache = Array<UInt16>(repeating: layoutCacheNoValue, count: 256)
        layoutCacheValid = false
        layoutLock.unlock()
    }

    @objc class func isLayoutCacheValid() -> Bool {
        layoutLock.lock()
        defer { layoutLock.unlock() }
        return layoutCacheValid
    }
}
