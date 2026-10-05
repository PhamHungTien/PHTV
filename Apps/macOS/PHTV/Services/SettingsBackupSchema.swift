import Foundation

/// One portable-settings registry for export and import. Runtime flags, device
/// identity, TCC, logs and update-channel internals are deliberately not portable.
enum SettingsBackupSchema {
    static var defaults: [String: Any] {
        var values = SettingsBootstrap.registrationDefaults()
        for key in [
            UserDefaultsKey.runOnStartupLegacy, UserDefaultsKey.switchKey2Migrated,
            UserDefaultsKey.tempOffSpelling, UserDefaultsKey.tempOffPHTV, UserDefaultsKey.otherLanguage
        ] { values.removeValue(forKey: key) }
        values[UserDefaultsKey.autoRestartOnSettingsClose] = Defaults.autoRestartOnSettingsClose
        values[UserDefaultsKey.convertToolHotKey] = Int(Int32(bitPattern: 0xFE0000FE))
        for key in ["convertToolToAllCaps", "convertToolToAllNonCaps", "convertToolToCapsFirstLetter",
                    "convertToolToCapsEachWord", "convertToolRemoveMark"] { values[key] = false }
        values["convertToolLiveConvert"] = true
        values["PHTVPickerLastTab"] = -2
        values["PHTVPickerLastEmojiSubCategory"] = 0
        values["com.phtv.recentEmojis"] = [String]()
        values["com.phtv.emojiFrequency"] = [String: Int]()
        values["RecentGIFs"] = [Int]()
        values["RecentStickers"] = [Int]()
        return values
    }

    static func normalizedSettings(_ settings: [String: AnyCodableValue]) throws -> [String: Any] {
        let registry = defaults
        var output: [String: Any] = [:]
        for (key, value) in settings {
            guard let fallback = registry[key] else { throw BackupError.invalid("khóa cài đặt không hỗ trợ: \(key)") }
            let example = try AnyCodableValue(fallback)
            switch (example, value) {
            case (.boolean, .boolean(let v)): output[key] = v
            case (.boolean, .integer(let v)) where v == 0 || v == 1: output[key] = v != 0
            case (.integer, .integer(let v)):
                guard integerIsValid(v, key: key) else { throw BackupError.invalid("giá trị \(key)") }
                output[key] = v
            case (.integer, .double(let v)):
                guard let n = Int(exactly: v), integerIsValid(n, key: key) else { throw BackupError.invalid("giá trị \(key)") }
                output[key] = n
            case (.double, .double(let v)):
                guard doubleIsValid(v, key: key) else { throw BackupError.invalid("giá trị \(key)") }
                output[key] = v
            case (.double, .integer(let v)):
                guard doubleIsValid(Double(v), key: key) else { throw BackupError.invalid("giá trị \(key)") }
                output[key] = Double(v)
            case (.string, .string(let v)) where v.count <= 256: output[key] = v
            case (.array, .array(let values)):
                guard values.count <= 1000 else { throw BackupError.invalid("danh sách quá dài") }
                if key == UserDefaultsKey.customConsonants {
                    let strings = values.compactMap { if case .string(let s) = $0 { return s }; return nil }
                    guard strings.count == values.count, strings.count <= PHTVCustomConsonants.maximumCount,
                          strings.allSatisfy({ PHTVCustomConsonants.normalizedEntry($0) != nil })
                    else { throw BackupError.invalid(key) }
                    output[key] = PHTVCustomConsonants.normalized(strings)
                    continue
                } else if key == "com.phtv.recentEmojis" {
                    guard values.allSatisfy({ if case .string(let s) = $0 { return s.count <= 64 }; return false })
                    else { throw BackupError.invalid(key) }
                } else {
                    guard values.allSatisfy({ if case .integer(let n) = $0 { return n >= 0 }; return false })
                    else { throw BackupError.invalid(key) }
                }
                output[key] = values.map(\.value)
            case (.dictionary, .dictionary(let values)):
                guard values.count <= 10000, values.allSatisfy({ k, v in
                    if case .integer(let n) = v { return k.count <= 64 && n >= 0 && n < Int.max }
                    return false
                }) else { throw BackupError.invalid(key) }
                output[key] = values.mapValues(\.value)
            default: throw BackupError.invalid("sai kiểu dữ liệu: \(key)")
            }
        }
        return output
    }

