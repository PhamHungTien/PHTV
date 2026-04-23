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
    case accessibilityRequired

    static func resolve(snapshot: PHTVTypingRuntimeHealthSnapshot) -> Self {
        switch snapshot.phase {
        case .accessibilityRequired:
            return .accessibilityRequired
        case .waitingForEventTap, .relaunchPending:
            return .waitingForEventTap
        case .ready:
            return .ready
        }
    }

    static func resolve(
        accessibilityTrusted: Bool,
        eventTapReady: Bool
    ) -> Self {
        resolve(
            snapshot: PHTVTypingRuntimeHealthSnapshot.resolve(
                axTrusted: accessibilityTrusted,
                eventTapReady: eventTapReady,
                relaunchPending: false,
                safeModeEnabled: false,
                activeAppProfile: .generic
            )
        )
    }

    var hasAccessibilityPermission: Bool {
        self != .accessibilityRequired
    }

    var isTypingPermissionReady: Bool {
        self == .ready
    }
}

enum PHTVPermissionGuidanceStep: Equatable {
    case ready
    case accessibility
    case waitingForEventTap

    static func resolve(snapshot: PHTVTypingRuntimeHealthSnapshot) -> Self {
        switch snapshot.phase {
        case .accessibilityRequired:
            return .accessibility
        case .waitingForEventTap, .relaunchPending:
            return .waitingForEventTap
        case .ready:
            return .ready
        }
    }

