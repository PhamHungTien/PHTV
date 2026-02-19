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
        $isEnabled.sink { [weak self] value in
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

    // MARK: - Convenience Properties (Backward Compatibility)

    // These properties provide backward compatibility for Views that haven't been updated yet
    var inputMethod: InputMethod {
        get { inputMethodState.inputMethod }
        set { inputMethodState.inputMethod = newValue }
    }

    var codeTable: CodeTable {
        get { inputMethodState.codeTable }
        set { inputMethodState.codeTable = newValue }
    }

    var checkSpelling: Bool {
        get { inputMethodState.checkSpelling }
        set { inputMethodState.checkSpelling = newValue }
    }

    var useModernOrthography: Bool {
        get { inputMethodState.useModernOrthography }
        set { inputMethodState.useModernOrthography = newValue }
    }

    var quickTelex: Bool {
        get { inputMethodState.quickTelex }
        set { inputMethodState.quickTelex = newValue }
    }


    var sendKeyStepByStep: Bool {
        get { inputMethodState.sendKeyStepByStep }
        set { inputMethodState.sendKeyStepByStep = newValue }
    }

    var useSmartSwitchKey: Bool {
        get { inputMethodState.useSmartSwitchKey }
        set { inputMethodState.useSmartSwitchKey = newValue }
    }

    var upperCaseFirstChar: Bool {
        get { inputMethodState.upperCaseFirstChar }
        set { inputMethodState.upperCaseFirstChar = newValue }
    }

    var allowConsonantZFWJ: Bool {
        get { inputMethodState.allowConsonantZFWJ }
        set { inputMethodState.allowConsonantZFWJ = newValue }
    }

    var quickStartConsonant: Bool {
        get { inputMethodState.quickStartConsonant }
        set { inputMethodState.quickStartConsonant = newValue }
    }

    var quickEndConsonant: Bool {
        get { inputMethodState.quickEndConsonant }
        set { inputMethodState.quickEndConsonant = newValue }
    }

    var rememberCode: Bool {
        get { inputMethodState.rememberCode }
        set { inputMethodState.rememberCode = newValue }
    }

    var autoRestoreEnglishWord: Bool {
        get { inputMethodState.autoRestoreEnglishWord }
        set { inputMethodState.autoRestoreEnglishWord = newValue }
    }

    var restoreOnEscape: Bool {
        get { inputMethodState.restoreOnEscape }
        set { inputMethodState.restoreOnEscape = newValue }
    }

    var restoreKey: RestoreKey {
        get { inputMethodState.restoreKey }
        set { inputMethodState.restoreKey = newValue }
    }

    var pauseKeyEnabled: Bool {
        get { inputMethodState.pauseKeyEnabled }
        set { inputMethodState.pauseKeyEnabled = newValue }
    }

    var pauseKey: UInt16 {
        get { inputMethodState.pauseKey }
        set { inputMethodState.pauseKey = newValue }
    }

    var pauseKeyName: String {
        get { inputMethodState.pauseKeyName }
        set { inputMethodState.pauseKeyName = newValue }
    }

    // Macro state properties
    var useMacro: Bool {
        get { macroState.useMacro }
        set { macroState.useMacro = newValue }
    }

    var useMacroInEnglishMode: Bool {
        get { macroState.useMacroInEnglishMode }
        set { macroState.useMacroInEnglishMode = newValue }
    }

    var autoCapsMacro: Bool {
        get { macroState.autoCapsMacro }
        set { macroState.autoCapsMacro = newValue }
    }

    var macroCategories: [MacroCategory] {
        get { macroState.macroCategories }
        set { macroState.macroCategories = newValue }
    }

    var enableEmojiHotkey: Bool {
        get { macroState.enableEmojiHotkey }
        set { macroState.enableEmojiHotkey = newValue }
    }

    var emojiHotkeyModifiersRaw: Int {
        get { macroState.emojiHotkeyModifiersRaw }
        set { macroState.emojiHotkeyModifiersRaw = newValue }
    }

    var emojiHotkeyKeyCode: UInt16 {
        get { macroState.emojiHotkeyKeyCode }
        set { macroState.emojiHotkeyKeyCode = newValue }
    }

    var emojiHotkeyModifiers: NSEvent.ModifierFlags {
        get { macroState.emojiHotkeyModifiers }
        set { macroState.emojiHotkeyModifiers = newValue }
    }

    // System state properties
    var runOnStartup: Bool {
        get { systemState.runOnStartup }
        set { systemState.runOnStartup = newValue }
    }

    var performLayoutCompat: Bool {
        get { systemState.performLayoutCompat }
        set { systemState.performLayoutCompat = newValue }
    }

    var showIconOnDock: Bool {
        get { systemState.showIconOnDock }
        set { systemState.showIconOnDock = newValue }
    }

    var settingsWindowAlwaysOnTop: Bool {
        get { systemState.settingsWindowAlwaysOnTop }
        set { systemState.settingsWindowAlwaysOnTop = newValue }
    }

    var safeMode: Bool {
        get { systemState.safeMode }
        set { systemState.safeMode = newValue }
    }

    var enableTextReplacementFix: Bool {
        systemState.enableTextReplacementFix
    }

    var hasAccessibilityPermission: Bool {
        get { systemState.hasAccessibilityPermission }
        set { systemState.hasAccessibilityPermission = newValue }
    }

    var updateAvailableMessage: String {
        get { systemState.updateAvailableMessage }
        set { systemState.updateAvailableMessage = newValue }
    }

    var showUpdateBanner: Bool {
        get { systemState.showUpdateBanner }
        set { systemState.showUpdateBanner = newValue }
    }

    var latestVersion: String {
        get { systemState.latestVersion }
        set { systemState.latestVersion = newValue }
    }

    var updateCheckFrequency: UpdateCheckFrequency {
        get { systemState.updateCheckFrequency }
        set { systemState.updateCheckFrequency = newValue }
    }

    var showCustomUpdateBanner: Bool {
        get { systemState.showCustomUpdateBanner }
        set { systemState.showCustomUpdateBanner = newValue }
    }

    var customUpdateBannerInfo: UpdateBannerInfo? {
        get { systemState.customUpdateBannerInfo }
        set { systemState.customUpdateBannerInfo = newValue }
    }

    // Bug report settings
    var includeSystemInfo: Bool {
        get { systemState.includeSystemInfo }
        set { systemState.includeSystemInfo = newValue }
    }

    var includeLogs: Bool {
        get { systemState.includeLogs }
        set { systemState.includeLogs = newValue }
    }

    var includeCrashLogs: Bool {
        get { systemState.includeCrashLogs }
        set { systemState.includeCrashLogs = newValue }
    }

    // UI state properties
    var switchKeyCommand: Bool {
        get { uiState.switchKeyCommand }
        set { uiState.switchKeyCommand = newValue }
    }

    var switchKeyOption: Bool {
        get { uiState.switchKeyOption }
        set { uiState.switchKeyOption = newValue }
    }

    var switchKeyControl: Bool {
        get { uiState.switchKeyControl }
        set { uiState.switchKeyControl = newValue }
    }

    var switchKeyShift: Bool {
        get { uiState.switchKeyShift }
        set { uiState.switchKeyShift = newValue }
    }

    var switchKeyFn: Bool {
        get { uiState.switchKeyFn }
        set { uiState.switchKeyFn = newValue }
    }

    var switchKeyCode: UInt16 {
        get { uiState.switchKeyCode }
        set { uiState.switchKeyCode = newValue }
    }

    var switchKeyName: String {
        get { uiState.switchKeyName }
        set { uiState.switchKeyName = newValue }
    }

    var beepOnModeSwitch: Bool {
        get { uiState.beepOnModeSwitch }
        set { uiState.beepOnModeSwitch = newValue }
    }

    var beepVolume: Double {
        get { uiState.beepVolume }
        set { uiState.beepVolume = newValue }
    }

    var menuBarIconSize: Double {
        get { uiState.menuBarIconSize }
        set { uiState.menuBarIconSize = newValue }
    }

    var useVietnameseMenubarIcon: Bool {
        get { uiState.useVietnameseMenubarIcon }
        set { uiState.useVietnameseMenubarIcon = newValue }
    }

    // App lists state properties
    var excludedApps: [ExcludedApp] {
        get { appListsState.excludedApps }
        set { appListsState.excludedApps = newValue }
    }

    var sendKeyStepByStepApps: [SendKeyStepByStepApp] {
        get { appListsState.sendKeyStepByStepApps }
        set { appListsState.sendKeyStepByStepApps = newValue }
    }

    var upperCaseExcludedApps: [ExcludedApp] {
        get { appListsState.upperCaseExcludedApps }
        set { appListsState.upperCaseExcludedApps = newValue }
    }

    // Hotkey encoding/decoding methods
    func encodeSwitchKeyStatus() -> Int {
        uiState.encodeSwitchKeyStatus()
    }

    // App lists management methods
    func addExcludedApp(_ app: ExcludedApp) {
        appListsState.addExcludedApp(app)
    }

    func removeExcludedApp(_ app: ExcludedApp) {
        appListsState.removeExcludedApp(app)
    }

    func isAppExcluded(bundleIdentifier: String) -> Bool {
        appListsState.isAppExcluded(bundleIdentifier: bundleIdentifier)
    }

    func addSendKeyStepByStepApp(_ app: SendKeyStepByStepApp) {
        appListsState.addSendKeyStepByStepApp(app)
    }

    func removeSendKeyStepByStepApp(_ app: SendKeyStepByStepApp) {
        appListsState.removeSendKeyStepByStepApp(app)
    }

    func isAppInSendKeyStepByStepList(bundleIdentifier: String) -> Bool {
        appListsState.isAppInSendKeyStepByStepList(bundleIdentifier: bundleIdentifier)
    }

    func addUpperCaseExcludedApp(_ app: ExcludedApp) {
        appListsState.addUpperCaseExcludedApp(app)
    }

    func removeUpperCaseExcludedApp(_ app: ExcludedApp) {
        appListsState.removeUpperCaseExcludedApp(app)
    }

    func isAppUpperCaseExcluded(bundleIdentifier: String) -> Bool {
        appListsState.isAppUpperCaseExcluded(bundleIdentifier: bundleIdentifier)
    }

    func checkAccessibilityPermission() {
        systemState.checkAccessibilityPermission()
    }
}
