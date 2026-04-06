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
        NSLog(
            "[Sparkle] Initialized with SPUStandardUpdaterController + popup pinning (checks=%@ downloads=%@ interval=%.0f)",
            updater.automaticallyChecksForUpdates ? "YES" : "NO",
            updater.automaticallyDownloadsUpdates ? "YES" : "NO",
            updater.updateCheckInterval
        )
    }

    /// Manually trigger update check (Sparkle handles all UI)
    @objc func checkForUpdatesWithFeedback() {
        NSLog("[Sparkle] Manual check requested")
        updater.checkForUpdates()
    }

    /// Background update check
    @objc func checkForUpdates() {
        NSLog("[Sparkle] Background check requested")
        guard updater.automaticallyChecksForUpdates else {
            NSLog("[Sparkle] Skipping background check because automatic checks are disabled")
            return
        }
        updater.checkForUpdatesInBackground()
    }

    /// Configure update check interval in seconds
    @objc func setUpdateCheckInterval(_ interval: TimeInterval) {
        NSLog("[Sparkle] Update interval set to %.0f seconds", interval)
        updater.updateCheckInterval = interval
    }
}

@MainActor
private final class SparkleUpdaterDelegate: NSObject, SPUUpdaterDelegate {
    nonisolated func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
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
    private var observerTasks: [Task<Void, Never>] = []
    private var cascadeScanTasks: [Task<Void, Never>] = []
    /// Cascade scan delays (seconds) after session begins, to catch windows that appear slightly late
    private static let scanDelays: [TimeInterval] = [0.05, 0.15, 0.35, 0.7, 1.2, 2.0, 3.5]

    override init() {
        super.init()
        registerObservers()
    }

    deinit {
        observerTasks.forEach { $0.cancel() }
        cascadeScanTasks.forEach { $0.cancel() }
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

    /// Called after the alert is already on screen — scan immediately to pin it on top.
    nonisolated func standardUserDriverDidShowModalAlert() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            // Session may already be active; just promote whatever Sparkle window is now visible.
            self.isUpdateSessionActive = true
            self.bringUpdatePopupToFront()
        }
    }

    nonisolated func standardUserDriverWillFinishUpdateSession() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isUpdateSessionActive = false
            self.cancelCascadeScans()
            self.restoreWindowLevels()
        }
    }

    private func registerObservers() {
        observerTasks.forEach { $0.cancel() }
        observerTasks = [
            makeObserverTask(name: NSWindow.didBecomeMainNotification) { [weak self] notification in
                self?.handleWindowBecameKey(notification)
            },
            makeObserverTask(name: NSWindow.didBecomeKeyNotification) { [weak self] notification in
                self?.handleWindowBecameKey(notification)
            },
            makeObserverTask(name: NSApplication.didBecomeActiveNotification) { [weak self] notification in
                self?.handleAppDidBecomeActive(notification)
            }
        ]
    }

    @objc
    private func handleWindowBecameKey(_ notification: Notification) {
        guard isUpdateSessionActive,
              let window = notification.object as? NSWindow,
              isSparkleWindow(window) else { return }
        promoteWindow(window)
    }

    @objc
    private func handleAppDidBecomeActive(_ notification: Notification) {
        _ = notification
        guard isUpdateSessionActive else { return }
        bringUpdatePopupToFront()
    }

    private func beginUpdateSession() {
        guard !isUpdateSessionActive else {
            // Already active — just re-scan in case a new window appeared.
            bringUpdatePopupToFront()
            return
        }
        isUpdateSessionActive = true
        bringUpdatePopupToFront()
        // Schedule cascade scans so windows that appear with a delay are still promoted.
        scheduleCascadeScans()
    }

    /// Fires `bringUpdatePopupToFront` at each delay offset so late-appearing Sparkle
    /// windows (e.g. the "No updates available" alert) are always pinned on top.
    private func scheduleCascadeScans() {
        cancelCascadeScans()
        cascadeScanTasks = Self.scanDelays.map { delay in
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(delay))
                guard let self, !Task.isCancelled, self.isUpdateSessionActive else { return }
                self.bringUpdatePopupToFront()
            }
        }
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
        for tracked in trackedWindows {
            guard let window = tracked.window else { continue }
            window.level = tracked.originalLevel
        }
        trackedWindows.removeAll()
    }

    private func makeObserverTask(
        name: Notification.Name,
        handler: @escaping @MainActor (Notification) -> Void
    ) -> Task<Void, Never> {
        Task { @MainActor in
            for await notification in NotificationCenter.default.notifications(named: name) {
                guard !Task.isCancelled else { break }
                handler(notification)
            }
        }
    }

    private func cancelCascadeScans() {
        cascadeScanTasks.forEach { $0.cancel() }
        cascadeScanTasks.removeAll()
    }

    /// Detects whether a window belongs to Sparkle by checking bundle IDs and class names.
    private func isSparkleWindow(_ window: NSWindow) -> Bool {
        let sparkleKeywords = ["sparkle", "spu", "suupdater"]

        func matchesSparkle(_ string: String) -> Bool {
            let lower = string.lowercased()
            return sparkleKeywords.contains(where: { lower.contains($0) })
        }

        if let controller = window.windowController {
            let cls = type(of: controller)
            if matchesSparkle(Bundle(for: cls).bundleIdentifier ?? "") { return true }
            if matchesSparkle(String(describing: cls)) { return true }
        }

        if let delegate = window.delegate {
            let cls = type(of: delegate)
            if matchesSparkle(Bundle(for: cls).bundleIdentifier ?? "") { return true }
            if matchesSparkle(String(describing: cls)) { return true }
        }

        if matchesSparkle(String(describing: type(of: window))) { return true }

        return false
    }
}
