//
//  PHTVAppContextService.swift
//  PHTV
//
//  Centralized app-context queries for focused app and cached characteristics.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit
import Foundation
import Darwin

@objcMembers
final class PHTVEventTargetContextBox: NSObject {
    let eventTargetBundleId: String?
    let focusedBundleId: String?
    let effectiveBundleId: String?
    let spotlightActive: Bool
    let appCharacteristics: PHTVAppCharacteristicsBox

    let isBrowser: Bool
    let isTerminalApp: Bool
    let isJetBrainsApp: Bool
    let isTerminalPanel: Bool
    let isCliTarget: Bool
    let postToHIDTap: Bool
    let cliTimingProfile: PHTVCliTimingProfileBox?

    init(eventTargetBundleId: String?,
         focusedBundleId: String?,
         effectiveBundleId: String?,
         spotlightActive: Bool,
         appCharacteristics: PHTVAppCharacteristicsBox,
         isBrowser: Bool,
         isTerminalApp: Bool,
         isJetBrainsApp: Bool,
         isTerminalPanel: Bool,
         isCliTarget: Bool,
         postToHIDTap: Bool,
         cliTimingProfile: PHTVCliTimingProfileBox?) {
        self.eventTargetBundleId = eventTargetBundleId
        self.focusedBundleId = focusedBundleId
        self.effectiveBundleId = effectiveBundleId
        self.spotlightActive = spotlightActive
        self.appCharacteristics = appCharacteristics
        self.isBrowser = isBrowser
        self.isTerminalApp = isTerminalApp
        self.isJetBrainsApp = isJetBrainsApp
        self.isTerminalPanel = isTerminalPanel
        self.isCliTarget = isCliTarget
        self.postToHIDTap = postToHIDTap
        self.cliTimingProfile = cliTimingProfile
    }
}

@objcMembers
final class PHTVAppContextService: NSObject {
    private static let frontmostBundleCacheDurationMs: UInt64 = 1000

    private final class FrontmostBundleStateBox: @unchecked Sendable {
        private let lock = NSLock()
        private var lastFetchTime: UInt64 = 0
        private var cachedBundleId: String?

        func read(now: UInt64, cacheDurationMs: UInt64) -> (isValid: Bool, bundleId: String?) {
            lock.lock()
            defer { lock.unlock() }

            guard lastFetchTime > 0 else {
                return (false, nil)
            }

            let elapsedMs = PHTVTimingService.machTimeToMs(now - lastFetchTime)
            if elapsedMs < cacheDurationMs {
                return (true, cachedBundleId)
            }
            return (false, nil)
        }

        func store(now: UInt64, bundleId: String?) {
            lock.lock()
            lastFetchTime = now
            cachedBundleId = bundleId
            lock.unlock()
        }

        func invalidate() {
            lock.lock()
            lastFetchTime = 0
            cachedBundleId = nil
            lock.unlock()
        }
    }

    private static let frontmostBundleState = FrontmostBundleStateBox()

    private class func loadFrontmostBundleIdFromWorkspace() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    private class var frontmostBundleId: String? {
        let now = mach_absolute_time()
        let snapshot = frontmostBundleState.read(now: now, cacheDurationMs: frontmostBundleCacheDurationMs)
        if snapshot.isValid {
            return snapshot.bundleId
        }

        let freshBundleId = loadFrontmostBundleIdFromWorkspace()
        frontmostBundleState.store(now: now, bundleId: freshBundleId)
        return freshBundleId
    }

    @objc(currentFrontmostBundleId)
    class func currentFrontmostBundleId() -> String? {
        frontmostBundleId
    }

    @objc(invalidateFrontmostBundleCache)
    class func invalidateFrontmostBundleCache() {
        frontmostBundleState.invalidate()
    }

    @objc(updateFrontmostBundleCache:)
    class func updateFrontmostBundleCache(_ bundleId: String?) {
        frontmostBundleState.store(now: mach_absolute_time(), bundleId: bundleId)
    }

