//
//  AppState+Convenience.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit

// MARK: - Convenience Accessors

@MainActor
extension AppState {
    // MARK: Backward Compatibility Properties

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

    // MARK: Macro State

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

    // MARK: System State

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

    // MARK: Bug Report

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

    // MARK: UI State

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

    // MARK: App Lists

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

    // MARK: Helpers

    func encodeSwitchKeyStatus() -> Int {
        uiState.encodeSwitchKeyStatus()
    }

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
