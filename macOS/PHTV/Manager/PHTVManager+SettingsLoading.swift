//
//  PHTVManager+SettingsLoading.swift
//  PHTV
//
//  Settings load/default methods for PHTVManager.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit
import Foundation

private struct PHTVLastLoggedCoreSettings {
    var language: Int32 = -1
    var inputType: Int32 = -1
    var codeTable: Int32 = -1
    var checkSpelling: Int32 = -1
}

private final class PHTVCoreSettingsLogState: @unchecked Sendable {
    private let lock = NSLock()
    private var lastLoggedSettings = PHTVLastLoggedCoreSettings()
    private var loadCount = 0

    func shouldLogAndRecord(_ settings: PHTVLastLoggedCoreSettings) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        loadCount += 1
        let changed = settings.language != lastLoggedSettings.language
            || settings.inputType != lastLoggedSettings.inputType
            || settings.codeTable != lastLoggedSettings.codeTable
            || settings.checkSpelling != lastLoggedSettings.checkSpelling
        if changed || loadCount == 1 {
            lastLoggedSettings = settings
            return true
        }
        return false
    }
}

private let phtvCoreSettingsLogState = PHTVCoreSettingsLogState()

@objc extension PHTVManager {
    @nonobjc private class func phtv_decodeInt32(_ value: Any?) -> Int32? {
        switch value {
        case let int32Value as Int32:
            return int32Value
        case let intValue as Int:
            return Int32(clamping: intValue)
        case let numberValue as NSNumber:
            return numberValue.int32Value
        case let stringValue as String:
            let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let parsed = Int32(trimmed) else {
                return nil
            }
            return parsed
        default:
            return nil
        }
    }

    private class func phtv_readIntWithFallback(
        defaults: UserDefaults,
        key: String,
        fallback: Int32
    ) -> Int32 {
        guard defaults.object(forKey: key) != nil else {
            return fallback
        }
        return Int32(defaults.integer(forKey: key))
    }

    @nonobjc private class func phtv_readNormalizedIntWithFallback(
        defaults: UserDefaults,
        key: String,
        fallback: Int32,
        allowedRange: ClosedRange<Int32>,
        normalizedValue: Int32
    ) -> (value: Int32, normalized: Bool) {
        guard let persisted = defaults.object(forKey: key) else {
            return (fallback, false)
        }

        guard let parsedValue = phtv_decodeInt32(persisted),
              allowedRange.contains(parsedValue) else {
            return (normalizedValue, true)
        }

        return (parsedValue, false)
    }

    @nonobjc private class func phtv_normalizeSwitchKeyStatus(
        _ rawStatus: Int32,
        fallback: Int32
    ) -> (value: Int32, normalized: Bool) {
        let keyMask = UInt32(KeyCode.keyMask)
        let modifierMask = UInt32(
            KeyCode.controlMask
            | KeyCode.optionMask
            | KeyCode.commandMask
            | KeyCode.shiftMask
            | KeyCode.fnMask
        )
        let beepMask = UInt32(KeyCode.beepMask)
        let leftRightMask = UInt32(
            KeyCode.leftControlMask
            | KeyCode.rightControlMask
            | KeyCode.leftOptionMask
            | KeyCode.rightOptionMask
            | KeyCode.leftCommandMask
            | KeyCode.rightCommandMask
            | KeyCode.leftShiftMask
            | KeyCode.rightShiftMask
        )
        let allowedMask = keyMask | modifierMask | leftRightMask | beepMask

        let raw = UInt32(bitPattern: rawStatus)
        let filtered = raw & allowedMask
        let modifiers = filtered & modifierMask
        let key = filtered & keyMask
        let keyIsValid = key != UInt32(KeyCode.keyMask)

        let hasModifier = modifiers != 0
        let hasPhysicalKey = key != UInt32(KeyCode.noKey)
        let isNotSet = key == UInt32(KeyCode.noKey) && !hasModifier

        guard keyIsValid, (hasModifier || hasPhysicalKey || isNotSet) else {
            return (fallback, true)
        }

        let value = Int32(bitPattern: filtered)
        return (value, value != rawStatus)
    }

