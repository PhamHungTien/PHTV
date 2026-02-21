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
            "checkSpelling": NSNumber(value: phtvRuntimeCheckSpelling()),
            "useModernOrthography": NSNumber(value: PHTVGetUseModernOrthography()),
            "quickTelex": NSNumber(value: PHTVGetQuickTelex()),
            "switchKeyStatus": NSNumber(value: phtvRuntimeSwitchKeyStatus()),
            "useMacro": NSNumber(value: PHTVGetUseMacro()),
            "useMacroInEnglishMode": NSNumber(value: PHTVGetUseMacroInEnglishMode()),
            "autoCapsMacro": NSNumber(value: PHTVGetAutoCapsMacro()),
            "sendKeyStepByStep": NSNumber(value: phtvRuntimeIsSendKeyStepByStepEnabled() ? 1 : 0),
            "useSmartSwitchKey": NSNumber(value: phtvRuntimeIsSmartSwitchKeyEnabled() ? 1 : 0),
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
}
