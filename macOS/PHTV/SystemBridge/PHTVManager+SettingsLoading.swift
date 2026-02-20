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

        PHTVSetEmojiHotkeySettings(enabled, modifiers, keyCode)
    }

    @objc(phtv_loadRuntimeSettingsFromUserDefaults)
    class func phtv_loadRuntimeSettingsFromUserDefaults() -> UInt {
        let defaults = UserDefaults.standard

        let language = phtv_readIntWithFallback(
            defaults: defaults,
            key: "InputMethod",
            fallback: Int32(PHTVGetCurrentLanguage())
        )
        PHTVSetCurrentLanguage(language)

        let inputType = phtv_readIntWithFallback(
            defaults: defaults,
            key: "InputType",
            fallback: Int32(PHTVGetCurrentInputType())
        )
        PHTVSetCurrentInputType(inputType)

        let codeTable = phtv_readIntWithFallback(
            defaults: defaults,
            key: "CodeTable",
            fallback: Int32(PHTVGetCurrentCodeTable())
        )
        PHTVSetCurrentCodeTable(codeTable)

        NSLog(
            "[AppDelegate] Loaded core settings: language=%d, inputType=%d, codeTable=%d",
            language,
            inputType,
            codeTable
        )

        PHTVSetUseModernOrthography(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "ModernOrthography",
                fallback: Int32(PHTVGetUseModernOrthography())
            )
        )
        PHTVSetQuickTelex(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "QuickTelex",
                fallback: Int32(PHTVGetQuickTelex())
            )
        )
        PHTVSetFreeMark(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "FreeMark",
                fallback: Int32(PHTVGetFreeMark())
            )
        )

        PHTVSetUseMacro(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "UseMacro",
                fallback: Int32(PHTVGetUseMacro())
            )
        )
        PHTVSetUseMacroInEnglishMode(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "UseMacroInEnglishMode",
                fallback: Int32(PHTVGetUseMacroInEnglishMode())
            )
        )
        PHTVSetAutoCapsMacro(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "vAutoCapsMacro",
                fallback: Int32(PHTVGetAutoCapsMacro())
            )
        )

        PHTVSetSendKeyStepByStepEnabled(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "SendKeyStepByStep",
                fallback: PHTVIsSendKeyStepByStepEnabled() ? 1 : 0
            ) != 0
        )
        PHTVSetUseSmartSwitchKey(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "UseSmartSwitchKey",
                fallback: PHTVIsSmartSwitchKeyEnabled() ? 1 : 0
            ) != 0
        )
        PHTVSetUpperCaseFirstChar(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "UpperCaseFirstChar",
                fallback: Int32(PHTVGetUpperCaseFirstChar())
            )
        )
        PHTVSetAllowConsonantZFWJ(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "vAllowConsonantZFWJ",
                fallback: 1
            )
        )
        PHTVSetQuickStartConsonant(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "vQuickStartConsonant",
                fallback: Int32(PHTVGetQuickStartConsonant())
            )
        )
        PHTVSetQuickEndConsonant(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "vQuickEndConsonant",
                fallback: Int32(PHTVGetQuickEndConsonant())
            )
        )
        PHTVSetRememberCode(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "vRememberCode",
                fallback: Int32(PHTVGetRememberCode())
            )
        )
        PHTVSetPerformLayoutCompat(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "vPerformLayoutCompat",
                fallback: Int32(PHTVGetPerformLayoutCompat())
            )
        )

        PHTVSetRestoreOnEscape(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "vRestoreOnEscape",
                fallback: Int32(PHTVGetRestoreOnEscape())
            )
        )
        PHTVSetCustomEscapeKey(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "vCustomEscapeKey",
                fallback: Int32(PHTVGetCustomEscapeKey())
            )
        )
        PHTVSetPauseKeyEnabled(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "vPauseKeyEnabled",
                fallback: Int32(PHTVGetPauseKeyEnabled())
            )
        )
        PHTVSetPauseKey(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "vPauseKey",
                fallback: Int32(PHTVGetPauseKey())
            )
        )

        PHTVSetAutoRestoreEnglishWord(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "vAutoRestoreEnglishWord",
                fallback: Int32(PHTVGetAutoRestoreEnglishWord())
            )
        )
        PHTVSetShowIconOnDock(
            phtv_readIntWithFallback(
                defaults: defaults,
                key: "vShowIconOnDock",
                fallback: Int32(PHTVGetShowIconOnDock())
            ) != 0
        )

        let savedHotkey = defaults.integer(forKey: "SwitchKeyStatus")
        if savedHotkey != 0 {
            PHTVSetSwitchKeyStatus(Int32(savedHotkey))
            NSLog("[AppDelegate] Loaded hotkey from UserDefaults: 0x%X", savedHotkey)
        } else {
            NSLog("[AppDelegate] No saved hotkey found, using default: 0x%X", PHTVGetSwitchKeyStatus())
        }

        phtv_loadEmojiHotkeySettingsFromDefaults()

        let settingsToken = phtv_computeSettingsToken(defaults: defaults)
        NSLog("[AppDelegate] All settings loaded from UserDefaults")
        return settingsToken
    }

    @objc(phtv_loadDefaultConfig)
    class func phtv_loadDefaultConfig() {
        let defaults = UserDefaults.standard

        PHTVSetCurrentLanguage(1)
        defaults.set(1, forKey: "InputMethod")

        PHTVSetCurrentInputType(0)
        defaults.set(0, forKey: "InputType")

        PHTVSetFreeMark(0)
        defaults.set(0, forKey: "FreeMark")

        PHTVSetCheckSpelling(1)
        defaults.set(1, forKey: "Spelling")

        PHTVSetCurrentCodeTable(0)
        defaults.set(0, forKey: "CodeTable")

        let defaultSwitchHotkey = PHTVDefaultSwitchHotkeyStatus()
        PHTVSetSwitchKeyStatus(defaultSwitchHotkey)
        defaults.set(Int(defaultSwitchHotkey), forKey: "SwitchKeyStatus")

        PHTVSetQuickTelex(0)
        defaults.set(0, forKey: "QuickTelex")

        PHTVSetUseModernOrthography(1)
        defaults.set(1, forKey: "ModernOrthography")

        PHTVSetFixRecommendBrowser(1)
        defaults.set(1, forKey: "FixRecommendBrowser")

        PHTVSetUseMacro(1)
        defaults.set(1, forKey: "UseMacro")

        PHTVSetUseMacroInEnglishMode(0)
        defaults.set(0, forKey: "UseMacroInEnglishMode")

        PHTVSetSendKeyStepByStepEnabled(false)
        defaults.set(0, forKey: "SendKeyStepByStep")

        PHTVSetUseSmartSwitchKey(true)
        defaults.set(1, forKey: "UseSmartSwitchKey")

        PHTVSetUpperCaseFirstChar(0)
        defaults.set(0, forKey: "UpperCaseFirstChar")

        PHTVSetTempOffSpelling(0)
        defaults.set(0, forKey: "vTempOffSpelling")

        PHTVSetAllowConsonantZFWJ(1)
        defaults.set(1, forKey: "vAllowConsonantZFWJ")

        PHTVSetQuickStartConsonant(0)
        defaults.set(0, forKey: "vQuickStartConsonant")

        PHTVSetQuickEndConsonant(0)
        defaults.set(0, forKey: "vQuickEndConsonant")

        PHTVSetRememberCode(1)
        defaults.set(1, forKey: "vRememberCode")

        PHTVSetOtherLanguage(1)
        defaults.set(1, forKey: "vOtherLanguage")

        PHTVSetTempOffPHTV(0)
        defaults.set(0, forKey: "vTempOffPHTV")

        PHTVSetAutoRestoreEnglishWord(1)
        defaults.set(1, forKey: "vAutoRestoreEnglishWord")

        PHTVSetRestoreOnEscape(1)
        defaults.set(1, forKey: "vRestoreOnEscape")

        PHTVSetCustomEscapeKey(0)
        defaults.set(0, forKey: "vCustomEscapeKey")

        PHTVSetShowIconOnDock(false)
        defaults.set(0, forKey: "vShowIconOnDock")

        PHTVSetPerformLayoutCompat(0)
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

        let defaultPauseKey = PHTVDefaultPauseKey()
        PHTVSetPauseKeyEnabled(0)
        PHTVSetPauseKey(defaultPauseKey)
    }
}