    static func resolve(
        accessibilityTrusted: Bool,
        eventTapReady: Bool
    ) -> Self {
        resolve(
            snapshot: PHTVTypingRuntimeHealthSnapshot.resolve(
                axTrusted: accessibilityTrusted,
                eventTapReady: eventTapReady,
                relaunchPending: false,
                safeModeEnabled: false,
                activeAppProfile: .generic
            )
        )
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
    var isTypingPermissionReady: Bool = false {
        didSet { notifyChangeIfNeeded(oldValue: oldValue, newValue: isTypingPermissionReady) }
    }
    var typingRuntimeHealth = PHTVTypingRuntimeHealthSnapshot.resolve(
        axTrusted: false,
        eventTapReady: false,
        relaunchPending: false,
        safeModeEnabled: false,
        activeAppProfile: .generic
    ) {
        didSet {
            guard typingRuntimeHealth != oldValue else { return }
            let resolvedState = typingRuntimeHealth.permissionState
            if hasAccessibilityPermission != resolvedState.hasAccessibilityPermission {
                hasAccessibilityPermission = resolvedState.hasAccessibilityPermission
            }
            if isTypingPermissionReady != resolvedState.isTypingPermissionReady {
                isTypingPermissionReady = resolvedState.isTypingPermissionReady
            }
            onChange?()
        }
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
    @ObservationIgnored private var notificationTasks: [Task<Void, Never>] = []
    @ObservationIgnored var isLoadingSettings = false
    @ObservationIgnored private var isUpdatingRunOnStartup = false
    @ObservationIgnored private var loginItemActiveTask: Task<Void, Never>?
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

    private func makeNotificationTask(
        center: NotificationCenter = .default,
        name: Notification.Name,
        handler: @escaping @MainActor (Notification) async -> Void
    ) -> Task<Void, Never> {
        Task { @MainActor in
            for await notification in center.notifications(named: name) {
                guard !Task.isCancelled else { break }
                await handler(notification)
            }
        }
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
            try? await Task.sleep(for: .milliseconds(Int64(Timing.settingsDebounce)))
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

    @discardableResult
    func checkAccessibilityPermission() -> PHTVTypingPermissionState {
        refreshPermissionState()
    }

    @discardableResult
    private func refreshPermissionState(eventTapReady: Bool? = nil) -> PHTVTypingPermissionState {
        let snapshot = makeTypingRuntimeHealthSnapshot(eventTapReady: eventTapReady)
        if typingRuntimeHealth != snapshot {
            typingRuntimeHealth = snapshot
        }
        return snapshot.permissionState
    }

    private func makeTypingRuntimeHealthSnapshot(
        eventTapReady: Bool? = nil,
        frontmostBundleId: String? = nil,
        relaunchPending: Bool? = nil
    ) -> PHTVTypingRuntimeHealthSnapshot {
        let accessibilityTrusted = AXIsProcessTrusted()
        let liveEventTapReady = accessibilityTrusted && PHTVManager.isInited() && PHTVManager.isEventTapEnabled()
        let effectiveEventTapReady = eventTapReady.map { $0 || liveEventTapReady } ?? liveEventTapReady
        let activeBundleId = frontmostBundleId ?? PHTVAppContextService.currentFrontmostBundleId()
        let profile = PHTVCompatibilityProfileResolver.resolve(forBundleId: activeBundleId)
        let isRelaunchPending = relaunchPending ?? AppDelegate.current()?.isRelaunchingAfterPermissionGrant ?? false

        return PHTVTypingRuntimeStateMachine.snapshot(
            axTrusted: accessibilityTrusted,
            eventTapReady: effectiveEventTapReady,
            relaunchPending: isRelaunchPending,
            safeModeEnabled: safeMode,
            activeAppProfile: profile.kind,
            activeBundleId: activeBundleId
        )
    }

    // MARK: - Login Item Monitoring

    /// Start lightweight login-item status refresh while Settings is visible.
    func startLoginItemStatusMonitoring() {
        guard loginItemActiveTask == nil else { return }

        loginItemActiveTask = makeNotificationTask(name: NSApplication.didBecomeActiveNotification) { [weak self] _ in
            self?.refreshRunOnStartupStatus(logContext: "didBecomeActive")
        }

        refreshRunOnStartupStatus(logContext: "settings-open")
        NSLog("[LoginItem] Status refresh monitoring started (active-app task)")
    }

    /// Stop login-item status refresh observer.
    func stopLoginItemStatusMonitoring() {
        if let task = loginItemActiveTask {
            task.cancel()
            loginItemActiveTask = nil
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
        notificationTasks.forEach { $0.cancel() }

        notificationTasks = [
            makeNotificationTask(name: NotificationName.typingRuntimeHealthChanged) { [weak self] notification in
                guard let self,
                      let snapshot = notification.object as? PHTVTypingRuntimeHealthSnapshot else { return }
                if self.typingRuntimeHealth != snapshot {
                    self.typingRuntimeHealth = snapshot
                }
            },
            makeNotificationTask(name: NotificationName.accessibilityStatusChanged) { [weak self] notification in
                guard let self,
                      let isEnabled = notification.object as? NSNumber else { return }
                self.refreshPermissionState(eventTapReady: isEnabled.boolValue)
            },
            makeNotificationTask(
                center: DistributedNotificationCenter.default(),
                name: Notification.Name("com.apple.accessibility.api")
            ) { [weak self] _ in
                guard let self else { return }

                // Short settle delay: TCC database write propagates asynchronously.
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }

                self.refreshPermissionState()
                let axTrusted = AXIsProcessTrusted()
                NSLog(
                    "[SystemState] AX TCC notification → AX=%@, eventTapReady=%@",
                    axTrusted ? "YES" : "NO",
                    self.isTypingPermissionReady ? "YES" : "NO"
                )
            },
            makeNotificationTask(
                center: DistributedNotificationCenter.default(),
                name: Notification.Name("com.apple.TCC.access.changed")
            ) { [weak self] _ in
                guard let self else { return }

                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }

                self.refreshPermissionState()
                let axTrusted = AXIsProcessTrusted()
                NSLog(
                    "[SystemState] Generic TCC notification → AX=%@, eventTapReady=%@",
                    axTrusted ? "YES" : "NO",
                    self.isTypingPermissionReady ? "YES" : "NO"
                )
            },
            makeNotificationTask(name: NotificationName.checkForUpdatesResponse) { [weak self] notification in
                guard let self,
                      let response = notification.object as? [String: Any] else { return }

                let updateAvailable = (response["updateAvailable"] as? Bool) ?? false
                let message = response["message"] as? String ?? ""
                let latestVersion = response["latestVersion"] as? String ?? ""

                guard updateAvailable, !message.isEmpty, !latestVersion.isEmpty else { return }
                self.updateAvailableMessage = message
                self.latestVersion = latestVersion
                self.showUpdateBanner = true
            },
            makeNotificationTask(name: NotificationName.sparkleShowUpdateBanner) { [weak self] notification in
                guard let self,
                      let info = notification.object as? [String: String] else { return }

                let updateInfo = UpdateBannerInfo(
                    version: info["version"] ?? "",
                    releaseNotes: info["releaseNotes"] ?? "",
                    downloadURL: info["downloadURL"] ?? ""
                )
                self.customUpdateBannerInfo = updateInfo
                self.showCustomUpdateBanner = true
                NSLog("[SystemState] Showing update banner for version %@", updateInfo.version)
            },
            makeNotificationTask(name: NotificationName.runOnStartupChanged) { [weak self] notification in
                guard let self,
                      let userInfo = notification.userInfo,
                      let enabled = userInfo[NotificationUserInfoKey.enabled] as? Bool else { return }

                self.isUpdatingRunOnStartup = true
                self.runOnStartup = enabled
                self.isUpdatingRunOnStartup = false
                PHTVLogger.shared.info("[SystemState] RunOnStartup synced from notification: \(enabled)")
            },
            makeNotificationTask(name: NotificationName.applicationWillTerminate) { [weak self] _ in
                self?.cleanupObservers()
            }
        ]
    }

    func cleanupObservers() {
        systemSettingsNotificationTask?.cancel()
        systemSettingsNotificationTask = nil

        notificationTasks.forEach { $0.cancel() }
        notificationTasks.removeAll()

        loginItemActiveTask?.cancel()
        loginItemActiveTask = nil
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
