//
//  AppState.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import AppKit
import Observation
import ServiceManagement

/// Main application state coordinator that manages all sub-states
@MainActor
@Observable
final class AppState {
    static let shared = AppState()

    // MARK: - Sub-States (ViewModels)

    /// Input method and Vietnamese typing features
    @ObservationIgnored var inputMethodState = InputMethodState()

    /// Macro and emoji hotkey settings
    @ObservationIgnored var macroState = MacroState()

    /// Clipboard history settings
    @ObservationIgnored var clipboardHistoryState = ClipboardHistoryState()

    /// System settings, permissions, and updates
    @ObservationIgnored var systemState = SystemState()

    /// UI settings, hotkeys, and display preferences
    @ObservationIgnored var uiState = UIState()

    /// Excluded apps and send key step by step apps
    @ObservationIgnored var appListsState = AppListsState()

    // MARK: - Global State

    /// Global language toggle (Vietnamese/English)
    var isEnabled: Bool = true {
        didSet {
            guard isEnabled != oldValue, !isLoadingSettings else { return }
            let defaults = UserDefaults.standard
            let language = isEnabled ? 1 : 0
            defaults.set(language, forKey: UserDefaultsKey.inputMethod)

            if uiState.beepOnModeSwitch && uiState.beepVolume > 0.0 {
                BeepManager.shared.play(volume: uiState.beepVolume)
            }

            NotificationCenter.default.post(
                name: NotificationName.languageChangedFromSwiftUI,
                object: NSNumber(value: language)
            )
        }
    }

    // MARK: - Private State

    @ObservationIgnored private var notificationTasks: [Task<Void, Never>] = []
    @ObservationIgnored private var externalSettingsObservationTask: Task<Void, Never>?
    @ObservationIgnored private var isLoadingSettings = false
    @ObservationIgnored private var isSubstateInvalidationScheduled = false
    private var substateObservationTick = 0

    private static var liveDebugEnabled: Bool {
        let env = ProcessInfo.processInfo.environment["PHTV_LIVE_DEBUG"]
        if let env, !env.isEmpty {
            return env != "0"
        }
        return UserDefaults.standard.integer(forKey: UserDefaultsKey.liveDebug, default: 0) != 0
    }

    private func liveLog(_ message: String) {
        guard Self.liveDebugEnabled else { return }
        NSLog("[PHTV Live] %@", message)
    }

    func trackedSubstate<Value>(_ value: Value) -> Value {
        _ = substateObservationTick
        return value
    }

