//
//  AppDelegate+MacroData.swift
//  PHTV
//
//  Swift port of AppDelegate+MacroData.mm.
//

import Foundation

private let phtvDefaultsKeyMacroList = "macroList"
private let phtvDefaultsKeyCustomDictionary = "customDictionary"
private let phtvDefaultsKeySpelling = "Spelling"

private func phtvMacroLiveDebugEnabled() -> Bool {
    if let env = ProcessInfo.processInfo.environment["PHTV_LIVE_DEBUG"], !env.isEmpty {
        return env != "0"
    }
    if let stored = UserDefaults.standard.object(forKey: "PHTV_LIVE_DEBUG") as? NSNumber {
        return stored.intValue != 0
    }
    return false
}

private func phtvMacroLiveLog(_ message: String) {
    guard phtvMacroLiveDebugEnabled() else {
        return
    }
    NSLog("[PHTV Live] %@", message)
}

@MainActor extension AppDelegate {
    private func syncMacrosFromUserDefaults(resetSession: Bool) {
        let defaults = UserDefaults.standard
        let macroListData = defaults.data(forKey: phtvDefaultsKeyMacroList)
        let macros = MacroStorage.load(defaults: defaults)

        if macros.isEmpty {
            let emptyData = MacroStorage.engineBinaryData(from: [])
            PHTVEngineDataBridge.initializeMacroMap(with: emptyData)

            if macroListData != nil && defaults.data(forKey: phtvDefaultsKeyMacroList) == nil {
                phtvMacroLiveLog("macroList parse failed, backed up and reset")
            } else {
                phtvMacroLiveLog("macros cleared")
            }
        } else {
            let binaryData = MacroStorage.engineBinaryData(from: macros)
            PHTVEngineDataBridge.initializeMacroMap(with: binaryData)
            phtvMacroLiveLog("macros synced: count=\(macros.count)")
        }

        if resetSession {
            PHTVManager.requestNewSession()
        }
    }

    @objc func handleMacrosUpdated(_ notification: Notification?) {
        _ = notification
        phtvMacroLiveLog("received MacrosUpdated")
        syncMacrosFromUserDefaults(resetSession: true)
    }

    @objc func loadExistingMacros() {
        syncMacrosFromUserDefaults(resetSession: false)
    }

    @objc func initEnglishWordDictionary() {
        if let enBundlePath = Bundle.main.path(forResource: "en_dict", ofType: "bin") {
            if PHTVEngineDataBridge.initializeEnglishDictionary(atPath: enBundlePath) {
                NSLog("[EnglishWordDetector] English dictionary loaded: %zu words",
                      PHTVEngineDataBridge.englishDictionarySize())
            } else {
                NSLog("[EnglishWordDetector] Failed to load English dictionary")
            }
        } else {
            NSLog("[EnglishWordDetector] en_dict.bin not found in bundle")
        }

        if let viBundlePath = Bundle.main.path(forResource: "vi_dict", ofType: "bin") {
            if PHTVEngineDataBridge.initializeVietnameseDictionary(atPath: viBundlePath) {
                NSLog("[EnglishWordDetector] Vietnamese dictionary loaded: %zu words",
                      PHTVEngineDataBridge.vietnameseDictionarySize())
            } else {
                NSLog("[EnglishWordDetector] Failed to load Vietnamese dictionary")
            }
        } else {
            NSLog("[EnglishWordDetector] vi_dict.bin not found in bundle")
        }

        syncCustomDictionaryFromUserDefaults()

        let defaults = UserDefaults.standard
        let spellCheckEnabled: Int
        if defaults.object(forKey: phtvDefaultsKeySpelling) == nil {
            spellCheckEnabled = 1
        } else {
            spellCheckEnabled = defaults.integer(forKey: phtvDefaultsKeySpelling)
        }
        PHTVEngineRuntimeFacade.setCheckSpelling(Int32(spellCheckEnabled))
        NSLog("[EnglishWordDetector] Spell check enabled: %d", spellCheckEnabled)
    }

    @objc func syncCustomDictionaryFromUserDefaults() {
        let defaults = UserDefaults.standard
        guard let customDictData = defaults.data(forKey: phtvDefaultsKeyCustomDictionary),
              !customDictData.isEmpty else {
            PHTVEngineDataBridge.clearCustomDictionary()
            NSLog("[CustomDictionary] No custom words found")
            return
        }

        let words: Any
        do {
            words = try JSONSerialization.jsonObject(with: customDictData, options: [])
        } catch {
            NSLog("[CustomDictionary] Failed to parse JSON: %@", error.localizedDescription)
            return
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: words, options: [])
            PHTVEngineDataBridge.initializeCustomDictionary(withJSONData: jsonData)
            NSLog("[CustomDictionary] Loaded %zu English, %zu Vietnamese custom words",
                  PHTVEngineDataBridge.customEnglishWordCount(),
                  PHTVEngineDataBridge.customVietnameseWordCount())
        } catch {
            NSLog("[CustomDictionary] Failed to serialize JSON: %@", error.localizedDescription)
        }
    }

    @objc func handleCustomDictionaryUpdated(_ notification: Notification?) {
        _ = notification
        phtvMacroLiveLog("received CustomDictionaryUpdated")
        syncCustomDictionaryFromUserDefaults()
    }
}
