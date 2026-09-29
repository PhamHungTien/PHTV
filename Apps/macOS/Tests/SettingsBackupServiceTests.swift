import AppKit
import XCTest
@testable import PHTV

final class SettingsBackupServiceTests: XCTestCase {
    @MainActor
    private func fixture(_ body: (SettingsBackupService, UserDefaults, URL, String) throws -> Void) throws {
        let name = "PHTV.Backup.Tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            defaults.removePersistentDomain(forName: name)
            try? FileManager.default.removeItem(at: root)
        }
        try body(SettingsBackupService(defaults: defaults, root: root, defaultsDomain: name), defaults, root, name)
    }

    @MainActor
    func testAllRegisteredPortableDefaultsRoundTripToEmptyDestination() throws {
        try fixture { source, _, _, _ in
            let backup = try source.create()
            XCTAssertEqual(Set(backup.settings!.keys), Set(SettingsBackupSchema.defaults.keys))
            XCTAssertNotNil(backup.clipboardHistory)
            XCTAssertNotNil(backup.clipboardLibrary)
            let decoded = try SettingsBackupService.decode(JSONEncoder().encode(backup))
            try fixture { destination, defaults, _, _ in
                try destination.apply(decoded)
                let restored = try destination.create()
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]
                XCTAssertEqual(try encoder.encode(backup.settings), try encoder.encode(restored.settings))
                XCTAssertEqual(defaults.data(forKey: "smartSwitchKey"), Data([0, 0]))
            }
        }
    }

    @MainActor
    func testPreviouslyMissingSettingsAndCollectionsRoundTrip() throws {
        try fixture { source, defaults, _, _ in
            let settings: [String: Any] = [
                UserDefaultsKey.switchKey2Status: 49,
                UserDefaultsKey.singleModifierSwitchKeys: 511,
                UserDefaultsKey.enableClipboardHistory: true,
                UserDefaultsKey.emojiHotkeyModifiers: Int(NSEvent.ModifierFlags.function.rawValue),
                UserDefaultsKey.useSystemTextReplacements: true,
                UserDefaultsKey.autoInstallUpdates: false,
                UserDefaultsKey.automaticUpdateChecks: false,
                UserDefaultsKey.updateCheckInterval: 0,
                UserDefaultsKey.keyboardCleaningDuration: 120.0,
                "convertToolToAllCaps": true,
                "com.phtv.recentEmojis": ["🇻🇳", "👨‍👩‍👧‍👦"],
                "com.phtv.emojiFrequency": ["🇻🇳": 7],
                "RecentGIFs": [Int64(123456789012)], "RecentStickers": [42]
            ]
            for (key, value) in settings { defaults.set(value, forKey: key) }
            defaults.set(Data(#"[{"word":"PHTV","type":"en","id":"legacy"}]"#.utf8), forKey: "customDictionary")
            let backup = try source.create()
            try fixture { destination, restored, _, _ in
                try destination.apply(try SettingsBackupService.decode(JSONEncoder().encode(backup)))
                for (key, value) in settings {
                    XCTAssertEqual(restored.object(forKey: key) as? NSObject, value as? NSObject, key)
                }
                XCTAssertEqual(try JSONDecoder().decode([[String: String]].self, from: XCTUnwrap(restored.data(forKey: "customDictionary")))[0]["word"], "PHTV")
                XCTAssertTrue(restored.bool(forKey: UserDefaultsKey.switchKey2Migrated))
            }
        }
    }

    @MainActor
    func testClipboardImagesFilesGroupsAndHotkeysSurviveNewRoot() throws {
        try fixture { source, _, root, _ in
            let id = UUID()
            let cache = root.appendingPathComponent("ClipboardHistoryFiles/\(id.uuidString)")
            try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
            let image = cache.appendingPathComponent("image.png")
            let document = cache.appendingPathComponent("document.txt")
            try Data([1, 2, 3]).write(to: image)
            try Data("được trường".utf8).write(to: document)
            let hotkey = ClipboardItemHotkey(modifiers: [.command, .option], keyCode: 18)
            let history = [ClipboardHistoryItem(id: id, timestamp: Date(), textContent: "Ảnh", imageData: nil, filePaths: nil,
                fileReferences: [ClipboardHistoryFileReference(originalPath: "/missing/document.txt", cachedPath: document.path),
                                 ClipboardHistoryFileReference(originalPath: "/external/keep-separately.zip")],
                sourceApp: "com.apple.TextEdit", imageFilePath: image.path, isPinned: true, hotkey: hotkey)]
            try JSONEncoder().encode(history).write(to: root.appendingPathComponent("clipboard_history.json"))
            let group = ClipboardSavedGroup(name: "Công việc")
            let library = ClipboardSavedLibrary(groups: [group], items: [ClipboardSavedItem(title: "Mẫu", content: " dòng 1\n dòng 2 ", groupID: group.id)])
            try JSONEncoder().encode(library).write(to: root.appendingPathComponent("clipboard_saved_items.json"))
            let backup = try source.create()
            XCTAssertEqual(backup.externalFileReferenceCount, 1)
            XCTAssertNil(backup.clipboardHistory?.first?.imageFilePath)
            try fixture { destination, _, targetRoot, _ in
                try destination.apply(try SettingsBackupService.decode(JSONEncoder().encode(backup)))
                let data = try Data(contentsOf: targetRoot.appendingPathComponent("clipboard_history.json"))
                let restored = try XCTUnwrap(JSONDecoder().decode([ClipboardHistoryItem].self, from: data).first)
                XCTAssertEqual(restored.id, id)
                XCTAssertEqual(restored.imageData, Data([1, 2, 3]))
                XCTAssertEqual(restored.hotkey, hotkey)
                XCTAssertTrue(restored.isPinned)
                let path = try XCTUnwrap(restored.fileReferences?.first?.cachedPath)
                XCTAssertTrue(path.hasPrefix(targetRoot.path))
                XCTAssertEqual(try String(contentsOfFile: path, encoding: .utf8), "được trường")
                XCTAssertEqual(try destination.create().clipboardLibrary, library)
            }
        }
    }

    @MainActor
    func testAllMacroSnippetTypesAndMetadataSurviveFullBackup() throws {
        try fixture { source, defaults, _, _ in
            let category = MacroCategory(name: "Test")
            var macros = (SnippetType.allCases + [.systemTextReplacement]).enumerated().map {
                MacroItem(shortcut: "m\($0.offset)", expansion: "  mẫu\n ", categoryId: category.id, snippetType: $0.element)
            }
            macros[0].usageCount = 25
            macros[0].lastUsed = Date(timeIntervalSince1970: 12345)
            defaults.set(try JSONEncoder().encode(macros), forKey: UserDefaultsKey.macroList)
            defaults.set(try JSONEncoder().encode([category]), forKey: UserDefaultsKey.macroCategories)
            let backup = try source.create()
            try fixture { destination, target, _, _ in
                try destination.apply(try SettingsBackupService.decode(JSONEncoder().encode(backup)))
                XCTAssertEqual(try JSONDecoder().decode([MacroItem].self, from: XCTUnwrap(target.data(forKey: UserDefaultsKey.macroList))), macros)
            }
        }
    }

    @MainActor
    func testFailureAtEveryCommitStageRestoresFilesAndExactPreferences() throws {
        for stage in ["clipboard_history.json", "clipboard_saved_items.json", "preferences", "commit"] {
            try fixture { service, defaults, root, domain in
                defaults.register(defaults: [UserDefaultsKey.quickTelex: false])
                defaults.set("untouched", forKey: "testSentinel")
                let original = Data("[]".utf8)
                let url = root.appendingPathComponent("clipboard_history.json")
                try original.write(to: url)
                let prior = defaults.persistentDomain(forName: domain)! as NSDictionary
                var backup = SettingsBackup(version: "3.0", exportDate: "", settings: [UserDefaultsKey.quickTelex: .boolean(true)])
                backup.clipboardHistory = [ClipboardHistoryItem(id: UUID(), timestamp: Date(), textContent: "new", imageData: nil, filePaths: nil, sourceApp: nil)]
                backup.clipboardLibrary = ClipboardSavedLibrary()
                service.beforeWrite = { if $0 == stage { throw CocoaError(.fileWriteOutOfSpace) } }
                XCTAssertThrowsError(try service.apply(backup), stage)
                XCTAssertEqual(defaults.persistentDomain(forName: domain)! as NSDictionary, prior, stage)
                XCTAssertEqual(try Data(contentsOf: url), original, stage)
                XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("clipboard_saved_items.json").path))
                XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("backup-import-journal.json").path))
            }
        }
    }

    @MainActor
    func testDurableJournalRecoversInterruptedImportOnNewService() throws {
        try fixture { service, defaults, root, domain in
            let key = UserDefaultsKey.quickTelex
            let prior = try PropertyListSerialization.data(fromPropertyList: [false], format: .binary, options: 0)
            let journal = SettingsBackupService.Journal(preferenceKeys: [key], preferences: [key: prior],
                fileNames: ["clipboard_history.json"], files: ["clipboard_history.json": Data("[]".utf8)])
            try JSONEncoder().encode(journal).write(to: root.appendingPathComponent("backup-import-journal.json"))
            defaults.set(true, forKey: key)
            try Data("corrupted partial write".utf8).write(to: root.appendingPathComponent("clipboard_history.json"))
            XCTAssertThrowsError(try service.create())
            try SettingsBackupService(defaults: defaults, root: root, defaultsDomain: domain).recoverInterruptedImport()
            XCTAssertFalse(defaults.bool(forKey: key))
            XCTAssertEqual(try service.create().clipboardHistory?.count, 0)
        }
    }

    @MainActor
    func testLegacyMissingFieldsPreserveDestinationAndEmptyArraysClear() throws {
        try fixture { service, defaults, _, _ in
            let macros = [MacroItem(shortcut: "a", expansion: "abc")]
            defaults.set(try JSONEncoder().encode(macros), forKey: UserDefaultsKey.macroList)
            try service.apply(SettingsBackupService.decode(Data(#"{"version":"1.0","exportDate":"old","excludedApps":["com.test.app"]}"#.utf8)))
            XCTAssertEqual(try service.create().macros, macros)
            XCTAssertEqual(try service.create().excludedAppsV2?.first?.bundleIdentifier, "com.test.app")
            try service.apply(SettingsBackupService.decode(Data(#"{"version":"2.0","exportDate":"old","macros":[]}"#.utf8)))
            XCTAssertEqual(try service.create().macros, [])
        }
    }

    @MainActor
    func testInvalidArchivesNeverWrite() throws {
        let invalid = [
            #"{"version":"99","exportDate":""}"#,
            #"{"version":"3.0","exportDate":"","settings":{"unknown":true}}"#,
            #"{"version":"3.0","exportDate":"","settings":{"vInputType":99}}"#,
            #"{"version":"3.0","exportDate":"","settings":{"vInputType":null}}"#,
            #"{"version":"3.0","exportDate":"","macros":[{"shortcut":"","expansion":"x"}]}"#
        ]
        try fixture { service, defaults, root, domain in
            defaults.set("sentinel", forKey: "testSentinel")
            let before = defaults.persistentDomain(forName: domain)! as NSDictionary
            for json in invalid {
                XCTAssertThrowsError(try service.apply(SettingsBackupService.decode(Data(json.utf8))), json)
                XCTAssertEqual(defaults.persistentDomain(forName: domain)! as NSDictionary, before)
                XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), [])
            }
        }
    }

    @MainActor
    func testCorruptSourceExportFailsWithoutClearingIt() throws {
        try fixture { service, defaults, _, _ in
            let bytes = Data("not JSON".utf8)
            defaults.set(bytes, forKey: UserDefaultsKey.macroList)
            XCTAssertThrowsError(try service.create())
            XCTAssertEqual(defaults.data(forKey: UserDefaultsKey.macroList), bytes)
        }
    }

    func testMacroOnlyJSONPreservesDynamicTypesAndContent() throws {
        let macros = SnippetType.allCases.map { MacroItem(shortcut: $0.rawValue, expansion: " \n mẫu ", snippetType: $0) }
        let restored = try MacroTransferCodec.decode(MacroTransferCodec.encode(macros: macros, categories: []), json: true)
        XCTAssertEqual(restored.macros, macros)
    }

    func testOldMacroJSONAndMergeReplaceByIDOrNormalizedShortcut() throws {
        let old = Data(#"{"macros":[{"shortcut":"ABC","expansion":" new "}]}"#.utf8)
        let archive = try MacroTransferCodec.decode(old, json: true)
        let merged = try MacroTransferCodec.merged(archive, macros: [MacroItem(shortcut: "abc", expansion: "old")], categories: [])
        XCTAssertEqual(merged.macros.count, 1)
        XCTAssertEqual(merged.macros[0].expansion, " new ")
        XCTAssertEqual(merged.macros[0].snippetType, .static)
        let again = try MacroTransferCodec.merged(merged, macros: merged.macros, categories: [])
        XCTAssertEqual(again.macros, merged.macros)
    }

    func testCSVQuotesMultilineCommasAndWhitespace() throws {
        let text = "# comment\r\na,unquoted,comma\r\nb,\" dòng 1\n\"\"dòng 2\"\" \"\n"
        let macros = try MacroTransferCodec.decode(Data(text.utf8), json: false).macros
        XCTAssertEqual(macros.count, 2)
        XCTAssertEqual(macros[0].expansion, "unquoted,comma")
        XCTAssertEqual(macros[1].expansion, " dòng 1\n\"dòng 2\" ")
        for bad in ["valid,value\nbroken line", "x,\"open", "x,\"closed\"oops", "x,"] {
            XCTAssertThrowsError(try MacroTransferCodec.decode(Data(bad.utf8), json: false))
        }
    }

    func testNestedValuesRejectUnsupportedTypesRatherThanReplacingWithEmptyText() throws {
        let value = try AnyCodableValue(["list": ["one", "two"], "counts": ["one": 2]] as [String: Any])
        XCTAssertNoThrow(try JSONDecoder().decode(AnyCodableValue.self, from: JSONEncoder().encode(value)))
        XCTAssertThrowsError(try AnyCodableValue(Date()))
        XCTAssertThrowsError(try AnyCodableValue(Double.infinity))
        XCTAssertThrowsError(try JSONDecoder().decode(AnyCodableValue.self, from: Data("null".utf8)))
    }

    @MainActor
    func testInvalidSettingBoundariesAndReferencesAreRejectedBeforeWrites() throws {
        try fixture { service, _, root, _ in
            for (key, value) in [
                (UserDefaultsKey.inputType, AnyCodableValue.integer(4)),
                (UserDefaultsKey.codeTable, .integer(-1)),
                (UserDefaultsKey.beepVolume, .double(1.01)),
                (UserDefaultsKey.singleModifierSwitchKeys, .integer(512)),
                (UserDefaultsKey.keyboardCleaningDuration, .double(0)),
                (UserDefaultsKey.clipboardHistoryMaxItems, .integer(101)),
                (UserDefaultsKey.updateCheckInterval, .double(0.5)),
                (UserDefaultsKey.emojiHotkeyModifiers, .integer(-1))
            ] {
                XCTAssertThrowsError(try service.apply(SettingsBackup(version: "3.0", exportDate: "", settings: [key: value])), key)
            }
            var backup = SettingsBackup(version: "3.0", exportDate: "")
            backup.clipboardFiles = [ClipboardBackupFile(itemID: UUID(), referenceIndex: 0, data: Data([1]))]
            XCTAssertThrowsError(try service.apply(backup))
            backup.clipboardFiles = nil
            backup.clipboardLibrary = ClipboardSavedLibrary(items: [ClipboardSavedItem(title: "test", content: "abc", groupID: UUID())])
            XCTAssertThrowsError(try service.apply(backup))
            backup.clipboardLibrary = ClipboardSavedLibrary(version: 99)
            XCTAssertThrowsError(try service.apply(backup))
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), [])
        }
    }

    @MainActor
    func testPartialCategoryReplacementCannotOrphanExistingMacros() throws {
        try fixture { service, defaults, _, _ in
            let category = MacroCategory(name: "Keep")
            let bytes = try JSONEncoder().encode([MacroItem(shortcut: "abc", expansion: "content", categoryId: category.id)])
            defaults.set(bytes, forKey: UserDefaultsKey.macroList)
            defaults.set(try JSONEncoder().encode([category]), forKey: UserDefaultsKey.macroCategories)
            XCTAssertThrowsError(try service.apply(SettingsBackup(version: "2.0", exportDate: "", macroCategories: [])))
            XCTAssertEqual(defaults.data(forKey: UserDefaultsKey.macroList), bytes)
        }
    }

    @MainActor
    func testCacheWritesCannotEscapeThroughSymlink() throws {
        try fixture { service, _, root, _ in
            try fixture { _, _, outside, _ in
                try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("ClipboardHistoryFiles"), withDestinationURL: outside)
                let item = ClipboardHistoryItem(id: UUID(), timestamp: Date(), textContent: nil, imageData: nil, filePaths: nil,
                    fileReferences: [ClipboardHistoryFileReference(originalPath: "/external/file.txt")], sourceApp: nil)
                var backup = SettingsBackup(version: "3.0", exportDate: "")
                backup.clipboardHistory = [item]
                backup.clipboardFiles = [ClipboardBackupFile(itemID: item.id, referenceIndex: 0, data: Data([1]))]
                XCTAssertThrowsError(try service.apply(backup))
                XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: outside.path), [])
            }
        }
    }

    @MainActor
    func testMissingCacheCannotBeSilentlyExportedAsEmpty() throws {
        try fixture { service, _, root, _ in
            let item = ClipboardHistoryItem(id: UUID(), timestamp: Date(), textContent: nil, imageData: nil, filePaths: nil,
                sourceApp: nil, imageFilePath: root.appendingPathComponent("ClipboardHistoryFiles/missing.png").path)
            let bytes = try JSONEncoder().encode([item])
            try bytes.write(to: root.appendingPathComponent("clipboard_history.json"))
            XCTAssertThrowsError(try service.create())
            XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("clipboard_history.json")), bytes)
        }
    }

    @MainActor
    func testLegacyClipboardMigrationOccursOnlyOnSuccessfulImport() throws {
        try fixture { service, defaults, _, _ in
            let legacy = Data("[]".utf8)
            defaults.set(legacy, forKey: UserDefaultsKey.clipboardHistoryData)
            var backup = SettingsBackup(version: "3.0", exportDate: "")
            backup.clipboardHistory = []
            service.beforeWrite = { if $0 == "commit" { throw CocoaError(.fileWriteUnknown) } }
            XCTAssertThrowsError(try service.apply(backup))
            XCTAssertEqual(defaults.data(forKey: UserDefaultsKey.clipboardHistoryData), legacy)
            service.beforeWrite = nil
            try service.apply(backup)
            XCTAssertNil(defaults.object(forKey: UserDefaultsKey.clipboardHistoryData))
        }
    }

    func testSmartSwitchMalformedBinaryRejected() throws {
        for bytes: [UInt8] in [[], [0], [1, 0], [0, 0, 1], [1, 0, 1, 65, 255]] {
            var backup = SettingsBackup(version: "3.0", exportDate: "")
            backup.smartSwitchData = Data(bytes)
            XCTAssertThrowsError(try SettingsBackupSchema.validate(backup))
        }
    }
}