    private class func makeDefaultAppCharacteristics() -> PHTVAppCharacteristicsBox {
        PHTVAppCharacteristicsBox(
            isSpotlightLike: false,
            needsPrecomposedBatched: false,
            needsStepByStep: false,
            containsUnicodeCompound: false,
            isSafari: false
        )
    }

    @objc(defaultAppCharacteristics)
    class func defaultAppCharacteristics() -> PHTVAppCharacteristicsBox {
        makeDefaultAppCharacteristics()
    }

    @objc(spotlightActiveForSafeMode:)
    class func spotlightActive(forSafeMode safeMode: Bool) -> Bool {
        guard !safeMode else {
            return false
        }
        return PHTVSpotlightDetectionService.isSpotlightActive()
    }

    @objc(bundleIdFromPID:safeMode:)
    class func bundleId(fromPID pid: Int32, safeMode: Bool) -> String? {
        PHTVCacheStateService.bundleIdFromPID(pid, safeMode: safeMode)
    }

    @objc(shouldDisableVietnameseForBundleId:)
    class func shouldDisableVietnamese(forBundleId bundleId: String?) -> Bool {
        PHTVAppDetectionService.shouldDisableVietnamese(bundleId)
    }

    @objc(needsNiceSpaceForBundleId:)
    class func needsNiceSpace(forBundleId bundleId: String?) -> Bool {
        PHTVAppDetectionService.needsNiceSpace(bundleId)
    }

    @objc(focusedBundleIdForSafeMode:cacheDurationMs:)
    class func focusedBundleId(forSafeMode safeMode: Bool, cacheDurationMs: UInt64) -> String? {
        focusedBundleId(forSafeMode: safeMode, cacheDurationMs: cacheDurationMs, spotlightAlreadyChecked: false)
    }

    private class func focusedBundleId(forSafeMode safeMode: Bool,
                                       cacheDurationMs: UInt64,
                                       spotlightAlreadyChecked: Bool) -> String? {
        guard !safeMode else {
            return frontmostBundleId
        }

        let now = mach_absolute_time()
        let lastCheck = PHTVCacheStateService.lastSpotlightCheckTime()
        let cachedBundleId = PHTVCacheStateService.cachedFocusedBundleId()

        let elapsedMs = PHTVTimingService.machTimeToMs(now - lastCheck)
        if elapsedMs < cacheDurationMs, lastCheck > 0, let cachedBundleId {
            return cachedBundleId
        }

        if !spotlightAlreadyChecked {
            _ = PHTVSpotlightDetectionService.isSpotlightActive()
        }
        return PHTVCacheStateService.cachedFocusedBundleId() ?? frontmostBundleId
    }

    @objc(appCharacteristicsForBundleId:maxAgeMs:)
    class func appCharacteristics(forBundleId bundleId: String?, maxAgeMs: UInt64) -> PHTVAppCharacteristicsBox? {
        guard let bundleId, !bundleId.isEmpty else {
            return nil
        }

        let invalidationReason = PHTVCacheStateService.prepareAppCharacteristicsCache(
            forBundleId: bundleId,
            maxAgeMs: maxAgeMs
        )

#if DEBUG
        if invalidationReason == 1 {
            NSLog("[Cache] App switched to %@, invalidating app characteristics cache", bundleId)
        } else if invalidationReason == 2 {
            NSLog("[Cache] 10s elapsed, invalidating cache for browser responsiveness")
        }
#endif

        if let box = PHTVCacheStateService.appCharacteristics(forBundleId: bundleId) {
            return box
        }

        let box = PHTVAppCharacteristicsBox(
            isSpotlightLike: PHTVAppDetectionService.isSpotlightLikeApp(bundleId),
            needsPrecomposedBatched: PHTVAppDetectionService.needsPrecomposedBatched(bundleId),
            needsStepByStep: PHTVAppDetectionService.needsStepByStep(bundleId),
            containsUnicodeCompound: PHTVAppDetectionService.containsUnicodeCompound(bundleId),
            isSafari: PHTVAppDetectionService.isSafariApp(bundleId)
        )

