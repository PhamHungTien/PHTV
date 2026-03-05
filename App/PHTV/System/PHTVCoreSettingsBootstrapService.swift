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

    private class func readAutoRestoreEnglishMode(defaults: UserDefaults) -> AutoRestoreEnglishMode {
        defaults.autoRestoreEnglishMode()
    }

    private class func restoreIfWrongSpellingValue(
        autoRestoreEnglishWord: Int32,
        mode: AutoRestoreEnglishMode
    ) -> Int32 {
        guard autoRestoreEnglishWord != 0 else {
            return 0
        }
        return mode.enablesWrongSpellingFallback ? 1 : 0
    }

    @objc class func loadFromUserDefaults() {
        let defaults = UserDefaults.standard

        var language = Int32(defaults.integer(forKey: "InputMethod"))
        if language < 0 {
            language = 1
        }
        PHTVEngineRuntimeFacade.setCurrentLanguage(language)

        var inputType = Int32(defaults.integer(forKey: "InputType"))
        if inputType < 0 {
            inputType = 0
        }
        PHTVEngineRuntimeFacade.setCurrentInputType(inputType)

        PHTVEngineRuntimeFacade.setFreeMark(0)

        var codeTable = Int32(defaults.integer(forKey: "CodeTable"))
        if codeTable < 0 {
            codeTable = 0
        }
        PHTVEngineRuntimeFacade.setCurrentCodeTable(codeTable)

        PHTVEngineRuntimeFacade.setCheckSpelling(
            readPersistedInt(defaults: defaults, key: "Spelling", defaultValue: 1)
        )
        PHTVEngineRuntimeFacade.setUseModernOrthography(
            readPersistedInt(defaults: defaults, key: "ModernOrthography", defaultValue: 1)
        )
        PHTVEngineRuntimeFacade.setQuickTelex(
            readPersistedInt(defaults: defaults, key: "QuickTelex", defaultValue: 0)
        )
        PHTVEngineRuntimeFacade.setFixRecommendBrowser(
            readPersistedInt(defaults: defaults, key: "FixRecommendBrowser", defaultValue: 1)
        )

        PHTVEngineRuntimeFacade.setUseMacro(
            readPersistedInt(defaults: defaults, key: "UseMacro", defaultValue: 0)
        )
        PHTVEngineRuntimeFacade.setUseMacroInEnglishMode(
            readPersistedInt(defaults: defaults, key: "UseMacroInEnglishMode", defaultValue: 0)
        )
        PHTVEngineRuntimeFacade.setAutoCapsMacro(Int32(defaults.integer(forKey: "vAutoCapsMacro")))

        PHTVEngineRuntimeFacade.setSendKeyStepByStepEnabled(
            readPersistedInt(defaults: defaults, key: "SendKeyStepByStep", defaultValue: 0) != 0
        )
        PHTVEngineRuntimeFacade.setSmartSwitchKeyEnabled(
            readPersistedInt(defaults: defaults, key: "UseSmartSwitchKey", defaultValue: 1) != 0
        )
        PHTVEngineRuntimeFacade.setUpperCaseFirstChar(
            readPersistedInt(defaults: defaults, key: "UpperCaseFirstChar", defaultValue: 0)
        )

        PHTVEngineRuntimeFacade.setTempOffSpelling(Int32(defaults.integer(forKey: "vTempOffSpelling")))

        let autoRestoreEnglishWord = readPersistedInt(
            defaults: defaults,
            key: UserDefaultsKey.autoRestoreEnglishWord,
            defaultValue: Defaults.autoRestoreEnglishWord ? 1 : 0
        )
        PHTVEngineRuntimeFacade.setAutoRestoreEnglishWord(autoRestoreEnglishWord)

        let autoRestoreMode = readAutoRestoreEnglishMode(defaults: defaults)
        PHTVEngineRuntimeFacade.setAutoRestoreEnglishWordMode(Int32(autoRestoreMode.rawValue))
        let restoreIfWrongSpelling = restoreIfWrongSpellingValue(
            autoRestoreEnglishWord: autoRestoreEnglishWord,
            mode: autoRestoreMode
        )
        PHTVEngineRuntimeFacade.setRestoreIfWrongSpelling(restoreIfWrongSpelling)
        defaults.set(autoRestoreMode.rawValue, forKey: UserDefaultsKey.autoRestoreEnglishWordMode)
        defaults.set(Int(restoreIfWrongSpelling), forKey: UserDefaultsKey.restoreIfWrongSpelling)

        PHTVEngineRuntimeFacade.setAllowConsonantZFWJ(
            readPersistedInt(defaults: defaults, key: "vAllowConsonantZFWJ", defaultValue: 1)
        )
        PHTVEngineRuntimeFacade.setQuickEndConsonant(
            readPersistedInt(defaults: defaults, key: "vQuickEndConsonant", defaultValue: 0)
        )
        PHTVEngineRuntimeFacade.setQuickStartConsonant(
            readPersistedInt(defaults: defaults, key: "vQuickStartConsonant", defaultValue: 0)
        )
        PHTVEngineRuntimeFacade.setRememberCode(
            readPersistedInt(defaults: defaults, key: "vRememberCode", defaultValue: 1)
        )

        PHTVEngineRuntimeFacade.setOtherLanguageMode(Int32(defaults.integer(forKey: "vOtherLanguage")))
        PHTVEngineRuntimeFacade.setTempOffEngine(Int32(defaults.integer(forKey: "vTempOffPHTV")))
        PHTVEngineRuntimeFacade.setPerformLayoutCompat(Int32(defaults.integer(forKey: "vPerformLayoutCompat")))

        PHTVEngineRuntimeFacade.setSafeMode(defaults.bool(forKey: "SafeMode"))
    }
}
