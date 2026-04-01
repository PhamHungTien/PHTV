//
//  SystemState.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit
import ServiceManagement
import ApplicationServices
import Observation

enum PHTVTypingPermissionState: Equatable {
    case ready
    case waitingForEventTap
    case inputMonitoringRequired
    case accessibilityRequired

    static func resolve(
        accessibilityTrusted: Bool,
        inputMonitoringGranted: Bool = true,
        eventTapReady: Bool
    ) -> Self {
        guard accessibilityTrusted else {
            return .accessibilityRequired
        }
        guard inputMonitoringGranted else {
            return .inputMonitoringRequired
        }
        return eventTapReady ? .ready : .waitingForEventTap
    }

    var hasAccessibilityPermission: Bool {
        self != .accessibilityRequired
    }

    var isTypingPermissionReady: Bool {
        self == .ready
    }
}

/// Manages system settings, permissions, and updates
@MainActor
@Observable
final class SystemState {
    // System settings
    var runOnStartup: Bool = false {
        didSet {
            handleObservedChange(oldValue: oldValue, newValue: runOnStartup) {
                self.applyRunOnStartupChange(self.runOnStartup)
            }
        }
    }
    var performLayoutCompat: Bool = false {
        didSet { handleSystemSettingDidChange(oldValue: oldValue, newValue: performLayoutCompat) }
    }
    var showIconOnDock: Bool = false {
        didSet {
            handleObservedChange(oldValue: oldValue, newValue: showIconOnDock) {
                SettingsObserver.shared.suspendNotifications()
                let defaults = UserDefaults.standard
                defaults.set(self.showIconOnDock, forKey: UserDefaultsKey.showIconOnDock)
                NotificationCenter.default.post(
                    name: NotificationName.phtvSettingsChanged,
                    object: nil
                )
            }
        }
    }
    var settingsWindowAlwaysOnTop: Bool = false {
        didSet {
            handleObservedChange(oldValue: oldValue, newValue: settingsWindowAlwaysOnTop) {
                SettingsObserver.shared.suspendNotifications()
                let defaults = UserDefaults.standard
                defaults.set(self.settingsWindowAlwaysOnTop, forKey: UserDefaultsKey.settingsWindowAlwaysOnTop)
            }
        }
    }
    var safeMode: Bool = false {
        didSet { handleSystemSettingDidChange(oldValue: oldValue, newValue: safeMode) }
    }

    // Text Replacement Fix is always enabled (no user setting)
    var enableTextReplacementFix: Bool { return true }

    // Accessibility / typing readiness
    var hasAccessibilityPermission: Bool = false {
        didSet { notifyChangeIfNeeded(oldValue: oldValue, newValue: hasAccessibilityPermission) }
    }
    var hasInputMonitoringPermission: Bool = false {
        didSet { notifyChangeIfNeeded(oldValue: oldValue, newValue: hasInputMonitoringPermission) }
    }
    var isTypingPermissionReady: Bool = false {
        didSet { notifyChangeIfNeeded(oldValue: oldValue, newValue: isTypingPermissionReady) }
    }

    // Update notification - shown when new version is available on startup
    var updateAvailableMessage: String = "" {
        didSet { notifyChangeIfNeeded(oldValue: oldValue, newValue: updateAvailableMessage) }
    }
    var showUpdateBanner: Bool = false {
        didSet { notifyChangeIfNeeded(oldValue: oldValue, newValue: showUpdateBanner) }
    }
    var latestVersion: String = "" {
        didSet { notifyChangeIfNeeded(oldValue: oldValue, newValue: latestVersion) }
    }

    // Sparkle update configuration
    var updateCheckFrequency: UpdateCheckFrequency = .daily {
        didSet {
            handleObservedChange(oldValue: oldValue, newValue: updateCheckFrequency) {
                SettingsObserver.shared.suspendNotifications()
                let defaults = UserDefaults.standard
                defaults.set(self.updateCheckFrequency.rawValue, forKey: UserDefaultsKey.updateCheckInterval)
                NotificationCenter.default.post(
                    name: NotificationName.updateCheckFrequencyChanged,
                    object: NSNumber(value: self.updateCheckFrequency.rawValue)
                )
            }
        }
    }
    var showCustomUpdateBanner: Bool = false {
        didSet { notifyChangeIfNeeded(oldValue: oldValue, newValue: showCustomUpdateBanner) }
    }
    var customUpdateBannerInfo: UpdateBannerInfo? = nil {
        didSet { notifyChangeIfNeeded(oldValue: oldValue, newValue: customUpdateBannerInfo) }
    }

