//
//  PHTVEventTapHealthService.swift
//  PHTV
//
//  Event tap periodic health checks for keydown hot path.
//

import ApplicationServices
import Foundation

@objcMembers
final class PHTVEventTapHealthService: NSObject {
    private final class HealthStateBox: @unchecked Sendable {
        let lock = NSLock()
        var eventCounter: UInt = 0
        var recoveryCounter: UInt = 0
        var healthyCounter: UInt = 0
    }
    private static let state = HealthStateBox()

    @objc(checkAndRecoverForEventType:)
    class func checkAndRecover(forEventType type: CGEventType) -> Bool {
        guard type == .keyDown else {
            return true
        }

        state.lock.lock()
        let checkInterval: UInt = state.healthyCounter > 2000 ? 50 : 25
        state.eventCounter &+= 1
        let shouldRunHealthCheck = (state.eventCounter % checkInterval == 0)
        state.lock.unlock()

        guard shouldRunHealthCheck else {
            return true
        }

        if !PHTVManager.isEventTapEnabled() {
            state.lock.lock()
            state.healthyCounter = 0
            state.recoveryCounter &+= 1
            let recoveryCounter = state.recoveryCounter
            state.lock.unlock()

            // Throttle log: only log every 10th recovery.
            if recoveryCounter % 10 == 1 {
                NSLog("[EventTap] Detected disabled tap - recovering (occurrence #%lu)", recoveryCounter)
            }

            PHTVManager.ensureEventTapAlive()
            return false
        }

        state.lock.lock()
        if state.healthyCounter < 2000 {
            state.healthyCounter += 1
        }
        state.lock.unlock()
        return true
    }
}
