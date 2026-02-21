//
//  PHTVCoreSettingsBootstrapService.swift
//  PHTV
//
//  Bootstraps core runtime settings in C++ engine from UserDefaults.
//

import Foundation

@objcMembers
final class PHTVCoreSettingsBootstrapService: NSObject {
    private class func readPersistedInt(
        defaults: UserDefaults,
        key: String,
        defaultValue: Int32
    ) -> Int32 {
        guard defaults.object(forKey: key) != nil else {
            defaults.set(Int(defaultValue), forKey: key)
            return defaultValue
        }

        return Int32(defaults.integer(forKey: key))
    }

    @objc class func loadFromUserDefaults() {
        let defaults = UserDefaults.standard

        var language = Int32(defaults.integer(forKey: "InputMethod"))
        if language < 0 {
            language = 1
        }
        phtvRuntimeSetCurrentLanguage(language)

        var inputType = Int32(defaults.integer(forKey: "InputType"))
        if inputType < 0 {
            inputType = 0
        }
        phtvRuntimeSetCurrentInputType(inputType)

        PHTVSetFreeMark(0)

        var codeTable = Int32(defaults.integer(forKey: "CodeTable"))
        if codeTable < 0 {
            codeTable = 0
        }
        phtvRuntimeSetCurrentCodeTable(codeTable)

        phtvRuntimeSetCheckSpelling(
            readPersistedInt(defaults: defaults, key: "Spelling", defaultValue: 1)
        )
        PHTVSetUseModernOrthography(
            readPersistedInt(defaults: defaults, key: "ModernOrthography", defaultValue: 1)
        )
        PHTVSetQuickTelex(
            readPersistedInt(defaults: defaults, key: "QuickTelex", defaultValue: 0)
        )
        PHTVSetFixRecommendBrowser(
            readPersistedInt(defaults: defaults, key: "FixRecommendBrowser", defaultValue: 1)
        )

        PHTVSetUseMacro(
            readPersistedInt(defaults: defaults, key: "UseMacro", defaultValue: 0)
        )
        PHTVSetUseMacroInEnglishMode(
            readPersistedInt(defaults: defaults, key: "UseMacroInEnglishMode", defaultValue: 0)
        )
        PHTVSetAutoCapsMacro(Int32(defaults.integer(forKey: "vAutoCapsMacro")))

        phtvRuntimeSetSendKeyStepByStepEnabled(
            readPersistedInt(defaults: defaults, key: "SendKeyStepByStep", defaultValue: 0) != 0
        )
        PHTVSetUseSmartSwitchKey(
            readPersistedInt(defaults: defaults, key: "UseSmartSwitchKey", defaultValue: 1) != 0
        )
        PHTVSetUpperCaseFirstChar(
            readPersistedInt(defaults: defaults, key: "UpperCaseFirstChar", defaultValue: 0)
        )

        PHTVSetTempOffSpelling(Int32(defaults.integer(forKey: "vTempOffSpelling")))

        PHTVSetAllowConsonantZFWJ(
            readPersistedInt(defaults: defaults, key: "vAllowConsonantZFWJ", defaultValue: 1)
        )
        PHTVSetQuickEndConsonant(
            readPersistedInt(defaults: defaults, key: "vQuickEndConsonant", defaultValue: 0)
        )
        PHTVSetQuickStartConsonant(
            readPersistedInt(defaults: defaults, key: "vQuickStartConsonant", defaultValue: 0)
        )
        PHTVSetRememberCode(
            readPersistedInt(defaults: defaults, key: "vRememberCode", defaultValue: 1)
        )

        PHTVSetOtherLanguage(Int32(defaults.integer(forKey: "vOtherLanguage")))
        PHTVSetTempOffPHTV(Int32(defaults.integer(forKey: "vTempOffPHTV")))
        PHTVSetPerformLayoutCompat(Int32(defaults.integer(forKey: "vPerformLayoutCompat")))

        PHTVSetSafeMode(defaults.bool(forKey: "SafeMode"))
    }
}