    // Bug report settings
    var includeSystemInfo: Bool = true {
        didSet { handleBugReportSettingDidChange(oldValue: oldValue, newValue: includeSystemInfo) }
    }
    var includeLogs: Bool = false {
        didSet { handleBugReportSettingDidChange(oldValue: oldValue, newValue: includeLogs) }
    }
    var includeCrashLogs: Bool = true {
        didSet { handleBugReportSettingDidChange(oldValue: oldValue, newValue: includeCrashLogs) }
    }

    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private var notificationObservers: [NSObjectProtocol] = []
    @ObservationIgnored var isLoadingSettings = false
    @ObservationIgnored private var isUpdatingRunOnStartup = false
    @ObservationIgnored private var loginItemActiveObserver: NSObjectProtocol?
    @ObservationIgnored private var systemSettingsNotificationTask: Task<Void, Never>?

    private func isRunOnStartupEffectivelyEnabled(_ status: SMAppService.Status) -> Bool {
        switch status {
        case .enabled, .requiresApproval:
            return true
        case .notRegistered, .notFound:
            return false
        @unknown default:
            return false
        }
    }

    // Helper to access AppDelegate safely on main actor
    @MainActor
    private func getAppDelegate() -> AppDelegate? {
        return AppDelegate.current()
    }

    init() {}

    @discardableResult
    private func notifyChangeIfNeeded<Value: Equatable>(oldValue: Value, newValue: Value) -> Bool {
        guard newValue != oldValue else { return false }
        onChange?()
        return true
    }

    private func handleObservedChange<Value: Equatable>(
        oldValue: Value,
        newValue: Value,
        action: (() -> Void)? = nil
    ) {
        guard notifyChangeIfNeeded(oldValue: oldValue, newValue: newValue) else { return }
        guard !isLoadingSettings else { return }
        action?()
    }

    private func handleSystemSettingDidChange<Value: Equatable>(oldValue: Value, newValue: Value) {
        handleObservedChange(oldValue: oldValue, newValue: newValue) {
            self.saveSettings()
            self.scheduleSystemSettingsNotification()
        }
    }

    private func handleBugReportSettingDidChange<Value: Equatable>(oldValue: Value, newValue: Value) {
        handleObservedChange(oldValue: oldValue, newValue: newValue) {
            self.saveSettings()
        }
    }