    private class func phtv_foldSettingsToken(_ token: UInt, _ value: Any?) -> UInt {
        let hashValue = UInt(bitPattern: (value as AnyObject?)?.hash ?? 0)
        return (token &* 16_777_619) ^ hashValue
    }

    @nonobjc private class func phtv_readAutoRestoreEnglishMode(defaults: UserDefaults) -> AutoRestoreEnglishMode {
        defaults.autoRestoreEnglishMode()
    }

    @nonobjc private class func phtv_restoreIfWrongSpellingValue(
        autoRestoreEnglishWord: Int32,
        mode: AutoRestoreEnglishMode
    ) -> Int32 {
        _ = autoRestoreEnglishWord
        _ = mode
        return 0
    }

    private class func phtv_computeSettingsToken(defaults: UserDefaults) -> UInt {
        var token: UInt = 2_166_136_261
        let tokenKeys = [
            UserDefaultsKey.spelling,
            UserDefaultsKey.modernOrthography,
            UserDefaultsKey.quickTelex,
            UserDefaultsKey.useMacro,
            UserDefaultsKey.useMacroInEnglishMode,
            UserDefaultsKey.autoCapsMacro,
            UserDefaultsKey.sendKeyStepByStep,
            UserDefaultsKey.useSmartSwitchKey,
            UserDefaultsKey.upperCaseFirstChar,
            UserDefaultsKey.allowConsonantZFWJ,
            UserDefaultsKey.quickStartConsonant,
            UserDefaultsKey.quickEndConsonant,
            UserDefaultsKey.rememberCode,
            UserDefaultsKey.performLayoutCompat,
            UserDefaultsKey.showIconOnDock,
            UserDefaultsKey.restoreOnEscape,
            UserDefaultsKey.customEscapeKey,
            UserDefaultsKey.pauseKeyEnabled,
            UserDefaultsKey.pauseKey,
            UserDefaultsKey.autoRestoreEnglishWord,
            UserDefaultsKey.autoRestoreEnglishWordMode,
            UserDefaultsKey.restoreIfWrongSpelling,
            UserDefaultsKey.enableEmojiHotkey,
            UserDefaultsKey.emojiHotkeyModifiers,
            UserDefaultsKey.emojiHotkeyKeyCode,
            UserDefaultsKey.switchKey2Status
        ]

        for key in tokenKeys {
            token = phtv_foldSettingsToken(token, defaults.object(forKey: key))
        }
        return token
    }

    @objc(phtv_currentSettingsTokenFromUserDefaults)
    class func phtv_currentSettingsTokenFromUserDefaults() -> UInt {
        return phtv_computeSettingsToken(defaults: .standard)
    }

    @objc(phtv_loadEmojiHotkeySettingsFromDefaults)
    class func phtv_loadEmojiHotkeySettingsFromDefaults() {
        let defaults = UserDefaults.standard

        let defaultEnabled: Int32 = 1
        let defaultModifiers = Int32(NSEvent.ModifierFlags.command.rawValue)
        let defaultKeyCode = Int32(KeyCode.eKey)
        let modifierMask = Int32(
            NSEvent.ModifierFlags.command.rawValue
            | NSEvent.ModifierFlags.option.rawValue
            | NSEvent.ModifierFlags.control.rawValue
            | NSEvent.ModifierFlags.shift.rawValue
            | NSEvent.ModifierFlags.function.rawValue
        )

        var shouldPersistNormalizedValues = false

        let enabled: Int32
        if defaults.object(forKey: UserDefaultsKey.enableEmojiHotkey) == nil {
            enabled = defaultEnabled
            shouldPersistNormalizedValues = true
        } else {
            enabled = defaults.bool(forKey: UserDefaultsKey.enableEmojiHotkey) ? 1 : 0
        }

        let rawModifiers = Int32(defaults.integer(forKey: UserDefaultsKey.emojiHotkeyModifiers))
        var modifiers = rawModifiers & modifierMask
        if modifiers == 0 {
            modifiers = defaultModifiers
            shouldPersistNormalizedValues = true
        } else if modifiers != rawModifiers {
            shouldPersistNormalizedValues = true
        }