        PHTVCacheStateService.setAppCharacteristics(
            forBundleId: bundleId,
            isSpotlightLike: box.isSpotlightLike,
            needsPrecomposedBatched: box.needsPrecomposedBatched,
            needsStepByStep: box.needsStepByStep,
            containsUnicodeCompound: box.containsUnicodeCompound,
            isSafari: box.isSafari
        )

        return box
    }

    @objc(eventTargetContextForEventTargetPid:safeMode:spotlightCacheDurationMs:appCharacteristicsMaxAgeMs:)
    class func eventTargetContext(forEventTargetPid eventTargetPid: Int32,
                                  safeMode: Bool,
                                  spotlightCacheDurationMs: UInt64,
                                  appCharacteristicsMaxAgeMs: UInt64) -> PHTVEventTargetContextBox {
        let eventTargetBundleId = eventTargetPid > 0 ? bundleId(fromPID: eventTargetPid, safeMode: safeMode) : nil
        let spotlightActive = spotlightActive(forSafeMode: safeMode)
        let focusedBundleId = focusedBundleId(
            forSafeMode: safeMode,
            cacheDurationMs: spotlightCacheDurationMs,
            spotlightAlreadyChecked: true
        )
        let effectiveBundleId = (spotlightActive && focusedBundleId != nil) ? focusedBundleId : (eventTargetBundleId ?? focusedBundleId)

        let appCharacteristics = appCharacteristics(forBundleId: effectiveBundleId, maxAgeMs: appCharacteristicsMaxAgeMs)
            ?? defaultAppCharacteristics()

        let isTargetBrowser = eventTargetBundleId.map(PHTVAppDetectionService.isBrowserApp(_:)) ?? false
        let isEffectiveBrowser = effectiveBundleId.map(PHTVAppDetectionService.isBrowserApp(_:)) ?? false
        let isBrowser = isTargetBrowser || isEffectiveBrowser

        let isTerminalApp = effectiveBundleId.map(PHTVAppDetectionService.isTerminalApp(_:)) ?? false
        let isJetBrainsApp = effectiveBundleId.map(PHTVAppDetectionService.isJetBrainsApp(_:)) ?? false
        let isTerminalPanel = (!safeMode && !isTerminalApp)
            ? PHTVAccessibilityService.isTerminalPanelFocused()
            : false
        let isCliTarget = isTerminalApp || isJetBrainsApp || isTerminalPanel
        let canContainClaudeCodeSession = isTerminalApp || isTerminalPanel
        let isClaudeCodeSession = (!safeMode && canContainClaudeCodeSession)
            ? PHTVAccessibilityService.isClaudeCodeSessionFocused()
            : false
        let cliTimingProfile: PHTVCliTimingProfileBox? = {
            guard isCliTarget else {
                return nil
            }
            let profileCode = PHTVCliProfileService.profileCode(
                forBundleId: effectiveBundleId,
                isClaudeCodeSession: isClaudeCodeSession
            )
            return PHTVCliProfileService.profile(forCode: profileCode)
        }()
        let postToHIDTap = (!isBrowser && spotlightActive) || appCharacteristics.isSpotlightLike

        return PHTVEventTargetContextBox(
            eventTargetBundleId: eventTargetBundleId,
            focusedBundleId: focusedBundleId,
            effectiveBundleId: effectiveBundleId,
            spotlightActive: spotlightActive,
            appCharacteristics: appCharacteristics,
            isBrowser: isBrowser,
            isTerminalApp: isTerminalApp,
            isJetBrainsApp: isJetBrainsApp,
            isTerminalPanel: isTerminalPanel,
            isCliTarget: isCliTarget,
            postToHIDTap: postToHIDTap,
            cliTimingProfile: cliTimingProfile
        )
    }
}
