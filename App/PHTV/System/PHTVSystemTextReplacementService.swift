//
//  PHTVSystemTextReplacementService.swift
//  PHTV
//
//  Reads macOS Text Replacements and merges them into the runtime macro map.
//

import Foundation

final class PHTVSystemTextReplacementService: NSObject {
    private static let replacementsKey = "NSUserDictionaryReplacementItems"
    private static let replaceKey = "replace"
    private static let withKey = "with"
    private static let enabledKey = "on"

    @objc(isEnabledInDefaults:)
    class func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(
            forKey: UserDefaultsKey.useSystemTextReplacements,
            default: Defaults.useSystemTextReplacements
        )
    }

    @objc(currentReplacementCount)
    class func currentReplacementCount() -> Int {
        normalizedEntries(from: rawReplacementItems()).count
    }

    class func runtimeMacros(
        userMacros: [MacroItem],
        defaults: UserDefaults = .standard
    ) -> [MacroItem] {
        mergedRuntimeMacros(
            userMacros: userMacros,
            useSystemTextReplacements: isEnabled(in: defaults),
            rawItems: rawReplacementItems()
        )
    }

    class func mergedRuntimeMacros(
        userMacros: [MacroItem],
        useSystemTextReplacements: Bool,
        rawItems: [[String: Any]]
    ) -> [MacroItem] {
        guard useSystemTextReplacements else {
            return userMacros
        }

        let systemEntries = normalizedEntries(from: rawItems)
        guard !systemEntries.isEmpty else {
            return userMacros
        }

        var merged = userMacros
        var seenShortcuts = Set(
            userMacros.map { normalizedText($0.shortcut).folding(options: [.caseInsensitive], locale: .current) }
        )

        for entry in systemEntries {
            let key = entry.shortcut.folding(options: [.caseInsensitive], locale: .current)
            guard seenShortcuts.insert(key).inserted else {
                continue
            }
            merged.append(MacroItem(shortcut: entry.shortcut, expansion: entry.expansion))
        }

        return merged
    }

    class func rawReplacementItems(
        globalDefaults: UserDefaults = UserDefaults(suiteName: UserDefaults.globalDomain) ?? .standard
    ) -> [[String: Any]] {
        if let items = globalDefaults.array(forKey: replacementsKey) as? [[String: Any]] {
            return items
        }

        if let domain = globalDefaults.persistentDomain(forName: UserDefaults.globalDomain),
           let items = domain[replacementsKey] as? [[String: Any]] {
            return items
        }

        return []
    }

    class func normalizedEntries(from rawItems: [[String: Any]]) -> [(shortcut: String, expansion: String)] {
        var result: [(shortcut: String, expansion: String)] = []
        var seenShortcuts = Set<String>()

        for item in rawItems {
            if let enabled = item[enabledKey] as? NSNumber, enabled.intValue == 0 {
                continue
            }

            let shortcut = normalizedText(item[replaceKey] as? String)
            let expansion = normalizedText(item[withKey] as? String)
            guard !shortcut.isEmpty, !expansion.isEmpty, shortcut != expansion else {
                continue
            }
            guard shortcut.lengthOfBytes(using: .utf8) <= Int(UInt8.max) else {
                continue
            }
            guard expansion.lengthOfBytes(using: .utf8) <= Int(UInt16.max) else {
                continue
            }

            let key = shortcut.folding(options: [.caseInsensitive], locale: .current)
            guard seenShortcuts.insert(key).inserted else {
                continue
            }

            result.append((shortcut, expansion))
        }

        return result
    }

    private class func normalizedText(_ text: String?) -> String {
        let trimmed = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed as NSString).precomposedStringWithCanonicalMapping
    }
}
