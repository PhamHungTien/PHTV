//
//  SystemState.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import ServiceManagement
import Combine

/// Manages system settings, permissions, and updates
@MainActor
final class SystemState: ObservableObject {
    // System settings
    @Published var runOnStartup: Bool = false
    @Published var performLayoutCompat: Bool = false
    @Published var showIconOnDock: Bool = false
    @Published var settingsWindowAlwaysOnTop: Bool = false
    @Published var safeMode: Bool = false

    // Text Replacement Fix is always enabled (no user setting)
    var enableTextReplacementFix: Bool { return true }

    // Accessibility
    @Published var hasAccessibilityPermission: Bool = false

    // Update notification - shown when new version is available on startup
    @Published var updateAvailableMessage: String = ""
    @Published var showUpdateBanner: Bool = false
    @Published var latestVersion: String = ""

    // Sparkle update configuration
    @Published var updateCheckFrequency: UpdateCheckFrequency = .daily
    @Published var showCustomUpdateBanner: Bool = false
    @Published var customUpdateBannerInfo: UpdateBannerInfo? = nil

    // Bug report settings
    @Published var includeSystemInfo: Bool = true
    @Published var includeLogs: Bool = false
    @Published var includeCrashLogs: Bool = true

    private var cancellables = Set<AnyCancellable>()
    private var notificationObservers: [NSObjectProtocol] = []
    var isLoadingSettings = false
    private var isUpdatingRunOnStartup = false
    private var loginItemCheckTimer: Timer?
    private var lastRunOnStartupChangeTime: Date?

    // Helper to access AppDelegate safely on main actor
    @MainActor
    private func getAppDelegate() -> AppDelegate? {
        return NSApp.delegate as? AppDelegate
    }

    init() {}

    // MARK: - Load/Save Settings

    func loadSettings() {
        let defaults = UserDefaults.standard

        // Load system settings - check actual SMAppService status for runOnStartup
        if #available(macOS 13.0, *) {
            let appService = SMAppService.mainApp
            let status = (appService.status == .enabled)
            NSLog("[SystemState] Loading runOnStartup from SMAppService: %@", status ? "enabled" : "disabled")
            isUpdatingRunOnStartup = true
            runOnStartup = status
            isUpdatingRunOnStartup = false
        } else {
            runOnStartup = defaults.bool(forKey: UserDefaultsKey.runOnStartup, default: Defaults.runOnStartup)
        }

        performLayoutCompat = defaults.bool(
            forKey: UserDefaultsKey.performLayoutCompat,
            default: Defaults.performLayoutCompat
        )
        showIconOnDock = defaults.bool(forKey: UserDefaultsKey.showIconOnDock, default: Defaults.showIconOnDock)
        settingsWindowAlwaysOnTop = defaults.bool(
            forKey: UserDefaultsKey.settingsWindowAlwaysOnTop,
            default: Defaults.settingsWindowAlwaysOnTop
        )
        safeMode = defaults.bool(forKey: UserDefaultsKey.safeMode, default: Defaults.safeMode)

        // Load Sparkle settings
        let updateInterval = defaults.integer(
            forKey: UserDefaultsKey.updateCheckInterval,
            default: Defaults.updateCheckInterval
        )
        updateCheckFrequency = UpdateCheckFrequency.from(interval: updateInterval)

        // Always use stable channel and always auto-install updates.
        defaults.enforceStableUpdateChannel()