    private func scheduleSystemSettingsNotification() {
        systemSettingsNotificationTask?.cancel()
        systemSettingsNotificationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Timing.settingsDebounce) * 1_000_000)
            guard self != nil, !Task.isCancelled else { return }
            NotificationCenter.default.post(name: NotificationName.phtvSettingsChanged, object: nil)
        }
    }

    private func applyRunOnStartupChange(_ value: Bool) {
        guard !isUpdatingRunOnStartup else {
            NSLog("[SystemState] runOnStartup observer skipped")
            return
        }

        NSLog("[SystemState] 🔄 runOnStartup observer triggered: value=%@", value ? "ON" : "OFF")

        guard let appDelegate = getAppDelegate() else {
            NSLog("[SystemState] ⚠️ AppDelegate unavailable, applying runOnStartup fallback path")
            do {
                if value {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                let nsError = error as NSError
                NSLog(
                    "[SystemState] ❌ Fallback %@ failed: %@ (domain=%@ code=%ld)",
                    value ? "register" : "unregister",
                    nsError.localizedDescription,
                    nsError.domain,
                    nsError.code
                )
            }
            refreshRunOnStartupStatus(logContext: "observer-fallback")
            return
        }

        NSLog("[SystemState] ✅ Calling AppDelegate.setRunOnStartup(%@)", value ? "YES" : "NO")
        appDelegate.setRunOnStartup(value)
    }

    // MARK: - Load/Save Settings

    func loadSettings(shouldRefreshRunOnStartupStatus: Bool = true, logRunOnStartupStatus: Bool = true) {
        let defaults = UserDefaults.standard

        // Load system settings - use SMAppService status as source of truth.
        if shouldRefreshRunOnStartupStatus {
            refreshRunOnStartupStatus(
                logContext: logRunOnStartupStatus ? "load-settings" : nil
            )
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
        if defaults.requiresStableUpdateChannelEnforcement() {
            SettingsObserver.shared.suspendNotifications()
            defaults.enforceStableUpdateChannel()
        }

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

    func reloadFromDefaults(shouldRefreshRunOnStartupStatus: Bool = true, logRunOnStartupStatus: Bool = true) {
        loadSettings(
            shouldRefreshRunOnStartupStatus: shouldRefreshRunOnStartupStatus,
            logRunOnStartupStatus: logRunOnStartupStatus
        )
    }

    // MARK: - Accessibility

    func checkAccessibilityPermission() {
        Task { @MainActor in
            refreshPermissionState()
        }
    }

    private func refreshPermissionState(eventTapReady: Bool? = nil) {
        let axTrusted = AXIsProcessTrusted()
        let postEventGranted = PHTVPermissionService.hasPostEventAccess()
        let accessibilityTrusted = axTrusted && postEventGranted
        let inputMonitoringGranted = PHTVPermissionService.hasListenEventAccess()
        let liveEventTapReady = accessibilityTrusted && PHTVManager.isInited() && PHTVManager.isEventTapEnabled()
        let effectiveEventTapReady = eventTapReady.map { $0 || liveEventTapReady } ?? liveEventTapReady
        let resolvedState = PHTVTypingPermissionState.resolve(
            accessibilityTrusted: accessibilityTrusted,
            inputMonitoringGranted: inputMonitoringGranted,
            eventTapReady: effectiveEventTapReady
        )
        if hasAccessibilityPermission != resolvedState.hasAccessibilityPermission {
            hasAccessibilityPermission = resolvedState.hasAccessibilityPermission
        }
        if hasInputMonitoringPermission != inputMonitoringGranted {
            hasInputMonitoringPermission = inputMonitoringGranted
        }
        if isTypingPermissionReady != resolvedState.isTypingPermissionReady {
            isTypingPermissionReady = resolvedState.isTypingPermissionReady
        }
    }

    // MARK: - Login Item Monitoring

    /// Start lightweight login-item status refresh while Settings is visible.
    func startLoginItemStatusMonitoring() {
        guard loginItemActiveObserver == nil else { return }

        loginItemActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshRunOnStartupStatus(logContext: "didBecomeActive")
            }
        }

        refreshRunOnStartupStatus(logContext: "settings-open")
        NSLog("[LoginItem] Status refresh monitoring started (active-app observer)")
    }

    /// Stop login-item status refresh observer.
    func stopLoginItemStatusMonitoring() {
        if let observer = loginItemActiveObserver {
            NotificationCenter.default.removeObserver(observer)
            loginItemActiveObserver = nil
            NSLog("[LoginItem] Status refresh monitoring stopped")
        }
    }

    private func refreshRunOnStartupStatus(logContext: String?) {
        let status = SMAppService.mainApp.status
        let isEnabled = isRunOnStartupEffectivelyEnabled(status)

        if runOnStartup != isEnabled {
            isUpdatingRunOnStartup = true
            runOnStartup = isEnabled
            isUpdatingRunOnStartup = false

            SettingsObserver.shared.suspendNotifications()
            let defaults = UserDefaults.standard
            defaults.set(isEnabled, forKey: UserDefaultsKey.runOnStartup)
            defaults.set(isEnabled ? 1 : 0, forKey: UserDefaultsKey.runOnStartupLegacy)
        }

        guard let logContext else {
            return
        }

        switch status {
        case .enabled:
            NSLog("[LoginItem] ✅ %@: enabled", logContext)
        case .notRegistered:
            NSLog("[LoginItem] ℹ️ %@: not registered", logContext)
        case .requiresApproval:
            NSLog("[LoginItem] ⚠️ %@: requires user approval in System Settings > Login Items", logContext)
        case .notFound:
            NSLog("[LoginItem] ⚠️ %@: login item not found; try toggling off/on", logContext)
        @unknown default:
            NSLog("[LoginItem] ⚠️ %@: unknown SMAppService status=%ld", logContext, status.rawValue)
        }
    }

    // MARK: - Setup Observers

    func setupObservers() {
        // Observation-based state now handles side effects in property observers.
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
                    self.refreshPermissionState(eventTapReady: isEnabled.boolValue)
                }
            }
        }
        notificationObservers.append(observer1)

        // React immediately to macOS TCC accessibility changes without depending on
        // the PHTVTCCNotificationService chain. This is the Apple-recommended approach
        // for detecting accessibility permission grants in real time.
        let accessibilityObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.accessibility.api"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                // Short settle delay: TCC database write propagates asynchronously.
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
                self.refreshPermissionState()
                let axTrusted = AXIsProcessTrusted()
                let postEventGranted = PHTVPermissionService.hasPostEventAccess()
                NSLog(
                    "[SystemState] AX TCC notification → AX=%@, PostEvent=%@, InputMonitoring=%@, eventTapReady=%@",
                    axTrusted ? "YES" : "NO",
                    postEventGranted ? "YES" : "NO",
                    self.hasInputMonitoringPermission ? "YES" : "NO",
                    self.isTypingPermissionReady ? "YES" : "NO"
                )
            }
        }
        notificationObservers.append(accessibilityObserver)

        let tccObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.TCC.access.changed"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
                self.refreshPermissionState()
                let axTrusted = AXIsProcessTrusted()
                let postEventGranted = PHTVPermissionService.hasPostEventAccess()
                NSLog(
                    "[SystemState] Generic TCC notification → AX=%@, PostEvent=%@, InputMonitoring=%@, eventTapReady=%@",
                    axTrusted ? "YES" : "NO",
                    postEventGranted ? "YES" : "NO",
                    self.hasInputMonitoringPermission ? "YES" : "NO",
                    self.isTypingPermissionReady ? "YES" : "NO"
                )
            }
        }
        notificationObservers.append(tccObserver)

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
        systemSettingsNotificationTask?.cancel()
        systemSettingsNotificationTask = nil

        notificationObservers.forEach { observer in
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()

        if let observer = loginItemActiveObserver {
            NotificationCenter.default.removeObserver(observer)
            loginItemActiveObserver = nil
        }
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
