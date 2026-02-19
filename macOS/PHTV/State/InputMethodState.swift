//
//  InputMethodState.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import Combine

/// Manages input method settings and Vietnamese typing features
@MainActor
final class InputMethodState: ObservableObject {
    // Input method settings
    @Published var inputMethod: InputMethod = .telex
    @Published var codeTable: CodeTable = .unicode

    // Features
    @Published var checkSpelling: Bool = true
    @Published var useModernOrthography: Bool = true
    @Published var quickTelex: Bool = false
    @Published var sendKeyStepByStep: Bool = false
    @Published var useSmartSwitchKey: Bool = true
    @Published var upperCaseFirstChar: Bool = false
    @Published var allowConsonantZFWJ: Bool = true
    @Published var quickStartConsonant: Bool = false
    @Published var quickEndConsonant: Bool = false
    @Published var rememberCode: Bool = true

    // Auto restore English words - default: ON for new users
    @Published var autoRestoreEnglishWord: Bool = true

    // Restore to raw keys (customizable key)
    @Published var restoreOnEscape: Bool = true
    @Published var restoreKey: RestoreKey = .esc

    // Pause Vietnamese input when holding a key
    @Published var pauseKeyEnabled: Bool = false
    @Published var pauseKey: UInt16 = Defaults.pauseKeyCode
    @Published var pauseKeyName: String = Defaults.pauseKeyName

    private var cancellables = Set<AnyCancellable>()
    var isLoadingSettings = false

    init() {}

    // MARK: - Load/Save Settings

    func loadSettings() {
        let defaults = UserDefaults.standard

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
        defaults.set(autoRestoreEnglishWord, forKey: UserDefaultsKey.autoRestoreEnglishWord)

        // Restore to raw keys (customizable key)
        defaults.set(restoreOnEscape, forKey: UserDefaultsKey.restoreOnEscape)
        defaults.set(restoreKey.rawValue, forKey: UserDefaultsKey.customEscapeKey)

        // Pause Vietnamese input when holding a key
        defaults.set(pauseKeyEnabled, forKey: UserDefaultsKey.pauseKeyEnabled)
        defaults.set(Int(pauseKey), forKey: UserDefaultsKey.pauseKey)
        defaults.set(pauseKeyName, forKey: UserDefaultsKey.pauseKeyName)

    }

    func reloadFromDefaults() {
        let defaults = UserDefaults.standard

        let inputTypeIndex = defaults.integer(
            forKey: UserDefaultsKey.inputType,
            default: Defaults.inputMethod.toIndex()
        )
        let newInputMethod = InputMethod.from(index: inputTypeIndex)

        let codeTableIndex = defaults.integer(
            forKey: UserDefaultsKey.codeTable,
            default: Defaults.codeTable.toIndex()
        )
        let newCodeTable = CodeTable.from(index: codeTableIndex)

        // Update only if values changed to avoid unnecessary refreshes
        if newInputMethod != inputMethod {
            inputMethod = newInputMethod
        }

        if newCodeTable != codeTable {
            codeTable = newCodeTable
        }
    }

    // MARK: - Setup Observers

    func setupObservers() {
        // Observer for input method
        $inputMethod.sink { [weak self] newMethod in
            guard let self = self, !self.isLoadingSettings else { return }
            SettingsObserver.shared.suspendNotifications()
            let defaults = UserDefaults.standard
            defaults.set(newMethod.toIndex(), forKey: UserDefaultsKey.inputType)
            NotificationCenter.default.post(
                name: NotificationName.inputMethodChanged,
                object: NSNumber(value: newMethod.toIndex()))
        }.store(in: &cancellables)

        // Observer for code table
        $codeTable.sink { [weak self] newTable in
            guard let self = self, !self.isLoadingSettings else { return }
            SettingsObserver.shared.suspendNotifications()
            let defaults = UserDefaults.standard
            defaults.set(newTable.toIndex(), forKey: UserDefaultsKey.codeTable)
            NotificationCenter.default.post(
                name: NotificationName.codeTableChanged,
                object: NSNumber(value: newTable.toIndex()))
        }.store(in: &cancellables)

        // Uppercase first character: apply immediately (no debounce)
        $upperCaseFirstChar
            .removeDuplicates()
            .sink { [weak self] value in
                guard let self = self, !self.isLoadingSettings else { return }
                SettingsObserver.shared.suspendNotifications()
                let defaults = UserDefaults.standard
                defaults.set(value, forKey: UserDefaultsKey.upperCaseFirstChar)
                NotificationCenter.default.post(
                    name: NotificationName.phtvSettingsChanged, object: nil
                )
            }.store(in: &cancellables)

        // Observer for other settings that need to save and notify backend
        Publishers.MergeMany([
            $checkSpelling.map { _ in () }.eraseToAnyPublisher(),
            $useModernOrthography.map { _ in () }.eraseToAnyPublisher(),
            $quickTelex.map { _ in () }.eraseToAnyPublisher(),
            $useSmartSwitchKey.map { _ in () }.eraseToAnyPublisher(),
            $allowConsonantZFWJ.map { _ in () }.eraseToAnyPublisher(),
            $quickStartConsonant.map { _ in () }.eraseToAnyPublisher(),
            $quickEndConsonant.map { _ in () }.eraseToAnyPublisher(),
            $rememberCode.map { _ in () }.eraseToAnyPublisher(),
            $sendKeyStepByStep.map { _ in () }.eraseToAnyPublisher(),
            $autoRestoreEnglishWord.map { _ in () }.eraseToAnyPublisher(),
            $restoreOnEscape.map { _ in () }.eraseToAnyPublisher(),
            $restoreKey.map { _ in () }.eraseToAnyPublisher(),
            $pauseKeyEnabled.map { _ in () }.eraseToAnyPublisher(),
            $pauseKey.map { _ in () }.eraseToAnyPublisher(),
            $pauseKeyName.map { _ in () }.eraseToAnyPublisher()
        ])
        .debounce(for: .milliseconds(Timing.settingsDebounce), scheduler: RunLoop.main)
        .sink { [weak self] _ in
            guard let self = self, !self.isLoadingSettings else { return }
            self.saveSettings()
            NotificationCenter.default.post(
                name: NotificationName.phtvSettingsChanged, object: nil
            )
        }.store(in: &cancellables)
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

        restoreOnEscape = Defaults.restoreOnEscape
        restoreKey = RestoreKey.from(keyCode: Int(Defaults.restoreKeyCode))

        pauseKeyEnabled = Defaults.pauseKeyEnabled
        pauseKey = Defaults.pauseKeyCode
        pauseKeyName = Defaults.pauseKeyName

        saveSettings()
    }
}
