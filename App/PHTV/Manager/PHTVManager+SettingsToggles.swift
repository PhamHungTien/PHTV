//
//  PHTVManager+SettingsToggles.swift
//  PHTV
//
//  Runtime settings toggle/snapshot methods for PHTVManager.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
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

    @nonobjc private class func phtv_currentAutoRestoreEnglishMode(defaults: UserDefaults) -> AutoRestoreEnglishMode {
        _ = defaults
        return .englishOnly
    }

    @discardableResult
    @nonobjc private class func phtv_applyAutoRestoreEnglishSetting(
        autoRestoreEnglishWord: Int32,
        mode: AutoRestoreEnglishMode,
        defaults: UserDefaults
    ) -> Int32 {
        _ = mode
        let normalizedAutoRestore: Int32 = autoRestoreEnglishWord == 0 ? 0 : 1
        let normalizedMode = AutoRestoreEnglishMode.englishOnly
        let restoreIfWrongSpelling: Int32 = 0

        PHTVEngineRuntimeFacade.setAutoRestoreEnglishWord(normalizedAutoRestore)
        PHTVEngineRuntimeFacade.setAutoRestoreEnglishWordMode(Int32(normalizedMode.rawValue))
        PHTVEngineRuntimeFacade.setRestoreIfWrongSpelling(restoreIfWrongSpelling)
        defaults.set(Int(normalizedAutoRestore), forKey: UserDefaultsKey.autoRestoreEnglishWord)
        defaults.set(normalizedMode.rawValue, forKey: UserDefaultsKey.autoRestoreEnglishWordMode)
        defaults.set(Int(restoreIfWrongSpelling), forKey: UserDefaultsKey.restoreIfWrongSpelling)
        return restoreIfWrongSpelling
    }

    @objc(phtv_toggleSpellCheckSetting)
    class func phtv_toggleSpellCheckSetting() -> Int32 {
        phtv_toggleRuntimeIntSetting(
            currentValue: { PHTVEngineRuntimeFacade.checkSpelling() },
            applyValue: { PHTVEngineRuntimeFacade.setCheckSpelling($0) },
            defaultsKey: "Spelling",
            syncSpellingBeforeSessionReset: true
        )
    }

    @objc(phtv_toggleAllowConsonantZFWJSetting)
    class func phtv_toggleAllowConsonantZFWJSetting() -> Int32 {
        phtv_toggleRuntimeIntSetting(
            currentValue: { PHTVEngineRuntimeFacade.allowConsonantZFWJ() },
            applyValue: { PHTVEngineRuntimeFacade.setAllowConsonantZFWJ($0) },
            defaultsKey: "vAllowConsonantZFWJ",
            syncSpellingBeforeSessionReset: false
        )
    }

    @objc(phtv_toggleModernOrthographySetting)
    class func phtv_toggleModernOrthographySetting() -> Int32 {
        phtv_toggleRuntimeIntSetting(
            currentValue: { PHTVEngineRuntimeFacade.useModernOrthography() },
            applyValue: { PHTVEngineRuntimeFacade.setUseModernOrthography($0) },
            defaultsKey: "ModernOrthography",
            syncSpellingBeforeSessionReset: false
        )
    }

    @objc(phtv_toggleQuickTelexSetting)
    class func phtv_toggleQuickTelexSetting() -> Int32 {
        phtv_toggleRuntimeIntSetting(
            currentValue: { PHTVEngineRuntimeFacade.quickTelex() },
            applyValue: { PHTVEngineRuntimeFacade.setQuickTelex($0) },
            defaultsKey: "QuickTelex",
            syncSpellingBeforeSessionReset: false
        )
    }

    @objc(phtv_toggleUpperCaseFirstCharSetting)
    class func phtv_toggleUpperCaseFirstCharSetting() -> Int32 {
        phtv_toggleRuntimeIntSetting(
            currentValue: { PHTVEngineRuntimeFacade.upperCaseFirstChar() },
            applyValue: { PHTVEngineRuntimeFacade.setUpperCaseFirstChar($0) },
            defaultsKey: "UpperCaseFirstChar",
            syncSpellingBeforeSessionReset: false
        )
    }

    @objc(phtv_toggleAutoRestoreEnglishWordSetting)
    class func phtv_toggleAutoRestoreEnglishWordSetting() -> Int32 {
        let defaults = UserDefaults.standard
        let toggled: Int32 = PHTVEngineRuntimeFacade.autoRestoreEnglishWord() == 0 ? 1 : 0
        let mode = phtv_currentAutoRestoreEnglishMode(defaults: defaults)

        _ = phtv_applyAutoRestoreEnglishSetting(
            autoRestoreEnglishWord: toggled,
            mode: mode,
            defaults: defaults
        )
        phtv_requestNewSession()
        return toggled
    }

    @objc(phtv_runtimeSettingsSnapshot)
    class func phtv_runtimeSettingsSnapshot() -> [String: NSNumber] {
        [
            "checkSpelling": NSNumber(value: PHTVEngineRuntimeFacade.checkSpelling()),
            "useModernOrthography": NSNumber(value: PHTVEngineRuntimeFacade.useModernOrthography()),
            "quickTelex": NSNumber(value: PHTVEngineRuntimeFacade.quickTelex()),
            "switchKeyStatus": NSNumber(value: PHTVEngineRuntimeFacade.switchKeyStatus()),
            "useMacro": NSNumber(value: PHTVEngineRuntimeFacade.useMacro()),
            "useMacroInEnglishMode": NSNumber(value: PHTVEngineRuntimeFacade.useMacroInEnglishMode()),
            "autoCapsMacro": NSNumber(value: PHTVEngineRuntimeFacade.autoCapsMacro()),
            "sendKeyStepByStep": NSNumber(value: PHTVEngineRuntimeFacade.isSendKeyStepByStepEnabled() ? 1 : 0),
            "useSmartSwitchKey": NSNumber(value: PHTVEngineRuntimeFacade.isSmartSwitchKeyEnabled() ? 1 : 0),
            "upperCaseFirstChar": NSNumber(value: PHTVEngineRuntimeFacade.upperCaseFirstChar()),
            "allowConsonantZFWJ": NSNumber(value: PHTVEngineRuntimeFacade.allowConsonantZFWJ()),
            "quickStartConsonant": NSNumber(value: PHTVEngineRuntimeFacade.quickStartConsonant()),
            "quickEndConsonant": NSNumber(value: PHTVEngineRuntimeFacade.quickEndConsonant()),
            "rememberCode": NSNumber(value: PHTVEngineRuntimeFacade.rememberCode()),
            "performLayoutCompat": NSNumber(value: PHTVEngineRuntimeFacade.performLayoutCompat()),
            "showIconOnDock": NSNumber(value: PHTVEngineRuntimeFacade.showIconOnDock()),
            "restoreOnEscape": NSNumber(value: PHTVEngineRuntimeFacade.restoreOnEscape()),
            "customEscapeKey": NSNumber(value: PHTVEngineRuntimeFacade.customEscapeKey()),
            "pauseKeyEnabled": NSNumber(value: PHTVEngineRuntimeFacade.pauseKeyEnabled()),
            "pauseKey": NSNumber(value: PHTVEngineRuntimeFacade.pauseKey()),
            "autoRestoreEnglishWord": NSNumber(value: PHTVEngineRuntimeFacade.autoRestoreEnglishWord()),
            "autoRestoreEnglishWordMode": NSNumber(value: PHTVEngineRuntimeFacade.autoRestoreEnglishWordMode()),
            "restoreIfWrongSpelling": NSNumber(value: PHTVEngineRuntimeFacade.restoreIfWrongSpelling()),
            "enableEmojiHotkey": NSNumber(value: PHTVEngineRuntimeFacade.enableEmojiHotkey()),
            "emojiHotkeyModifiers": NSNumber(value: PHTVEngineRuntimeFacade.emojiHotkeyModifiers()),
            "emojiHotkeyKeyCode": NSNumber(value: PHTVEngineRuntimeFacade.emojiHotkeyKeyCode())
        ]
    }
}
