//
//  SparkleManager.swift
//  PHTV
//
//  Lightweight Sparkle wrapper using default Sparkle behavior.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit
import Foundation
import Sparkle

@MainActor
@objcMembers
final class SparkleManager: NSObject {
    private static let sharedInstance = SparkleManager()
    private static let updaterDelegate = SparkleUpdaterDelegate()
    private static let userDriverDelegate = SparkleUserDriverDelegate()

    @objc(shared)
    class func shared() -> SparkleManager {
        sharedInstance
    }

    private lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: SparkleManager.updaterDelegate,
        userDriverDelegate: SparkleManager.userDriverDelegate
    )

    @objc private(set) lazy var updater: SPUUpdater = {
        updaterController.updater
    }()

    override init() {
        super.init()
        _ = updaterController
        NSLog("[Sparkle] Initialized with SPUStandardUpdaterController + popup pinning")
    }

    /// Manually trigger update check (Sparkle handles all UI)
    @objc func checkForUpdatesWithFeedback() {
        NSLog("[Sparkle] Manual check requested")
        updater.checkForUpdates()
    }

    /// Background update check
    @objc func checkForUpdates() {
        NSLog("[Sparkle] Background check requested")
        updater.checkForUpdatesInBackground()
    }

    /// Configure update check interval in seconds
    @objc func setUpdateCheckInterval(_ interval: TimeInterval) {
        NSLog("[Sparkle] Update interval set to %.0f seconds", interval)
        UserDefaults.standard.set(interval, forKey: "SUScheduledCheckInterval")
    }
}

@MainActor
private final class SparkleUpdaterDelegate: NSObject, SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        _ = updater
        NSLog("[Sparkle] Will install update: %@", item.displayVersionString)
    }

    nonisolated func feedURLString(for updater: SPUUpdater) -> String? {
        _ = updater
        // Route to arch-specific appcast so users only download the binary for their CPU.
        // Legacy universal builds (pre-2.6.7) don't have this delegate, so they fall back to
        // the hardcoded SUFeedURL (appcast.xml = arm64 feed) in Info.plist.
        var size = 0
        sysctlbyname("hw.optional.arm64", nil, &size, nil, 0)
        var isArm64: Int32 = 0
        sysctlbyname("hw.optional.arm64", &isArm64, &size, nil, 0)

        let feed = isArm64 != 0
            ? "https://phamhungtien.github.io/PHTV/appcast.xml"
            : "https://phamhungtien.github.io/PHTV/appcast-intel.xml"
        NSLog("[Sparkle] Using feed: %@", feed)
        return feed
    }
}

@MainActor
private final class SparkleUserDriverDelegate: NSObject, SPUStandardUserDriverDelegate {
    private final class TrackedWindow {
        weak var window: NSWindow?
        let originalLevel: NSWindow.Level

        init(window: NSWindow, originalLevel: NSWindow.Level) {
            self.window = window
            self.originalLevel = originalLevel
        }
    }

    private var trackedWindows: [TrackedWindow] = []
    private var isUpdateSessionActive = false

    override init() {
        super.init()
        registerObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    nonisolated var supportsGentleScheduledUpdateReminders: Bool {
        true
    }

    nonisolated func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool,
                                                               forUpdate update: SUAppcastItem,
                                                               state: SPUUserUpdateState) {
        _ = handleShowingUpdate
        _ = update
        _ = state
        Task { @MainActor [weak self] in
            self?.beginUpdateSession()
        }
    }

    nonisolated func standardUserDriverWillShowModalAlert() {
        Task { @MainActor [weak self] in
            self?.beginUpdateSession()
        }
    }

    nonisolated func standardUserDriverDidShowModalAlert() {
        Task { @MainActor [weak self] in
            self?.beginUpdateSession()
        }
    }

    nonisolated func standardUserDriverWillFinishUpdateSession() {
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            self.isUpdateSessionActive = false
            self.restoreWindowLevels()
        }
    }

    private func registerObservers() {
        let center = NotificationCenter.default

        center.addObserver(
            self,
            selector: #selector(handleWindowNotification(_:)),
            name: NSWindow.didBecomeMainNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handleWindowNotification(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive(_:)),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc
    private func handleWindowNotification(_ notification: Notification) {
        guard isUpdateSessionActive else {
            return
        }
        guard let window = notification.object as? NSWindow, isSparkleWindow(window) else {
            return
        }

        promoteWindow(window)
    }

    @objc
    private func handleAppDidBecomeActive(_ notification: Notification) {
        _ = notification
        guard isUpdateSessionActive else {
            return
        }
        bringUpdatePopupToFront()
    }

    private func beginUpdateSession() {
        isUpdateSessionActive = true
        bringUpdatePopupToFront()
    }

    private func bringUpdatePopupToFront() {
        NSApp.activate(ignoringOtherApps: true)

        for window in NSApp.windows where window.isVisible && isSparkleWindow(window) {
            promoteWindow(window)
        }

        trackedWindows.removeAll { $0.window == nil }
    }

    private func promoteWindow(_ window: NSWindow) {
        if !trackedWindows.contains(where: { $0.window === window }) {
            trackedWindows.append(TrackedWindow(window: window, originalLevel: window.level))
        }

        window.level = .floating
        window.collectionBehavior.insert(.fullScreenAuxiliary)
        window.orderFrontRegardless()
    }

    private func restoreWindowLevels() {
        for trackedWindow in trackedWindows {
            guard let window = trackedWindow.window else {
                continue
            }
            window.level = trackedWindow.originalLevel
        }
        trackedWindows.removeAll()
    }

    private func isSparkleWindow(_ window: NSWindow) -> Bool {
        if let controller = window.windowController {
            let controllerClass = type(of: controller)
            let controllerBundleID = Bundle(for: controllerClass).bundleIdentifier ?? ""
            if controllerBundleID.localizedCaseInsensitiveContains("sparkle") {
                return true
            }
        }

        if let delegate = window.delegate {
            let delegateClass = type(of: delegate)
            let delegateBundleID = Bundle(for: delegateClass).bundleIdentifier ?? ""
            if delegateBundleID.localizedCaseInsensitiveContains("sparkle") {
                return true
            }
        }

        return false
    }
}
