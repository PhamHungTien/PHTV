//
//  AppDelegate+Sparkle.swift
//  PHTV
//
//  Swift port of AppDelegate+Sparkle.mm.
//

import AppKit
import Foundation

@objc extension AppDelegate {
    func registerSparkleObservers() {
        let center = NotificationCenter.default

        center.addObserver(self,
                           selector: #selector(handleSparkleManualCheck(_:)),
                           name: NotificationName.sparkleManualCheck,
                           object: nil)

        center.addObserver(self,
                           selector: #selector(handleUpdateFrequencyChanged(_:)),
                           name: NotificationName.updateCheckFrequencyChanged,
                           object: nil)
    }

    func handleSparkleManualCheck(_ notification: Notification) {
        _ = notification
        NSLog("[Sparkle] Manual check requested from UI")
        NSApp.activate(ignoringOtherApps: true)
        SparkleManager.shared().checkForUpdatesWithFeedback()
    }

    func handleUpdateFrequencyChanged(_ notification: Notification) {
        guard let interval = notification.object as? NSNumber else {
            return
        }

        NSLog("[Sparkle] Update frequency changed to: %.0f seconds", interval.doubleValue)
        SparkleManager.shared().setUpdateCheckInterval(interval.doubleValue)
    }
}
