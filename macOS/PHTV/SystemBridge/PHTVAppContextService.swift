//
//  PHTVAppContextService.swift
//  PHTV
//
//  Centralized app-context queries for focused app and cached characteristics.
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
    nonisolated(unsafe) private static var shouldDisableLock = NSLock()
    nonisolated(unsafe) private static var shouldDisableLastPid: Int32 = -1
    nonisolated(unsafe) private static var shouldDisableLastCheckTime: UInt64 = 0
    nonisolated(unsafe) private static var shouldDisableLastResult = false

    private class var frontmostBundleId: String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
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

    @objc(shouldDisableVietnameseForTargetPid:cacheDurationMs:safeMode:spotlightCacheDurationMs:)
    class func shouldDisableVietnamese(forTargetPid targetPid: Int32,
                                       cacheDurationMs: UInt64,
                                       safeMode: Bool,
                                       spotlightCacheDurationMs: UInt64) -> Bool {
        let now = mach_absolute_time()

        shouldDisableLock.lock()
        let lastPid = shouldDisableLastPid
        let lastCheckTime = shouldDisableLastCheckTime
        let lastResult = shouldDisableLastResult
        shouldDisableLock.unlock()

        if targetPid > 0, targetPid == lastPid, lastCheckTime > 0 {
            let elapsedMs = PHTVTimingService.machTimeToMs(now - lastCheckTime)
            if elapsedMs < cacheDurationMs {
                return lastResult
            }
        }

        let bundleId = focusedBundleId(forSafeMode: safeMode, cacheDurationMs: spotlightCacheDurationMs)
        let shouldDisable = shouldDisableVietnamese(forBundleId: bundleId)

        shouldDisableLock.lock()
        shouldDisableLastPid = targetPid > 0 ? targetPid : -1
        shouldDisableLastCheckTime = now
        shouldDisableLastResult = shouldDisable
        shouldDisableLock.unlock()

        return shouldDisable
    }

    @objc(focusedBundleIdForSafeMode:cacheDurationMs:)
    class func focusedBundleId(forSafeMode safeMode: Bool, cacheDurationMs: UInt64) -> String? {
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

        _ = PHTVSpotlightDetectionService.isSpotlightActive()
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
        let focusedBundleId = focusedBundleId(forSafeMode: safeMode, cacheDurationMs: spotlightCacheDurationMs)
        let effectiveBundleId = (spotlightActive && focusedBundleId != nil) ? focusedBundleId : (eventTargetBundleId ?? focusedBundleId)

        let appCharacteristics = appCharacteristics(forBundleId: effectiveBundleId, maxAgeMs: appCharacteristicsMaxAgeMs)
            ?? defaultAppCharacteristics()

        let isTargetBrowser = eventTargetBundleId.map(PHTVAppDetectionService.isBrowserApp(_:)) ?? false
        let isEffectiveBrowser = effectiveBundleId.map(PHTVAppDetectionService.isBrowserApp(_:)) ?? false
        let isBrowser = isTargetBrowser || isEffectiveBrowser

        let isTerminalApp = effectiveBundleId.map(PHTVAppDetectionService.isTerminalApp(_:)) ?? false
        let isJetBrainsApp = effectiveBundleId.map(PHTVAppDetectionService.isJetBrainsApp(_:)) ?? false
        let isTerminalPanel = (!safeMode && !isTerminalApp && !isJetBrainsApp)
            ? PHTVAccessibilityService.isTerminalPanelFocused()
            : false
        let isCliTarget = isTerminalApp || isJetBrainsApp || isTerminalPanel
        let cliTimingProfile: PHTVCliTimingProfileBox? = {
            guard isCliTarget else {
                return nil
            }
            let profileCode = PHTVCliProfileService.profileCode(forBundleId: effectiveBundleId)
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
