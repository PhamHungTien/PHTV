//
//  SparkleManager.swift
//  PHTV
//
//  Swift port of SparkleManager.mm while preserving ObjC API compatibility.
//

import AppKit
import Foundation
import Sparkle

@MainActor
@objcMembers
final class SparkleManager: NSObject, SPUUpdaterDelegate, @preconcurrency SPUStandardUserDriverDelegate {
    private static let sharedInstance = SparkleManager()

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

    private func isSparkleWindow(_ window: NSWindow) -> Bool {
        let className = NSStringFromClass(type(of: window))
        if className.contains("SU") || className.localizedCaseInsensitiveContains("Sparkle") {
            return true
        }
        let bundleIdentifier = Bundle(for: type(of: window)).bundleIdentifier?.lowercased() ?? ""
        return bundleIdentifier.contains("sparkle")
    }

    private func promoteSparkleWindowsToFront() {
        for window in NSApp.windows where isSparkleWindow(window) {
            if window.level.rawValue < NSWindow.Level.floating.rawValue {
                window.level = .floating
            }
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }

    private func bringUpdateUIToFront() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
        promoteSparkleWindowsToFront()
    }

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
        bringUpdateUIToFront()
        updater.checkForUpdates()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.promoteSparkleWindowsToFront()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.promoteSparkleWindowsToFront()
        }
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

        if handleShowingUpdate {
            bringUpdateUIToFront()
        }

        isManualCheck = false
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        NSLog("[Sparkle] User attention received for update: %@", update.displayVersionString)
        bringUpdateUIToFront()
    }
}
