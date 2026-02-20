//
//  PHTVPermissionService.swift
//  PHTV
//
//  Centralized runtime Accessibility permission checks.
//

import ApplicationServices
import Foundation

@objc final class PHTVPermissionService: NSObject {
    nonisolated(unsafe) private static var lastPermissionCheckResult = false
    nonisolated(unsafe) private static var lastPermissionCheckTime: TimeInterval = 0
    nonisolated(unsafe) private static var permissionFailureCount = 0
    nonisolated(unsafe) private static var permissionBackoffUntil: TimeInterval = 0
    nonisolated(unsafe) private static var lastPermissionOutcome = false
    nonisolated(unsafe) private static var hasLastPermissionOutcome = false

    // No cache while waiting for permission, 5s when permission is granted.
    private static let cacheTTLWaitingForPermission: TimeInterval = 0
    private static let cacheTTLPermissionGranted: TimeInterval = 5

    private static let maxTestTapRetries = 3
    private static let testTapRetryDelayUsec: useconds_t = 50_000

    @objc static func invalidatePermissionCache() {
        lastPermissionCheckTime = 0
        lastPermissionCheckResult = false
        permissionFailureCount = 0
        permissionBackoffUntil = 0
        hasLastPermissionOutcome = false
        NSLog("[Permission] Cache invalidated - next check will be fresh")
    }

    @objc static func forcePermissionCheck() -> Bool {
        invalidatePermissionCache()
        return canCreateEventTap()
    }

    @objc static func canCreateEventTap() -> Bool {
        let now = Date().timeIntervalSince1970

        if now < permissionBackoffUntil {
#if DEBUG
            NSLog(
                "[Permission] Backoff active for %.2fs (failures=%ld)",
                permissionBackoffUntil - now,
                permissionFailureCount
            )
#endif
            return false
        }

        let cacheTTL = lastPermissionCheckResult ? cacheTTLPermissionGranted : cacheTTLWaitingForPermission
        if cacheTTL > 0, now - lastPermissionCheckTime < cacheTTL {
            return lastPermissionCheckResult
        }

        let hasPermission = tryCreateTestTapWithRetries()

        if hasPermission {
            permissionFailureCount = 0
            permissionBackoffUntil = 0
            if !hasLastPermissionOutcome || !lastPermissionOutcome {
                NSLog("[Permission] Check: TestTap=SUCCESS")
            }
        } else {
            permissionFailureCount += 1
            let exponent = min(permissionFailureCount, 6)
            let backoff = min(15.0, pow(2.0, Double(exponent)) * 0.25)
            permissionBackoffUntil = now + backoff

            if !hasLastPermissionOutcome || lastPermissionOutcome || (permissionFailureCount % 5 == 1) {
                NSLog(
                    "[Permission] Check: TestTap=FAILED (count=%ld) — backing off for %.2fs",
                    permissionFailureCount,
                    backoff
                )
            }
        }

        lastPermissionCheckResult = hasPermission
        lastPermissionCheckTime = now
        lastPermissionOutcome = hasPermission
        hasLastPermissionOutcome = true

        return hasPermission
    }

    private static func tryCreateTestTapWithRetries() -> Bool {
        let callback: CGEventTapCallBack = { _, _, event, _ in
            return Unmanaged.passUnretained(event)
        }

        let eventsMask = CGEventMask(1 << CGEventType.keyDown.rawValue)

        for attempt in 0..<maxTestTapRetries {
            guard let testTap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .tailAppendEventTap,
                options: .defaultTap,
                eventsOfInterest: eventsMask,
                callback: callback,
                userInfo: nil
            ) else {
                if attempt < maxTestTapRetries - 1 {
                    usleep(testTapRetryDelayUsec)
                }
                continue
            }

            CFMachPortInvalidate(testTap)
#if DEBUG
            if attempt > 0 {
                NSLog("[Permission] Test tap SUCCESS on attempt %d", attempt + 1)
            }
#endif
            return true
        }

#if DEBUG
        NSLog("[Permission] Test tap FAILED after %d attempts", maxTestTapRetries)
#endif
        return false
    }
}