        let rawKeyCode = defaults.integer(forKey: UserDefaultsKey.emojiHotkeyKeyCode)
        let isValidKeyCode = (0...Int(KeyCode.keyMask)).contains(rawKeyCode) || rawKeyCode == Int(KeyCode.noKey)
        let keyCode: Int32
        if isValidKeyCode {
            keyCode = Int32(rawKeyCode)
        } else {
            keyCode = defaultKeyCode
            shouldPersistNormalizedValues = true
        }

        if shouldPersistNormalizedValues {
            defaults.set(enabled != 0, forKey: UserDefaultsKey.enableEmojiHotkey)
            defaults.set(Int(modifiers), forKey: UserDefaultsKey.emojiHotkeyModifiers)
            defaults.set(Int(keyCode), forKey: UserDefaultsKey.emojiHotkeyKeyCode)
        }

        PHTVEngineRuntimeFacade.setEmojiHotkeySettings(enabled, modifiers, keyCode)
    }

    @objc(phtv_loadRuntimeSettingsFromUserDefaults)
    class func phtv_loadRuntimeSettingsFromUserDefaults() -> UInt {
        let defaults = UserDefaults.standard

        let languageSetting = phtv_readNormalizedIntWithFallback(
            defaults: defaults,
            key: UserDefaultsKey.inputMethod,
            fallback: Int32(PHTVEngineRuntimeFacade.currentLanguage()),
            allowedRange: 0...1,
            normalizedValue: 1
        )
        let language = languageSetting.value
        PHTVEngineRuntimeFacade.setCurrentLanguage(language)

        let inputTypeSetting = phtv_readNormalizedIntWithFallback(
            defaults: defaults,
            key: UserDefaultsKey.inputType,
            fallback: Int32(PHTVEngineRuntimeFacade.currentInputType()),
            allowedRange: 0...3,
            normalizedValue: 0
        )
        let inputType = inputTypeSetting.value
        PHTVEngineRuntimeFacade.setCurrentInputType(inputType)

        let codeTableSetting = phtv_readNormalizedIntWithFallback(
            defaults: defaults,
            key: UserDefaultsKey.codeTable,
            fallback: Int32(PHTVEngineRuntimeFacade.currentCodeTable()),
            allowedRange: 0...4,
            normalizedValue: 0
        )
        let codeTable = codeTableSetting.value
        PHTVEngineRuntimeFacade.setCurrentCodeTable(codeTable)

        if languageSetting.normalized {
            defaults.set(Int(language), forKey: UserDefaultsKey.inputMethod)
        }
        if inputTypeSetting.normalized {
            defaults.set(Int(inputType), forKey: UserDefaultsKey.inputType)
        }
        if codeTableSetting.normalized {
            defaults.set(Int(codeTable), forKey: UserDefaultsKey.codeTable)
        }

        let checkSpelling = phtv_readIntWithFallback(
            defaults: defaults,
            key: UserDefaultsKey.spelling,
            fallback: Defaults.checkSpelling ? 1 : 0
        )
        PHTVEngineRuntimeFacade.setCheckSpelling(checkSpelling)

        let shouldLogCoreSettings = phtvCoreSettingsLogState.shouldLogAndRecord(
            PHTVLastLoggedCoreSettings(
                language: language,
                inputType: inputType,
                codeTable: codeTable,
                checkSpelling: checkSpelling
            )
        )
        if shouldLogCoreSettings {
            NSLog(
                "[AppDelegate] Loaded core settings: language=%d, inputType=%d, codeTable=%d, spelling=%d",
                language,
                inputType,
                codeTable,
                checkSpelling
            )
        }

        if languageSetting.normalized || inputTypeSetting.normalized || codeTableSetting.normalized {
            NSLog(
                "[AppDelegate] Normalized invalid core settings (language=%d inputType=%d codeTable=%d)",
                language,
                inputType,
                codeTable
            )
        }

