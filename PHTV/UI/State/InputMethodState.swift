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
    @Published var restoreOnInvalidWord: Bool = false
    @Published var sendKeyStepByStep: Bool = false
    @Published var useSmartSwitchKey: Bool = true
    @Published var upperCaseFirstChar: Bool = false
    @Published var allowConsonantZFWJ: Bool = false
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
    @Published var pauseKey: UInt16 = 58  // Default: Left Option
    @Published var pauseKeyName: String = "Option"

    private var cancellables = Set<AnyCancellable>()
    var isLoadingSettings = false

    init() {}

    // MARK: - Load/Save Settings

    func loadSettings() {
        let defaults = UserDefaults.standard

        // Load input method and code table
        let inputTypeIndex = defaults.integer(forKey: "InputType")
        inputMethod = InputMethod.from(index: inputTypeIndex)

        let codeTableIndex = defaults.integer(forKey: "CodeTable")
        codeTable = CodeTable.from(index: codeTableIndex)

        // Load input settings
        checkSpelling = defaults.bool(forKey: "Spelling")
        useModernOrthography = defaults.bool(forKey: "ModernOrthography")
        quickTelex = defaults.bool(forKey: "QuickTelex")
        restoreOnInvalidWord = defaults.bool(forKey: "RestoreIfInvalidWord")
        sendKeyStepByStep = defaults.bool(forKey: "SendKeyStepByStep")
        useSmartSwitchKey = defaults.bool(forKey: "UseSmartSwitchKey")
        upperCaseFirstChar = defaults.bool(forKey: "UpperCaseFirstChar")
        allowConsonantZFWJ = defaults.bool(forKey: "vAllowConsonantZFWJ")
        quickStartConsonant = defaults.bool(forKey: "vQuickStartConsonant")
        quickEndConsonant = defaults.bool(forKey: "vQuickEndConsonant")
        rememberCode = defaults.bool(forKey: "vRememberCode")

        // Auto restore English words
        autoRestoreEnglishWord = defaults.bool(forKey: "vAutoRestoreEnglishWord")

        // Restore to raw keys (customizable key)
        restoreOnEscape = defaults.object(forKey: "vRestoreOnEscape") as? Bool ?? true
        let restoreKeyCode = defaults.integer(forKey: "vCustomEscapeKey")
        restoreKey = RestoreKey.from(keyCode: restoreKeyCode == 0 ? 53 : restoreKeyCode)

        // Pause Vietnamese input when holding a key
        pauseKeyEnabled = defaults.object(forKey: "vPauseKeyEnabled") as? Bool ?? false
        pauseKey = UInt16(defaults.integer(forKey: "vPauseKey"))
        if pauseKey == 0 {
            pauseKey = 58  // Default: Left Option
        }
        pauseKeyName = defaults.string(forKey: "vPauseKeyName") ?? "Option"
    }

    func saveSettings() {
        let defaults = UserDefaults.standard

        // Save input method and code table
        defaults.set(inputMethod.toIndex(), forKey: "InputType")
        defaults.set(codeTable.toIndex(), forKey: "CodeTable")

        // Save input settings
        defaults.set(checkSpelling, forKey: "Spelling")
        defaults.set(useModernOrthography, forKey: "ModernOrthography")
        defaults.set(quickTelex, forKey: "QuickTelex")
        defaults.set(restoreOnInvalidWord, forKey: "RestoreIfInvalidWord")
        defaults.set(sendKeyStepByStep, forKey: "SendKeyStepByStep")
        defaults.set(useSmartSwitchKey, forKey: "UseSmartSwitchKey")
        defaults.set(upperCaseFirstChar, forKey: "UpperCaseFirstChar")
        defaults.set(allowConsonantZFWJ, forKey: "vAllowConsonantZFWJ")
        defaults.set(quickStartConsonant, forKey: "vQuickStartConsonant")
        defaults.set(quickEndConsonant, forKey: "vQuickEndConsonant")
        defaults.set(rememberCode, forKey: "vRememberCode")

        // Auto restore English words
        defaults.set(autoRestoreEnglishWord, forKey: "vAutoRestoreEnglishWord")

        // Restore to raw keys (customizable key)
        defaults.set(restoreOnEscape, forKey: "vRestoreOnEscape")
        defaults.set(restoreKey.rawValue, forKey: "vCustomEscapeKey")

        // Pause Vietnamese input when holding a key
        defaults.set(pauseKeyEnabled, forKey: "vPauseKeyEnabled")
        defaults.set(Int(pauseKey), forKey: "vPauseKey")
        defaults.set(pauseKeyName, forKey: "vPauseKeyName")

        defaults.synchronize()
    }

    func reloadFromDefaults() {
        let defaults = UserDefaults.standard

        let inputTypeIndex = defaults.integer(forKey: "InputType")
        let newInputMethod = InputMethod.from(index: inputTypeIndex)

        let codeTableIndex = defaults.integer(forKey: "CodeTable")
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
            let defaults = UserDefaults.standard
            defaults.set(newMethod.toIndex(), forKey: "InputType")
            defaults.synchronize()
            NotificationCenter.default.post(
                name: NSNotification.Name("InputMethodChanged"),
                object: NSNumber(value: newMethod.toIndex()))
        }.store(in: &cancellables)

        // Observer for code table
        $codeTable.sink { [weak self] newTable in
            guard let self = self, !self.isLoadingSettings else { return }
            let defaults = UserDefaults.standard
            defaults.set(newTable.toIndex(), forKey: "CodeTable")
            defaults.synchronize()
            NotificationCenter.default.post(
                name: NSNotification.Name("CodeTableChanged"),
                object: NSNumber(value: newTable.toIndex()))
        }.store(in: &cancellables)

        // Uppercase first character: apply immediately (no debounce)
        $upperCaseFirstChar
            .removeDuplicates()
            .sink { [weak self] value in
                guard let self = self, !self.isLoadingSettings else { return }
                let defaults = UserDefaults.standard
                defaults.set(value, forKey: "UpperCaseFirstChar")
                defaults.synchronize()
                NotificationCenter.default.post(
                    name: NSNotification.Name("PHTVSettingsChanged"), object: nil
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
            $restoreOnInvalidWord.map { _ in () }.eraseToAnyPublisher(),
            $sendKeyStepByStep.map { _ in () }.eraseToAnyPublisher(),
            $autoRestoreEnglishWord.map { _ in () }.eraseToAnyPublisher(),
            $restoreOnEscape.map { _ in () }.eraseToAnyPublisher(),
            $restoreKey.map { _ in () }.eraseToAnyPublisher(),
            $pauseKeyEnabled.map { _ in () }.eraseToAnyPublisher(),
            $pauseKey.map { _ in () }.eraseToAnyPublisher(),
            $pauseKeyName.map { _ in () }.eraseToAnyPublisher()
        ])
        .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
        .sink { [weak self] _ in
            guard let self = self, !self.isLoadingSettings else { return }
            self.saveSettings()
            NotificationCenter.default.post(
                name: NSNotification.Name("PHTVSettingsChanged"), object: nil
            )
        }.store(in: &cancellables)
    }

    func resetToDefaults() {
        isLoadingSettings = true
        defer { isLoadingSettings = false }

        inputMethod = .telex
        codeTable = .unicode

        checkSpelling = true
        useModernOrthography = true
        quickTelex = false
        restoreOnInvalidWord = false
        sendKeyStepByStep = false
        useSmartSwitchKey = true
        upperCaseFirstChar = false
        allowConsonantZFWJ = false
        quickStartConsonant = false
        quickEndConsonant = false
        rememberCode = true
        autoRestoreEnglishWord = true

        restoreOnEscape = true
        restoreKey = .esc

        pauseKeyEnabled = false
        pauseKey = 58
        pauseKeyName = "Option"

        saveSettings()
    }
}
