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
final class PHTVAppRuntimeFlagsBox: NSObject {
    let isBrowser: Bool
    let isTerminalApp: Bool
    let isJetBrainsApp: Bool
    let cliProfileCode: Int32

    init(isBrowser: Bool,
         isTerminalApp: Bool,
         isJetBrainsApp: Bool,
         cliProfileCode: Int32) {
        self.isBrowser = isBrowser
        self.isTerminalApp = isTerminalApp
        self.isJetBrainsApp = isJetBrainsApp
        self.cliProfileCode = cliProfileCode
    }
}

@objcMembers
final class PHTVAppContextService: NSObject {
    private class var frontmostBundleId: String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
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

    @objc(runtimeFlagsForEffectiveBundleId:eventTargetBundleId:)
    class func runtimeFlags(forEffectiveBundleId effectiveBundleId: String?,
                            eventTargetBundleId: String?) -> PHTVAppRuntimeFlagsBox {
        let isTargetBrowser = eventTargetBundleId.map(PHTVAppDetectionService.isBrowserApp(_:)) ?? false
        let isEffectiveBrowser = effectiveBundleId.map(PHTVAppDetectionService.isBrowserApp(_:)) ?? false
        let isBrowser = isTargetBrowser || isEffectiveBrowser

        let isTerminalApp = effectiveBundleId.map(PHTVAppDetectionService.isTerminalApp(_:)) ?? false
        let isJetBrainsApp = effectiveBundleId.map(PHTVAppDetectionService.isJetBrainsApp(_:)) ?? false
        let cliProfileCode = PHTVCliProfileService.profileCode(forBundleId: effectiveBundleId)

        return PHTVAppRuntimeFlagsBox(
            isBrowser: isBrowser,
            isTerminalApp: isTerminalApp,
            isJetBrainsApp: isJetBrainsApp,
            cliProfileCode: cliProfileCode
        )
    }
}
