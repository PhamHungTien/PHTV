//
//  PHTVManager+SettingsLoading.swift
//  PHTV
//
//  Settings load/default methods for PHTVManager.
//

import AppKit
import Foundation

@objc extension PHTVManager {
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

    private class func phtv_foldSettingsToken(_ token: UInt, _ value: Any?) -> UInt {
        let hashValue = UInt(bitPattern: (value as AnyObject?)?.hash ?? 0)
        return (token &* 16_777_619) ^ hashValue
    }

    private class func phtv_computeSettingsToken(defaults: UserDefaults) -> UInt {
        var token: UInt = 2_166_136_261
        let tokenKeys = [
            "Spelling",
            "ModernOrthography",
            "QuickTelex",
            "UseMacro",
            "UseMacroInEnglishMode",
            "vAutoCapsMacro",
            "SendKeyStepByStep",
            "UseSmartSwitchKey",
            "UpperCaseFirstChar",
            "vAllowConsonantZFWJ",
            "vQuickStartConsonant",
            "vQuickEndConsonant",
            "vRememberCode",
            "vPerformLayoutCompat",
            "vShowIconOnDock",
            "vRestoreOnEscape",
            "vCustomEscapeKey",
            "vPauseKeyEnabled",
            "vPauseKey",
            "vAutoRestoreEnglishWord",
            "vEnableEmojiHotkey",
            "vEmojiHotkeyModifiers",
            "vEmojiHotkeyKeyCode"
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

        let enabled: Int32
        if defaults.object(forKey: "vEnableEmojiHotkey") == nil {
            enabled = 1
        } else {
            enabled = defaults.bool(forKey: "vEnableEmojiHotkey") ? 1 : 0
        }

        let modifiers: Int32
        if defaults.object(forKey: "vEmojiHotkeyModifiers") == nil {
            modifiers = Int32(NSEvent.ModifierFlags.command.rawValue)
        } else {
            modifiers = Int32(defaults.integer(forKey: "vEmojiHotkeyModifiers"))
        }

        let keyCode: Int32
        if defaults.object(forKey: "vEmojiHotkeyKeyCode") == nil {
            keyCode = 14
        } else {
            keyCode = Int32(defaults.integer(forKey: "vEmojiHotkeyKeyCode"))
        }

        PHTVEngineRuntimeFacade.setEmojiHotkeySettings(enabled, modifiers, keyCode)
    }

    @objc(phtv_loadRuntimeSettingsFromUserDefaults)
    class func phtv_loadRuntimeSettingsFromUserDefaults() -> UInt {
        let defaults = UserDefaults.standard

        let language = phtv_readIntWithFallback(
            defaults: defaults,
            key: "InputMethod",
            fallback: Int32(PHTVEngineRuntimeFacade.currentLanguage())
        )
        PHTVEngineRuntimeFacade.setCurrentLanguage(language)

        let inputType = phtv_readIntWithFallback(
            defaults: defaults,
            key: "InputType",
            fallback: Int32(PHTVEngineRuntimeFacade.currentInputType())
        )
        PHTVEngineRuntimeFacade.setCurrentInputType(inputType)

        let codeTable = phtv_readIntWithFallback(
            defaults: defaults,
            key: "CodeTable",
            fallback: Int32(PHTVEngineRuntimeFacade.currentCodeTable())
        )
        PHTVEngineRuntimeFacade.setCurrentCodeTable(codeTable)

        let checkSpelling = phtv_readIntWithFallback(
            defaults: defaults,
            key: "Spelling",
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

        PHTVEngineRuntimeFacade.setUseModernOrthography(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "ModernOrthography",
                fallback: Int32(PHTVEngineRuntimeFacade.useModernOrthography())
            )
        )
        PHTVEngineRuntimeFacade.setQuickTelex(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "QuickTelex",
                fallback: Int32(PHTVEngineRuntimeFacade.quickTelex())
            )
        )
        PHTVEngineRuntimeFacade.setFreeMark(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "FreeMark",
                fallback: Int32(PHTVEngineRuntimeFacade.freeMark())
            )
        )

