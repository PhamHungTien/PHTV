//
//  AppDelegate+Sparkle.swift
//  PHTV
//
//  Sparkle bridge using default Sparkle UI flow.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit
import Foundation

@objc extension AppDelegate {
    func bootstrapSparkleUpdates() {
        _ = SparkleManager.shared()

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(10))
            NSLog("[Sparkle] Checking for updates (launch bootstrap)...")
            SparkleManager.shared().checkForUpdates()
        }
    }

    func registerSparkleObservers() {
        sparkleNotificationTasks.forEach { $0.cancel() }
        sparkleNotificationTasks = [
            makeNotificationTask(name: NotificationName.sparkleManualCheck) { appDelegate, notification in
                appDelegate.handleSparkleManualCheck(notification)
            },
            makeNotificationTask(name: NotificationName.updateCheckFrequencyChanged) { appDelegate, notification in
                appDelegate.handleUpdateFrequencyChanged(notification)
            },
            makeNotificationTask(name: NotificationName.sparkleInstallUpdate) { appDelegate, notification in
                appDelegate.handleSparkleInstallUpdate(notification)
            }
        ]
    }

    func handleSparkleManualCheck(_ notification: Notification) {
        _ = notification
        NSLog("[Sparkle] Manual check requested from UI")
        SparkleManager.shared().checkForUpdatesWithFeedback()
    }

    func handleUpdateFrequencyChanged(_ notification: Notification) {
        guard let interval = notification.object as? NSNumber else {
            return
        }

        NSLog("[Sparkle] Update frequency changed to: %.0f seconds", interval.doubleValue)
        SparkleManager.shared().setUpdateCheckInterval(interval.doubleValue)
    }

    func handleSparkleInstallUpdate(_ notification: Notification) {
        _ = notification
        NSLog("[Sparkle] Install update requested from custom banner")
        SparkleManager.shared().checkForUpdatesWithFeedback()
    }
}
