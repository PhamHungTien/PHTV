//
//  PHTVPermissionService.swift
//  PHTV
//
//  Centralized runtime Accessibility permission checks.
//

import ApplicationServices
import Foundation

@objc final class PHTVPermissionService: NSObject {
    private final class PermissionStateBox: @unchecked Sendable {
        let lock = NSLock()
        var lastPermissionCheckResult = false
        var lastPermissionCheckTime: TimeInterval = 0
        var permissionFailureCount = 0
        var permissionBackoffUntil: TimeInterval = 0
        var lastPermissionOutcome = false
        var hasLastPermissionOutcome = false
    }
    private static let permissionState = PermissionStateBox()

    // No cache while waiting for permission, 5s when permission is granted.
    private static let cacheTTLWaitingForPermission: TimeInterval = 0
    private static let cacheTTLPermissionGranted: TimeInterval = 5

    private static let maxTestTapRetries = 3
    private static let testTapRetryDelayUsec: useconds_t = 50_000

    @objc static func hasListenEventAccess() -> Bool {
        if #available(macOS 10.15, *) {
            return CGPreflightListenEventAccess()
        }
        return true
    }

    @objc static func hasPostEventAccess() -> Bool {
        if #available(macOS 10.15, *) {
            return CGPreflightPostEventAccess()
        }
        return true
    }

    @objc static func requestListenEventAccess() -> Bool {
        if #available(macOS 10.15, *) {
            return CGRequestListenEventAccess()
        }
        return true
    }

    @objc static func requestPostEventAccess() -> Bool {
        if #available(macOS 10.15, *) {
            return CGRequestPostEventAccess()
        }
        return true
    }

    @objc static func invalidatePermissionCache() {
        permissionState.lock.lock()
        permissionState.lastPermissionCheckTime = 0
        permissionState.lastPermissionCheckResult = false
        permissionState.permissionFailureCount = 0
        permissionState.permissionBackoffUntil = 0
        permissionState.hasLastPermissionOutcome = false
        permissionState.lock.unlock()
        NSLog("[Permission] Cache invalidated - next check will be fresh")
    }

    @objc static func forcePermissionCheck() -> Bool {
        invalidatePermissionCache()
        return canCreateEventTap()
    }

    @objc static func canCreateEventTap() -> Bool {
        let canListen = hasListenEventAccess()
        let canPost = hasPostEventAccess()
        if !canListen || !canPost {
            if !canListen {
                NSLog("[Permission] Input Monitoring (ListenEvent) is NOT granted")
            }
            if !canPost {
                NSLog("[Permission] Accessibility/Event Synthesis (PostEvent) is NOT granted")
            }
            permissionState.lock.lock()
            permissionState.lastPermissionCheckResult = false
            permissionState.lastPermissionCheckTime = Date().timeIntervalSince1970
            permissionState.lastPermissionOutcome = false
            permissionState.hasLastPermissionOutcome = true
            permissionState.lock.unlock()
            return false
        }

        let now = Date().timeIntervalSince1970
        var backoffUntil = 0.0
        var failureCount = 0
        var lastPermissionCheckResult = false
        var lastPermissionCheckTime: TimeInterval = 0

        permissionState.lock.lock()
        backoffUntil = permissionState.permissionBackoffUntil
        failureCount = permissionState.permissionFailureCount
        lastPermissionCheckResult = permissionState.lastPermissionCheckResult
        lastPermissionCheckTime = permissionState.lastPermissionCheckTime
        permissionState.lock.unlock()

        if now < backoffUntil {
#if DEBUG
            NSLog(
                "[Permission] Backoff active for %.2fs (failures=%ld)",
                backoffUntil - now,
                failureCount
            )
#endif
            return false
        }

        let cacheTTL = lastPermissionCheckResult ? cacheTTLPermissionGranted : cacheTTLWaitingForPermission
        if cacheTTL > 0, now - lastPermissionCheckTime < cacheTTL {
            return lastPermissionCheckResult
        }

        let hasPermission = tryCreateTestTapWithRetries()
        var shouldLogSuccess = false
        var shouldLogFailure = false
        var loggedFailureCount = 0
        var loggedBackoff = 0.0

        permissionState.lock.lock()
        let previousHasLastOutcome = permissionState.hasLastPermissionOutcome
        let previousOutcome = permissionState.lastPermissionOutcome

        if hasPermission {
            permissionState.permissionFailureCount = 0
            permissionState.permissionBackoffUntil = 0
            shouldLogSuccess = !previousHasLastOutcome || !previousOutcome
        } else {
            permissionState.permissionFailureCount += 1
            let exponent = min(permissionState.permissionFailureCount, 6)
            let backoff = min(15.0, pow(2.0, Double(exponent)) * 0.25)
            permissionState.permissionBackoffUntil = now + backoff
            loggedFailureCount = permissionState.permissionFailureCount
            loggedBackoff = backoff
            shouldLogFailure = !previousHasLastOutcome || previousOutcome || (loggedFailureCount % 5 == 1)
        }

        permissionState.lastPermissionCheckResult = hasPermission
        permissionState.lastPermissionCheckTime = now
        permissionState.lastPermissionOutcome = hasPermission
        permissionState.hasLastPermissionOutcome = true
        permissionState.lock.unlock()

        if shouldLogSuccess {
            NSLog("[Permission] Check: TestTap=SUCCESS")
        } else if shouldLogFailure {
            NSLog(
                "[Permission] Check: TestTap=FAILED (count=%ld) — backing off for %.2fs",
                loggedFailureCount,
                loggedBackoff
            )
        }

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
