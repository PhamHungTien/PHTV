//
//  PHTVTCCNotificationService.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation

@objcMembers
final class PHTVTCCNotificationService: NSObject {
    private static let tccDatabaseChangedNotification = Notification.Name("TCCDatabaseChanged")
    private static let accessibilityStatusChangedNotification = Notification.Name("AccessibilityStatusChanged")
    private static let settledCheckDelay: TimeInterval = 0.2

    nonisolated(unsafe) private static var observers: [NSObjectProtocol] = []

    @objc class func startListening() {
        guard observers.isEmpty else {
            NSLog("[TCC] Notification listener already started")
            return
        }

        NSLog("[TCC] Starting notification listener...")

        let distributedCenter = DistributedNotificationCenter.default()

        let observer1 = distributedCenter.addObserver(
            forName: Notification.Name("com.apple.accessibility.api"),
            object: nil,
            queue: .main
        ) { notification in
            NSLog("[TCC] 🔔 TCC notification received: %@", notification.name.rawValue)
            NSLog("[TCC] userInfo: %@", String(describing: notification.userInfo))
            handleTCCNotification(notification)
        }

        let observer2 = distributedCenter.addObserver(
            forName: Notification.Name("com.apple.TCC.access.changed"),
            object: nil,
            queue: .main
        ) { notification in
            NSLog("[TCC] 🔔 TCC access changed notification: %@", String(describing: notification.userInfo))
            handleTCCNotification(notification)
        }

        observers = [observer1, observer2]
        NSLog("[TCC] Notification listener started successfully (%lu observer(s))", observers.count)
    }

    @objc class func stopListening() {
        guard !observers.isEmpty else {
            return
        }

        NSLog("[TCC] Stopping notification listener...")
        let distributedCenter = DistributedNotificationCenter.default()
        for observer in observers {
            distributedCenter.removeObserver(observer)
        }
        observers.removeAll()
        NSLog("[TCC] Notification listener stopped")
    }

    private class func handleTCCNotification(_ notification: Notification) {
        PHTVManager.invalidatePermissionCache()

        NotificationCenter.default.post(
            name: tccDatabaseChangedNotification,
            object: nil,
            userInfo: notification.userInfo
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + settledCheckDelay) {
            let hasPermission = PHTVManager.canCreateEventTap()
            NSLog("[TCC] Post-notification check: %@", hasPermission ? "GRANTED" : "DENIED")
            NotificationCenter.default.post(
                name: accessibilityStatusChangedNotification,
                object: NSNumber(value: hasPermission)
            )
        }
    }
}