        PHTVEngineRuntimeFacade.setUseMacro(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "UseMacro",
                fallback: Int32(PHTVEngineRuntimeFacade.useMacro())
            )
        )
        PHTVEngineRuntimeFacade.setUseMacroInEnglishMode(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "UseMacroInEnglishMode",
                fallback: Int32(PHTVEngineRuntimeFacade.useMacroInEnglishMode())
            )
        )
        PHTVEngineRuntimeFacade.setAutoCapsMacro(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "vAutoCapsMacro",
                fallback: Int32(PHTVEngineRuntimeFacade.autoCapsMacro())
            )
        )

        PHTVEngineRuntimeFacade.setSendKeyStepByStepEnabled(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "SendKeyStepByStep",
                fallback: PHTVEngineRuntimeFacade.isSendKeyStepByStepEnabled() ? 1 : 0
            ) != 0
        )
        PHTVEngineRuntimeFacade.setSmartSwitchKeyEnabled(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "UseSmartSwitchKey",
                fallback: PHTVEngineRuntimeFacade.isSmartSwitchKeyEnabled() ? 1 : 0
            ) != 0
        )
        PHTVEngineRuntimeFacade.setUpperCaseFirstChar(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "UpperCaseFirstChar",
                fallback: Int32(PHTVEngineRuntimeFacade.upperCaseFirstChar())
            )
        )
        PHTVEngineRuntimeFacade.setAllowConsonantZFWJ(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "vAllowConsonantZFWJ",
                fallback: 1
            )
        )
        PHTVEngineRuntimeFacade.setQuickStartConsonant(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "vQuickStartConsonant",
                fallback: Int32(PHTVEngineRuntimeFacade.quickStartConsonant())
            )
        )
        PHTVEngineRuntimeFacade.setQuickEndConsonant(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "vQuickEndConsonant",
                fallback: Int32(PHTVEngineRuntimeFacade.quickEndConsonant())
            )
        )
        PHTVEngineRuntimeFacade.setRememberCode(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "vRememberCode",
                fallback: Int32(PHTVEngineRuntimeFacade.rememberCode())
            )
        )
        PHTVEngineRuntimeFacade.setPerformLayoutCompat(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "vPerformLayoutCompat",
                fallback: Int32(PHTVEngineRuntimeFacade.performLayoutCompat())
            )
        )

        PHTVEngineRuntimeFacade.setRestoreOnEscape(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "vRestoreOnEscape",
                fallback: Int32(PHTVEngineRuntimeFacade.restoreOnEscape())
            )
        )
        PHTVEngineRuntimeFacade.setCustomEscapeKey(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "vCustomEscapeKey",
                fallback: Int32(PHTVEngineRuntimeFacade.customEscapeKey())
            )
        )
        PHTVEngineRuntimeFacade.setPauseKeyEnabled(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "vPauseKeyEnabled",
                fallback: Int32(PHTVEngineRuntimeFacade.pauseKeyEnabled())
            )
        )
        PHTVEngineRuntimeFacade.setPauseKey(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "vPauseKey",
                fallback: Int32(PHTVEngineRuntimeFacade.pauseKey())
            )
        )

        PHTVEngineRuntimeFacade.setAutoRestoreEnglishWord(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "vAutoRestoreEnglishWord",
                fallback: Int32(PHTVEngineRuntimeFacade.autoRestoreEnglishWord())
            )
        )
        PHTVEngineRuntimeFacade.setShowIconOnDock(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "vShowIconOnDock",
                fallback: Int32(PHTVEngineRuntimeFacade.showIconOnDock())
            ) != 0
        )

        let savedHotkey = defaults.integer(forKey: "SwitchKeyStatus")
        if savedHotkey != 0 {
            PHTVEngineRuntimeFacade.setSwitchKeyStatus(Int32(savedHotkey))
            NSLog("[AppDelegate] Loaded hotkey from UserDefaults: 0x%X", savedHotkey)
        } else {
            NSLog("[AppDelegate] No saved hotkey found, using default: 0x%X", PHTVEngineRuntimeFacade.switchKeyStatus())
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
        defaults.set(1, forKey: "InputMethod")

        PHTVEngineRuntimeFacade.setCurrentInputType(0)
        defaults.set(0, forKey: "InputType")

        PHTVEngineRuntimeFacade.setFreeMark(0)
        defaults.set(0, forKey: "FreeMark")

        PHTVEngineRuntimeFacade.setCheckSpelling(1)
        defaults.set(1, forKey: "Spelling")

        PHTVEngineRuntimeFacade.setCurrentCodeTable(0)
        defaults.set(0, forKey: "CodeTable")

        let defaultSwitchHotkey = PHTVEngineRuntimeFacade.defaultSwitchHotkeyStatus()
        PHTVEngineRuntimeFacade.setSwitchKeyStatus(defaultSwitchHotkey)
        defaults.set(Int(defaultSwitchHotkey), forKey: "SwitchKeyStatus")

        PHTVEngineRuntimeFacade.setQuickTelex(0)
        defaults.set(0, forKey: "QuickTelex")

        PHTVEngineRuntimeFacade.setUseModernOrthography(1)
        defaults.set(1, forKey: "ModernOrthography")

        PHTVEngineRuntimeFacade.setFixRecommendBrowser(1)
        defaults.set(1, forKey: "FixRecommendBrowser")

        PHTVEngineRuntimeFacade.setUseMacro(1)
        defaults.set(1, forKey: "UseMacro")

        PHTVEngineRuntimeFacade.setUseMacroInEnglishMode(0)
        defaults.set(0, forKey: "UseMacroInEnglishMode")

        PHTVEngineRuntimeFacade.setSendKeyStepByStepEnabled(false)
        defaults.set(0, forKey: "SendKeyStepByStep")

        PHTVEngineRuntimeFacade.setSmartSwitchKeyEnabled(true)
        defaults.set(1, forKey: "UseSmartSwitchKey")

        PHTVEngineRuntimeFacade.setUpperCaseFirstChar(0)
        defaults.set(0, forKey: "UpperCaseFirstChar")

        PHTVEngineRuntimeFacade.setTempOffSpelling(0)
        defaults.set(0, forKey: "vTempOffSpelling")

        PHTVEngineRuntimeFacade.setAllowConsonantZFWJ(1)
        defaults.set(1, forKey: "vAllowConsonantZFWJ")

        PHTVEngineRuntimeFacade.setQuickStartConsonant(0)
        defaults.set(0, forKey: "vQuickStartConsonant")

        PHTVEngineRuntimeFacade.setQuickEndConsonant(0)
        defaults.set(0, forKey: "vQuickEndConsonant")

        PHTVEngineRuntimeFacade.setRememberCode(1)
        defaults.set(1, forKey: "vRememberCode")

        PHTVEngineRuntimeFacade.setOtherLanguageMode(1)
        defaults.set(1, forKey: "vOtherLanguage")

        PHTVEngineRuntimeFacade.setTempOffEngine(0)
        defaults.set(0, forKey: "vTempOffPHTV")

        PHTVEngineRuntimeFacade.setAutoRestoreEnglishWord(1)
        defaults.set(1, forKey: "vAutoRestoreEnglishWord")

        PHTVEngineRuntimeFacade.setRestoreOnEscape(1)
        defaults.set(1, forKey: "vRestoreOnEscape")

        PHTVEngineRuntimeFacade.setCustomEscapeKey(0)
        defaults.set(0, forKey: "vCustomEscapeKey")

        PHTVEngineRuntimeFacade.setShowIconOnDock(false)
        defaults.set(0, forKey: "vShowIconOnDock")

        PHTVEngineRuntimeFacade.setPerformLayoutCompat(0)
        defaults.set(0, forKey: "vPerformLayoutCompat")

        defaults.set(1, forKey: "GrayIcon")
        defaults.set(false, forKey: "PHTV_RunOnStartup")
        defaults.set(0, forKey: "RunOnStartup")
        defaults.set(1, forKey: "vSettingsWindowAlwaysOnTop")
        defaults.set(0, forKey: "vBeepOnModeSwitch")
        defaults.set(0.5, forKey: "vBeepVolume")
        defaults.set(18.0, forKey: "vMenuBarIconSize")
        defaults.set(0, forKey: "vUseVietnameseMenubarIcon")

        defaults.set(86_400, forKey: "SUScheduledCheckInterval")
        defaults.set(true, forKey: "vAutoInstallUpdates")

        defaults.set(true, forKey: "vIncludeSystemInfo")
        defaults.set(false, forKey: "vIncludeLogs")
        defaults.set(true, forKey: "vIncludeCrashLogs")

        let defaultPauseKey = PHTVEngineRuntimeFacade.defaultPauseKey()
        PHTVEngineRuntimeFacade.setPauseKeyEnabled(0)
        PHTVEngineRuntimeFacade.setPauseKey(defaultPauseKey)
    }
}
