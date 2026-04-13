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
        let allowedMask = keyMask | modifierMask | beepMask

        let raw = UInt32(bitPattern: rawStatus)
        let filtered = raw & allowedMask
        let modifiers = filtered & modifierMask
        let key = filtered & keyMask
        let keyIsValid = key != UInt32(KeyCode.keyMask)

        guard modifiers != 0, keyIsValid else {
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
            UserDefaultsKey.emojiHotkeyKeyCode
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
            fallback: Int32(PHTVEngineRuntimeFacade.checkSpelling())
        )
        PHTVEngineRuntimeFacade.setCheckSpelling(checkSpelling)

        NSLog(
            "[AppDelegate] Loaded core settings: language=%d, inputType=%d, codeTable=%d, spelling=%d",
            language,
            inputType,
            codeTable,
            checkSpelling
        )

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

        phtv_loadEmojiHotkeySettingsFromDefaults()

        let settingsToken = phtv_computeSettingsToken(defaults: defaults)
        NSLog("[AppDelegate] All settings loaded from UserDefaults")
        return settingsToken
    }

    @objc(phtv_loadDefaultConfig)
    class func phtv_loadDefaultConfig() {
        let defaults = UserDefaults.standard

        PHTVEngineRuntimeFacade.setCurrentLanguage(1)
        defaults.set(1, forKey: UserDefaultsKey.inputMethod)

        PHTVEngineRuntimeFacade.setCurrentInputType(0)
        defaults.set(0, forKey: UserDefaultsKey.inputType)

        PHTVEngineRuntimeFacade.setFreeMark(0)
        defaults.set(0, forKey: UserDefaultsKey.freeMark)

        PHTVEngineRuntimeFacade.setCheckSpelling(1)
        defaults.set(1, forKey: UserDefaultsKey.spelling)

        PHTVEngineRuntimeFacade.setCurrentCodeTable(0)
        defaults.set(0, forKey: UserDefaultsKey.codeTable)

        let defaultSwitchHotkey = Int32(Defaults.defaultSwitchKeyStatus)
        PHTVEngineRuntimeFacade.setSwitchKeyStatus(defaultSwitchHotkey)
        defaults.set(Int(defaultSwitchHotkey), forKey: UserDefaultsKey.switchKeyStatus)

        PHTVEngineRuntimeFacade.setQuickTelex(0)
        defaults.set(0, forKey: UserDefaultsKey.quickTelex)

        PHTVEngineRuntimeFacade.setUseModernOrthography(1)
        defaults.set(1, forKey: UserDefaultsKey.modernOrthography)

        PHTVEngineRuntimeFacade.setFixRecommendBrowser(1)
        defaults.set(1, forKey: UserDefaultsKey.fixRecommendBrowser)

        PHTVEngineRuntimeFacade.setUseMacro(1)
        defaults.set(1, forKey: UserDefaultsKey.useMacro)

        PHTVEngineRuntimeFacade.setUseMacroInEnglishMode(0)
        defaults.set(0, forKey: UserDefaultsKey.useMacroInEnglishMode)

        PHTVEngineRuntimeFacade.setSendKeyStepByStepEnabled(false)
        defaults.set(0, forKey: UserDefaultsKey.sendKeyStepByStep)

        PHTVEngineRuntimeFacade.setSmartSwitchKeyEnabled(true)
        defaults.set(1, forKey: UserDefaultsKey.useSmartSwitchKey)

        PHTVEngineRuntimeFacade.setUpperCaseFirstChar(0)
        defaults.set(0, forKey: UserDefaultsKey.upperCaseFirstChar)

        PHTVEngineRuntimeFacade.setTempOffSpelling(0)
        defaults.set(0, forKey: UserDefaultsKey.tempOffSpelling)

        PHTVEngineRuntimeFacade.setAllowConsonantZFWJ(1)
        defaults.set(1, forKey: UserDefaultsKey.allowConsonantZFWJ)

        PHTVEngineRuntimeFacade.setQuickStartConsonant(0)
        defaults.set(0, forKey: UserDefaultsKey.quickStartConsonant)

        PHTVEngineRuntimeFacade.setQuickEndConsonant(0)
        defaults.set(0, forKey: UserDefaultsKey.quickEndConsonant)

        PHTVEngineRuntimeFacade.setRememberCode(1)
        defaults.set(1, forKey: UserDefaultsKey.rememberCode)

        PHTVEngineRuntimeFacade.setOtherLanguageMode(1)
        defaults.set(1, forKey: UserDefaultsKey.otherLanguage)

        PHTVEngineRuntimeFacade.setTempOffEngine(0)
        defaults.set(0, forKey: UserDefaultsKey.tempOffPHTV)

        PHTVEngineRuntimeFacade.setAutoRestoreEnglishWord(1)
        defaults.set(1, forKey: UserDefaultsKey.autoRestoreEnglishWord)
        PHTVEngineRuntimeFacade.setAutoRestoreEnglishWordMode(Int32(Defaults.autoRestoreEnglishWordMode.rawValue))
        defaults.set(Defaults.autoRestoreEnglishWordMode.rawValue, forKey: UserDefaultsKey.autoRestoreEnglishWordMode)
        let restoreIfWrongSpelling = Defaults.restoreIfWrongSpelling ? 1 : 0
        PHTVEngineRuntimeFacade.setRestoreIfWrongSpelling(Int32(restoreIfWrongSpelling))
        defaults.set(restoreIfWrongSpelling, forKey: UserDefaultsKey.restoreIfWrongSpelling)

        PHTVEngineRuntimeFacade.setRestoreOnEscape(1)
        defaults.set(1, forKey: UserDefaultsKey.restoreOnEscape)

        PHTVEngineRuntimeFacade.setCustomEscapeKey(0)
        defaults.set(0, forKey: UserDefaultsKey.customEscapeKey)

        PHTVEngineRuntimeFacade.setShowIconOnDock(false)
        defaults.set(0, forKey: UserDefaultsKey.showIconOnDock)

        PHTVEngineRuntimeFacade.setPerformLayoutCompat(0)
        defaults.set(0, forKey: UserDefaultsKey.performLayoutCompat)

        defaults.set(1, forKey: UserDefaultsKey.grayIcon)
        defaults.set(false, forKey: UserDefaultsKey.runOnStartup)
        defaults.set(0, forKey: UserDefaultsKey.runOnStartupLegacy)
        defaults.set(1, forKey: UserDefaultsKey.settingsWindowAlwaysOnTop)
        defaults.set(0, forKey: UserDefaultsKey.beepOnModeSwitch)
        defaults.set(0.5, forKey: UserDefaultsKey.beepVolume)
        defaults.set(18.0, forKey: UserDefaultsKey.menuBarIconSize)
        defaults.set(0, forKey: UserDefaultsKey.useVietnameseMenubarIcon)

        defaults.set(86_400, forKey: UserDefaultsKey.updateCheckInterval)
        defaults.set(true, forKey: UserDefaultsKey.legacyAutoInstallUpdates)

        defaults.set(true, forKey: UserDefaultsKey.includeSystemInfo)
        defaults.set(false, forKey: UserDefaultsKey.includeLogs)
        defaults.set(true, forKey: UserDefaultsKey.includeCrashLogs)

        let defaultPauseKey = Int32(KeyCode.leftOption)
        PHTVEngineRuntimeFacade.setPauseKeyEnabled(0)
        PHTVEngineRuntimeFacade.setPauseKey(defaultPauseKey)
    }
}
