//
//  InputMethodState.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation
import Observation

/// Manages input method settings and Vietnamese typing features
@MainActor
@Observable
final class InputMethodState {
    // Input method settings
    var inputMethod: InputMethod = .telex {
        didSet {
            handleObservedChange(oldValue: oldValue, newValue: inputMethod) {
                SettingsObserver.shared.suspendNotifications()
                let defaults = UserDefaults.standard
                defaults.set(self.inputMethod.toIndex(), forKey: UserDefaultsKey.inputType)
                NotificationCenter.default.post(
                    name: NotificationName.inputMethodChanged,
                    object: NSNumber(value: self.inputMethod.toIndex())
                )
            }
        }
    }
    var codeTable: CodeTable = .unicode {
        didSet {
            handleObservedChange(oldValue: oldValue, newValue: codeTable) {
                SettingsObserver.shared.suspendNotifications()
                let defaults = UserDefaults.standard
                defaults.set(self.codeTable.toIndex(), forKey: UserDefaultsKey.codeTable)
                NotificationCenter.default.post(
                    name: NotificationName.codeTableChanged,
                    object: NSNumber(value: self.codeTable.toIndex())
                )
            }
        }
    }

    // Features
    var checkSpelling: Bool = true {
        didSet { handleRuntimeSettingDidChange(oldValue: oldValue, newValue: checkSpelling) }
    }
    var useModernOrthography: Bool = true {
        didSet { handleRuntimeSettingDidChange(oldValue: oldValue, newValue: useModernOrthography) }
    }
    var quickTelex: Bool = false {
        didSet { handleRuntimeSettingDidChange(oldValue: oldValue, newValue: quickTelex) }
    }
    var sendKeyStepByStep: Bool = false {
        didSet { handleRuntimeSettingDidChange(oldValue: oldValue, newValue: sendKeyStepByStep) }
    }
    var useSmartSwitchKey: Bool = true {
        didSet { handleRuntimeSettingDidChange(oldValue: oldValue, newValue: useSmartSwitchKey) }
    }
    var upperCaseFirstChar: Bool = false {
        didSet {
            handleObservedChange(oldValue: oldValue, newValue: upperCaseFirstChar) {
                SettingsObserver.shared.suspendNotifications()
                let defaults = UserDefaults.standard
                defaults.set(self.upperCaseFirstChar, forKey: UserDefaultsKey.upperCaseFirstChar)
                NotificationCenter.default.post(
                    name: NotificationName.phtvSettingsChanged,
                    object: nil
                )
            }
        }
    }
    var allowConsonantZFWJ: Bool = true {
        didSet { handleRuntimeSettingDidChange(oldValue: oldValue, newValue: allowConsonantZFWJ) }
    }
    var quickStartConsonant: Bool = false {
        didSet { handleRuntimeSettingDidChange(oldValue: oldValue, newValue: quickStartConsonant) }
    }
    var quickEndConsonant: Bool = false {
        didSet { handleRuntimeSettingDidChange(oldValue: oldValue, newValue: quickEndConsonant) }
    }
    var rememberCode: Bool = true {
        didSet { handleRuntimeSettingDidChange(oldValue: oldValue, newValue: rememberCode) }
    }

    // Auto restore English words - default: ON for new users
    var autoRestoreEnglishWord: Bool = true {
        didSet {
            handleObservedChange(oldValue: oldValue, newValue: autoRestoreEnglishWord) {
                self.handleAutoRestoreEnglishSettingsDidChange()
            }
        }
    }
    var autoRestoreEnglishWordMode: AutoRestoreEnglishMode = .englishOnly {
        didSet {
            handleObservedChange(oldValue: oldValue, newValue: autoRestoreEnglishWordMode) {
                self.handleAutoRestoreEnglishSettingsDidChange()
            }
        }
    }

