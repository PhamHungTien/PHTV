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

        phtvRuntimeSetEmojiHotkeySettings(enabled, modifiers, keyCode)
    }

    @objc(phtv_loadRuntimeSettingsFromUserDefaults)
    class func phtv_loadRuntimeSettingsFromUserDefaults() -> UInt {
        let defaults = UserDefaults.standard

        let language = phtv_readIntWithFallback(
            defaults: defaults,
            key: "InputMethod",
            fallback: Int32(phtvRuntimeCurrentLanguage())
        )
        phtvRuntimeSetCurrentLanguage(language)

        let inputType = phtv_readIntWithFallback(
            defaults: defaults,
            key: "InputType",
            fallback: Int32(phtvRuntimeCurrentInputType())
        )
        phtvRuntimeSetCurrentInputType(inputType)

        let codeTable = phtv_readIntWithFallback(
            defaults: defaults,
            key: "CodeTable",
            fallback: Int32(phtvRuntimeCurrentCodeTable())
        )
        phtvRuntimeSetCurrentCodeTable(codeTable)

        let checkSpelling = phtv_readIntWithFallback(
            defaults: defaults,
            key: "Spelling",
            fallback: Int32(phtvRuntimeCheckSpelling())
        )
        phtvRuntimeSetCheckSpelling(checkSpelling)

        NSLog(
            "[AppDelegate] Loaded core settings: language=%d, inputType=%d, codeTable=%d, spelling=%d",
            language,
            inputType,
            codeTable,
            checkSpelling
        )

        phtvRuntimeSetUseModernOrthography(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "ModernOrthography",
                fallback: Int32(phtvRuntimeUseModernOrthography())
            )
        )
        phtvRuntimeSetQuickTelex(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "QuickTelex",
                fallback: Int32(phtvRuntimeQuickTelex())
            )
        )
        phtvRuntimeSetFreeMark(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "FreeMark",
                fallback: Int32(phtvRuntimeFreeMark())
            )
        )

        phtvRuntimeSetUseMacro(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "UseMacro",
                fallback: Int32(phtvRuntimeUseMacro())
            )
        )
        phtvRuntimeSetUseMacroInEnglishMode(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "UseMacroInEnglishMode",
                fallback: Int32(phtvRuntimeUseMacroInEnglishMode())
            )
        )
        phtvRuntimeSetAutoCapsMacro(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "vAutoCapsMacro",
                fallback: Int32(phtvRuntimeAutoCapsMacro())
            )
        )

        phtvRuntimeSetSendKeyStepByStepEnabled(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "SendKeyStepByStep",
                fallback: phtvRuntimeIsSendKeyStepByStepEnabled() ? 1 : 0
            ) != 0
        )
        phtvRuntimeSetUseSmartSwitchKey(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "UseSmartSwitchKey",
                fallback: phtvRuntimeIsSmartSwitchKeyEnabled() ? 1 : 0
            ) != 0
        )
        phtvRuntimeSetUpperCaseFirstChar(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "UpperCaseFirstChar",
                fallback: Int32(phtvRuntimeUpperCaseFirstChar())
            )
        )
        phtvRuntimeSetAllowConsonantZFWJ(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "vAllowConsonantZFWJ",
                fallback: 1
            )
        )
        phtvRuntimeSetQuickStartConsonant(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "vQuickStartConsonant",
                fallback: Int32(phtvRuntimeQuickStartConsonant())
            )
        )
        phtvRuntimeSetQuickEndConsonant(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "vQuickEndConsonant",
                fallback: Int32(phtvRuntimeQuickEndConsonant())
            )
        )
        phtvRuntimeSetRememberCode(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "vRememberCode",
                fallback: Int32(phtvRuntimeRememberCode())
            )
        )
        phtvRuntimeSetPerformLayoutCompat(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "vPerformLayoutCompat",
                fallback: Int32(phtvRuntimePerformLayoutCompat())
            )
        )

        phtvRuntimeSetRestoreOnEscape(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "vRestoreOnEscape",
                fallback: Int32(phtvRuntimeRestoreOnEscape())
            )
        )
        phtvRuntimeSetCustomEscapeKey(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "vCustomEscapeKey",
                fallback: Int32(phtvRuntimeCustomEscapeKey())
            )
        )
        phtvRuntimeSetPauseKeyEnabled(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "vPauseKeyEnabled",
                fallback: Int32(phtvRuntimePauseKeyEnabled())
            )
        )
        phtvRuntimeSetPauseKey(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "vPauseKey",
                fallback: Int32(phtvRuntimePauseKey())
            )
        )

        phtvRuntimeSetAutoRestoreEnglishWord(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "vAutoRestoreEnglishWord",
                fallback: Int32(phtvRuntimeAutoRestoreEnglishWord())
            )
        )
        phtvRuntimeSetShowIconOnDock(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "vShowIconOnDock",
                fallback: Int32(phtvRuntimeShowIconOnDock())
            ) != 0
        )

        let savedHotkey = defaults.integer(forKey: "SwitchKeyStatus")
        if savedHotkey != 0 {
            phtvRuntimeSetSwitchKeyStatus(Int32(savedHotkey))
            NSLog("[AppDelegate] Loaded hotkey from UserDefaults: 0x%X", savedHotkey)
        } else {
            NSLog("[AppDelegate] No saved hotkey found, using default: 0x%X", phtvRuntimeSwitchKeyStatus())
        }

        phtv_loadEmojiHotkeySettingsFromDefaults()

        let settingsToken = phtv_computeSettingsToken(defaults: defaults)
        NSLog("[AppDelegate] All settings loaded from UserDefaults")
        return settingsToken
    }

    @objc(phtv_loadDefaultConfig)
    class func phtv_loadDefaultConfig() {
        let defaults = UserDefaults.standard

        phtvRuntimeSetCurrentLanguage(1)
        defaults.set(1, forKey: "InputMethod")

        phtvRuntimeSetCurrentInputType(0)
        defaults.set(0, forKey: "InputType")

        phtvRuntimeSetFreeMark(0)
        defaults.set(0, forKey: "FreeMark")

        phtvRuntimeSetCheckSpelling(1)
        defaults.set(1, forKey: "Spelling")

        phtvRuntimeSetCurrentCodeTable(0)
        defaults.set(0, forKey: "CodeTable")

        let defaultSwitchHotkey = phtvRuntimeDefaultSwitchHotkeyStatus()
        phtvRuntimeSetSwitchKeyStatus(defaultSwitchHotkey)
        defaults.set(Int(defaultSwitchHotkey), forKey: "SwitchKeyStatus")

        phtvRuntimeSetQuickTelex(0)
        defaults.set(0, forKey: "QuickTelex")

        phtvRuntimeSetUseModernOrthography(1)
        defaults.set(1, forKey: "ModernOrthography")

        phtvRuntimeSetFixRecommendBrowser(1)
        defaults.set(1, forKey: "FixRecommendBrowser")

        phtvRuntimeSetUseMacro(1)
        defaults.set(1, forKey: "UseMacro")

        phtvRuntimeSetUseMacroInEnglishMode(0)
        defaults.set(0, forKey: "UseMacroInEnglishMode")

        phtvRuntimeSetSendKeyStepByStepEnabled(false)
        defaults.set(0, forKey: "SendKeyStepByStep")

        phtvRuntimeSetUseSmartSwitchKey(true)
        defaults.set(1, forKey: "UseSmartSwitchKey")

        phtvRuntimeSetUpperCaseFirstChar(0)
        defaults.set(0, forKey: "UpperCaseFirstChar")

        phtvRuntimeSetTempOffSpelling(0)
        defaults.set(0, forKey: "vTempOffSpelling")

        phtvRuntimeSetAllowConsonantZFWJ(1)
        defaults.set(1, forKey: "vAllowConsonantZFWJ")

        phtvRuntimeSetQuickStartConsonant(0)
        defaults.set(0, forKey: "vQuickStartConsonant")

        phtvRuntimeSetQuickEndConsonant(0)
        defaults.set(0, forKey: "vQuickEndConsonant")

        phtvRuntimeSetRememberCode(1)
        defaults.set(1, forKey: "vRememberCode")

        phtvRuntimeSetOtherLanguage(1)
        defaults.set(1, forKey: "vOtherLanguage")

        phtvRuntimeSetTempOffPHTV(0)
        defaults.set(0, forKey: "vTempOffPHTV")

        phtvRuntimeSetAutoRestoreEnglishWord(1)
        defaults.set(1, forKey: "vAutoRestoreEnglishWord")

        phtvRuntimeSetRestoreOnEscape(1)
        defaults.set(1, forKey: "vRestoreOnEscape")

        phtvRuntimeSetCustomEscapeKey(0)
        defaults.set(0, forKey: "vCustomEscapeKey")

        phtvRuntimeSetShowIconOnDock(false)
        defaults.set(0, forKey: "vShowIconOnDock")

        phtvRuntimeSetPerformLayoutCompat(0)
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

        let defaultPauseKey = phtvRuntimeDefaultPauseKey()
        phtvRuntimeSetPauseKeyEnabled(0)
        phtvRuntimeSetPauseKey(defaultPauseKey)
    }
}
