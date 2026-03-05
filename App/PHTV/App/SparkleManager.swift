//
//  SparkleManager.swift
//  PHTV
//
//  Swift port of SparkleManager.mm while preserving ObjC API compatibility.
//

import Foundation
import Sparkle

@MainActor
@objcMembers
final class SparkleManager: NSObject {
    private static let sharedInstance = SparkleManager()

    @objc(shared)
    class func shared() -> SparkleManager {
        sharedInstance
    }

    private var isManualCheck = false
    private lazy var updaterDelegate = SparkleUpdaterDelegate(owner: self)
    private lazy var userDriverDelegate = SparkleUserDriverDelegate(owner: self)

    private lazy var customUserDriver = PHSilentUserDriver(
        hostBundle: .main,
        delegate: userDriverDelegate
    )

    @objc private(set) lazy var updater: SPUUpdater = {
        SPUUpdater(
            hostBundle: .main,
            applicationBundle: .main,
            userDriver: customUserDriver,
            delegate: updaterDelegate
        )
    }()

    override init() {
        super.init()
        startUpdater()
        NSLog("[Sparkle] Initialized with PHSilentUserDriver (stable channel only)")
    }

    private func startUpdater() {
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

    fileprivate func didFindValidUpdate(_ item: SUAppcastItem) {
        NSLog("[Sparkle] didFindValidUpdate: %@ (%@)", item.displayVersionString, item.versionString)
        // Keep manual-check flag until user driver handles result.
    }

    fileprivate func didNotFindUpdate() {
        NSLog("[Sparkle] No updates available (manual check: %@)", isManualCheck ? "YES" : "NO")

        if isManualCheck {
            NotificationCenter.default.post(name: NotificationName.sparkleNoUpdateFound, object: nil)
        }

        isManualCheck = false
    }

    fileprivate func didFinishLoadingAppcast(_ appcast: SUAppcast) {
        NSLog("[Sparkle] Appcast loaded: %lu items", appcast.items.count)
    }

    fileprivate func failedToDownloadUpdate(_ error: any Error) {
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

            NotificationCenter.default.post(name: NotificationName.checkForUpdatesResponse, object: info)
        }

        isManualCheck = false
    }

    fileprivate func willInstallUpdate(_ item: SUAppcastItem) {
        NSLog("[Sparkle] Will install update: %@", item.displayVersionString)
    }

    fileprivate func clearManualCheckFlagOnUserDriverEvent() {
        isManualCheck = false
    }
}

@MainActor
private final class SparkleUpdaterDelegate: NSObject, SPUUpdaterDelegate {
    private weak var owner: SparkleManager?

    init(owner: SparkleManager) {
        self.owner = owner
        super.init()
    }

    func feedURLString(for updater: SPUUpdater) -> String? {
        _ = updater
        NSLog("[Sparkle] Using STABLE feed")
        return nil // Use Info.plist value
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        _ = updater
        owner?.didFindValidUpdate(item)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        _ = updater
        owner?.didNotFindUpdate()
    }

    func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        _ = updater
        owner?.didFinishLoadingAppcast(appcast)
    }

    func updater(_ updater: SPUUpdater, failedToDownloadUpdate item: SUAppcastItem, error: any Error) {
        _ = updater
        _ = item
        owner?.failedToDownloadUpdate(error)
    }

    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        _ = updater
        owner?.willInstallUpdate(item)
    }
}

@MainActor
private final class SparkleUserDriverDelegate: NSObject, @preconcurrency SPUStandardUserDriverDelegate {
    private weak var owner: SparkleManager?

    init(owner: SparkleManager) {
        self.owner = owner
        super.init()
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool,
                                                   forUpdate update: SUAppcastItem,
                                                   state: SPUUserUpdateState) {
        _ = state
        NSLog("[Sparkle] standardUserDriverWillHandleShowingUpdate: %@ (handleShowingUpdate: %@)",
              update.displayVersionString,
              handleShowingUpdate ? "YES" : "NO")
        owner?.clearManualCheckFlagOnUserDriverEvent()
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        NSLog("[Sparkle] User attention received for update: %@", update.displayVersionString)
    }
}
