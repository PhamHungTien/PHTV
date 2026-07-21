//
//  PHTVTCCNotificationService.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import ApplicationServices
import Foundation

@objcMembers
final class PHTVTCCNotificationService: NSObject {
    private static let tccDatabaseChangedNotification = NotificationName.tccDatabaseChanged
    private static let accessibilityStatusChangedNotification = NotificationName.accessibilityStatusChanged
    private static let settledCheckDelay: TimeInterval = 0.2

    private final class ObserverStateBox: @unchecked Sendable {
        private let lock = NSLock()
        private var tasks: [Task<Void, Never>] = []

        func withLock<T>(_ body: (inout [Task<Void, Never>]) -> T) -> T {
            lock.lock()
            defer { lock.unlock() }
            return body(&tasks)
        }
    }

    private static let observerState = ObserverStateBox()

    private class func makeDistributedNotificationTask(name: Notification.Name) -> Task<Void, Never> {
        let distributedCenter = DistributedNotificationCenter.default()

        return Task { @MainActor in
            for await notification in distributedCenter.notifications(named: name) {
                guard !Task.isCancelled else { break }
                if name.rawValue == "com.apple.accessibility.api" {
                    NSLog("[TCC] 🔔 TCC notification received: %@", notification.name.rawValue)
                } else {
                    NSLog("[TCC] 🔔 TCC access changed notification received")
                }
                handleTCCNotification(notification)
            }
        }
    }

    @objc class func startListening() {
        let isAlreadyStarted = observerState.withLock { tasks in
            !tasks.isEmpty
        }
        guard !isAlreadyStarted else {
            NSLog("[TCC] Notification listener already started")
            return
        }

        NSLog("[TCC] Starting notification listener...")

        let taskCount = observerState.withLock { tasks -> Int in
            tasks = [
                makeDistributedNotificationTask(name: Notification.Name("com.apple.accessibility.api")),
                makeDistributedNotificationTask(name: Notification.Name("com.apple.TCC.access.changed"))
            ]
            return tasks.count
        }
        NSLog("[TCC] Notification listener started successfully (%lu task(s))", taskCount)
    }

    @objc class func stopListening() {
        let removedTasks = observerState.withLock { tasks -> [Task<Void, Never>] in
            let removed = tasks
            tasks.removeAll()
            return removed
        }
        guard !removedTasks.isEmpty else {
            return
        }

        NSLog("[TCC] Stopping notification listener...")
        for task in removedTasks {
            task.cancel()
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
            try? await Task.sleep(for: .seconds(settledCheckDelay))

            // AXIsProcessTrusted() and CGPreflightListenEventAccess() are the canonical
            // checks for the two TCC permissions required before event tap recovery.
            // Avoid calling canCreateEventTap() here: it may fail due to macOS propagation
            // delay and pollute the shared backoff state, delaying recovery for the
            // AppDelegate timer that actually performs initialization.
            //
            // SystemState has its own com.apple.accessibility.api observer that updates
            // the UI independently — no need to post AccessibilityStatusChanged here.
            // Instead, directly trigger initialization when AX is trusted.
            let axTrusted = AXIsProcessTrusted()
            let inputTrusted = PHTVPermissionService.hasInputMonitoringPermission()
            NSLog(
                "[TCC] Post-notification check: AXTrusted=%@ InputTrusted=%@",
                axTrusted ? "YES" : "NO",
                inputTrusted ? "YES" : "NO"
            )

            if axTrusted && inputTrusted {
                // Trigger initialization immediately instead of waiting for the next timer tick.
                AppDelegate.current()?.checkAccessibilityAndRestart()
            } else {
                AppDelegate.current()?.needsRelaunchAfterPermission = true
                AppDelegate.current()?.continuePermissionGuidanceIfNeeded()
                // Permission was revoked or not yet effective — notify observers to refresh.
                NotificationCenter.default.post(
                    name: accessibilityStatusChangedNotification,
                    object: NSNumber(value: false)
                )
            }
        }
    }
}
