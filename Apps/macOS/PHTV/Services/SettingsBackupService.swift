import AppKit

@MainActor
final class SettingsBackupService {
    static func stopToProtectData(after error: Error) -> Never {
        let alert = NSAlert()
        alert.messageText = "Chưa thể phục hồi lần nhập dữ liệu bị gián đoạn"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "Thoát để bảo vệ dữ liệu")
        alert.runModal()
        // Do not run normal termination persistence over an unfinished journal.
        exit(EXIT_FAILURE)
    }
    static var applicationRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PHTV", isDirectory: true)
    }

    let defaults: UserDefaults
    let root: URL
    private let defaultsDomain: String
    /// Test seam: fail a particular write without touching real user storage.
    var beforeWrite: ((String) throws -> Void)?
    private let fm = FileManager.default
    private var journalURL: URL { root.appendingPathComponent("backup-import-journal.json") }

    init(defaults: UserDefaults = .standard, root: URL = SettingsBackupService.applicationRoot,
         defaultsDomain: String = Bundle.main.bundleIdentifier ?? "com.phamhungtien.phtv") {
        self.defaults = defaults
        self.root = root
        self.defaultsDomain = defaultsDomain
    }

    nonisolated static func decode(_ data: Data) throws -> SettingsBackup {
        guard data.count <= 512 * 1024 * 1024 else { throw BackupError.invalid("file vượt 512 MB") }
        let backup = try JSONDecoder().decode(SettingsBackup.self, from: data)
        try SettingsBackupSchema.validate(backup)
        return backup
    }

    static func read(_ url: URL) throws -> SettingsBackup {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 512 * 1024 * 1024 else { throw BackupError.invalid("file vượt 512 MB") }
        return try decode(Data(contentsOf: url))
    }

    private func stored<T: Decodable>(_ type: T.Type, key: String, fallback: T) throws -> T {
        guard let value = defaults.object(forKey: key) else { return fallback }
        guard let data = value as? Data else { throw BackupError.invalid("dữ liệu đang lưu: \(key)") }
        return try JSONDecoder().decode(type, from: data)
    }

    private func file<T: Decodable>(_ type: T.Type, name: String, fallback: T) throws -> T {
        let url = root.appendingPathComponent(name)
        guard fm.fileExists(atPath: url.path) else { return fallback }
        return try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }

    func create() throws -> SettingsBackup {
        // Do not export a partial transaction or silently heal corrupted source data.
        guard !fm.fileExists(atPath: journalURL.path) else { throw BackupError.rollbackFailed }
        var settings: [String: AnyCodableValue] = [:]
        for (key, fallback) in SettingsBackupSchema.defaults {
            settings[key] = try AnyCodableValue(defaults.object(forKey: key) ?? fallback)
        }
        var backup = SettingsBackup(
            version: SettingsBackup.currentVersion,
            exportDate: ISO8601DateFormatter().string(from: Date()),
            settings: settings,
            macros: try stored([MacroItem].self, key: UserDefaultsKey.macroList, fallback: []),
            macroCategories: try stored([MacroCategory].self, key: UserDefaultsKey.macroCategories, fallback: []),
            excludedAppsV2: try stored([ExcludedApp].self, key: UserDefaultsKey.excludedApps, fallback: []),
            sendKeyStepByStepApps: try stored([ExcludedApp].self, key: UserDefaultsKey.sendKeyStepByStepApps, fallback: []),
            upperCaseExcludedApps: try stored([ExcludedApp].self, key: UserDefaultsKey.upperCaseExcludedApps, fallback: []),
            macroExcludedApps: try stored([MacroExcludedApp].self, key: UserDefaultsKey.macroExcludedApps, fallback: [])
        )
        let history: [ClipboardHistoryItem]
        if let legacy = defaults.data(forKey: UserDefaultsKey.clipboardHistoryData) {
            history = try JSONDecoder().decode([ClipboardHistoryItem].self, from: legacy)
        } else {
            history = try file([ClipboardHistoryItem].self, name: "clipboard_history.json", fallback: [])
        }
        var assets: [ClipboardBackupFile] = []
        var totalBytes = 0
        func readCache(_ path: String) throws -> Data {
            let url = URL(fileURLWithPath: path).resolvingSymlinksInPath()
            let cacheRoot = root.appendingPathComponent("ClipboardHistoryFiles").resolvingSymlinksInPath().path + "/"
            guard url.path.hasPrefix(cacheRoot) else { throw BackupError.invalid("cache ngoài thư mục PHTV") }
            let size = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard size.isRegularFile == true, let count = size.fileSize,
                  count <= 256 * 1024 * 1024 - totalBytes else {
                throw BackupError.invalid("dữ liệu đính kèm vượt 256 MB")
            }
            let data = try Data(contentsOf: url)
            totalBytes += data.count
            return data
        }
        backup.clipboardHistory = try history.map { item in
            let image = try item.imageFilePath.map { try readCache($0) } ?? item.imageData
            var refs: [ClipboardHistoryFileReference]?
            if let originalRefs = item.fileReferences {
                refs = try originalRefs.enumerated().map { index, ref in
                    if let path = ref.cachedPath {
                        assets.append(ClipboardBackupFile(itemID: item.id, referenceIndex: index, data: try readCache(path)))
                    }
                    return ClipboardHistoryFileReference(originalPath: ref.originalPath, displayName: ref.displayName, sizeBytes: ref.sizeBytes)
                }
            }
            return ClipboardHistoryItem(id: item.id, timestamp: item.timestamp, textContent: item.textContent,
                                        imageData: image, filePaths: item.filePaths, fileReferences: refs,
                                        sourceApp: item.sourceApp, isPinned: item.isPinned, hotkey: item.hotkey)
        }
        backup.clipboardFiles = assets
        backup.clipboardLibrary = try file(ClipboardSavedLibrary.self, name: "clipboard_saved_items.json", fallback: ClipboardSavedLibrary())
        backup.smartSwitchData = defaults.data(forKey: "smartSwitchKey") ?? Data([0, 0])
        backup.customDictionary = try stored([[String: AnyCodableValue]].self, key: "customDictionary", fallback: [])
        try SettingsBackupSchema.validate(backup)
        return backup
    }

    struct Journal: Codable {
        var preferenceKeys: [String]
        var preferences: [String: Data]
        var fileNames: [String]
        var files: [String: Data]
    }

    func apply(_ backup: SettingsBackup) throws {
        try recoverInterruptedImport()
        try SettingsBackupSchema.validate(backup)
        var values = try SettingsBackupSchema.normalizedSettings(backup.settings ?? [:])
        if backup.macros != nil || backup.macroCategories != nil {
            let macros = try backup.macros ?? stored([MacroItem].self, key: UserDefaultsKey.macroList, fallback: [])
            let categories = try backup.macroCategories ?? stored([MacroCategory].self, key: UserDefaultsKey.macroCategories, fallback: [])
            try SettingsBackupSchema.validateMacros(macros, categories: categories)
        }
        func encode<T: Encodable>(_ value: T?, key: String) throws {
            if let value { values[key] = try JSONEncoder().encode(value) }
        }
        try encode(backup.macros, key: UserDefaultsKey.macroList)
        try encode(backup.macroCategories, key: UserDefaultsKey.macroCategories)
        try encode(backup.macroExcludedApps, key: UserDefaultsKey.macroExcludedApps)
        try encode(backup.customDictionary, key: "customDictionary")
        let legacyApps = backup.excludedApps?.map {
            ExcludedApp(bundleIdentifier: $0, name: $0.components(separatedBy: ".").last ?? $0, path: "")
        }
        try encode(backup.excludedAppsV2 ?? legacyApps, key: UserDefaultsKey.excludedApps)
        try encode(backup.sendKeyStepByStepApps, key: UserDefaultsKey.sendKeyStepByStepApps)
        try encode(backup.upperCaseExcludedApps, key: UserDefaultsKey.upperCaseExcludedApps)
        if let data = backup.smartSwitchData { values["smartSwitchKey"] = data }
        if values[UserDefaultsKey.switchKey2Status] != nil { values[UserDefaultsKey.switchKey2Migrated] = true }
        // Old backups may only contain the legacy flag. Do not retain an unrelated
        // mode from the destination machine in that case.
        if values[UserDefaultsKey.autoRestoreEnglishWordMode] == nil,
           let legacy = values[UserDefaultsKey.restoreIfWrongSpelling] as? Bool {
            values[UserDefaultsKey.autoRestoreEnglishWordMode] = legacy ? 0 : 1
        }
        var files: [String: Data] = [:]
        let assets = Dictionary(uniqueKeysWithValues: (backup.clipboardFiles ?? []).map { ("\($0.itemID):\($0.referenceIndex)", $0) })
        if let library = backup.clipboardLibrary { files["clipboard_saved_items.json"] = try JSONEncoder().encode(library) }
        if let history = backup.clipboardHistory {
            let imported = history.map { item in
                let refs = item.fileReferences?.enumerated().map { index, ref in
                    guard let asset = assets["\(item.id):\(index)"]
                    else { return ref }
                    // Never use archive paths as write targets. UUID-generated names
                    // also keep the existing cache intact until commit succeeds.
                    let suffix = URL(fileURLWithPath: ref.displayName).pathExtension
                        .filter { $0.isASCII && ($0.isLetter || $0.isNumber) }.prefix(16)
                    let leaf = UUID().uuidString + (suffix.isEmpty ? "" : ".\(suffix)")
                    let name = "ClipboardHistoryFiles/\(item.id.uuidString)/\(leaf)"
                    files[name] = asset.data
                    return ClipboardHistoryFileReference(originalPath: ref.originalPath,
                        cachedPath: root.appendingPathComponent(name).path, displayName: ref.displayName,
                        sizeBytes: Int64(asset.data.count))
                }
                return ClipboardHistoryItem(id: item.id, timestamp: item.timestamp, textContent: item.textContent,
                    imageData: item.imageData, filePaths: item.filePaths, fileReferences: refs,
                    sourceApp: item.sourceApp, isPinned: item.isPinned, hotkey: item.hotkey)
            }
            files["clipboard_history.json"] = try JSONEncoder().encode(imported)
        }
        let removals = backup.clipboardHistory == nil ? [] : [UserDefaultsKey.clipboardHistoryData]
        try commit(values: values, removals: removals, files: files)
    }

    private func checkedURL(_ relative: String) throws -> URL {
        let components = relative.split(separator: "/", omittingEmptySubsequences: false)
        let knownFile = ["clipboard_history.json", "clipboard_saved_items.json"].contains(relative)
        let asset = components.count == 3 && components[0] == "ClipboardHistoryFiles"
            && UUID(uuidString: String(components[1])) != nil
            && !components[2].isEmpty && components[2] != "." && components[2] != ".."
        guard knownFile || asset else { throw BackupError.invalid("đường dẫn dữ liệu") }
        // resolvingSymlinksInPath may leave a nonexistent leaf unresolved. Check
        // each existing ancestor, not just the final URL, before creating it.
        var ancestor = root
        for component in components {
            ancestor.appendPathComponent(String(component))
            if let attributes = try? fm.attributesOfItem(atPath: ancestor.path),
               attributes[.type] as? FileAttributeType == .typeSymbolicLink {
                throw BackupError.invalid("đường dẫn cache là symlink")
            }
        }
        let url = root.appendingPathComponent(relative)
        guard url.resolvingSymlinksInPath().path.hasPrefix(root.resolvingSymlinksInPath().path + "/")
        else { throw BackupError.invalid("đường dẫn symlink ngoài kho dữ liệu") }
        return url
    }

    private func write(_ data: Data, to url: URL) throws {
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
                               attributes: [.posixPermissions: 0o700])
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func commit(values: [String: Any], removals: [String], files: [String: Data]) throws {
        var journal = Journal(preferenceKeys: Array(Set(values.keys).union(removals)).sorted(),
                              preferences: [:], fileNames: files.keys.sorted(), files: [:])
        for key in journal.preferenceKeys {
            if let value = defaults.persistentDomain(forName: defaultsDomain)?[key] {
                journal.preferences[key] = try PropertyListSerialization.data(fromPropertyList: [value], format: .binary, options: 0)
            }
        }
        for name in journal.fileNames {
            let url = try checkedURL(name)
            if fm.fileExists(atPath: url.path) { journal.files[name] = try Data(contentsOf: url) }
        }
        try write(JSONEncoder().encode(journal), to: journalURL)
        do {
            for name in files.keys.sorted() {
                try beforeWrite?(name)
                try write(files[name]!, to: checkedURL(name))
            }
            try beforeWrite?("preferences")
            for key in removals { defaults.removeObject(forKey: key) }
            for (key, value) in values { defaults.set(value, forKey: key) }
            guard defaults.synchronize() else { throw CocoaError(.fileWriteUnknown) }
            try beforeWrite?("commit")
            try fm.removeItem(at: journalURL)
        } catch {
            do { try recoverInterruptedImport() }
            catch { throw BackupError.rollbackFailed }
            throw error
        }
    }

    /// The durable journal remains until every write succeeds. This also restores
    /// an interrupted import on next launch, before settings or history are loaded.
    func recoverInterruptedImport() throws {
        guard fm.fileExists(atPath: journalURL.path) else { return }
        let journal = try JSONDecoder().decode(Journal.self, from: Data(contentsOf: journalURL))
        for name in journal.fileNames {
            let url = try checkedURL(name)
            if let bytes = journal.files[name] { try write(bytes, to: url) }
            else if fm.fileExists(atPath: url.path) { try fm.removeItem(at: url) }
        }
        for key in journal.preferenceKeys {
            if let data = journal.preferences[key] {
                guard let array = try PropertyListSerialization.propertyList(from: data, format: nil) as? [Any],
                      array.count == 1 else { throw BackupError.rollbackFailed }
                defaults.set(array[0], forKey: key)
            } else { defaults.removeObject(forKey: key) }
        }
        guard defaults.synchronize() else { throw BackupError.rollbackFailed }
        try fm.removeItem(at: journalURL)
    }
}
