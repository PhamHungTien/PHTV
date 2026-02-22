//
//  AppState.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import AppKit
import Combine
import ServiceManagement

/// Main application state coordinator that manages all sub-states
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    // MARK: - Sub-States (ViewModels)

    /// Input method and Vietnamese typing features
    @Published var inputMethodState = InputMethodState()

    /// Macro and emoji hotkey settings
    @Published var macroState = MacroState()

    /// System settings, permissions, and updates
    @Published var systemState = SystemState()

    /// UI settings, hotkeys, and display preferences
    @Published var uiState = UIState()

    /// Excluded apps and send key step by step apps
    @Published var appListsState = AppListsState()

    // MARK: - Global State

    /// Global language toggle (Vietnamese/English)
    @Published var isEnabled: Bool = true

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()
    private var notificationObservers: [NSObjectProtocol] = []
    private var isLoadingSettings = false

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
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.setupObservers()
            self.setupNotificationObservers()
            self.setupExternalSettingsObserver()
            self.systemState.checkAccessibilityPermission()
        }
    }

    // MARK: - Load/Save Settings

    func loadSettings() {
        let defaults = UserDefaults.standard

        // Load global isEnabled state
        let inputMethodSaved = defaults.integer(forKey: UserDefaultsKey.inputMethod, default: 1)
        isEnabled = (inputMethodSaved == 1)

        // Load all sub-states
        inputMethodState.isLoadingSettings = true
        macroState.isLoadingSettings = true
        systemState.isLoadingSettings = true
        uiState.isLoadingSettings = true
        appListsState.isLoadingSettings = true

        inputMethodState.loadSettings()
        macroState.loadSettings()
        systemState.loadSettings()
        uiState.loadSettings()
        appListsState.loadSettings()

        inputMethodState.isLoadingSettings = false
        macroState.isLoadingSettings = false
        systemState.isLoadingSettings = false
        uiState.isLoadingSettings = false
        appListsState.isLoadingSettings = false
    }

    func saveSettings() {
        SettingsObserver.shared.suspendNotifications()

        // Save all sub-states
        inputMethodState.saveSettings()
        macroState.saveSettings()
        systemState.saveSettings()
        uiState.saveSettings()
        appListsState.saveSettings()


        // Notify Objective-C backend
        liveLog("posting PHTVSettingsChanged")
        NotificationCenter.default.post(
            name: NotificationName.phtvSettingsChanged, object: nil)
    }

    // MARK: - External Settings Observer

    /// Monitor external UserDefaults changes and reload settings in real-time
    private func setupExternalSettingsObserver() {
        SettingsObserver.shared.$settingsDidChange
            .debounce(for: .seconds(Timing.externalSettingsDebounce), scheduler: DispatchQueue.main)
            .sink { [weak self] (_: Date?) in
                guard let self = self else { return }
                self.reloadSettingsFromDefaults()
            }
            .store(in: &cancellables)
    }

    /// Reload only settings that may have changed externally
    private func reloadSettingsFromDefaults() {
        isLoadingSettings = true

        // Reload sub-states
        inputMethodState.isLoadingSettings = true
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
        appListsState.reloadFromDefaults()

        inputMethodState.isLoadingSettings = false
        uiState.isLoadingSettings = false
        appListsState.isLoadingSettings = false
        isLoadingSettings = false
    }

    // MARK: - Notification Observers

    private func setupNotificationObservers() {
        // Delegate notification observers to SystemState
        systemState.setupNotificationObservers()

        // Listen for language changes from manual actions (hotkey, UI, input type change)
        let observer1 = NotificationCenter.default.addObserver(
            forName: NotificationName.languageChangedFromBackend,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let language = notification.object as? NSNumber {
                Task { @MainActor in
                    self.isLoadingSettings = true
                    self.isEnabled = language.intValue == 1
                    self.isLoadingSettings = false

                    // Play beep for manual mode changes (if enabled)
                    if self.uiState.beepOnModeSwitch && self.uiState.beepVolume > 0.0 {
                        BeepManager.shared.play(volume: self.uiState.beepVolume)
                    }
                }
            }
        }
        notificationObservers.append(observer1)

        // Listen for language changes from excluded apps (no beep sound)
        let observer2 = NotificationCenter.default.addObserver(
            forName: NotificationName.languageChangedFromExcludedApp,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let language = notification.object as? NSNumber {
                Task { @MainActor in
                    self.isLoadingSettings = true
                    self.isEnabled = language.intValue == 1
                    self.isLoadingSettings = false
                }
            }
        }
        notificationObservers.append(observer2)

        // Listen for language changes from smart switch (no beep sound)
        let observer3 = NotificationCenter.default.addObserver(
            forName: NotificationName.languageChangedFromSmartSwitch,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let language = notification.object as? NSNumber {
                Task { @MainActor in
                    self.isLoadingSettings = true
                    self.isEnabled = language.intValue == 1
                    self.isLoadingSettings = false
                }
            }
        }
        notificationObservers.append(observer3)

        // Listen for language changes from input source switch (no beep sound)
        let observer4 = NotificationCenter.default.addObserver(
            forName: NotificationName.languageChangedFromObjC,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let language = notification.object as? NSNumber {
                Task { @MainActor in
                    self.isLoadingSettings = true
                    self.isEnabled = language.intValue == 1
                    self.isLoadingSettings = false
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

    /// Cleanup notification observers (call on app termination)
    @objc func cleanupObservers() {
        notificationObservers.forEach { observer in
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()

        systemState.cleanupObservers()
    }

    // MARK: - Setup Observers

    private func setupObservers() {
        // Setup observers for all sub-states
        inputMethodState.setupObservers()
        macroState.setupObservers()
        systemState.setupObservers()
        uiState.setupObservers()

        // Propagate sub-state changes to AppState
        // This ensures Views observing AppState are updated when a sub-state changes
        inputMethodState.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        macroState.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        systemState.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        uiState.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        appListsState.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        // Observer for global isEnabled (language toggle)
        $isEnabled
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] value in
            guard let self = self, !self.isLoadingSettings else { return }
            let defaults = UserDefaults.standard
            let language = value ? 1 : 0
            defaults.set(language, forKey: UserDefaultsKey.inputMethod)

            // Play beep if enabled (volume adjusted)
            if self.uiState.beepOnModeSwitch && self.uiState.beepVolume > 0.0 {
                BeepManager.shared.play(volume: self.uiState.beepVolume)
            }

            // Notify backend about language change from SwiftUI
            NotificationCenter.default.post(
                name: NotificationName.languageChangedFromSwiftUI,
                object: NSNumber(value: language))
        }.store(in: &cancellables)
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
