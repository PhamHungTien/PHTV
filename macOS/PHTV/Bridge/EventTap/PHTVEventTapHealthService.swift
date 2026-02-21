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
    nonisolated(unsafe) private static var eventCounter: UInt = 0
    nonisolated(unsafe) private static var recoveryCounter: UInt = 0
    nonisolated(unsafe) private static var healthyCounter: UInt = 0

    @objc(checkAndRecoverForEventType:)
    class func checkAndRecover(forEventType type: CGEventType) -> Bool {
        guard type == .keyDown else {
            return true
        }

        let checkInterval: UInt = healthyCounter > 2000 ? 50 : 25
        eventCounter &+= 1

        guard eventCounter % checkInterval == 0 else {
            return true
        }

        if !PHTVManager.isEventTapEnabled() {
            healthyCounter = 0
            recoveryCounter &+= 1

            // Throttle log: only log every 10th recovery.
            if recoveryCounter % 10 == 1 {
                NSLog("[EventTap] Detected disabled tap - recovering (occurrence #%lu)", recoveryCounter)
            }

            PHTVManager.ensureEventTapAlive()
            return false
        }

        if healthyCounter < 2000 {
            healthyCounter += 1
        }
        return true
    }
}
