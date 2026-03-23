//
//  PHTVSystemTextReplacementService.swift
//  PHTV
//
//  Reads macOS Text Replacements and merges them into the runtime macro map.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
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

        let systemShortcutKeys = Set(
            systemEntries.map { $0.shortcut.folding(options: [.caseInsensitive], locale: .current) }
        )

        // Keep the user macro payload, but mark colliding shortcuts as
        // system replacements so GUI apps can defer to native replacement.
        var merged = userMacros.map { macro -> MacroItem in
            var runtimeMacro = macro
            let key = normalizedText(runtimeMacro.shortcut).folding(options: [.caseInsensitive], locale: .current)
            if systemShortcutKeys.contains(key) {
                runtimeMacro.snippetType = .systemTextReplacement
            }
            return runtimeMacro
        }
        var seenShortcuts = Set(
            merged.map { normalizedText($0.shortcut).folding(options: [.caseInsensitive], locale: .current) }
        )

        for entry in systemEntries {
            let key = entry.shortcut.folding(options: [.caseInsensitive], locale: .current)
            guard seenShortcuts.insert(key).inserted else {
                continue
            }
            merged.append(
                MacroItem(
                    shortcut: entry.shortcut,
                    expansion: entry.expansion,
                    snippetType: .systemTextReplacement
                )
            )
        }

        return merged
    }

    @objc(shouldDeferToNativeTextReplacementForBundleId:)
    class func shouldDeferToNativeTextReplacement(forBundleId bundleId: String?) -> Bool {
        PHTVAppDetectionService.supportsNativeSystemTextReplacements(bundleId)
    }

    class func rawReplacementItems(
        globalDefaults: UserDefaults = .standard
    ) -> [[String: Any]] {
        if let items = globalDefaults.array(forKey: replacementsKey) as? [[String: Any]] {
            return items
        }

        // Text replacements live in the global domain, but NSGlobalDomain is not a
        // valid suite name for UserDefaults(suiteName:). Read it through standard
        // defaults to avoid runtime warnings during app startup and tests.
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