    // Restore to raw keys (customizable key)
    var restoreOnEscape: Bool = true {
        didSet { handleRuntimeSettingDidChange(oldValue: oldValue, newValue: restoreOnEscape) }
    }
    var restoreKey: RestoreKey = .esc {
        didSet { handleRuntimeSettingDidChange(oldValue: oldValue, newValue: restoreKey) }
    }

    // Pause Vietnamese input when holding a key
    var pauseKeyEnabled: Bool = false {
        didSet { handleRuntimeSettingDidChange(oldValue: oldValue, newValue: pauseKeyEnabled) }
    }
    var pauseKey: UInt16 = Defaults.pauseKeyCode {
        didSet { handleRuntimeSettingDidChange(oldValue: oldValue, newValue: pauseKey) }
    }
    var pauseKeyName: String = Defaults.pauseKeyName {
        didSet { handleRuntimeSettingDidChange(oldValue: oldValue, newValue: pauseKeyName) }
    }

    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored var isLoadingSettings = false
    @ObservationIgnored private var runtimeSettingsCommitTask: Task<Void, Never>?

    private static let autoRestoreEnglishLegacyKeys: [String] = [
        "RestoreIfInvalidWord"
    ]

    private func decodeBoolPreference(_ value: Any?) -> Bool? {
        if let boolValue = value as? Bool {
            return boolValue
        }
        if let numberValue = value as? NSNumber {
            return numberValue.boolValue
        }
        if let stringValue = value as? String {
            switch stringValue.lowercased() {
            case "1", "true", "yes":
                return true
            case "0", "false", "no":
                return false
            default:
                return nil
            }
        }
        return nil
    }

    private func decodeAutoRestoreEnglishMode(_ value: Any?) -> AutoRestoreEnglishMode? {
        AutoRestoreEnglishMode.from(persistedValue: value)
    }

    private var restoreIfWrongSpellingForRuntime: Bool {
        autoRestoreEnglishWord && autoRestoreEnglishWordMode.enablesWrongSpellingFallback
    }

    private func persistAutoRestoreEnglishSettings() {
        let defaults = UserDefaults.standard
        defaults.set(autoRestoreEnglishWord, forKey: UserDefaultsKey.autoRestoreEnglishWord)
        defaults.set(autoRestoreEnglishWordMode.rawValue, forKey: UserDefaultsKey.autoRestoreEnglishWordMode)
        defaults.set(restoreIfWrongSpellingForRuntime, forKey: UserDefaultsKey.restoreIfWrongSpelling)
    }

    private func handleObservedChange<Value: Equatable>(
        oldValue: Value,
        newValue: Value,
        action: (() -> Void)? = nil
    ) {
        guard newValue != oldValue else { return }
        onChange?()
        guard !isLoadingSettings else { return }
        action?()
    }

    private func handleRuntimeSettingDidChange<Value: Equatable>(oldValue: Value, newValue: Value) {
        handleObservedChange(oldValue: oldValue, newValue: newValue) {
            self.scheduleRuntimeSettingsCommit()
        }
    }

    private func handleAutoRestoreEnglishSettingsDidChange() {
        SettingsObserver.shared.suspendNotifications()
        persistAutoRestoreEnglishSettings()
        NotificationCenter.default.post(
            name: NotificationName.phtvSettingsChanged,
            object: nil
        )
    }