    private func scheduleSubstateObservationInvalidation() {
        guard !isSubstateInvalidationScheduled else { return }
        isSubstateInvalidationScheduled = true
        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self = self else { return }
            self.isSubstateInvalidationScheduled = false
            self.substateObservationTick &+= 1
        }
    }

    // MARK: - Initialization

    private init() {
        SettingsBootstrap.registerDefaults()
#if DEBUG
        DebugSelfTests.runOnce()
#endif
        isLoadingSettings = true
        loadSettings()
        isLoadingSettings = false
        PHTVLogger.shared.debug("AppState init complete")

        // Delay observer setup to avoid crashes during initialization
        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self = self else { return }
            self.setupObservers()
            self.setupNotificationObservers()
            self.setupExternalSettingsObserver()
            self.systemState.checkAccessibilityPermission()
        }
    }

    // MARK: - Load/Save Settings

    func loadSettings() {
        loadSettings(logSystemSettings: true)
    }

    private func loadSettings(logSystemSettings: Bool) {
        let defaults = UserDefaults.standard

        // Load global isEnabled state
        let inputMethodSaved = defaults.integer(forKey: UserDefaultsKey.inputMethod, default: 1)
        isEnabled = (inputMethodSaved == 1)

        // Load all sub-states
        inputMethodState.isLoadingSettings = true
        macroState.isLoadingSettings = true
        clipboardHistoryState.isLoadingSettings = true
        systemState.isLoadingSettings = true
        uiState.isLoadingSettings = true
        appListsState.isLoadingSettings = true

        inputMethodState.loadSettings()
        macroState.loadSettings()
        clipboardHistoryState.loadSettings()
        systemState.loadSettings(
            shouldRefreshRunOnStartupStatus: true,
            logRunOnStartupStatus: logSystemSettings
        )
        uiState.loadSettings()
        appListsState.loadSettings()

        inputMethodState.isLoadingSettings = false
        macroState.isLoadingSettings = false
        clipboardHistoryState.isLoadingSettings = false
        systemState.isLoadingSettings = false
        uiState.isLoadingSettings = false
        appListsState.isLoadingSettings = false
    }

    private func persistAllSettings(notifyBackend: Bool) {
        SettingsObserver.shared.suspendNotifications()

        let defaults = UserDefaults.standard
        let language = isEnabled ? 1 : 0
        defaults.set(language, forKey: UserDefaultsKey.inputMethod)

        inputMethodState.saveSettings()
        macroState.saveSettings()
        clipboardHistoryState.saveSettings()
        systemState.saveSettings()
        uiState.saveSettings()
        appListsState.saveSettings()

        if notifyBackend {
            liveLog("posting PHTVSettingsChanged")
            NotificationCenter.default.post(
                name: NotificationName.phtvSettingsChanged,
                object: nil
            )
        }
    }

    /// Bridges legacy runtime refresh requests into the SwiftUI state tree.
    func refreshFromRuntime() {
        liveLog("refreshing AppState from runtime")
        reloadSettingsFromDefaults(logSystemSettings: false)
        systemState.checkAccessibilityPermission()
    }

    func saveSettings() {
        persistAllSettings(notifyBackend: true)
    }

    private func synchronizePreferences(logContext: String) {
        let synchronized = CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)
        if !synchronized {
            NSLog("[AppState] Failed to synchronize preferences during %@", logContext)
        }
    }

    func flushPendingSettingsForWindowClose() {
        persistAllSettings(notifyBackend: true)
        synchronizePreferences(logContext: "settings-window close flush")
    }

    func flushPendingSettingsForTermination() {
        persistAllSettings(notifyBackend: false)
        synchronizePreferences(logContext: "termination flush")
    }

    // MARK: - External Settings Observer

    /// Monitor external UserDefaults changes and reload settings in real-time
    private func setupExternalSettingsObserver() {
        externalSettingsObservationTask?.cancel()
        externalSettingsObservationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await _ in NotificationCenter.default.notifications(named: NotificationName.settingsObserverDidChange) {
                guard !Task.isCancelled else { break }
                self.reloadSettingsFromDefaults(logSystemSettings: false)
            }
        }
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

    private func applyLanguageChange(from notification: Notification, playBeep: Bool) {
        guard let language = notification.object as? NSNumber else { return }

        isLoadingSettings = true
        isEnabled = language.intValue == 1
        isLoadingSettings = false

        if playBeep && uiState.beepOnModeSwitch && uiState.beepVolume > 0.0 {
            BeepManager.shared.play(volume: uiState.beepVolume)
        }
    }

    /// Reload only settings that may have changed externally
    private func reloadSettingsFromDefaults() {
        reloadSettingsFromDefaults(logSystemSettings: true)
    }

    private func reloadSettingsFromDefaults(logSystemSettings: Bool) {
        isLoadingSettings = true

        // Reload sub-states
        inputMethodState.isLoadingSettings = true
        macroState.isLoadingSettings = true
        clipboardHistoryState.isLoadingSettings = true
        systemState.isLoadingSettings = true
        uiState.isLoadingSettings = true
        appListsState.isLoadingSettings = true

        // Reload global isEnabled state
        let defaults = UserDefaults.standard
        let inputMethodSaved = defaults.integer(forKey: UserDefaultsKey.inputMethod, default: 1)
        let newIsEnabled = (inputMethodSaved == 1)
        if newIsEnabled != isEnabled {
            isEnabled = newIsEnabled
        }

        // Reload each sub-state
        inputMethodState.reloadFromDefaults()
        macroState.reloadFromDefaults()
        clipboardHistoryState.reloadFromDefaults()
        systemState.reloadFromDefaults(
            shouldRefreshRunOnStartupStatus: logSystemSettings,
            logRunOnStartupStatus: logSystemSettings
        )
        uiState.reloadFromDefaults()
        appListsState.reloadFromDefaults()

        inputMethodState.isLoadingSettings = false
        macroState.isLoadingSettings = false
        clipboardHistoryState.isLoadingSettings = false
        systemState.isLoadingSettings = false
        uiState.isLoadingSettings = false
        appListsState.isLoadingSettings = false
        isLoadingSettings = false
    }

    // MARK: - Notification Observers

    private func setupNotificationObservers() {
        // Delegate notification observers to SystemState
        systemState.setupNotificationObservers()
        notificationTasks.forEach { $0.cancel() }

        notificationTasks = [
            makeNotificationTask(name: NotificationName.languageChangedFromBackend) { [weak self] notification in
                self?.applyLanguageChange(from: notification, playBeep: true)
            },
            makeNotificationTask(name: NotificationName.languageChangedFromExcludedApp) { [weak self] notification in
                self?.applyLanguageChange(from: notification, playBeep: false)
            },
            makeNotificationTask(name: NotificationName.languageChangedFromSmartSwitch) { [weak self] notification in
                self?.applyLanguageChange(from: notification, playBeep: false)
            },
            makeNotificationTask(name: NotificationName.languageChangedFromObjC) { [weak self] notification in
                self?.applyLanguageChange(from: notification, playBeep: false)
            },
            makeNotificationTask(name: NotificationName.applicationWillTerminate) { [weak self] _ in
                self?.cleanupObservers()
            }
        ]
    }

    /// Cleanup notification observers (call on app termination)
    @objc func cleanupObservers() {
        externalSettingsObservationTask?.cancel()
        externalSettingsObservationTask = nil

        notificationTasks.forEach { $0.cancel() }
        notificationTasks.removeAll()

        systemState.cleanupObservers()
    }

    // MARK: - Setup Observers

    private func setupObservers() {
        // Setup observers for all sub-states
        inputMethodState.setupObservers()
        macroState.setupObservers()
        clipboardHistoryState.setupObservers()
        systemState.setupObservers()
        uiState.setupObservers()
        inputMethodState.onChange = { [weak self] in self?.scheduleSubstateObservationInvalidation() }
        macroState.onChange = { [weak self] in self?.scheduleSubstateObservationInvalidation() }
        clipboardHistoryState.onChange = { [weak self] in self?.scheduleSubstateObservationInvalidation() }
        systemState.onChange = { [weak self] in self?.scheduleSubstateObservationInvalidation() }
        uiState.onChange = { [weak self] in self?.scheduleSubstateObservationInvalidation() }
        appListsState.onChange = { [weak self] in self?.scheduleSubstateObservationInvalidation() }
    }

    // MARK: - Reset to Defaults

    func resetToDefaults() {
        isLoadingSettings = true
        defer { isLoadingSettings = false }

        // Reset global state
        isEnabled = true

        // Reset all sub-states
        inputMethodState.resetToDefaults()
        macroState.resetToDefaults()
        clipboardHistoryState.resetToDefaults()
        systemState.resetToDefaults()
        uiState.resetToDefaults()
        appListsState.resetToDefaults()

        // Notify backend about reset
        NotificationCenter.default.post(
            name: NotificationName.settingsResetToDefaults,
            object: nil
        )
    }

}
