//
//  PHTVPermissionService.swift
//  PHTV
//
//  Centralized runtime typing permission checks.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import ApplicationServices
import Foundation

enum PHTVEventTapProbeAttemptResult: Equatable {
    case creationFailed
    case enableFailed
    case ready
}

struct PHTVEventTapProbeOutcome: Equatable {
    let result: PHTVEventTapProbeAttemptResult
    let attempts: Int

    var isReady: Bool {
        result == .ready
    }
}

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

    private static func cacheMissingPermissionAndReturnFalse(_ message: String) -> Bool {
        let now = Date().timeIntervalSince1970
        var shouldLog = false
        permissionState.lock.lock()
        shouldLog = !permissionState.hasLastPermissionOutcome
            || permissionState.lastPermissionOutcome
            || (now - permissionState.lastPermissionCheckTime) >= 5
        permissionState.lastPermissionCheckResult = false
        permissionState.lastPermissionCheckTime = now
        permissionState.permissionFailureCount = 0
        permissionState.permissionBackoffUntil = 0
        permissionState.lastPermissionOutcome = false
        permissionState.hasLastPermissionOutcome = true
        permissionState.lock.unlock()
        if shouldLog {
            NSLog("[Permission] %@", message)
        }
        return false
    }

    @objc static func canCreateEventTap() -> Bool {
        guard AXIsProcessTrusted() else {
            return cacheMissingPermissionAndReturnFalse("AX_NOT_TRUSTED")
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

        let probeOutcome = tryCreateTestTapWithRetries()
        let hasPermission = probeOutcome.isReady
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
            // AX is trusted, so a failed active-tap probe is treated as a short
            // propagation or session-readiness delay rather than another permission.
            let backoff: TimeInterval = 1.0
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
            NSLog(
                "[Permission] ACTIVE_TAP_READY (attempt=%ld)",
                probeOutcome.attempts
            )
        } else if shouldLogFailure {
            let resultName = switch probeOutcome.result {
            case .creationFailed: "ACTIVE_TAP_CREATE_FAILED"
            case .enableFailed: "ACTIVE_TAP_ENABLE_FAILED"
            case .ready: "ACTIVE_TAP_READY"
            }
            NSLog(
                "[Permission] %@ (attempts=%ld, failures=%ld) — backing off for %.2fs",
                resultName,
                probeOutcome.attempts,
                loggedFailureCount,
                loggedBackoff
            )
        }

        return hasPermission
    }

    static func runEventTapProbe(
        maxRetries: Int,
        retryDelay: () -> Void,
        attempt: () -> PHTVEventTapProbeAttemptResult
    ) -> PHTVEventTapProbeOutcome {
        guard maxRetries > 0 else {
            return PHTVEventTapProbeOutcome(result: .creationFailed, attempts: 0)
        }

        var lastResult = PHTVEventTapProbeAttemptResult.creationFailed
        for attemptIndex in 0..<maxRetries {
            lastResult = attempt()
            if lastResult == .ready {
                return PHTVEventTapProbeOutcome(result: .ready, attempts: attemptIndex + 1)
            }
            if attemptIndex < maxRetries - 1 {
                retryDelay()
            }
        }

        return PHTVEventTapProbeOutcome(result: lastResult, attempts: maxRetries)
    }

    private static func tryCreateTestTapWithRetries() -> PHTVEventTapProbeOutcome {
        runEventTapProbe(
            maxRetries: maxTestTapRetries,
            retryDelay: { usleep(testTapRetryDelayUsec) },
            attempt: performTestTapAttempt
        )
    }

    private static func performTestTapAttempt() -> PHTVEventTapProbeAttemptResult {
        let callback: CGEventTapCallBack = { _, _, event, _ in
            Unmanaged.passUnretained(event)
        }

        guard let testTap = CGEvent.tapCreate(
            tap: PHTVKeyboardEventTapConfiguration.location,
            place: PHTVKeyboardEventTapConfiguration.placement,
            options: PHTVKeyboardEventTapConfiguration.options,
            eventsOfInterest: PHTVKeyboardEventTapConfiguration.eventMask,
            callback: callback,
            userInfo: nil
        ) else {
            return .creationFailed
        }
        defer { CFMachPortInvalidate(testTap) }

        CGEvent.tapEnable(tap: testTap, enable: true)
        return CGEvent.tapIsEnabled(tap: testTap) ? .ready : .enableFailed
    }
}