        // Load bug report settings
        includeSystemInfo = defaults.bool(
            forKey: UserDefaultsKey.includeSystemInfo,
            default: Defaults.includeSystemInfo
        )
        includeLogs = defaults.bool(forKey: UserDefaultsKey.includeLogs, default: Defaults.includeLogs)
        includeCrashLogs = defaults.bool(
            forKey: UserDefaultsKey.includeCrashLogs,
            default: Defaults.includeCrashLogs
        )
    }

    func saveSettings() {
        SettingsObserver.shared.suspendNotifications()
        let defaults = UserDefaults.standard

        // Save system settings
        defaults.set(runOnStartup, forKey: UserDefaultsKey.runOnStartup)
        defaults.set(performLayoutCompat, forKey: UserDefaultsKey.performLayoutCompat)
        defaults.set(showIconOnDock, forKey: UserDefaultsKey.showIconOnDock)
        defaults.set(settingsWindowAlwaysOnTop, forKey: UserDefaultsKey.settingsWindowAlwaysOnTop)

        // Save safe mode and sync with backend
        defaults.set(safeMode, forKey: UserDefaultsKey.safeMode)
        PHTVManager.setSafeModeEnabled(safeMode)

        // Save Sparkle settings
        defaults.set(updateCheckFrequency.rawValue, forKey: UserDefaultsKey.updateCheckInterval)
        defaults.enforceStableUpdateChannel()

        // Save bug report settings
        defaults.set(includeSystemInfo, forKey: UserDefaultsKey.includeSystemInfo)
        defaults.set(includeLogs, forKey: UserDefaultsKey.includeLogs)
        defaults.set(includeCrashLogs, forKey: UserDefaultsKey.includeCrashLogs)

    }

    func reloadFromDefaults() {
        loadSettings()
    }

    // MARK: - Accessibility

    func checkAccessibilityPermission() {
        // CRITICAL: Use PHTVManager.canCreateEventTap() - the ONLY reliable method
        Task { @MainActor in
            self.hasAccessibilityPermission = PHTVManager.canCreateEventTap()
        }
    }

    // MARK: - Login Item Monitoring

    /// Start periodic monitoring of login item status
    func startLoginItemStatusMonitoring() {
        guard #available(macOS 13.0, *) else { return }
        guard loginItemCheckTimer == nil else { return }

        // Check every 5 seconds
        loginItemCheckTimer = Timer.scheduledTimer(withTimeInterval: Timing.loginItemCheckInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkLoginItemStatus()
            }
        }

        // Also check immediately
        Task { @MainActor in
            await checkLoginItemStatus()
        }

        NSLog(
            "[LoginItem] Periodic status monitoring started (interval: %.1fs)",
            Timing.loginItemCheckInterval
        )
    }

    /// Stop periodic monitoring of login item status
    func stopLoginItemStatusMonitoring() {
        guard loginItemCheckTimer != nil else { return }
        loginItemCheckTimer?.invalidate()
        loginItemCheckTimer = nil
        NSLog("[LoginItem] Periodic status monitoring stopped")
    }

    /// Check if SMAppService status matches our UI state
    @available(macOS 13.0, *)
    @MainActor
    private func checkLoginItemStatus() async {
        guard !isUpdatingRunOnStartup else { return }

        // Don't override user changes immediately
        if let lastChange = lastRunOnStartupChangeTime {
            let timeSinceChange = Date().timeIntervalSince(lastChange)
            if timeSinceChange < Timing.loginItemGracePeriod {
                #if DEBUG
                NSLog("[LoginItem] Skipping check - user changed setting %.1fs ago (< 10s grace period)", timeSinceChange)
                #endif
                return
            }
        }

        let appService = SMAppService.mainApp
        let actualStatus = (appService.status == .enabled)

        // Only log if there's a mismatch
        if actualStatus != runOnStartup {
            NSLog("[LoginItem] ⚠️ Status mismatch detected! UI: %@, SMAppService: %@",
                  runOnStartup ? "ON" : "OFF", actualStatus ? "ON" : "OFF")

            // Update UI to match reality
            isUpdatingRunOnStartup = true
            runOnStartup = actualStatus
            isUpdatingRunOnStartup = false

            // Update UserDefaults too
            SettingsObserver.shared.suspendNotifications()
            let defaults = UserDefaults.standard
            defaults.set(actualStatus, forKey: UserDefaultsKey.runOnStartup)
            defaults.set(actualStatus ? 1 : 0, forKey: UserDefaultsKey.runOnStartupLegacy)

            NSLog("[LoginItem] ✅ UI synced to actual status: %@", actualStatus ? "ON" : "OFF")
        }
    }

    // MARK: - Setup Observers

    func setupObservers() {
        // Observer for runOnStartup
        $runOnStartup
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] value in
            guard let self = self, !self.isLoadingSettings, !self.isUpdatingRunOnStartup else {
                NSLog("[SystemState] runOnStartup observer skipped")
                return
            }

            NSLog("[SystemState] 🔄 runOnStartup observer triggered: value=%@", value ? "ON" : "OFF")

            // Record timestamp
            self.lastRunOnStartupChangeTime = Date()

            guard let appDelegate = self.getAppDelegate() else {
                NSLog("[SystemState] ❌ NSApp.delegate as AppDelegate returned nil")
                return
            }

            NSLog("[SystemState] ✅ Calling AppDelegate.setRunOnStartup(%@)", value ? "YES" : "NO")
            appDelegate.setRunOnStartup(value)
        }.store(in: &cancellables)

        // Observer for showIconOnDock
        $showIconOnDock
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] value in
            guard let self = self, !self.isLoadingSettings else { return }
            SettingsObserver.shared.suspendNotifications()
            let defaults = UserDefaults.standard
            defaults.set(value, forKey: UserDefaultsKey.showIconOnDock)
            NotificationCenter.default.post(
                name: NotificationName.phtvSettingsChanged, object: nil)
        }.store(in: &cancellables)

        // Observer for settingsWindowAlwaysOnTop
        $settingsWindowAlwaysOnTop
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] value in
            guard let self = self, !self.isLoadingSettings else { return }
            SettingsObserver.shared.suspendNotifications()
            let defaults = UserDefaults.standard
            defaults.set(value, forKey: UserDefaultsKey.settingsWindowAlwaysOnTop)
        }.store(in: &cancellables)

        // Observer for system settings
        Publishers.MergeMany([
            $performLayoutCompat.map { _ in () }.eraseToAnyPublisher(),
            $safeMode.map { _ in () }.eraseToAnyPublisher()
        ])
        .debounce(for: .milliseconds(Timing.settingsDebounce), scheduler: RunLoop.main)
        .dropFirst()
        .sink { [weak self] _ in
            guard let self = self, !self.isLoadingSettings else { return }
            self.saveSettings()
            NotificationCenter.default.post(
                name: NotificationName.phtvSettingsChanged, object: nil)
        }.store(in: &cancellables)

        // Update frequency observer
        $updateCheckFrequency
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] frequency in
            guard let self = self, !self.isLoadingSettings else { return }
            SettingsObserver.shared.suspendNotifications()
            let defaults = UserDefaults.standard
            defaults.set(frequency.rawValue, forKey: UserDefaultsKey.updateCheckInterval)

            NotificationCenter.default.post(
                name: NotificationName.updateCheckFrequencyChanged,
                object: NSNumber(value: frequency.rawValue)
            )
        }.store(in: &cancellables)

        // Bug report settings observers
        Publishers.MergeMany([
            $includeSystemInfo.map { _ in () }.eraseToAnyPublisher(),
            $includeLogs.map { _ in () }.eraseToAnyPublisher(),
            $includeCrashLogs.map { _ in () }.eraseToAnyPublisher()
        ])
        .debounce(for: .milliseconds(Timing.settingsDebounce), scheduler: RunLoop.main)
        .dropFirst()
        .sink { [weak self] _ in
            guard let self = self, !self.isLoadingSettings else { return }
            self.saveSettings()
        }.store(in: &cancellables)
    }

    func setupNotificationObservers() {
        let observer1 = NotificationCenter.default.addObserver(
            forName: NotificationName.accessibilityStatusChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let isEnabled = notification.object as? NSNumber {
                Task { @MainActor in
                    self.hasAccessibilityPermission = isEnabled.boolValue
                }
            }
        }
        notificationObservers.append(observer1)

        // Listen for update check responses from backend
        let observer2 = NotificationCenter.default.addObserver(
            forName: NotificationName.checkForUpdatesResponse,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let response = notification.object as? [String: Any] {
                let updateAvailable = (response["updateAvailable"] as? Bool) ?? false
                let message = response["message"] as? String ?? ""
                let latestVersion = response["latestVersion"] as? String ?? ""

                if updateAvailable && !message.isEmpty && !latestVersion.isEmpty {
                    Task { @MainActor in
                        self.updateAvailableMessage = message
                        self.latestVersion = latestVersion
                        self.showUpdateBanner = true
                    }
                }
            }
        }
        notificationObservers.append(observer2)

        // Sparkle custom update banner
        let observer3 = NotificationCenter.default.addObserver(
            forName: NotificationName.sparkleShowUpdateBanner,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let info = notification.object as? [String: String] {
                Task { @MainActor in
                    let updateInfo = UpdateBannerInfo(
                        version: info["version"] ?? "",
                        releaseNotes: info["releaseNotes"] ?? "",
                        downloadURL: info["downloadURL"] ?? ""
                    )
                    self.customUpdateBannerInfo = updateInfo
                    self.showCustomUpdateBanner = true
                    NSLog("[SystemState] Showing update banner for version %@", updateInfo.version)
                }
            }
        }
        notificationObservers.append(observer3)

        // Listen for Launch at Login changes from AppDelegate
        let observer4 = NotificationCenter.default.addObserver(
            forName: NotificationName.runOnStartupChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let userInfo = notification.userInfo,
               let enabled = userInfo[NotificationUserInfoKey.enabled] as? Bool {
                Task { @MainActor in
                    self.isUpdatingRunOnStartup = true
                    self.runOnStartup = enabled
                    self.isUpdatingRunOnStartup = false
                    PHTVLogger.shared.info("[SystemState] RunOnStartup synced from notification: \(enabled)")
                }
            }
        }
        notificationObservers.append(observer4)

        // Listen for app termination
        let terminateObserver = NotificationCenter.default.addObserver(
            forName: NotificationName.applicationWillTerminate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.cleanupObservers()
            }
        }
        notificationObservers.append(terminateObserver)
    }

    func cleanupObservers() {
        notificationObservers.forEach { observer in
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()

        loginItemCheckTimer?.invalidate()
        loginItemCheckTimer = nil
    }

    func resetToDefaults() {
        isLoadingSettings = true
        defer { isLoadingSettings = false }

        runOnStartup = Defaults.runOnStartup
        performLayoutCompat = Defaults.performLayoutCompat
        showIconOnDock = Defaults.showIconOnDock
        safeMode = Defaults.safeMode
        settingsWindowAlwaysOnTop = Defaults.settingsWindowAlwaysOnTop

        let checkInterval = Defaults.updateCheckInterval
        updateCheckFrequency = UpdateCheckFrequency.from(interval: checkInterval)

        includeSystemInfo = Defaults.includeSystemInfo
        includeLogs = Defaults.includeLogs
        includeCrashLogs = Defaults.includeCrashLogs

        saveSettings()
    }
}