    private static func integerIsValid(_ n: Int, key: String) -> Bool {
        switch key {
        case UserDefaultsKey.inputMethod: return (0...1).contains(n)
        case UserDefaultsKey.inputType: return (0...3).contains(n)
        case UserDefaultsKey.codeTable, UserDefaultsKey.convertToolFromCode, UserDefaultsKey.convertToolToCode:
            return (0...4).contains(n)
        case UserDefaultsKey.autoRestoreEnglishWordMode: return (0...1).contains(n)
        case UserDefaultsKey.clipboardHistoryMaxItems: return (10...100).contains(n)
        case UserDefaultsKey.clipboardHistoryRetention: return ClipboardHistoryRetention(rawValue: n) != nil
        case UserDefaultsKey.customEscapeKey: return [53, 58, 59, 61, 62].contains(n)
        case UserDefaultsKey.pauseKey,
             UserDefaultsKey.emojiHotkeyKeyCode, UserDefaultsKey.clipboardHotkeyKeyCode:
            return (0...Int(KeyCode.keyMask)).contains(n)
        case UserDefaultsKey.switchKeyStatus, UserDefaultsKey.switchKey2Status, UserDefaultsKey.convertToolHotKey:
            return n >= Int(Int32.min) && n <= Int(UInt32.max)
        case UserDefaultsKey.emojiHotkeyModifiers, UserDefaultsKey.clipboardHotkeyModifiers:
            return n >= 0 && (n & ~0x9EFFFF) == 0
        case UserDefaultsKey.singleModifierSwitchKeys: return (0...511).contains(n)
        case UserDefaultsKey.updateCheckInterval: return (0...31_536_000).contains(n)
        case "PHTVPickerLastTab": return [-2, -3, -4, -5].contains(n)
        case "PHTVPickerLastEmojiSubCategory": return (0...100).contains(n)
        default: return (0...1).contains(n)
        }
    }

    private static func doubleIsValid(_ n: Double, key: String) -> Bool {
        guard n.isFinite else { return false }
        switch key {
        case UserDefaultsKey.beepVolume: return (0...1).contains(n)
        case UserDefaultsKey.menuBarIconSize: return (8...64).contains(n)
        case UserDefaultsKey.keyboardCleaningDuration: return (1...3600).contains(n)
        default: return false
        }
    }

