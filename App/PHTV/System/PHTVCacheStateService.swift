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

    private static let layoutCacheNoValue: UInt16 = .max

    private struct PIDCacheState {
        var pidBundleCache = [Int32: String]()
        var lastPidCacheCleanTime: UInt64 = 0
    }

    private final class PIDCacheStateBox: @unchecked Sendable {
        private let lock = NSLock()
        private var state = PIDCacheState()

        func withLock<T>(_ body: (inout PIDCacheState) -> T) -> T {
            lock.lock()
            defer { lock.unlock() }
            return body(&state)
        }
    }

    private struct AppCharacteristicsState {
        var appCharacteristicsCache = [String: PHTVAppCharacteristicsBox]()
        var lastCachedBundleId: String?
        var lastAppCharCacheInvalidationTime: UInt64 = 0
    }

    private final class AppCharacteristicsStateBox: @unchecked Sendable {
        private let lock = NSLock()
        private var state = AppCharacteristicsState()

        func withLock<T>(_ body: (inout AppCharacteristicsState) -> T) -> T {
            lock.lock()
            defer { lock.unlock() }
            return body(&state)
        }
    }

    private struct SpotlightCacheState {
        var cachedSpotlightActive = false
        var lastSpotlightCheckTime: UInt64 = 0
        var cachedFocusedPID: Int32 = 0
        var cachedFocusedBundleId: String?
        var lastSpotlightInvalidationTime: UInt64 = 0
    }

    private final class SpotlightCacheStateBox: @unchecked Sendable {
        private let lock = NSLock()
        private var state = SpotlightCacheState()

        func withLock<T>(_ body: (inout SpotlightCacheState) -> T) -> T {
            lock.lock()
            defer { lock.unlock() }
            return body(&state)
        }
    }

    private struct LayoutCacheState {
        var layoutCache = Array<UInt16>(repeating: layoutCacheNoValue, count: 256)
        var layoutCacheValid = false
    }

    private final class LayoutCacheStateBox: @unchecked Sendable {
        private let lock = NSLock()
        private var state = LayoutCacheState()

        func withLock<T>(_ body: (inout LayoutCacheState) -> T) -> T {
            lock.lock()
            defer { lock.unlock() }
            return body(&state)
        }
    }

    private static let pidState = PIDCacheStateBox()
    private static let appCharacteristicsState = AppCharacteristicsStateBox()
    private static let spotlightState = SpotlightCacheStateBox()
    private static let layoutState = LayoutCacheStateBox()

    // MARK: - PID Cache

    @objc(bundleIdFromPID:safeMode:)
    class func bundleIdFromPID(_ pid: Int32, safeMode: Bool) -> String? {
        guard pid > 0 else {
            return nil
        }

        let now = mach_absolute_time()
        var didClearCache = false
        if let cached = pidState.withLock({ state -> String? in
            if state.lastPidCacheCleanTime == 0 {
                state.lastPidCacheCleanTime = now
            }

            let elapsedMs = PHTVTimingService.machTimeToMs(now - state.lastPidCacheCleanTime)
            if elapsedMs > pidCacheCleanIntervalMs {
                state.pidBundleCache.removeAll(keepingCapacity: true)
                state.lastPidCacheCleanTime = now
                didClearCache = true
            }
            return state.pidBundleCache[pid]
        }) {
#if DEBUG
            if didClearCache {
            NSLog("[Cache] PID cache cleared (interval expired)")
            }
#endif
            return cached.isEmpty ? nil : cached
        }
#if DEBUG
        if didClearCache {
            NSLog("[Cache] PID cache cleared (interval expired)")
        }
#endif

        if let app = NSRunningApplication(processIdentifier: pid_t(pid)) {
            let bundleId = app.bundleIdentifier ?? pidCacheEmptyValue
            pidState.withLock { state in
                state.pidBundleCache[pid] = bundleId
            }
            return bundleId.isEmpty ? nil : bundleId
        }

        if safeMode {
            pidState.withLock { state in
                state.pidBundleCache[pid] = pidCacheEmptyValue
            }
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
                pidState.withLock { state in
                    state.pidBundleCache[pid] = "com.apple.Spotlight"
                }
                return "com.apple.Spotlight"
            }
            if path.contains("SystemUIServer") {
                pidState.withLock { state in
                    state.pidBundleCache[pid] = "com.apple.systemuiserver"
                }
                return "com.apple.systemuiserver"
            }
            if path.contains("Launchpad") {
                pidState.withLock { state in
                    state.pidBundleCache[pid] = "com.apple.launchpad.launcher"
                }
                return "com.apple.launchpad.launcher"
            }
        }

        pidState.withLock { state in
            state.pidBundleCache[pid] = pidCacheEmptyValue
        }
        return nil
    }

    @objc class func cleanPIDCacheIfNeeded() {
        let now = mach_absolute_time()
        pidState.withLock { state in
            guard !state.pidBundleCache.isEmpty, state.lastPidCacheCleanTime > 0 else {
                return
            }
            let elapsedMs = PHTVTimingService.machTimeToMs(now - state.lastPidCacheCleanTime)
            if elapsedMs > pidCacheCleanIntervalMs {
                state.pidBundleCache.removeAll(keepingCapacity: true)
                state.lastPidCacheCleanTime = now
            }
        }
    }

    @objc class func invalidatePIDCache() {
        pidState.withLock { state in
            state.pidBundleCache.removeAll(keepingCapacity: false)
            state.lastPidCacheCleanTime = 0
        }
    }

    // MARK: - App Characteristics Cache

    @objc(appCharacteristicsForBundleId:)
    class func appCharacteristics(forBundleId bundleId: String?) -> PHTVAppCharacteristicsBox? {
        guard let bundleId, !bundleId.isEmpty else {
            return nil
        }
        return appCharacteristicsState.withLock { state in
            state.appCharacteristicsCache[bundleId]
        }
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
        return appCharacteristicsState.withLock { state in
            var reason = 0
            if let lastBundleId = state.lastCachedBundleId, lastBundleId != bundleId {
                reason = 1
            } else if state.lastAppCharCacheInvalidationTime == 0 {
                reason = 2
            } else {
                let elapsedMs = PHTVTimingService.machTimeToMs(now - state.lastAppCharCacheInvalidationTime)
                if elapsedMs > maxAgeMs {
                    reason = 2
                }
            }

            guard reason != 0 else {
                return 0
            }

            state.appCharacteristicsCache.removeAll(keepingCapacity: false)
            state.lastCachedBundleId = bundleId
            state.lastAppCharCacheInvalidationTime = now
            return reason
        }
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
        appCharacteristicsState.withLock { state in
            state.appCharacteristicsCache[bundleId] = box
        }
    }

    @objc class func invalidateAppCharacteristicsCache() {
        appCharacteristicsState.withLock { state in
            state.appCharacteristicsCache.removeAll(keepingCapacity: false)
            state.lastCachedBundleId = nil
            state.lastAppCharCacheInvalidationTime = mach_absolute_time()
        }
    }

    @objc class func lastCachedBundleId() -> String? {
        appCharacteristicsState.withLock { state in
            state.lastCachedBundleId
        }
    }

    @objc(setLastCachedBundleId:)
    class func setLastCachedBundleId(_ bundleId: String?) {
        appCharacteristicsState.withLock { state in
            state.lastCachedBundleId = bundleId
        }
    }

    // MARK: - Spotlight Cache

    @objc class func cachedSpotlightActive() -> Bool {
        spotlightState.withLock { state in
            state.cachedSpotlightActive
        }
    }

    @objc class func cachedFocusedPID() -> Int32 {
        spotlightState.withLock { state in
            state.cachedFocusedPID
        }
    }

    @objc class func cachedFocusedBundleId() -> String? {
        spotlightState.withLock { state in
            state.cachedFocusedBundleId
        }
    }

    @objc class func lastSpotlightCheckTime() -> UInt64 {
        spotlightState.withLock { state in
            state.lastSpotlightCheckTime
        }
    }

    @objc class func lastSpotlightInvalidationTime() -> UInt64 {
        spotlightState.withLock { state in
            state.lastSpotlightInvalidationTime
        }
    }

    @objc class func updateSpotlightCache(_ isActive: Bool, pid: Int32, bundleId: String?) {
        spotlightState.withLock { state in
            state.cachedSpotlightActive = isActive
            state.lastSpotlightCheckTime = mach_absolute_time()
            state.cachedFocusedPID = pid
            state.cachedFocusedBundleId = bundleId
        }
    }

    // Returns:
    // 0 = skipped (dedup window)
    // 1 = invalidated (already inactive)
    // 2 = invalidated (was active)
    @objc class func invalidateSpotlightCache(dedupWindowMs: UInt64) -> Int {
        let now = mach_absolute_time()

        return spotlightState.withLock { state in
            let elapsedSinceLastInvalidationMs = (state.lastSpotlightInvalidationTime > 0)
                ? PHTVTimingService.machTimeToMs(now - state.lastSpotlightInvalidationTime)
                : UInt64.max

            let alreadyInvalid = (!state.cachedSpotlightActive &&
                                  state.cachedFocusedPID == 0 &&
                                  state.cachedFocusedBundleId == nil)
            if alreadyInvalid && elapsedSinceLastInvalidationMs < dedupWindowMs {
                return 0
            }

            let wasActive = state.cachedSpotlightActive
            state.cachedSpotlightActive = false
            state.lastSpotlightCheckTime = 0
            state.cachedFocusedPID = 0
            state.cachedFocusedBundleId = nil
            state.lastSpotlightInvalidationTime = now

            return wasActive ? 2 : 1
        }
    }

    // MARK: - Layout Cache

    @objc class func cachedLayoutConversion(_ keycode: UInt16) -> UInt16 {
        let index = Int(keycode)
        guard index < 256 else { return layoutCacheNoValue }

        return layoutState.withLock { state in
            guard state.layoutCacheValid else { return layoutCacheNoValue }
            return state.layoutCache[index]
        }
    }

    @objc class func setCachedLayoutConversion(_ keycode: UInt16, result: UInt16) {
        let index = Int(keycode)
        guard index < 256 else { return }

        layoutState.withLock { state in
            if !state.layoutCacheValid {
                state.layoutCache = Array<UInt16>(repeating: layoutCacheNoValue, count: 256)
                state.layoutCacheValid = true
            }
            state.layoutCache[index] = result
        }
    }

    @objc class func invalidateLayoutCache() {
        layoutState.withLock { state in
            state.layoutCache = Array<UInt16>(repeating: layoutCacheNoValue, count: 256)
            state.layoutCacheValid = false
        }
    }

    @objc class func isLayoutCacheValid() -> Bool {
        layoutState.withLock { state in
            state.layoutCacheValid
        }
    }
}
