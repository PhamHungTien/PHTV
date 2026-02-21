//
//  AppDelegate+MacroData.swift
//  PHTV
//
//  Swift port of AppDelegate+MacroData.mm.
//

import Foundation

private let phtvDefaultsKeyMacroList = "macroList"
private let phtvDefaultsKeyMacroListCorruptedBackup = "macroList.corruptedBackup"
private let phtvDefaultsKeyMacroData = "macroData"
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

private extension Data {
    mutating func appendUInt8(_ value: UInt8) {
        var value = value
        Swift.withUnsafeBytes(of: &value) { rawBuffer in
            append(contentsOf: rawBuffer)
        }
    }

    mutating func appendUInt16(_ value: UInt16) {
        var valueLE = value.littleEndian
        Swift.withUnsafeBytes(of: &valueLE) { rawBuffer in
            append(contentsOf: rawBuffer)
        }
    }
}

@MainActor extension AppDelegate {
    private func syncMacrosFromUserDefaults(resetSession: Bool) {
        let defaults = UserDefaults.standard
        let macroListData = defaults.data(forKey: phtvDefaultsKeyMacroList)

        if let macroListData, !macroListData.isEmpty {
            let decoded: Any
            do {
                decoded = try JSONSerialization.jsonObject(with: macroListData, options: .mutableContainers)
            } catch {
                NSLog("[AppDelegate] ERROR: Failed to parse macroList: %@", String(describing: error))
                defaults.set(macroListData, forKey: phtvDefaultsKeyMacroListCorruptedBackup)
                defaults.removeObject(forKey: phtvDefaultsKeyMacroList)
                defaults.removeObject(forKey: phtvDefaultsKeyMacroData)

                var emptyData = Data()
                emptyData.appendUInt16(0)
                PHTVEngineDataBridge.initializeMacroMap(with: emptyData)
                phtvMacroLiveLog("macroList parse failed, backed up to \(phtvDefaultsKeyMacroListCorruptedBackup) and reset")

                if resetSession {
                    PHTVManager.requestNewSession()
                }
                return
            }

            guard let macros = decoded as? [[String: Any]] else {
                NSLog("[AppDelegate] ERROR: Failed to parse macroList: root is not array")
                defaults.set(macroListData, forKey: phtvDefaultsKeyMacroListCorruptedBackup)
                defaults.removeObject(forKey: phtvDefaultsKeyMacroList)
                defaults.removeObject(forKey: phtvDefaultsKeyMacroData)

                var emptyData = Data()
                emptyData.appendUInt16(0)
                PHTVEngineDataBridge.initializeMacroMap(with: emptyData)
                phtvMacroLiveLog("macroList parse failed, backed up to \(phtvDefaultsKeyMacroListCorruptedBackup) and reset")

                if resetSession {
                    PHTVManager.requestNewSession()
                }
                return
            }

            let snippetTypeMap: [String: UInt8] = [
                "static": 0,
                "date": 1,
                "time": 2,
                "datetime": 3,
                "clipboard": 4,
                "random": 5,
                "counter": 6
            ]

            var binaryData = Data()
            binaryData.appendUInt16(UInt16(macros.count))

            for macro in macros {
                let shortcut = (macro["shortcut"] as? String) ?? ""
                let expansion = (macro["expansion"] as? String) ?? ""
                let snippetTypeStr = (macro["snippetType"] as? String) ?? "static"

                let shortcutData = shortcut.data(using: .utf8) ?? Data()
                binaryData.appendUInt8(UInt8(truncatingIfNeeded: shortcutData.count))
                binaryData.append(shortcutData)

                let expansionData = expansion.data(using: .utf8) ?? Data()
                binaryData.appendUInt16(UInt16(truncatingIfNeeded: expansionData.count))
                binaryData.append(expansionData)

                let snippetType = snippetTypeMap[snippetTypeStr] ?? 0
                binaryData.appendUInt8(snippetType)
            }

            defaults.set(binaryData, forKey: phtvDefaultsKeyMacroData)
            PHTVEngineDataBridge.initializeMacroMap(with: binaryData)
            phtvMacroLiveLog("macros synced: count=\(macros.count)")
        } else {
            defaults.removeObject(forKey: phtvDefaultsKeyMacroData)

            var emptyData = Data()
            emptyData.appendUInt16(0)
            PHTVEngineDataBridge.initializeMacroMap(with: emptyData)
            phtvMacroLiveLog("macros cleared")
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
        PHTVEngineDataBridge.setCheckSpellingValue(Int32(spellCheckEnabled))
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
