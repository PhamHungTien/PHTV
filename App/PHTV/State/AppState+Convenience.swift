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
        get { trackedSubstate(inputMethodState.inputMethod) }
        set { inputMethodState.inputMethod = newValue }
    }

    var codeTable: CodeTable {
        get { trackedSubstate(inputMethodState.codeTable) }
        set { inputMethodState.codeTable = newValue }
    }

    var checkSpelling: Bool {
        get { trackedSubstate(inputMethodState.checkSpelling) }
        set { inputMethodState.checkSpelling = newValue }
    }

    var useModernOrthography: Bool {
        get { trackedSubstate(inputMethodState.useModernOrthography) }
        set { inputMethodState.useModernOrthography = newValue }
    }

    var quickTelex: Bool {
        get { trackedSubstate(inputMethodState.quickTelex) }
        set { inputMethodState.quickTelex = newValue }
    }

    var sendKeyStepByStep: Bool {
        get { trackedSubstate(inputMethodState.sendKeyStepByStep) }
        set { inputMethodState.sendKeyStepByStep = newValue }
    }

    var useSmartSwitchKey: Bool {
        get { trackedSubstate(inputMethodState.useSmartSwitchKey) }
        set { inputMethodState.useSmartSwitchKey = newValue }
    }

    var upperCaseFirstChar: Bool {
        get { trackedSubstate(inputMethodState.upperCaseFirstChar) }
        set { inputMethodState.upperCaseFirstChar = newValue }
    }

    var allowConsonantZFWJ: Bool {
        get { trackedSubstate(inputMethodState.allowConsonantZFWJ) }
        set { inputMethodState.allowConsonantZFWJ = newValue }
    }

    var quickStartConsonant: Bool {
        get { trackedSubstate(inputMethodState.quickStartConsonant) }
        set { inputMethodState.quickStartConsonant = newValue }
    }

    var quickEndConsonant: Bool {
        get { trackedSubstate(inputMethodState.quickEndConsonant) }
        set { inputMethodState.quickEndConsonant = newValue }
    }

    var rememberCode: Bool {
        get { trackedSubstate(inputMethodState.rememberCode) }
        set { inputMethodState.rememberCode = newValue }
    }

    var autoRestoreEnglishWord: Bool {
        get { trackedSubstate(inputMethodState.autoRestoreEnglishWord) }
        set { inputMethodState.autoRestoreEnglishWord = newValue }
    }

    var autoRestoreEnglishWordMode: AutoRestoreEnglishMode {
        get { trackedSubstate(inputMethodState.autoRestoreEnglishWordMode) }
        set { inputMethodState.autoRestoreEnglishWordMode = newValue }
    }

    var restoreOnEscape: Bool {
        get { trackedSubstate(inputMethodState.restoreOnEscape) }
        set { inputMethodState.restoreOnEscape = newValue }
    }

    var restoreKey: RestoreKey {
        get { trackedSubstate(inputMethodState.restoreKey) }
        set { inputMethodState.restoreKey = newValue }
    }

    var pauseKeyEnabled: Bool {
        get { trackedSubstate(inputMethodState.pauseKeyEnabled) }
        set { inputMethodState.pauseKeyEnabled = newValue }
    }

    var pauseKey: UInt16 {
        get { trackedSubstate(inputMethodState.pauseKey) }
        set { inputMethodState.pauseKey = newValue }
    }

    var pauseKeyName: String {
        get { trackedSubstate(inputMethodState.pauseKeyName) }
        set { inputMethodState.pauseKeyName = newValue }
    }

    // MARK: Macro State

    var useMacro: Bool {
        get { trackedSubstate(macroState.useMacro) }
        set { macroState.useMacro = newValue }
    }

    var useMacroInEnglishMode: Bool {
        get { trackedSubstate(macroState.useMacroInEnglishMode) }
        set { macroState.useMacroInEnglishMode = newValue }
    }

    var useSystemTextReplacements: Bool {
        get { trackedSubstate(macroState.useSystemTextReplacements) }
        set { macroState.useSystemTextReplacements = newValue }
    }

    var autoCapsMacro: Bool {
        get { trackedSubstate(macroState.autoCapsMacro) }
        set { macroState.autoCapsMacro = newValue }
    }

    var macroCategories: [MacroCategory] {
        get { trackedSubstate(macroState.macroCategories) }
        set { macroState.macroCategories = newValue }
    }

    var enableEmojiHotkey: Bool {
        get { trackedSubstate(macroState.enableEmojiHotkey) }
        set { macroState.enableEmojiHotkey = newValue }
    }

    var emojiHotkeyModifiersRaw: Int {
        get { trackedSubstate(macroState.emojiHotkeyModifiersRaw) }
        set { macroState.emojiHotkeyModifiersRaw = newValue }
    }

    var emojiHotkeyKeyCode: UInt16 {
        get { trackedSubstate(macroState.emojiHotkeyKeyCode) }
        set { macroState.emojiHotkeyKeyCode = newValue }
    }

    var emojiHotkeyModifiers: NSEvent.ModifierFlags {
        get { trackedSubstate(macroState.emojiHotkeyModifiers) }
        set { macroState.emojiHotkeyModifiers = newValue }
    }

    // MARK: Clipboard History State

    var enableClipboardHistory: Bool {
        get { trackedSubstate(clipboardHistoryState.enableClipboardHistory) }
        set { clipboardHistoryState.enableClipboardHistory = newValue }
    }

    var clipboardHotkeyModifiersRaw: Int {
        get { trackedSubstate(clipboardHistoryState.clipboardHotkeyModifiersRaw) }
        set { clipboardHistoryState.clipboardHotkeyModifiersRaw = newValue }
    }

    var clipboardHotkeyKeyCode: UInt16 {
        get { trackedSubstate(clipboardHistoryState.clipboardHotkeyKeyCode) }
        set { clipboardHistoryState.clipboardHotkeyKeyCode = newValue }
    }

    var clipboardHotkeyModifiers: NSEvent.ModifierFlags {
        get { trackedSubstate(clipboardHistoryState.clipboardHotkeyModifiers) }
        set { clipboardHistoryState.clipboardHotkeyModifiers = newValue }
    }

    var clipboardHistoryMaxItems: Int {
        get { trackedSubstate(clipboardHistoryState.clipboardHistoryMaxItems) }
        set { clipboardHistoryState.clipboardHistoryMaxItems = newValue }
    }

    // MARK: System State

    var runOnStartup: Bool {
        get { trackedSubstate(systemState.runOnStartup) }
        set { systemState.runOnStartup = newValue }
    }

    var performLayoutCompat: Bool {
        get { trackedSubstate(systemState.performLayoutCompat) }
        set { systemState.performLayoutCompat = newValue }
    }

    var showIconOnDock: Bool {
        get { trackedSubstate(systemState.showIconOnDock) }
        set { systemState.showIconOnDock = newValue }
    }

    var settingsWindowAlwaysOnTop: Bool {
        get { trackedSubstate(systemState.settingsWindowAlwaysOnTop) }
        set { systemState.settingsWindowAlwaysOnTop = newValue }
    }

    var safeMode: Bool {
        get { trackedSubstate(systemState.safeMode) }
        set { systemState.safeMode = newValue }
    }

    var enableTextReplacementFix: Bool {
        trackedSubstate(systemState.enableTextReplacementFix)
    }

    var hasAccessibilityPermission: Bool {
        get { trackedSubstate(systemState.hasAccessibilityPermission) }
        set { systemState.hasAccessibilityPermission = newValue }
    }

    var isTypingPermissionReady: Bool {
        get { trackedSubstate(systemState.isTypingPermissionReady) }
        set { systemState.isTypingPermissionReady = newValue }
    }

    var typingRuntimeHealth: PHTVTypingRuntimeHealthSnapshot {
        get { trackedSubstate(systemState.typingRuntimeHealth) }
        set { systemState.typingRuntimeHealth = newValue }
    }

    var updateAvailableMessage: String {
        get { trackedSubstate(systemState.updateAvailableMessage) }
        set { systemState.updateAvailableMessage = newValue }
    }

    var showUpdateBanner: Bool {
        get { trackedSubstate(systemState.showUpdateBanner) }
        set { systemState.showUpdateBanner = newValue }
    }

    var latestVersion: String {
        get { trackedSubstate(systemState.latestVersion) }
        set { systemState.latestVersion = newValue }
    }

    var updateCheckFrequency: UpdateCheckFrequency {
        get { trackedSubstate(systemState.updateCheckFrequency) }
        set { systemState.updateCheckFrequency = newValue }
    }

    var showCustomUpdateBanner: Bool {
        get { trackedSubstate(systemState.showCustomUpdateBanner) }
        set { systemState.showCustomUpdateBanner = newValue }
    }

    var customUpdateBannerInfo: UpdateBannerInfo? {
        get { trackedSubstate(systemState.customUpdateBannerInfo) }
        set { systemState.customUpdateBannerInfo = newValue }
    }

    // MARK: Bug Report

    var includeSystemInfo: Bool {
        get { trackedSubstate(systemState.includeSystemInfo) }
        set { systemState.includeSystemInfo = newValue }
    }

    var includeLogs: Bool {
        get { trackedSubstate(systemState.includeLogs) }
        set { systemState.includeLogs = newValue }
    }

    var includeCrashLogs: Bool {
        get { trackedSubstate(systemState.includeCrashLogs) }
        set { systemState.includeCrashLogs = newValue }
    }

    // MARK: UI State

    var switchKeyCommand: Bool {
        get { trackedSubstate(uiState.switchKeyCommand) }
        set { uiState.switchKeyCommand = newValue }
    }

    var switchKeyOption: Bool {
        get { trackedSubstate(uiState.switchKeyOption) }
        set { uiState.switchKeyOption = newValue }
    }

    var switchKeyControl: Bool {
        get { trackedSubstate(uiState.switchKeyControl) }
        set { uiState.switchKeyControl = newValue }
    }

    var switchKeyShift: Bool {
        get { trackedSubstate(uiState.switchKeyShift) }
        set { uiState.switchKeyShift = newValue }
    }

    var switchKeyFn: Bool {
        get { trackedSubstate(uiState.switchKeyFn) }
        set { uiState.switchKeyFn = newValue }
    }

    var switchKeyCode: UInt16 {
        get { trackedSubstate(uiState.switchKeyCode) }
        set { uiState.switchKeyCode = newValue }
    }

    var switchKeyName: String {
        get { trackedSubstate(uiState.switchKeyName) }
        set { uiState.switchKeyName = newValue }
    }

    var beepOnModeSwitch: Bool {
        get { trackedSubstate(uiState.beepOnModeSwitch) }
        set { uiState.beepOnModeSwitch = newValue }
    }

    var beepVolume: Double {
        get { trackedSubstate(uiState.beepVolume) }
        set { uiState.beepVolume = newValue }
    }

    var menuBarIconSize: Double {
        get { trackedSubstate(uiState.menuBarIconSize) }
        set { uiState.menuBarIconSize = newValue }
    }

    var useVietnameseMenubarIcon: Bool {
        get { trackedSubstate(uiState.useVietnameseMenubarIcon) }
        set { uiState.useVietnameseMenubarIcon = newValue }
    }

    // MARK: App Lists

    var excludedApps: [ExcludedApp] {
        get { trackedSubstate(appListsState.excludedApps) }
        set { appListsState.excludedApps = newValue }
    }

    var sendKeyStepByStepApps: [SendKeyStepByStepApp] {
        get { trackedSubstate(appListsState.sendKeyStepByStepApps) }
        set { appListsState.sendKeyStepByStepApps = newValue }
    }

    var upperCaseExcludedApps: [ExcludedApp] {
        get { trackedSubstate(appListsState.upperCaseExcludedApps) }
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

    @discardableResult
    func checkAccessibilityPermission() -> PHTVTypingPermissionState {
        systemState.checkAccessibilityPermission()
    }
}
