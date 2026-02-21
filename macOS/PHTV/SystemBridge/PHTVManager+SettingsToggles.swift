//
//  PHTVManager+SettingsToggles.swift
//  PHTV
//
//  Runtime settings toggle/snapshot methods for PHTVManager.
//

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

    @objc(phtv_toggleSpellCheckSetting)
    class func phtv_toggleSpellCheckSetting() -> Int32 {
        phtv_toggleRuntimeIntSetting(
            currentValue: { Int32(phtvRuntimeCheckSpelling()) },
            applyValue: { phtvRuntimeSetCheckSpelling($0) },
            defaultsKey: "Spelling",
            syncSpellingBeforeSessionReset: true
        )
    }

    @objc(phtv_toggleAllowConsonantZFWJSetting)
    class func phtv_toggleAllowConsonantZFWJSetting() -> Int32 {
        phtv_toggleRuntimeIntSetting(
            currentValue: { Int32(phtvRuntimeAllowConsonantZFWJ()) },
            applyValue: { phtvRuntimeSetAllowConsonantZFWJ($0) },
            defaultsKey: "vAllowConsonantZFWJ",
            syncSpellingBeforeSessionReset: false
        )
    }

    @objc(phtv_toggleModernOrthographySetting)
    class func phtv_toggleModernOrthographySetting() -> Int32 {
        phtv_toggleRuntimeIntSetting(
            currentValue: { Int32(phtvRuntimeUseModernOrthography()) },
            applyValue: { phtvRuntimeSetUseModernOrthography($0) },
            defaultsKey: "ModernOrthography",
            syncSpellingBeforeSessionReset: false
        )
    }

    @objc(phtv_toggleQuickTelexSetting)
    class func phtv_toggleQuickTelexSetting() -> Int32 {
        phtv_toggleRuntimeIntSetting(
            currentValue: { Int32(phtvRuntimeQuickTelex()) },
            applyValue: { phtvRuntimeSetQuickTelex($0) },
            defaultsKey: "QuickTelex",
            syncSpellingBeforeSessionReset: false
        )
    }

    @objc(phtv_toggleUpperCaseFirstCharSetting)
    class func phtv_toggleUpperCaseFirstCharSetting() -> Int32 {
        phtv_toggleRuntimeIntSetting(
            currentValue: { Int32(phtvRuntimeUpperCaseFirstChar()) },
            applyValue: { phtvRuntimeSetUpperCaseFirstChar($0) },
            defaultsKey: "UpperCaseFirstChar",
            syncSpellingBeforeSessionReset: false
        )
    }

    @objc(phtv_toggleAutoRestoreEnglishWordSetting)
    class func phtv_toggleAutoRestoreEnglishWordSetting() -> Int32 {
        phtv_toggleRuntimeIntSetting(
            currentValue: { Int32(phtvRuntimeAutoRestoreEnglishWord()) },
            applyValue: { phtvRuntimeSetAutoRestoreEnglishWord($0) },
            defaultsKey: "vAutoRestoreEnglishWord",
            syncSpellingBeforeSessionReset: false
        )
    }

    @objc(phtv_runtimeSettingsSnapshot)
    class func phtv_runtimeSettingsSnapshot() -> [String: NSNumber] {
        [
            "checkSpelling": NSNumber(value: phtvRuntimeCheckSpelling()),
            "useModernOrthography": NSNumber(value: phtvRuntimeUseModernOrthography()),
            "quickTelex": NSNumber(value: phtvRuntimeQuickTelex()),
            "switchKeyStatus": NSNumber(value: phtvRuntimeSwitchKeyStatus()),
            "useMacro": NSNumber(value: phtvRuntimeUseMacro()),
            "useMacroInEnglishMode": NSNumber(value: phtvRuntimeUseMacroInEnglishMode()),
            "autoCapsMacro": NSNumber(value: phtvRuntimeAutoCapsMacro()),
            "sendKeyStepByStep": NSNumber(value: phtvRuntimeIsSendKeyStepByStepEnabled() ? 1 : 0),
            "useSmartSwitchKey": NSNumber(value: phtvRuntimeIsSmartSwitchKeyEnabled() ? 1 : 0),
            "upperCaseFirstChar": NSNumber(value: phtvRuntimeUpperCaseFirstChar()),
            "allowConsonantZFWJ": NSNumber(value: phtvRuntimeAllowConsonantZFWJ()),
            "quickStartConsonant": NSNumber(value: phtvRuntimeQuickStartConsonant()),
            "quickEndConsonant": NSNumber(value: phtvRuntimeQuickEndConsonant()),
            "rememberCode": NSNumber(value: phtvRuntimeRememberCode()),
            "performLayoutCompat": NSNumber(value: phtvRuntimePerformLayoutCompat()),
            "showIconOnDock": NSNumber(value: phtvRuntimeShowIconOnDock()),
            "restoreOnEscape": NSNumber(value: phtvRuntimeRestoreOnEscape()),
            "customEscapeKey": NSNumber(value: phtvRuntimeCustomEscapeKey()),
            "pauseKeyEnabled": NSNumber(value: phtvRuntimePauseKeyEnabled()),
            "pauseKey": NSNumber(value: phtvRuntimePauseKey()),
            "autoRestoreEnglishWord": NSNumber(value: phtvRuntimeAutoRestoreEnglishWord()),
            "enableEmojiHotkey": NSNumber(value: phtvRuntimeEnableEmojiHotkey()),
            "emojiHotkeyModifiers": NSNumber(value: phtvRuntimeEmojiHotkeyModifiers()),
            "emojiHotkeyKeyCode": NSNumber(value: phtvRuntimeEmojiHotkeyKeyCode())
        ]
    }
}
