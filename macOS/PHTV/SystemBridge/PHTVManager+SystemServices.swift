//
//  PHTVManager+SystemServices.swift
//  PHTV
//
//  Swift port of service-wrapper methods from PHTVManager.m.
//

import AppKit
import Foundation

@objc extension PHTVManager {
    private class func phtv_toggleRuntimeIntSetting(
        currentValue: () -> Int32,
        applyValue: (Int32) -> Void,
        defaultsKey: String,
        syncSpellingBeforeSessionReset: Bool
    ) -> Int32 {
        let toggled: Int32 = currentValue() == 0 ? 1 : 0
        applyValue(toggled)

        UserDefaults.standard.set(Int(toggled), forKey: defaultsKey)
        if syncSpellingBeforeSessionReset {
            syncSpellingSetting()
        }

        phtv_requestNewSession()
        return toggled
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

    @objc(phtv_requestNewSession)
    class func phtv_requestNewSession() {
        RequestNewSession()
    }

    @objc(phtv_invalidateLayoutCache)
    class func phtv_invalidateLayoutCache() {
        InvalidateLayoutCache()
    }

    @objc(phtv_notifyInputMethodChanged)
    class func phtv_notifyInputMethodChanged() {
        OnInputMethodChanged()
    }

    @objc(phtv_notifyTableCodeChanged)
    class func phtv_notifyTableCodeChanged() {
        OnTableCodeChange()
    }

    @objc(phtv_notifyActiveAppChanged)
    class func phtv_notifyActiveAppChanged() {
        OnActiveAppChanged()
    }

    @objc(phtv_currentLanguage)
    class func phtv_currentLanguage() -> Int32 {
        Int32(PHTVGetCurrentLanguage())
    }

    @objc(phtv_setCurrentLanguage:)
    class func phtv_setCurrentLanguage(_ language: Int32) {
        PHTVSetCurrentLanguage(language)
    }

    @objc(phtv_currentInputType)
    class func phtv_currentInputType() -> Int32 {
        Int32(PHTVGetCurrentInputType())
    }

    @objc(phtv_setCurrentInputType:)
    class func phtv_setCurrentInputType(_ inputType: Int32) {
        PHTVSetCurrentInputType(inputType)
    }

    @objc(phtv_currentCodeTable)
    class func phtv_currentCodeTable() -> Int32 {
        Int32(PHTVGetCurrentCodeTable())
    }

    @objc(phtv_setCurrentCodeTable:)
    class func phtv_setCurrentCodeTable(_ codeTable: Int32) {
        PHTVSetCurrentCodeTable(codeTable)
    }

    @objc(phtv_isSmartSwitchKeyEnabled)
    class func phtv_isSmartSwitchKeyEnabled() -> Bool {
        PHTVIsSmartSwitchKeyEnabled()
    }

    @objc(phtv_isSendKeyStepByStepEnabled)
    class func phtv_isSendKeyStepByStepEnabled() -> Bool {
        PHTVIsSendKeyStepByStepEnabled()
    }

    @objc(phtv_setSendKeyStepByStepEnabled:)
    class func phtv_setSendKeyStepByStepEnabled(_ enabled: Bool) {
        PHTVSetSendKeyStepByStepEnabled(enabled)
    }

    @objc(phtv_setUpperCaseExcludedForCurrentApp:)
    class func phtv_setUpperCaseExcludedForCurrentApp(_ excluded: Bool) {
        PHTVSetUpperCaseExcludedForCurrentApp(excluded)
    }

    @objc(phtv_currentSwitchKeyStatus)
    class func phtv_currentSwitchKeyStatus() -> Int32 {
        Int32(PHTVGetSwitchKeyStatus())
    }

    @objc(phtv_setSwitchKeyStatus:)
    class func phtv_setSwitchKeyStatus(_ status: Int32) {
        PHTVSetSwitchKeyStatus(status)
    }

    @objc(phtv_setDockIconRuntimeVisible:)
    class func phtv_setDockIconRuntimeVisible(_ visible: Bool) {
        PHTVSetShowIconOnDock(visible)
    }

    @objc(phtv_toggleSpellCheckSetting)
    class func phtv_toggleSpellCheckSetting() -> Int32 {
        phtv_toggleRuntimeIntSetting(
            currentValue: { Int32(PHTVGetCheckSpelling()) },
            applyValue: { PHTVSetCheckSpelling($0) },
            defaultsKey: "Spelling",
            syncSpellingBeforeSessionReset: true
        )
    }

    @objc(phtv_toggleAllowConsonantZFWJSetting)
    class func phtv_toggleAllowConsonantZFWJSetting() -> Int32 {
        phtv_toggleRuntimeIntSetting(
            currentValue: { Int32(PHTVGetAllowConsonantZFWJ()) },
            applyValue: { PHTVSetAllowConsonantZFWJ($0) },
            defaultsKey: "vAllowConsonantZFWJ",
            syncSpellingBeforeSessionReset: false
        )
    }

    @objc(phtv_toggleModernOrthographySetting)
    class func phtv_toggleModernOrthographySetting() -> Int32 {
        phtv_toggleRuntimeIntSetting(
            currentValue: { Int32(PHTVGetUseModernOrthography()) },
            applyValue: { PHTVSetUseModernOrthography($0) },
            defaultsKey: "ModernOrthography",
            syncSpellingBeforeSessionReset: false
        )
    }

    @objc(phtv_toggleQuickTelexSetting)
    class func phtv_toggleQuickTelexSetting() -> Int32 {
        phtv_toggleRuntimeIntSetting(
            currentValue: { Int32(PHTVGetQuickTelex()) },
            applyValue: { PHTVSetQuickTelex($0) },
            defaultsKey: "QuickTelex",
            syncSpellingBeforeSessionReset: false
        )
    }

    @objc(phtv_toggleUpperCaseFirstCharSetting)
    class func phtv_toggleUpperCaseFirstCharSetting() -> Int32 {
        phtv_toggleRuntimeIntSetting(
            currentValue: { Int32(PHTVGetUpperCaseFirstChar()) },
            applyValue: { PHTVSetUpperCaseFirstChar($0) },
            defaultsKey: "UpperCaseFirstChar",
            syncSpellingBeforeSessionReset: false
        )
    }

    @objc(phtv_toggleAutoRestoreEnglishWordSetting)
    class func phtv_toggleAutoRestoreEnglishWordSetting() -> Int32 {
        phtv_toggleRuntimeIntSetting(
            currentValue: { Int32(PHTVGetAutoRestoreEnglishWord()) },
            applyValue: { PHTVSetAutoRestoreEnglishWord($0) },
            defaultsKey: "vAutoRestoreEnglishWord",
            syncSpellingBeforeSessionReset: false
        )
    }

    @objc(phtv_runtimeSettingsSnapshot)
    class func phtv_runtimeSettingsSnapshot() -> [String: NSNumber] {
        [
            "checkSpelling": NSNumber(value: PHTVGetCheckSpelling()),
            "useModernOrthography": NSNumber(value: PHTVGetUseModernOrthography()),
            "quickTelex": NSNumber(value: PHTVGetQuickTelex()),
            "switchKeyStatus": NSNumber(value: PHTVGetSwitchKeyStatus()),
            "useMacro": NSNumber(value: PHTVGetUseMacro()),
            "useMacroInEnglishMode": NSNumber(value: PHTVGetUseMacroInEnglishMode()),
            "autoCapsMacro": NSNumber(value: PHTVGetAutoCapsMacro()),
            "sendKeyStepByStep": NSNumber(value: PHTVIsSendKeyStepByStepEnabled() ? 1 : 0),
            "useSmartSwitchKey": NSNumber(value: PHTVIsSmartSwitchKeyEnabled() ? 1 : 0),
            "upperCaseFirstChar": NSNumber(value: PHTVGetUpperCaseFirstChar()),
            "allowConsonantZFWJ": NSNumber(value: PHTVGetAllowConsonantZFWJ()),
            "quickStartConsonant": NSNumber(value: PHTVGetQuickStartConsonant()),
            "quickEndConsonant": NSNumber(value: PHTVGetQuickEndConsonant()),
            "rememberCode": NSNumber(value: PHTVGetRememberCode()),
            "performLayoutCompat": NSNumber(value: PHTVGetPerformLayoutCompat()),
            "showIconOnDock": NSNumber(value: PHTVGetShowIconOnDock()),
            "restoreOnEscape": NSNumber(value: PHTVGetRestoreOnEscape()),
            "customEscapeKey": NSNumber(value: PHTVGetCustomEscapeKey()),
            "pauseKeyEnabled": NSNumber(value: PHTVGetPauseKeyEnabled()),
            "pauseKey": NSNumber(value: PHTVGetPauseKey()),
            "autoRestoreEnglishWord": NSNumber(value: PHTVGetAutoRestoreEnglishWord()),
            "enableEmojiHotkey": NSNumber(value: PHTVGetEnableEmojiHotkey()),
            "emojiHotkeyModifiers": NSNumber(value: PHTVGetEmojiHotkeyModifiers()),
            "emojiHotkeyKeyCode": NSNumber(value: PHTVGetEmojiHotkeyKeyCode())
        ]
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

    @objc(phtv_isTCCEntryCorrupt)
    class func phtv_isTCCEntryCorrupt() -> Bool {
        if canCreateEventTap() {
            return false
        }

        let isRegistered = PHTVTCCMaintenanceService.isAppRegisteredInTCC()
        if !isRegistered {
            NSLog("[TCC] ⚠️ CORRUPT ENTRY DETECTED - App not found in TCC database!")
            return true
        }

        return false
    }

    @objc(phtv_autoFixTCCEntryWithError:)
    class func phtv_autoFixTCCEntry(withError error: AutoreleasingUnsafeMutablePointer<NSError?>?) -> Bool {
        PHTVTCCMaintenanceService.autoFixTCCEntry(withError: error)
    }

    @objc(phtv_restartTCCDaemon)
    class func phtv_restartTCCDaemon() {
        PHTVTCCMaintenanceService.restartTCCDaemon()
    }

    @objc(phtv_startTCCNotificationListener)
    class func phtv_startTCCNotificationListener() {
        PHTVTCCNotificationService.startListening()
    }

    @objc(phtv_stopTCCNotificationListener)
    class func phtv_stopTCCNotificationListener() {
        PHTVTCCNotificationService.stopListening()
    }

    @objc(phtv_getTableCodes)
    class func phtv_getTableCodes() -> [String] {
        [
            "Unicode",
            "TCVN3 (ABC)",
            "VNI Windows",
            "Unicode tổ hợp",
            "Vietnamese Locale CP 1258"
        ]
    }

    @objc(phtv_getApplicationSupportFolder)
    class func phtv_getApplicationSupportFolder() -> String {
        let applicationSupportDirectory = NSSearchPathForDirectoriesInDomains(
            .applicationSupportDirectory,
            .userDomainMask,
            true
        ).first ?? (NSHomeDirectory() + "/Library/Application Support")
        return applicationSupportDirectory + "/PHTV"
    }

    @objc(phtv_getBinaryArchitectures)
    class func phtv_getBinaryArchitectures() -> String {
        PHTVBinaryIntegrityService.getBinaryArchitectures()
    }

    @objc(phtv_getBinaryHash)
    class func phtv_getBinaryHash() -> String? {
        PHTVBinaryIntegrityService.getBinaryHash()
    }

    @objc(phtv_hasBinaryChangedSinceLastRun)
    class func phtv_hasBinaryChangedSinceLastRun() -> Bool {
        PHTVBinaryIntegrityService.hasBinaryChangedSinceLastRun()
    }

    @objc(phtv_checkBinaryIntegrity)
    class func phtv_checkBinaryIntegrity() -> Bool {
        PHTVBinaryIntegrityService.checkBinaryIntegrity()
    }

    @objc(phtv_quickConvert)
    class func phtv_quickConvert() -> Bool {
        let pasteboard = NSPasteboard.general
        var htmlString = pasteboard.string(forType: .html)
        var rawString = pasteboard.string(forType: .string)
        var converted = false

        if let html = htmlString {
            htmlString = ConvertUtil(html)
            converted = true
        }
        if let raw = rawString {
            rawString = ConvertUtil(raw)
            converted = true
        }

        guard converted else {
            return false
        }

        pasteboard.clearContents()
        if let htmlString {
            pasteboard.setString(htmlString, forType: .html)
        }
        if let rawString {
            pasteboard.setString(rawString, forType: .string)
        }
        return true
    }

    @objc(phtv_isSafeModeEnabled)
    class func phtv_isSafeModeEnabled() -> Bool {
        PHTVGetSafeMode()
    }

    @objc(phtv_setSafeModeEnabled:)
    class func phtv_setSafeModeEnabled(_ enabled: Bool) {
        PHTVSetSafeMode(enabled)
        UserDefaults.standard.set(enabled, forKey: "SafeMode")

        if enabled {
            NSLog("[SafeMode] ENABLED - Accessibility API calls will be skipped")
        } else {
            NSLog("[SafeMode] DISABLED - Normal Accessibility API calls")
        }
    }

    @objc(phtv_clearAXTestFlag)
    class func phtv_clearAXTestFlag() {
        UserDefaults.standard.set(false, forKey: "AXTestInProgress")
        NSLog("[SafeMode] Cleared AX test flag on normal termination")
    }
}
