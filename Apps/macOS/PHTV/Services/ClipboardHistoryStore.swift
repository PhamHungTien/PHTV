import Foundation

/// Owns the durable history snapshot. Decode is pure; only a successful atomic
/// write permits removal of legacy defaults or cache files from an older snapshot.
@MainActor
final class ClipboardHistoryStore {
    struct Dependencies {
        var readFile: () throws -> Data?
        var writeFile: (Data) throws -> Void
        var preserveRecoveryFile: (Data) throws -> Void
        var readLegacy: () -> Data?
        var removeLegacy: () -> Void
        var removeCache: (UUID) -> Void
        var hasRecoveryBackup: () -> Bool = { false }
    }

    struct LoadResult {
        var items: [ClipboardHistoryItem]
        var warning: String?
        var canCleanupOrphans: Bool
    }

    private let dependencies: Dependencies
    private var pendingLegacy: Data?
    private var pendingRecoveryFile: Data?
    private var fileReadError: Error?
    private var durableIDs: Set<UUID> = []
    private var retiredIDs: Set<UUID> = []
    private var protectRecoveryCaches = false

    var recoveryWarning: String? {
        protectRecoveryCaches
            ? "Lịch sử có dữ liệu cần khôi phục. Bản gốc và cache được giữ để tránh mất ảnh hoặc file."
            : nil
    }

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    convenience init(fileURL: URL, defaults: UserDefaults = .standard) {
        self.init(dependencies: Dependencies(
            readFile: {
                do { return try Data(contentsOf: fileURL) }
                catch let error as CocoaError where error.code == .fileReadNoSuchFile { return nil }
            },
            writeFile: { data in
                try FileManager.default.createDirectory(
                    at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
                )
                try data.write(to: fileURL, options: .atomic)
            },
            preserveRecoveryFile: { data in
                let backup = fileURL.deletingPathExtension()
                    .appendingPathExtension("recovery-\(UUID().uuidString).json")
                try data.write(to: backup, options: .atomic)
            },
            readLegacy: { defaults.data(forKey: UserDefaultsKey.clipboardHistoryData) },
            removeLegacy: { defaults.removeObject(forKey: UserDefaultsKey.clipboardHistoryData) },
            removeCache: { ClipboardHistoryFileCache.removeCache(for: $0) },
            hasRecoveryBackup: {
                let prefix = fileURL.deletingPathExtension().lastPathComponent + ".recovery-"
                // An unreadable backup may reference any cache UUID. Keep all
                // caches until recovery has been handled and the app reopened.
                guard let files = try? FileManager.default.contentsOfDirectory(
                    atPath: fileURL.deletingLastPathComponent().path
                ) else { return true }
                return files.contains { $0.hasPrefix(prefix) && $0.hasSuffix(".json") }
            }
        ))
    }

    func load() -> LoadResult {
        protectRecoveryCaches = dependencies.hasRecoveryBackup()
        var warning = recoveryWarning
        if let legacy = dependencies.readLegacy() {
            do {
                let items = try JSONDecoder().decode([ClipboardHistoryItem].self, from: legacy)
                pendingLegacy = legacy
                durableIDs = Set(items.map(\.id))
                // Persist the complete source before any retention/count pruning.
                do {
                    // Earlier migration attempts can leave both sources. Never
                    // overwrite a different disk snapshot without preserving it.
                    do {
                        if let existing = try dependencies.readFile(), existing != legacy {
                            pendingRecoveryFile = existing
                            protectRecoveryCaches = true
                        }
                    } catch {
                        fileReadError = error
                        throw error
                    }
                    try save(items)
                    return LoadResult(items: items, warning: recoveryWarning, canCleanupOrphans: !protectRecoveryCaches)
                } catch {
                    return LoadResult(
                        items: items,
                        warning: "Chưa chuyển được lịch sử Clipboard sang file. Dữ liệu cũ vẫn được giữ để thử lại.",
                        canCleanupOrphans: false
                    )
                }
            } catch {
                // Preserve malformed bytes for recovery; a valid file may still
                // be usable. Never delete legacy data merely because decode failed.
                warning = "Không đọc được lịch sử Clipboard cũ. Bản gốc vẫn được giữ để khôi phục."
                protectRecoveryCaches = true
            }
        }

        do {
            guard let data = try dependencies.readFile() else {
                return LoadResult(items: [], warning: warning, canCleanupOrphans: false)
            }
            do {
                let items = try JSONDecoder().decode([ClipboardHistoryItem].self, from: data)
                durableIDs = Set(items.map(\.id))
                return LoadResult(items: items, warning: warning, canCleanupOrphans: !protectRecoveryCaches)
            } catch {
                pendingRecoveryFile = data
                protectRecoveryCaches = true
                return LoadResult(
                    items: [], warning: "Không đọc được file lịch sử Clipboard. Bản gốc sẽ được sao lưu trước khi ghi mới.",
                    canCleanupOrphans: false
                )
            }
        } catch {
            // Without the original bytes, overwriting would destroy the only
            // recoverable source. Re-open the store after the read error is fixed.
            fileReadError = error
            return LoadResult(
                items: [], warning: "Không truy cập được file lịch sử Clipboard. Tạm ngưng lưu để bảo vệ dữ liệu gốc.",
                canCleanupOrphans: false
            )
        }
    }

    func retireCaches(for ids: some Sequence<UUID>) {
        retiredIDs.formUnion(ids)
    }

    func save(_ items: [ClipboardHistoryItem]) throws {
        if let fileReadError { throw fileReadError }
        if let pendingLegacy, dependencies.readLegacy() != pendingLegacy {
            throw CocoaError(.fileWriteFileExists)
        }
        let data = try JSONEncoder().encode(items)
        if let pendingRecoveryFile {
            try dependencies.preserveRecoveryFile(pendingRecoveryFile)
            self.pendingRecoveryFile = nil
        }
        try dependencies.writeFile(data)
        // A changed source is not ours to delete, even if it changed during I/O.
        if let pendingLegacy {
            guard dependencies.readLegacy() == pendingLegacy else {
                throw CocoaError(.fileWriteFileExists)
            }
            dependencies.removeLegacy()
            self.pendingLegacy = nil
        }
        let currentIDs = Set(items.map(\.id))
        let removedIDs = durableIDs.union(retiredIDs).subtracting(currentIDs)
        durableIDs = currentIDs
        if protectRecoveryCaches {
            retiredIDs = removedIDs
        } else {
            retiredIDs.removeAll()
            removedIDs.forEach(dependencies.removeCache)
        }
    }
}