        PHTVEngineRuntimeFacade.setUseModernOrthography(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: UserDefaultsKey.modernOrthography,
                fallback: Int32(PHTVEngineRuntimeFacade.useModernOrthography())
            )
        )
        PHTVEngineRuntimeFacade.setQuickTelex(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: UserDefaultsKey.quickTelex,
                fallback: Int32(PHTVEngineRuntimeFacade.quickTelex())
            )
        )
        PHTVEngineRuntimeFacade.setFreeMark(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: UserDefaultsKey.freeMark,
                fallback: Int32(PHTVEngineRuntimeFacade.freeMark())
            )
        )

        PHTVEngineRuntimeFacade.setUseMacro(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: UserDefaultsKey.useMacro,
                fallback: Int32(PHTVEngineRuntimeFacade.useMacro())
            )
        )
        PHTVEngineRuntimeFacade.setUseMacroInEnglishMode(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: UserDefaultsKey.useMacroInEnglishMode,
                fallback: Int32(PHTVEngineRuntimeFacade.useMacroInEnglishMode())
            )
        )
        PHTVEngineRuntimeFacade.setAutoCapsMacro(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: UserDefaultsKey.autoCapsMacro,
                fallback: Int32(PHTVEngineRuntimeFacade.autoCapsMacro())
            )
        )

        PHTVEngineRuntimeFacade.setSendKeyStepByStepEnabled(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: UserDefaultsKey.sendKeyStepByStep,
                fallback: PHTVEngineRuntimeFacade.isSendKeyStepByStepEnabled() ? 1 : 0
            ) != 0
        )
        PHTVEngineRuntimeFacade.setSmartSwitchKeyEnabled(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: UserDefaultsKey.useSmartSwitchKey,
                fallback: PHTVEngineRuntimeFacade.isSmartSwitchKeyEnabled() ? 1 : 0
            ) != 0
        )
        PHTVEngineRuntimeFacade.setUpperCaseFirstChar(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: UserDefaultsKey.upperCaseFirstChar,
                fallback: Int32(PHTVEngineRuntimeFacade.upperCaseFirstChar())
            )
        )
        PHTVEngineRuntimeFacade.setAllowConsonantZFWJ(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: UserDefaultsKey.allowConsonantZFWJ,
                fallback: 1
            )
        )
        PHTVEngineRuntimeFacade.setQuickStartConsonant(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: UserDefaultsKey.quickStartConsonant,
                fallback: Int32(PHTVEngineRuntimeFacade.quickStartConsonant())
            )
        )
        PHTVEngineRuntimeFacade.setQuickEndConsonant(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: UserDefaultsKey.quickEndConsonant,
                fallback: Int32(PHTVEngineRuntimeFacade.quickEndConsonant())
            )
        )
        PHTVEngineRuntimeFacade.setRememberCode(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: UserDefaultsKey.rememberCode,
                fallback: Int32(PHTVEngineRuntimeFacade.rememberCode())
            )
        )
        PHTVEngineRuntimeFacade.setPerformLayoutCompat(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: UserDefaultsKey.performLayoutCompat,
                fallback: Int32(PHTVEngineRuntimeFacade.performLayoutCompat())
            )
        )

        PHTVEngineRuntimeFacade.setRestoreOnEscape(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: UserDefaultsKey.restoreOnEscape,
                fallback: Int32(PHTVEngineRuntimeFacade.restoreOnEscape())
            )
        )
        PHTVEngineRuntimeFacade.setCustomEscapeKey(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: UserDefaultsKey.customEscapeKey,
                fallback: Int32(PHTVEngineRuntimeFacade.customEscapeKey())
            )
        )
        PHTVEngineRuntimeFacade.setPauseKeyEnabled(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: UserDefaultsKey.pauseKeyEnabled,
                fallback: Int32(PHTVEngineRuntimeFacade.pauseKeyEnabled())
            )
        )
        PHTVEngineRuntimeFacade.setPauseKey(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: UserDefaultsKey.pauseKey,
                fallback: Int32(PHTVEngineRuntimeFacade.pauseKey())
            )
        )

        let autoRestoreEnglishWord = phtv_readIntWithFallback(
            defaults: defaults,
            key: UserDefaultsKey.autoRestoreEnglishWord,
            fallback: Int32(PHTVEngineRuntimeFacade.autoRestoreEnglishWord())
        )
        PHTVEngineRuntimeFacade.setAutoRestoreEnglishWord(autoRestoreEnglishWord)
        let autoRestoreMode = phtv_readAutoRestoreEnglishMode(defaults: defaults)
        PHTVEngineRuntimeFacade.setAutoRestoreEnglishWordMode(Int32(autoRestoreMode.rawValue))
        let restoreIfWrongSpelling = phtv_restoreIfWrongSpellingValue(
            autoRestoreEnglishWord: autoRestoreEnglishWord,
            mode: autoRestoreMode
        )
        PHTVEngineRuntimeFacade.setRestoreIfWrongSpelling(restoreIfWrongSpelling)
        defaults.set(autoRestoreMode.rawValue, forKey: UserDefaultsKey.autoRestoreEnglishWordMode)
        defaults.set(Int(restoreIfWrongSpelling), forKey: UserDefaultsKey.restoreIfWrongSpelling)
        PHTVEngineRuntimeFacade.setShowIconOnDock(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: UserDefaultsKey.showIconOnDock,
                fallback: Int32(PHTVEngineRuntimeFacade.showIconOnDock())
            ) != 0
        )

        let defaultSwitchHotkey = Int32(Defaults.defaultSwitchKeyStatus)
        let hasStoredSwitchHotkey = defaults.object(forKey: UserDefaultsKey.switchKeyStatus) != nil
        let rawSwitchHotkey = hasStoredSwitchHotkey
            ? Int32(truncatingIfNeeded: defaults.integer(forKey: UserDefaultsKey.switchKeyStatus))
            : defaultSwitchHotkey
        let normalizedSwitchHotkey = phtv_normalizeSwitchKeyStatus(
            rawSwitchHotkey,
            fallback: defaultSwitchHotkey
        )
        PHTVEngineRuntimeFacade.setSwitchKeyStatus(normalizedSwitchHotkey.value)

        if !hasStoredSwitchHotkey || normalizedSwitchHotkey.normalized {
            defaults.set(Int(normalizedSwitchHotkey.value), forKey: UserDefaultsKey.switchKeyStatus)
        }

        if normalizedSwitchHotkey.normalized {
            NSLog(
                "[AppDelegate] Normalized invalid SwitchKeyStatus 0x%X -> 0x%X",
                rawSwitchHotkey,
                normalizedSwitchHotkey.value
            )
        } else {
            NSLog("[AppDelegate] Loaded hotkey from UserDefaults: 0x%X", normalizedSwitchHotkey.value)
        }

        let switchKey2Migrated = defaults.bool(forKey: UserDefaultsKey.switchKey2Migrated)
        var rawSwitchKey2Status = Int32(truncatingIfNeeded: defaults.integer(forKey: UserDefaultsKey.switchKey2Status))
        if !switchKey2Migrated {
            if defaults.object(forKey: UserDefaultsKey.switchKey2Status) == nil || rawSwitchKey2Status == 0 {
                rawSwitchKey2Status = Int32(KeyCode.noKey)
                defaults.set(Int(KeyCode.noKey), forKey: UserDefaultsKey.switchKey2Status)
            }
            defaults.set(true, forKey: UserDefaultsKey.switchKey2Migrated)
        }
        PHTVEngineRuntimeFacade.setSwitchKey2Status(rawSwitchKey2Status)
        PHTVEngineRuntimeFacade.setSingleModifierSwitchKeys(0)

        phtv_loadEmojiHotkeySettingsFromDefaults()

        let settingsToken = phtv_computeSettingsToken(defaults: defaults)
        if shouldLogCoreSettings {
            NSLog("[AppDelegate] All settings loaded from UserDefaults")
        }
        return settingsToken
    }

    @objc(phtv_loadDefaultConfig)
    class func phtv_loadDefaultConfig() {
        let defaults = UserDefaults.standard

        PHTVEngineRuntimeFacade.setCurrentLanguage(1)
        defaults.set(1, forKey: UserDefaultsKey.inputMethod)

        PHTVEngineRuntimeFacade.setCurrentInputType(Int32(Defaults.inputMethod.toIndex()))
        defaults.set(Defaults.inputMethod.toIndex(), forKey: UserDefaultsKey.inputType)

        PHTVEngineRuntimeFacade.setFreeMark(0)
        defaults.set(0, forKey: UserDefaultsKey.freeMark)

        PHTVEngineRuntimeFacade.setCheckSpelling(Defaults.checkSpelling ? 1 : 0)
        defaults.set(Defaults.checkSpelling ? 1 : 0, forKey: UserDefaultsKey.spelling)

        PHTVEngineRuntimeFacade.setCurrentCodeTable(Int32(Defaults.codeTable.toIndex()))
        defaults.set(Defaults.codeTable.toIndex(), forKey: UserDefaultsKey.codeTable)

        let defaultSwitchHotkey = Int32(Defaults.defaultSwitchKeyStatus)
        PHTVEngineRuntimeFacade.setSwitchKeyStatus(defaultSwitchHotkey)
        defaults.set(Int(defaultSwitchHotkey), forKey: UserDefaultsKey.switchKeyStatus)

        PHTVEngineRuntimeFacade.setQuickTelex(Defaults.quickTelex ? 1 : 0)
        defaults.set(Defaults.quickTelex, forKey: UserDefaultsKey.quickTelex)

        PHTVEngineRuntimeFacade.setUseModernOrthography(Defaults.useModernOrthography ? 1 : 0)
        defaults.set(Defaults.useModernOrthography, forKey: UserDefaultsKey.modernOrthography)

        PHTVEngineRuntimeFacade.setFixRecommendBrowser(Defaults.fixRecommendBrowser ? 1 : 0)
        defaults.set(Defaults.fixRecommendBrowser ? 1 : 0, forKey: UserDefaultsKey.fixRecommendBrowser)

        PHTVEngineRuntimeFacade.setUseMacro(Defaults.useMacro ? 1 : 0)
        defaults.set(Defaults.useMacro, forKey: UserDefaultsKey.useMacro)

        PHTVEngineRuntimeFacade.setUseMacroInEnglishMode(Defaults.useMacroInEnglishMode ? 1 : 0)
        defaults.set(Defaults.useMacroInEnglishMode, forKey: UserDefaultsKey.useMacroInEnglishMode)

        PHTVEngineRuntimeFacade.setSendKeyStepByStepEnabled(Defaults.sendKeyStepByStep)
        defaults.set(Defaults.sendKeyStepByStep, forKey: UserDefaultsKey.sendKeyStepByStep)

        PHTVEngineRuntimeFacade.setSmartSwitchKeyEnabled(Defaults.useSmartSwitchKey)
        defaults.set(Defaults.useSmartSwitchKey, forKey: UserDefaultsKey.useSmartSwitchKey)

        PHTVEngineRuntimeFacade.setUpperCaseFirstChar(Defaults.upperCaseFirstChar ? 1 : 0)
        defaults.set(Defaults.upperCaseFirstChar, forKey: UserDefaultsKey.upperCaseFirstChar)

        PHTVEngineRuntimeFacade.setTempOffSpelling(0)
        defaults.set(0, forKey: UserDefaultsKey.tempOffSpelling)

        PHTVEngineRuntimeFacade.setAllowConsonantZFWJ(Defaults.allowConsonantZFWJ ? 1 : 0)
        defaults.set(Defaults.allowConsonantZFWJ, forKey: UserDefaultsKey.allowConsonantZFWJ)

        PHTVEngineRuntimeFacade.setQuickStartConsonant(Defaults.quickStartConsonant ? 1 : 0)
        defaults.set(Defaults.quickStartConsonant, forKey: UserDefaultsKey.quickStartConsonant)

        PHTVEngineRuntimeFacade.setQuickEndConsonant(Defaults.quickEndConsonant ? 1 : 0)
        defaults.set(Defaults.quickEndConsonant, forKey: UserDefaultsKey.quickEndConsonant)

        PHTVEngineRuntimeFacade.setRememberCode(Defaults.rememberCode ? 1 : 0)
        defaults.set(Defaults.rememberCode, forKey: UserDefaultsKey.rememberCode)

        PHTVEngineRuntimeFacade.setOtherLanguageMode(1)
        defaults.set(1, forKey: UserDefaultsKey.otherLanguage)

        PHTVEngineRuntimeFacade.setTempOffEngine(0)
        defaults.set(0, forKey: UserDefaultsKey.tempOffPHTV)

        let autoRestore = Defaults.autoRestoreEnglishWord ? 1 : 0
        PHTVEngineRuntimeFacade.setAutoRestoreEnglishWord(Int32(autoRestore))
        defaults.set(autoRestore, forKey: UserDefaultsKey.autoRestoreEnglishWord)
        PHTVEngineRuntimeFacade.setAutoRestoreEnglishWordMode(Int32(Defaults.autoRestoreEnglishWordMode.rawValue))
        defaults.set(Defaults.autoRestoreEnglishWordMode.rawValue, forKey: UserDefaultsKey.autoRestoreEnglishWordMode)
        let restoreIfWrongSpelling = Defaults.restoreIfWrongSpelling ? 1 : 0
        PHTVEngineRuntimeFacade.setRestoreIfWrongSpelling(Int32(restoreIfWrongSpelling))
        defaults.set(restoreIfWrongSpelling, forKey: UserDefaultsKey.restoreIfWrongSpelling)

        PHTVEngineRuntimeFacade.setRestoreOnEscape(Defaults.restoreOnEscape ? 1 : 0)
        defaults.set(Defaults.restoreOnEscape, forKey: UserDefaultsKey.restoreOnEscape)

        PHTVEngineRuntimeFacade.setCustomEscapeKey(Int32(Defaults.restoreKeyCode))
        defaults.set(Int(Defaults.restoreKeyCode), forKey: UserDefaultsKey.customEscapeKey)

        PHTVEngineRuntimeFacade.setShowIconOnDock(Defaults.showIconOnDock)
        defaults.set(Defaults.showIconOnDock, forKey: UserDefaultsKey.showIconOnDock)

        PHTVEngineRuntimeFacade.setPerformLayoutCompat(Defaults.performLayoutCompat ? 1 : 0)
        defaults.set(Defaults.performLayoutCompat, forKey: UserDefaultsKey.performLayoutCompat)

        defaults.set(1, forKey: UserDefaultsKey.grayIcon)
        defaults.set(Defaults.runOnStartup, forKey: UserDefaultsKey.runOnStartup)
        defaults.set(0, forKey: UserDefaultsKey.runOnStartupLegacy)
        defaults.set(Defaults.settingsWindowAlwaysOnTop, forKey: UserDefaultsKey.settingsWindowAlwaysOnTop)
        defaults.set(Defaults.beepOnModeSwitch, forKey: UserDefaultsKey.beepOnModeSwitch)
        defaults.set(Defaults.beepVolume, forKey: UserDefaultsKey.beepVolume)
        defaults.set(Defaults.menuBarIconSize, forKey: UserDefaultsKey.menuBarIconSize)
        defaults.set(Defaults.useVietnameseMenubarIcon, forKey: UserDefaultsKey.useVietnameseMenubarIcon)

        defaults.set(Defaults.updateCheckInterval, forKey: UserDefaultsKey.updateCheckInterval)
        defaults.set(Defaults.automaticUpdateChecks, forKey: UserDefaultsKey.automaticUpdateChecks)
        defaults.set(Defaults.autoInstallUpdates, forKey: UserDefaultsKey.autoInstallUpdates)
        defaults.enforceStableUpdateChannel()

        defaults.set(Defaults.includeSystemInfo, forKey: UserDefaultsKey.includeSystemInfo)
        defaults.set(Defaults.includeLogs, forKey: UserDefaultsKey.includeLogs)
        defaults.set(Defaults.includeCrashLogs, forKey: UserDefaultsKey.includeCrashLogs)

        let defaultPauseKey = Int32(Defaults.pauseKeyCode)
        PHTVEngineRuntimeFacade.setPauseKeyEnabled(Defaults.pauseKeyEnabled ? 1 : 0)
        PHTVEngineRuntimeFacade.setPauseKey(defaultPauseKey)
        defaults.set(Defaults.pauseKeyEnabled, forKey: UserDefaultsKey.pauseKeyEnabled)
        defaults.set(Int(Defaults.pauseKeyCode), forKey: UserDefaultsKey.pauseKey)
        defaults.set(Defaults.pauseKeyName, forKey: UserDefaultsKey.pauseKeyName)

        PHTVEngineRuntimeFacade.setSwitchKey2Status(Int32(KeyCode.noKey))
        defaults.set(Int(KeyCode.noKey), forKey: UserDefaultsKey.switchKey2Status)
        PHTVEngineRuntimeFacade.setSingleModifierSwitchKeys(0)
        defaults.set(0, forKey: UserDefaultsKey.singleModifierSwitchKeys)
    }
}
