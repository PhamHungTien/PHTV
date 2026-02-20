//
//  SparkleManager.swift
//  PHTV
//
//  Swift port of SparkleManager.mm while preserving ObjC API compatibility.
//

import Foundation
import Sparkle

@objcMembers
final class SparkleManager: NSObject, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    nonisolated(unsafe) private static let sharedInstance = SparkleManager()

    @objc(shared)
    class func shared() -> SparkleManager {
        return sharedInstance
    }

    private lazy var customUserDriver: PHSilentUserDriver = {
        return PHSilentUserDriver(hostBundle: .main, delegate: self)
    }()

    @objc private(set) lazy var updater: SPUUpdater = {
        return SPUUpdater(hostBundle: .main,
                          applicationBundle: .main,
                          userDriver: customUserDriver,
                          delegate: self)
    }()

    private var isManualCheck = false

    override init() {
        super.init()

        var startError: NSError?
        do {
            try updater.start()
        } catch let nsError as NSError {
            startError = nsError
        } catch {
            startError = NSError(domain: "SparkleManager", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Unknown Sparkle startup error"
            ])
        }

        if let startError {
            NSLog("[Sparkle] Failed to start updater: %@", startError.localizedDescription)
        }

        NSLog("[Sparkle] Initialized with PHSilentUserDriver (stable channel only)")
    }

    /// Manually trigger update check (user-initiated, shows feedback)
    @objc func checkForUpdatesWithFeedback() {
        NSLog("[Sparkle] User-initiated update check (with feedback)")
        isManualCheck = true
        updater.checkForUpdates()
    }

    /// Background update check (silent)
    @objc func checkForUpdates() {
        NSLog("[Sparkle] Background update check (silent)")
        isManualCheck = false
        updater.checkForUpdatesInBackground()
    }

    /// Configure update check interval in seconds
    @objc func setUpdateCheckInterval(_ interval: TimeInterval) {
        NSLog("[Sparkle] Update interval set to %.0f seconds", interval)
        UserDefaults.standard.set(interval, forKey: "SUScheduledCheckInterval")
    }

    // MARK: - SPUUpdaterDelegate

    func feedURLString(for updater: SPUUpdater) -> String? {
        NSLog("[Sparkle] Using STABLE feed")
        return nil // Use Info.plist value
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        NSLog("[Sparkle] didFindValidUpdate: %@ (%@)", item.displayVersionString, item.versionString)
        // Keep manual-check flag until user driver handles result.
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        NSLog("[Sparkle] No updates available (manual check: %@)", isManualCheck ? "YES" : "NO")

        if isManualCheck {
            NotificationCenter.default.post(name: NSNotification.Name("SparkleNoUpdateFound"), object: nil)
        }

        isManualCheck = false
    }

    func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        NSLog("[Sparkle] Appcast loaded: %lu items", appcast.items.count)
    }

    func updater(_ updater: SPUUpdater, failedToDownloadUpdate item: SUAppcastItem, error: any Error) {
        let nsError = error as NSError
        NSLog("[Sparkle] Failed to download update: %@ (manual check: %@)",
              nsError.localizedDescription,
              isManualCheck ? "YES" : "NO")

        if isManualCheck {
            let info: [String: Any] = [
                "message": "Lỗi tải bản cập nhật: \(nsError.localizedDescription)",
                "isError": true,
                "updateAvailable": false
            ]

            NotificationCenter.default.post(name: NSNotification.Name("CheckForUpdatesResponse"), object: info)
        }

        isManualCheck = false
    }

    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        NSLog("[Sparkle] Will install update: %@", item.displayVersionString)
    }

    // MARK: - SPUStandardUserDriverDelegate

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool,
                                                   forUpdate update: SUAppcastItem,
                                                   state: SPUUserUpdateState) {
        NSLog("[Sparkle] standardUserDriverWillHandleShowingUpdate: %@ (handleShowingUpdate: %@)",
              update.displayVersionString,
              handleShowingUpdate ? "YES" : "NO")

        isManualCheck = false
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        NSLog("[Sparkle] User attention received for update: %@", update.displayVersionString)
    }
}