    static func validate(_ backup: SettingsBackup) throws {
        guard ["1.0", "2.0", SettingsBackup.currentVersion].contains(backup.version)
        else { throw BackupError.invalid("phiên bản \(backup.version)") }
        _ = try normalizedSettings(backup.settings ?? [:])
        if let words = backup.customDictionary {
            guard words.count <= 100000, words.allSatisfy({ entry in
                guard case .string(let word) = entry["word"], case .string(let type) = entry["type"] else { return false }
                return !word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && word.utf8.count <= 1024
                    && ["en", "english", "vi", "vietnamese"].contains(type.lowercased())
            }) else { throw BackupError.invalid("từ điển tùy chỉnh") }
        }
        try validateMacros(backup.macros ?? [], categories: backup.macroCategories)
        for apps in [backup.excludedAppsV2, backup.sendKeyStepByStepApps, backup.upperCaseExcludedApps] {
            if let apps {
                guard apps.count <= 10000, Set(apps.map(\.bundleIdentifier)).count == apps.count,
                      apps.allSatisfy({ !$0.bundleIdentifier.isEmpty && $0.bundleIdentifier.utf8.count <= 255 })
                else { throw BackupError.invalid("danh sách ứng dụng") }
            }
        }
        if let apps = backup.macroExcludedApps {
            guard apps.count <= 10000, Set(apps.map(\.bundleIdentifier)).count == apps.count,
                  apps.allSatisfy({ !$0.bundleIdentifier.isEmpty && $0.bundleIdentifier.utf8.count <= 255 })
            else { throw BackupError.invalid("ứng dụng loại trừ gõ tắt") }
        }
        if let apps = backup.excludedApps {
            guard apps.count <= 10000, apps.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 255 })
            else { throw BackupError.invalid("ứng dụng định dạng cũ") }
        }
        if let history = backup.clipboardHistory {
            guard history.count <= 100000, Set(history.map(\.id)).count == history.count,
                  history.allSatisfy({ $0.imageFilePath == nil && ($0.hotkey?.isValid ?? true)
                      && ($0.fileReferences ?? []).allSatisfy({ $0.cachedPath == nil }) })
            else { throw BackupError.invalid("lịch sử Clipboard hoặc đường dẫn cache") }
        }
        if let library = backup.clipboardLibrary {
            guard (1...ClipboardSavedLibrary.currentVersion).contains(library.version),
                  Set(library.groups.map(\.id)).count == library.groups.count,
                  Set(library.items.map(\.id)).count == library.items.count,
                  library.groups.allSatisfy({ !$0.name.isEmpty && $0.name.count <= ClipboardSavedLibrary.maximumGroupNameLength }),
                  library.items.allSatisfy({ !$0.title.isEmpty && $0.title.count <= ClipboardSavedLibrary.maximumTitleLength
                      && !$0.content.isEmpty && $0.content.count <= ClipboardSavedLibrary.maximumContentLength
                      && ($0.hotkey?.isValid ?? true) })
            else { throw BackupError.invalid("mục Clipboard đã lưu") }
            let groupIDs = Set(library.groups.map(\.id))
            for item in library.items {
                if let group = item.groupID, !groupIDs.contains(group) {
                    throw BackupError.invalid("nhóm Clipboard không tồn tại")
                }
            }
        }
        var fileIDs = Set<String>()
        let historyByID = Dictionary(uniqueKeysWithValues: (backup.clipboardHistory ?? []).map { ($0.id, $0) })
        var attachmentBytes = 0
        for item in backup.clipboardHistory ?? [] {
            attachmentBytes += item.imageData?.count ?? 0
            guard attachmentBytes <= 256 * 1024 * 1024 else { throw BackupError.invalid("dữ liệu đính kèm vượt 256 MB") }
        }
        for file in backup.clipboardFiles ?? [] {
            attachmentBytes += file.data.count
            guard attachmentBytes <= 256 * 1024 * 1024 else { throw BackupError.invalid("dữ liệu đính kèm vượt 256 MB") }
            guard let item = historyByID[file.itemID],
                  let refs = item.fileReferences, refs.indices.contains(file.referenceIndex),
                  fileIDs.insert("\(file.itemID):\(file.referenceIndex)").inserted
            else { throw BackupError.invalid("file Clipboard không có mục tham chiếu") }
        }
        if let data = backup.smartSwitchData {
            let bytes = [UInt8](data)
            guard bytes.count >= 2 else { throw BackupError.invalid("Smart Switch") }
            let count = Int(bytes[0]) | Int(bytes[1]) << 8
            var cursor = 2
            var bundleIDs = Set<String>()
            for _ in 0..<count {
                guard cursor < bytes.count else { throw BackupError.invalid("Smart Switch") }
                let length = Int(bytes[cursor]); cursor += 1
                guard length > 0, cursor + length < bytes.count,
                      let bundle = String(bytes: bytes[cursor..<(cursor + length)], encoding: .utf8),
                      bundleIDs.insert(bundle).inserted, bytes[cursor + length] <= 9
                else { throw BackupError.invalid("Smart Switch") }
                cursor += length + 1
            }
            guard cursor == bytes.count else { throw BackupError.invalid("Smart Switch") }
        }
    }

    static func validateMacros(_ macros: [MacroItem], categories: [MacroCategory]?) throws {
        guard macros.count <= 65535, Set(macros.map(\.id)).count == macros.count,
              macros.allSatisfy({ !$0.shortcut.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  && $0.shortcut.utf8.count <= 255 && $0.expansion.utf8.count <= 65535 && $0.usageCount >= 0 })
        else { throw BackupError.invalid("gõ tắt trống, trùng ID hoặc vượt giới hạn engine") }
        if let categories {
            guard Set(categories.map(\.id)).count == categories.count else { throw BackupError.invalid("trùng danh mục") }
            let ids = Set(categories.map(\.id)).union([MacroCategory.defaultCategory.id])
            guard macros.allSatisfy({ $0.categoryId == nil || ids.contains($0.categoryId!) })
            else { throw BackupError.invalid("danh mục gõ tắt không tồn tại") }
        }
    }
}
