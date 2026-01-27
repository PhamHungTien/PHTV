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

    // Claude Code patch setting
    @Published var claudeCodePatchEnabled: Bool = false

    // Accessibility
    @Published var hasAccessibilityPermission: Bool = false

    // Update notification - shown when new version is available on startup
    @Published var updateAvailableMessage: String = ""
    @Published var showUpdateBanner: Bool = false
    @Published var latestVersion: String = ""

    // Sparkle update configuration
    @Published var updateCheckFrequency: UpdateCheckFrequency = .daily
    @Published var betaChannelEnabled: Bool = false
    @Published var autoInstallUpdates: Bool = true
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

    // Helper to access AppDelegate via C function
    @MainActor
    private func getAppDelegate() -> AppDelegate? {
        return GetAppDelegateInstance()
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
            runOnStartup = defaults.bool(forKey: UserDefaultsKey.runOnStartup)
        }

        performLayoutCompat = defaults.bool(forKey: UserDefaultsKey.performLayoutCompat)
        showIconOnDock = defaults.bool(forKey: UserDefaultsKey.showIconOnDock)
        settingsWindowAlwaysOnTop = defaults.bool(forKey: UserDefaultsKey.settingsWindowAlwaysOnTop)
        safeMode = defaults.bool(forKey: UserDefaultsKey.safeMode)

        // Load Claude Code patch setting - check actual patch status
        claudeCodePatchEnabled = ClaudeCodePatcher.shared.isPatched()

        // Load Sparkle settings
        let updateInterval = defaults.integer(forKey: UserDefaultsKey.updateCheckInterval)
        updateCheckFrequency = UpdateCheckFrequency.from(interval: updateInterval == 0 ? 86400 : updateInterval)
        betaChannelEnabled = defaults.bool(forKey: UserDefaultsKey.betaChannelEnabled)

        // Auto install updates - default to true if not set
        if defaults.object(forKey: UserDefaultsKey.autoInstallUpdates) == nil {
            autoInstallUpdates = true
        } else {
            autoInstallUpdates = defaults.bool(forKey: UserDefaultsKey.autoInstallUpdates)
        }

        // Load bug report settings
        includeSystemInfo = defaults.object(forKey: UserDefaultsKey.includeSystemInfo) as? Bool ?? Defaults.includeSystemInfo
        includeLogs = defaults.object(forKey: UserDefaultsKey.includeLogs) as? Bool ?? Defaults.includeLogs
        includeCrashLogs = defaults.object(forKey: UserDefaultsKey.includeCrashLogs) as? Bool ?? Defaults.includeCrashLogs
    }

    func saveSettings() {
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
        defaults.set(betaChannelEnabled, forKey: UserDefaultsKey.betaChannelEnabled)
        defaults.set(autoInstallUpdates, forKey: UserDefaultsKey.autoInstallUpdates)

        // Save bug report settings
        defaults.set(includeSystemInfo, forKey: UserDefaultsKey.includeSystemInfo)
        defaults.set(includeLogs, forKey: UserDefaultsKey.includeLogs)
        defaults.set(includeCrashLogs, forKey: UserDefaultsKey.includeCrashLogs)

        defaults.synchronize()
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

        NSLog("[LoginItem] Periodic status monitoring started (interval: 5s)")
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
                NSLog("[LoginItem] Skipping check - user changed setting %.1fs ago (< 10s grace period)", timeSinceChange)
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
            let defaults = UserDefaults.standard
            defaults.set(actualStatus, forKey: UserDefaultsKey.runOnStartup)
            defaults.set(actualStatus ? 1 : 0, forKey: UserDefaultsKey.runOnStartupLegacy)
            defaults.synchronize()

            NSLog("[LoginItem] ✅ UI synced to actual status: %@", actualStatus ? "ON" : "OFF")
        }
    }

    // MARK: - Setup Observers

    func setupObservers() {
        // Observer for runOnStartup
        $runOnStartup.sink { [weak self] value in
            guard let self = self, !self.isLoadingSettings, !self.isUpdatingRunOnStartup else {
                NSLog("[SystemState] runOnStartup observer skipped")
                return
            }

            NSLog("[SystemState] 🔄 runOnStartup observer triggered: value=%@", value ? "ON" : "OFF")

            // Record timestamp
            self.lastRunOnStartupChangeTime = Date()

            guard let appDelegate = self.getAppDelegate() else {
                NSLog("[SystemState] ❌ GetAppDelegateInstance() returned nil")
                return
            }

            NSLog("[SystemState] ✅ Calling AppDelegate.setRunOnStartup(%@)", value ? "YES" : "NO")
            appDelegate.setRunOnStartup(value)
        }.store(in: &cancellables)

        // Observer for showIconOnDock
        $showIconOnDock.sink { [weak self] value in
            guard let self = self, !self.isLoadingSettings else { return }
            let defaults = UserDefaults.standard
            defaults.set(value, forKey: UserDefaultsKey.showIconOnDock)
            NotificationCenter.default.post(
                name: NotificationName.phtvSettingsChanged, object: nil)
        }.store(in: &cancellables)

        // Observer for Claude Code patch
        $claudeCodePatchEnabled.sink { [weak self] value in
            guard let self = self, !self.isLoadingSettings else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                let patcher = ClaudeCodePatcher.shared
                let currentlyPatched = patcher.isPatched()

                if value && !currentlyPatched {
                    _ = patcher.applyPatch()
                } else if !value && currentlyPatched {
                    _ = patcher.removePatch()
                }
            }
        }.store(in: &cancellables)

        // Observer for system settings
        Publishers.MergeMany([
            $performLayoutCompat.map { _ in () }.eraseToAnyPublisher(),
            $safeMode.map { _ in () }.eraseToAnyPublisher()
        ])
        .debounce(for: .milliseconds(Timing.settingsDebounce), scheduler: RunLoop.main)
        .sink { [weak self] _ in
            guard let self = self, !self.isLoadingSettings else { return }
            self.saveSettings()
            NotificationCenter.default.post(
                name: NotificationName.phtvSettingsChanged, object: nil)
        }.store(in: &cancellables)

        // Update frequency observer
        $updateCheckFrequency.sink { [weak self] frequency in
            guard let self = self, !self.isLoadingSettings else { return }
            let defaults = UserDefaults.standard
            defaults.set(frequency.rawValue, forKey: UserDefaultsKey.updateCheckInterval)
            defaults.synchronize()

            NotificationCenter.default.post(
                name: NotificationName.updateCheckFrequencyChanged,
                object: NSNumber(value: frequency.rawValue)
            )
        }.store(in: &cancellables)

        // Beta channel observer
        $betaChannelEnabled.sink { [weak self] enabled in
            guard let self = self, !self.isLoadingSettings else { return }
            let defaults = UserDefaults.standard
            defaults.set(enabled, forKey: UserDefaultsKey.betaChannelEnabled)
            defaults.synchronize()

            NotificationCenter.default.post(
                name: NotificationName.betaChannelChanged,
                object: NSNumber(value: enabled)
            )
        }.store(in: &cancellables)

        // Auto install updates observer
        $autoInstallUpdates.sink { [weak self] enabled in
            guard let self = self, !self.isLoadingSettings else { return }
            let defaults = UserDefaults.standard
            defaults.set(enabled, forKey: UserDefaultsKey.autoInstallUpdates)
            defaults.synchronize()
        }.store(in: &cancellables)

        // Bug report settings observers
        Publishers.MergeMany([
            $includeSystemInfo.map { _ in () }.eraseToAnyPublisher(),
            $includeLogs.map { _ in () }.eraseToAnyPublisher(),
            $includeCrashLogs.map { _ in () }.eraseToAnyPublisher()
        ])
        .debounce(for: .milliseconds(Timing.settingsDebounce), scheduler: RunLoop.main)
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
               let enabled = userInfo["enabled"] as? Bool {
                Task { @MainActor in
                    self.isUpdatingRunOnStartup = true
                    self.runOnStartup = enabled
                    self.isUpdatingRunOnStartup = false
                    print("[SystemState] ✅ RunOnStartup synced from notification: \(enabled)")
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

        runOnStartup = false
        performLayoutCompat = false
        showIconOnDock = false
        safeMode = false
        settingsWindowAlwaysOnTop = false

        updateCheckFrequency = .daily
        betaChannelEnabled = false
        autoInstallUpdates = true

        includeSystemInfo = true
        includeLogs = false
        includeCrashLogs = true

        saveSettings()
    }
}
