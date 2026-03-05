//
//  AppDelegate+Sparkle.swift
//  PHTV
//
//  Sparkle bridge using default Sparkle UI flow.
//

import AppKit
import Foundation

@objc extension AppDelegate {
    func registerSparkleObservers() {
        let center = NotificationCenter.default

        center.addObserver(
            self,
            selector: #selector(handleSparkleManualCheck(_:)),
            name: NotificationName.sparkleManualCheck,
            object: nil
        )

        center.addObserver(
            self,
            selector: #selector(handleUpdateFrequencyChanged(_:)),
            name: NotificationName.updateCheckFrequencyChanged,
            object: nil
        )

        center.addObserver(
            self,
            selector: #selector(handleSparkleInstallUpdate(_:)),
            name: NotificationName.sparkleInstallUpdate,
            object: nil
        )
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