    private func scheduleRuntimeSettingsCommit() {
        runtimeSettingsCommitTask?.cancel()
        runtimeSettingsCommitTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard let self = self, !Task.isCancelled, !self.isLoadingSettings else { return }
            self.saveSettings()
            NotificationCenter.default.post(
                name: NotificationName.phtvSettingsChanged,
                object: nil
            )
        }
    }

    init() {}

    // MARK: - Load/Save Settings

    func loadSettings() {
        let defaults = UserDefaults.standard

        let migratedAutoRestoreKey = defaults.migrateValueIfMissing(
            forKey: UserDefaultsKey.autoRestoreEnglishWord,
            fromLegacyKeys: Self.autoRestoreEnglishLegacyKeys,
            transform: { [weak self] legacyValue in
                self?.decodeBoolPreference(legacyValue)
            }
        )
        if migratedAutoRestoreKey {
            NSLog("[InputMethodState] Migrated legacy auto-restore setting to %@", UserDefaultsKey.autoRestoreEnglishWord)
        }

        // Load input method and code table
        let inputTypeIndex = defaults.integer(
            forKey: UserDefaultsKey.inputType,
            default: Defaults.inputMethod.toIndex()
        )
        inputMethod = InputMethod.from(index: inputTypeIndex)

        let codeTableIndex = defaults.integer(
            forKey: UserDefaultsKey.codeTable,
            default: Defaults.codeTable.toIndex()
        )
        codeTable = CodeTable.from(index: codeTableIndex)

        // Load input settings
        checkSpelling = defaults.bool(forKey: UserDefaultsKey.spelling, default: Defaults.checkSpelling)
        useModernOrthography = defaults.bool(
            forKey: UserDefaultsKey.modernOrthography,
            default: Defaults.useModernOrthography
        )
        quickTelex = defaults.bool(forKey: UserDefaultsKey.quickTelex, default: Defaults.quickTelex)
        sendKeyStepByStep = defaults.bool(
            forKey: UserDefaultsKey.sendKeyStepByStep,
            default: Defaults.sendKeyStepByStep
        )
        useSmartSwitchKey = defaults.bool(
            forKey: UserDefaultsKey.useSmartSwitchKey,
            default: Defaults.useSmartSwitchKey
        )
        upperCaseFirstChar = defaults.bool(
            forKey: UserDefaultsKey.upperCaseFirstChar,
            default: Defaults.upperCaseFirstChar
        )
        allowConsonantZFWJ = defaults.bool(
            forKey: UserDefaultsKey.allowConsonantZFWJ,
            default: Defaults.allowConsonantZFWJ
        )
        quickStartConsonant = defaults.bool(
            forKey: UserDefaultsKey.quickStartConsonant,
            default: Defaults.quickStartConsonant
        )
        quickEndConsonant = defaults.bool(
            forKey: UserDefaultsKey.quickEndConsonant,
            default: Defaults.quickEndConsonant
        )
        rememberCode = defaults.bool(forKey: UserDefaultsKey.rememberCode, default: Defaults.rememberCode)

        // Auto restore English words
        autoRestoreEnglishWord = defaults.bool(
            forKey: UserDefaultsKey.autoRestoreEnglishWord,
            default: Defaults.autoRestoreEnglishWord
        )
        let hasPersistedAutoRestoreMode = decodeAutoRestoreEnglishMode(
            defaults.persistedObject(forKey: UserDefaultsKey.autoRestoreEnglishWordMode)
        ) != nil
        autoRestoreEnglishWordMode = defaults.autoRestoreEnglishMode()
        if !hasPersistedAutoRestoreMode {
            defaults.set(autoRestoreEnglishWordMode.rawValue, forKey: UserDefaultsKey.autoRestoreEnglishWordMode)
        }
        defaults.set(restoreIfWrongSpellingForRuntime, forKey: UserDefaultsKey.restoreIfWrongSpelling)

        // Restore to raw keys (customizable key)
        restoreOnEscape = defaults.bool(forKey: UserDefaultsKey.restoreOnEscape, default: Defaults.restoreOnEscape)
        let restoreKeyCode = defaults.integer(
            forKey: UserDefaultsKey.customEscapeKey,
            default: Int(Defaults.restoreKeyCode)
        )
        restoreKey = RestoreKey.from(keyCode: restoreKeyCode == 0 ? Int(Defaults.restoreKeyCode) : restoreKeyCode)

        // Pause Vietnamese input when holding a key
        pauseKeyEnabled = defaults.bool(forKey: UserDefaultsKey.pauseKeyEnabled, default: Defaults.pauseKeyEnabled)
        let savedPauseKey = defaults.integer(forKey: UserDefaultsKey.pauseKey, default: Int(Defaults.pauseKeyCode))
        pauseKey = UInt16(savedPauseKey == 0 ? Int(Defaults.pauseKeyCode) : savedPauseKey)
        pauseKeyName = defaults.string(forKey: UserDefaultsKey.pauseKeyName) ?? Defaults.pauseKeyName
    }

    func saveSettings() {
        SettingsObserver.shared.suspendNotifications()
        let defaults = UserDefaults.standard

        // Save input method and code table
        defaults.set(inputMethod.toIndex(), forKey: UserDefaultsKey.inputType)
        defaults.set(codeTable.toIndex(), forKey: UserDefaultsKey.codeTable)

        // Save input settings
        defaults.set(checkSpelling, forKey: UserDefaultsKey.spelling)
        defaults.set(useModernOrthography, forKey: UserDefaultsKey.modernOrthography)
        defaults.set(quickTelex, forKey: UserDefaultsKey.quickTelex)
        defaults.set(sendKeyStepByStep, forKey: UserDefaultsKey.sendKeyStepByStep)
        defaults.set(useSmartSwitchKey, forKey: UserDefaultsKey.useSmartSwitchKey)
        defaults.set(upperCaseFirstChar, forKey: UserDefaultsKey.upperCaseFirstChar)
        defaults.set(allowConsonantZFWJ, forKey: UserDefaultsKey.allowConsonantZFWJ)
        defaults.set(quickStartConsonant, forKey: UserDefaultsKey.quickStartConsonant)
        defaults.set(quickEndConsonant, forKey: UserDefaultsKey.quickEndConsonant)
        defaults.set(rememberCode, forKey: UserDefaultsKey.rememberCode)

        // Auto restore English words
        persistAutoRestoreEnglishSettings()

        // Restore to raw keys (customizable key)
        defaults.set(restoreOnEscape, forKey: UserDefaultsKey.restoreOnEscape)
        defaults.set(restoreKey.rawValue, forKey: UserDefaultsKey.customEscapeKey)

        // Pause Vietnamese input when holding a key
        defaults.set(pauseKeyEnabled, forKey: UserDefaultsKey.pauseKeyEnabled)
        defaults.set(Int(pauseKey), forKey: UserDefaultsKey.pauseKey)
        defaults.set(pauseKeyName, forKey: UserDefaultsKey.pauseKeyName)

    }

    func reloadFromDefaults() {
        loadSettings()
    }

    // MARK: - Setup Observers

    func setupObservers() {
        // Observation-based state now handles side effects in property observers.
    }

    func resetToDefaults() {
        isLoadingSettings = true
        defer { isLoadingSettings = false }

        inputMethod = Defaults.inputMethod
        codeTable = Defaults.codeTable

        checkSpelling = Defaults.checkSpelling
        useModernOrthography = Defaults.useModernOrthography
        quickTelex = Defaults.quickTelex
        sendKeyStepByStep = Defaults.sendKeyStepByStep
        useSmartSwitchKey = Defaults.useSmartSwitchKey
        upperCaseFirstChar = Defaults.upperCaseFirstChar
        allowConsonantZFWJ = Defaults.allowConsonantZFWJ
        quickStartConsonant = Defaults.quickStartConsonant
        quickEndConsonant = Defaults.quickEndConsonant
        rememberCode = Defaults.rememberCode
        autoRestoreEnglishWord = Defaults.autoRestoreEnglishWord
        autoRestoreEnglishWordMode = Defaults.autoRestoreEnglishWordMode

        restoreOnEscape = Defaults.restoreOnEscape
        restoreKey = RestoreKey.from(keyCode: Int(Defaults.restoreKeyCode))

        pauseKeyEnabled = Defaults.pauseKeyEnabled
        pauseKey = Defaults.pauseKeyCode
        pauseKeyName = Defaults.pauseKeyName

        saveSettings()
    }
}
