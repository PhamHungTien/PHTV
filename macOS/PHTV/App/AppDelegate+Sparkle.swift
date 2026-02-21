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
                           name: Notification.Name("SparkleManualCheck"),
                           object: nil)

        center.addObserver(self,
                           selector: #selector(handleSparkleUpdateFound(_:)),
                           name: Notification.Name("SparkleUpdateFound"),
                           object: nil)

        // Show "up to date" alert only for manual checks.
        center.addObserver(self,
                           selector: #selector(handleSparkleNoUpdate(_:)),
                           name: Notification.Name("SparkleNoUpdateFound"),
                           object: nil)

        center.addObserver(self,
                           selector: #selector(handleUpdateFrequencyChanged(_:)),
                           name: Notification.Name("UpdateCheckFrequencyChanged"),
                           object: nil)

        center.addObserver(self,
                           selector: #selector(handleSparkleInstallUpdate(_:)),
                           name: Notification.Name("SparkleInstallUpdate"),
                           object: nil)
    }

    func handleSparkleManualCheck(_ notification: Notification) {
        _ = notification
        NSLog("[Sparkle] Manual check requested from UI")
        SparkleManager.shared().checkForUpdatesWithFeedback()
    }

    func handleSparkleUpdateFound(_ notification: Notification) {
        guard let updateInfo = notification.object as? [String: Any] else {
            return
        }

        let version = updateInfo["version"] as? String ?? ""
        let downloadURL = updateInfo["downloadURL"] as? String ?? ""
        let releaseNotes = updateInfo["releaseNotes"] as? String ?? ""
        let message = "Phiên bản mới \(version) có sẵn"

        DispatchQueue.main.async {
            let response: [String: Any] = [
                "message": message,
                "isError": false,
                "updateAvailable": true,
                "latestVersion": version,
                "downloadUrl": downloadURL,
                "releaseNotes": releaseNotes
            ]

            NotificationCenter.default.post(name: Notification.Name("CheckForUpdatesResponse"), object: response)
        }
    }

    func handleSparkleNoUpdate(_ notification: Notification) {
        _ = notification

        DispatchQueue.main.async {
            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""

            let alert = NSAlert()
            alert.messageText = "Đã cập nhật"
            alert.informativeText = "Bạn đang sử dụng phiên bản mới nhất của PHTV (\(currentVersion))."
            alert.addButton(withTitle: "OK")
            alert.alertStyle = .informational
            alert.runModal()
        }
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
