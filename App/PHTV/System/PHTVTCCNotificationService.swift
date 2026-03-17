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

    private final class ObserverStateBox: @unchecked Sendable {
        private let lock = NSLock()
        private var observers: [NSObjectProtocol] = []

        func withLock<T>(_ body: (inout [NSObjectProtocol]) -> T) -> T {
            lock.lock()
            defer { lock.unlock() }
            return body(&observers)
        }
    }

    private static let observerState = ObserverStateBox()

    @objc class func startListening() {
        let isAlreadyStarted = observerState.withLock { observers in
            !observers.isEmpty
        }
        guard !isAlreadyStarted else {
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

        let observerCount = observerState.withLock { observers -> Int in
            observers = [observer1, observer2]
            return observers.count
        }
        NSLog("[TCC] Notification listener started successfully (%lu observer(s))", observerCount)
    }

    @objc class func stopListening() {
        let removedObservers = observerState.withLock { observers -> [NSObjectProtocol] in
            let removed = observers
            observers.removeAll()
            return removed
        }
        guard !removedObservers.isEmpty else {
            return
        }

        NSLog("[TCC] Stopping notification listener...")
        let distributedCenter = DistributedNotificationCenter.default()
        for observer in removedObservers {
            distributedCenter.removeObserver(observer)
        }
        NSLog("[TCC] Notification listener stopped")
    }

    private class func handleTCCNotification(_ notification: Notification) {
        PHTVManager.invalidatePermissionCache()

        NotificationCenter.default.post(
            name: tccDatabaseChangedNotification,
            object: nil,
            userInfo: notification.userInfo
        )

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(settledCheckDelay * 1_000_000_000))

            // AXIsProcessTrusted() is the Apple-canonical check for accessibility permission.
            // Avoid calling canCreateEventTap() here: it may fail due to macOS propagation
            // delay and pollute the shared backoff state, delaying recovery for the
            // AppDelegate timer that actually performs initialization.
            //
            // SystemState has its own com.apple.accessibility.api observer that updates
            // the UI independently — no need to post AccessibilityStatusChanged here.
            // Instead, directly trigger initialization when AX is trusted.
            let axTrusted = AXIsProcessTrusted()
            NSLog("[TCC] Post-notification check: AXTrusted=%@", axTrusted ? "YES" : "NO")

            if axTrusted {
                // Trigger initialization immediately instead of waiting for the next timer tick.
                AppDelegate.current()?.checkAccessibilityAndRestart()
            } else {
                // Permission was revoked or not yet effective — notify observers to refresh.
                NotificationCenter.default.post(
                    name: accessibilityStatusChangedNotification,
                    object: NSNumber(value: false)
                )
            }
        }
    }
}
