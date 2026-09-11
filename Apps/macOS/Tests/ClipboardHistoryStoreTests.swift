//
//  ClipboardHistoryStoreTests.swift
//  PHTV
//
//  History persistence uses in-memory dependencies only. No test touches the
//  user's preferences, clipboard, history file, or image/file cache.
//

import XCTest
@testable import PHTV

final class ClipboardHistoryStoreTests: XCTestCase {
    private func item(index: Int = 0, imageData: Data? = nil) -> ClipboardHistoryItem {
        ClipboardHistoryItem(
            id: UUID(),
            timestamp: Date(timeIntervalSinceReferenceDate: Double(index)),
            textContent: "History fixture \(index)",
            imageData: imageData,
            filePaths: nil,
            sourceApp: "com.example.history-store-test",
            isPinned: index.isMultiple(of: 2),
            hotkey: index.isMultiple(of: 2)
                ? ClipboardItemHotkey(modifiers: [.control, .option], keyCode: 18) : nil
        )
    }

    private func encode(_ items: [ClipboardHistoryItem]) throws -> Data {
        try JSONEncoder().encode(items)
    }

    private func decode(_ data: Data?) throws -> [ClipboardHistoryItem] {
        try JSONDecoder().decode([ClipboardHistoryItem].self, from: XCTUnwrap(data))
    }

    @MainActor
    func testMigrationCommitsEntireLegacySnapshotBeforeDeletingSourceOrRetiredCaches() throws {
        let fixture = ClipboardHistoryStoreFixture()
        // Deliberately old and over the usual count limit: migration cannot prune.
        let source = (0..<125).map { item(index: $0, imageData: Data([0x89, UInt8($0)])) }
        fixture.legacyData = try encode(source)
        let retiredID = UUID()
        let store = fixture.makeStore()
        store.retireCaches(for: [retiredID])

        let result = store.load()

        XCTAssertEqual(result.items, source)
        XCTAssertNil(result.warning)
        XCTAssertTrue(result.canCleanupOrphans)
        XCTAssertEqual(try decode(fixture.fileData), source)
        XCTAssertEqual(fixture.writes.count, 1)
        XCTAssertNil(fixture.legacyData)
        XCTAssertEqual(fixture.removedCacheIDs, [retiredID])
        XCTAssertEqual(fixture.events.filter { $0 != .readLegacy }, [
            .readFile, .writeFile, .removeLegacy, .removeCache(retiredID)
        ])
    }

    @MainActor
    func testFailedMigrationPreservesLegacyInlineBytesAndCachesThenCanRetry() throws {
        let fixture = ClipboardHistoryStoreFixture()
        let source = [item(imageData: Data([0x89, 0x50, 0x00, 0xFF])), item(index: 1)]
        let originalLegacy = try encode(source)
        let previousFile = try encode([item(index: 2)])
        fixture.legacyData = originalLegacy
        fixture.fileData = previousFile
        fixture.writeError = .write
        let store = fixture.makeStore()
        let retiredID = UUID()
        store.retireCaches(for: [retiredID])

        let result = store.load()

        XCTAssertEqual(result.items, source)
        XCTAssertNotNil(result.warning)
        XCTAssertFalse(result.canCleanupOrphans)
        XCTAssertEqual(fixture.legacyData, originalLegacy)
        XCTAssertEqual(fixture.fileData, previousFile)
        XCTAssertTrue(fixture.writes.isEmpty)
        XCTAssertTrue(fixture.removedCacheIDs.isEmpty)
        XCTAssertFalse(fixture.events.contains(.removeLegacy))

        fixture.writeError = nil
        try store.save(result.items)

        XCTAssertEqual(try decode(fixture.fileData), source)
        XCTAssertEqual(try decode(fixture.fileData).first?.imageData, source.first?.imageData)
        XCTAssertNil(fixture.legacyData)
        XCTAssertEqual(fixture.backups, [previousFile])
        XCTAssertTrue(fixture.removedCacheIDs.isEmpty,
                      "A retained recovery snapshot may still reference retired caches")
    }

    @MainActor
    func testRestartAfterFailedMigrationRecoversTheCompleteOriginalSource() throws {
        let fixture = ClipboardHistoryStoreFixture()
        let source = [item(imageData: Data([1, 2, 3])), item(index: 1)]
        let originalLegacy = try encode(source)
        fixture.legacyData = originalLegacy
        fixture.writeError = .write

        let firstResult = fixture.makeStore().load()
        XCTAssertEqual(firstResult.items, source)
        XCTAssertEqual(fixture.legacyData, originalLegacy)

        fixture.writeError = nil
        let restartedStore = fixture.makeStore()
        let restartedResult = restartedStore.load()

        XCTAssertEqual(restartedResult.items, source)
        XCTAssertNil(restartedResult.warning)
        XCTAssertTrue(restartedResult.canCleanupOrphans)
        XCTAssertEqual(try decode(fixture.fileData), source)
        XCTAssertNil(fixture.legacyData)
        XCTAssertTrue(fixture.removedCacheIDs.isEmpty)
    }

    @MainActor
    func testMalformedLegacyIsRetainedWhileValidFileRemainsUsable() throws {
        let fixture = ClipboardHistoryStoreFixture()
        let malformed = Data("[{\"id\":\"damaged-legacy\"}]".utf8)
        let diskItems = [item(index: 7)]
        fixture.legacyData = malformed
        fixture.fileData = try encode(diskItems)
        let store = fixture.makeStore()

        let result = store.load()

        XCTAssertEqual(result.items, diskItems)
        XCTAssertNotNil(result.warning)
        XCTAssertFalse(result.canCleanupOrphans)
        XCTAssertEqual(fixture.legacyData, malformed)
        XCTAssertTrue(fixture.writes.isEmpty)
        XCTAssertTrue(fixture.removedCacheIDs.isEmpty)
        store.retireCaches(for: diskItems.map(\.id))
        try store.save([])
        XCTAssertEqual(fixture.legacyData, malformed)
        XCTAssertFalse(fixture.events.contains(.removeLegacy))
        XCTAssertTrue(fixture.removedCacheIDs.isEmpty,
                      "Malformed legacy bytes may reference any cache UUID")
    }

    @MainActor
    func testMalformedLegacyWithoutFileIsNotDeletedOrAutomaticallyRewritten() throws {
        let fixture = ClipboardHistoryStoreFixture()
        let malformed = Data([0xFF, 0x00, 0xFE])
        fixture.legacyData = malformed

        let result = fixture.makeStore().load()

        XCTAssertTrue(result.items.isEmpty)
        XCTAssertNotNil(result.warning)
        XCTAssertFalse(result.canCleanupOrphans)
        XCTAssertEqual(fixture.legacyData, malformed)
        XCTAssertNil(fixture.fileData)
        XCTAssertTrue(fixture.writes.isEmpty)
        XCTAssertFalse(fixture.events.contains(.removeLegacy))
    }

    @MainActor
    func testCorruptFileIsBackedUpBeforeNewSnapshotOverwritesIt() throws {
        let fixture = ClipboardHistoryStoreFixture()
        let damaged = Data("original unreadable history bytes".utf8)
        fixture.fileData = damaged
        let store = fixture.makeStore()
        let result = store.load()
        XCTAssertTrue(result.items.isEmpty)
        XCTAssertNotNil(result.warning)
        XCTAssertFalse(result.canCleanupOrphans)
        XCTAssertTrue(fixture.backups.isEmpty)
        fixture.events.removeAll()
        let replacement = [item(index: 3)]

        try store.save(replacement)

        XCTAssertEqual(fixture.events, [.preserveRecoveryFile, .writeFile])
        XCTAssertEqual(fixture.backups, [damaged])
        XCTAssertEqual(try decode(fixture.fileData), replacement)
    }

    @MainActor
    func testFailedCorruptFileBackupBlocksOverwriteAndCacheCleanupUntilRetry() throws {
        let fixture = ClipboardHistoryStoreFixture()
        let damaged = Data([0xFF, 0x01])
        fixture.fileData = damaged
        fixture.backupError = .backup
        let store = fixture.makeStore()
        _ = store.load()
        let retiredID = UUID()
        store.retireCaches(for: [retiredID])
        fixture.events.removeAll()
        let replacement = [item(index: 4)]

        XCTAssertThrowsError(try store.save(replacement)) { error in
            XCTAssertEqual(error as? ClipboardHistoryStoreFixture.Failure, .backup)
        }

        XCTAssertEqual(fixture.events, [.preserveRecoveryFile])
        XCTAssertEqual(fixture.fileData, damaged)
        XCTAssertTrue(fixture.backups.isEmpty)
        XCTAssertTrue(fixture.writes.isEmpty)
        XCTAssertTrue(fixture.removedCacheIDs.isEmpty)
        fixture.backupError = nil
        try store.save(replacement)
        XCTAssertEqual(fixture.backups, [damaged])
        XCTAssertEqual(try decode(fixture.fileData), replacement)
        XCTAssertTrue(fixture.removedCacheIDs.isEmpty,
                      "Caches remain protected while the unreadable recovery backup exists")
    }

    @MainActor
    func testSuccessfulBackupSurvivesAFailedWriteAndIsNotRepeatedOnRetry() throws {
        let fixture = ClipboardHistoryStoreFixture()
        let damaged = Data("corrupt source".utf8)
        fixture.fileData = damaged
        fixture.writeError = .write
        let store = fixture.makeStore()
        _ = store.load()
        let replacement = [item(index: 5)]

        XCTAssertThrowsError(try store.save(replacement))

        XCTAssertEqual(fixture.backups, [damaged])
        XCTAssertEqual(fixture.fileData, damaged)
        fixture.writeError = nil
        try store.save(replacement)
        XCTAssertEqual(fixture.backups, [damaged])
        XCTAssertEqual(try decode(fixture.fileData), replacement)
    }

    @MainActor
    func testRestartWithRecoveryBackupDisablesOrphanAndRetiredCacheCleanup() throws {
        let fixture = ClipboardHistoryStoreFixture()
        let damaged = Data("damaged history referencing image caches".utf8)
        fixture.fileData = damaged
        let firstStore = fixture.makeStore()
        _ = firstStore.load()
        let currentItem = item(index: 20)
        try firstStore.save([currentItem])
        XCTAssertEqual(fixture.backups, [damaged])

        let restartedStore = fixture.makeStore()
        let result = restartedStore.load()

        XCTAssertEqual(result.items, [currentItem])
        XCTAssertNotNil(result.warning)
        XCTAssertFalse(result.canCleanupOrphans)
        restartedStore.retireCaches(for: [currentItem.id, UUID()])
        try restartedStore.save([])
        XCTAssertTrue(fixture.removedCacheIDs.isEmpty)
        XCTAssertEqual(fixture.backups, [damaged])

        // A later legacy migration must respect the same existing backup.
        let legacy = [item(index: 21)]
        fixture.legacyData = try encode(legacy)
        let afterLegacyMigration = fixture.makeStore().load()
        XCTAssertEqual(afterLegacyMigration.items, legacy)
        XCTAssertNotNil(afterLegacyMigration.warning)
        XCTAssertFalse(afterLegacyMigration.canCleanupOrphans)
        XCTAssertNil(fixture.legacyData)
        XCTAssertTrue(fixture.removedCacheIDs.isEmpty)
    }

    @MainActor
    func testValidLegacyCannotOverwriteAnUnreadableExistingFile() throws {
        let fixture = ClipboardHistoryStoreFixture()
        let legacy = [item(index: 22, imageData: Data([1, 3, 5]))]
        let source = try encode(legacy)
        let destination = try encode([item(index: 23)])
        fixture.legacyData = source
        fixture.fileData = destination
        fixture.readError = .read
        let store = fixture.makeStore()

        let result = store.load()

        XCTAssertEqual(result.items, legacy)
        XCTAssertNotNil(result.warning)
        XCTAssertFalse(result.canCleanupOrphans)
        XCTAssertEqual(fixture.legacyData, source)
        XCTAssertEqual(fixture.fileData, destination)
        XCTAssertTrue(fixture.writes.isEmpty)
        XCTAssertTrue(fixture.backups.isEmpty)
        XCTAssertTrue(fixture.removedCacheIDs.isEmpty)
        fixture.readError = nil
        fixture.events.removeAll()
        XCTAssertThrowsError(try store.save(legacy)) { error in
            XCTAssertEqual(error as? ClipboardHistoryStoreFixture.Failure, .read)
        }
        XCTAssertTrue(fixture.events.isEmpty,
                      "A failed initial read requires reopening before any overwrite")

        let restarted = fixture.makeStore().load()
        XCTAssertEqual(restarted.items, legacy)
        XCTAssertNotNil(restarted.warning)
        XCTAssertFalse(restarted.canCleanupOrphans)
        XCTAssertEqual(fixture.backups, [destination])
        XCTAssertEqual(try decode(fixture.fileData), legacy)
        XCTAssertNil(fixture.legacyData)
    }

    @MainActor
    func testDifferentExistingSnapshotMustBeBackedUpBeforeLegacyMigration() throws {
        let fixture = ClipboardHistoryStoreFixture()
        let legacy = [item(index: 24)]
        let source = try encode(legacy)
        let destination = try encode([item(index: 25, imageData: Data([2, 4, 6]))])
        fixture.legacyData = source
        fixture.fileData = destination
        fixture.backupError = .backup
        let store = fixture.makeStore()
        store.retireCaches(for: [UUID()])

        let result = store.load()

        XCTAssertEqual(result.items, legacy)
        XCTAssertNotNil(result.warning)
        XCTAssertFalse(result.canCleanupOrphans)
        XCTAssertEqual(fixture.legacyData, source)
        XCTAssertEqual(fixture.fileData, destination)
        XCTAssertTrue(fixture.writes.isEmpty)
        XCTAssertTrue(fixture.backups.isEmpty)
        XCTAssertTrue(fixture.removedCacheIDs.isEmpty)
        fixture.backupError = nil
        fixture.events.removeAll()
        try store.save(result.items)

        XCTAssertEqual(fixture.events.filter { $0 != .readLegacy }, [
            .preserveRecoveryFile, .writeFile, .removeLegacy
        ])
        XCTAssertEqual(fixture.backups, [destination])
        XCTAssertEqual(try decode(fixture.fileData), legacy)
        XCTAssertNil(fixture.legacyData)
        XCTAssertTrue(fixture.removedCacheIDs.isEmpty)
    }

    @MainActor
    func testIdenticalLegacyAndFileBytesDoNotNeedAnExtraRecoveryBackup() throws {
        let fixture = ClipboardHistoryStoreFixture()
        let source = [item(index: 26)]
        let data = try encode(source)
        fixture.legacyData = data
        fixture.fileData = data

        let result = fixture.makeStore().load()

        XCTAssertEqual(result.items, source)
        XCTAssertNil(result.warning)
        XCTAssertTrue(result.canCleanupOrphans)
        XCTAssertNil(fixture.legacyData)
        XCTAssertTrue(fixture.backups.isEmpty)
        XCTAssertFalse(fixture.events.contains(.preserveRecoveryFile))
    }

    @MainActor
    func testReadFailureProhibitsWritesUntilStoreIsReopened() throws {
        let fixture = ClipboardHistoryStoreFixture()
        let original = try encode([item(index: 6)])
        fixture.fileData = original
        fixture.readError = .read
        let store = fixture.makeStore()
        let result = store.load()

        XCTAssertTrue(result.items.isEmpty)
        XCTAssertNotNil(result.warning)
        XCTAssertFalse(result.canCleanupOrphans)
        fixture.readError = nil
        fixture.events.removeAll()
        XCTAssertThrowsError(try store.save([])) { error in
            XCTAssertEqual(error as? ClipboardHistoryStoreFixture.Failure, .read)
        }
        XCTAssertTrue(fixture.events.isEmpty)
        XCTAssertEqual(fixture.fileData, original)
        XCTAssertTrue(fixture.writes.isEmpty)
        XCTAssertTrue(fixture.removedCacheIDs.isEmpty)
        let reopened = fixture.makeStore()
        XCTAssertEqual(reopened.load().items, try decode(original))
        try reopened.save([])
        XCTAssertEqual(try decode(fixture.fileData), [])
    }

    @MainActor
    func testRetiredAndRemovedCachesWaitForSuccessfulSaveAndKeepStillReferencedIDs() throws {
        let fixture = ClipboardHistoryStoreFixture()
        let kept = item(index: 10)
        let removed = item(index: 11)
        let capturedThenRemoved = UUID()
        fixture.fileData = try encode([kept, removed])
        let store = fixture.makeStore()
        _ = store.load()
        store.retireCaches(for: [kept.id, removed.id, capturedThenRemoved])
        fixture.writeError = .write

        XCTAssertThrowsError(try store.save([kept]))

        XCTAssertTrue(fixture.removedCacheIDs.isEmpty)
        XCTAssertEqual(try decode(fixture.fileData), [kept, removed])
        fixture.writeError = nil
        fixture.events.removeAll()
        try store.save([kept])
        XCTAssertEqual(fixture.events.first, .writeFile)
        XCTAssertEqual(Set(fixture.removedCacheIDs), [removed.id, capturedThenRemoved])
        XCTAssertFalse(fixture.removedCacheIDs.contains(kept.id))
        XCTAssertEqual(try decode(fixture.fileData), [kept])

        fixture.removedCacheIDs.removeAll()
        try store.save([kept])
        XCTAssertTrue(fixture.removedCacheIDs.isEmpty, "A retired cache is not deleted repeatedly")
    }

    @MainActor
    func testLegacyChangedBeforeRetryCannotBeDeletedOrOverwrittenByTheStaleStore() throws {
        let fixture = ClipboardHistoryStoreFixture()
        let source = [item(index: 12)]
        fixture.legacyData = try encode(source)
        fixture.writeError = .write
        let store = fixture.makeStore()
        _ = store.load()
        let changedLegacy = try encode([item(index: 13, imageData: Data([4, 5, 6]))])
        fixture.legacyData = changedLegacy
        fixture.writeError = nil
        fixture.events.removeAll()

        XCTAssertThrowsError(try store.save(source))

        XCTAssertEqual(fixture.legacyData, changedLegacy)
        XCTAssertNil(fixture.fileData)
        XCTAssertEqual(fixture.events, [.readLegacy])
        XCTAssertTrue(fixture.writes.isEmpty)
        XCTAssertTrue(fixture.removedCacheIDs.isEmpty)
    }

    @MainActor
    func testLegacyChangedDuringWriteIsNotDeleted() throws {
        let fixture = ClipboardHistoryStoreFixture()
        let source = [item(index: 14)]
        let changedLegacy = try encode([item(index: 15, imageData: Data([7, 8, 9]))])
        fixture.legacyData = try encode(source)
        fixture.duringWrite = { fixture.legacyData = changedLegacy }
        let store = fixture.makeStore()
        store.retireCaches(for: [UUID()])

        let result = store.load()

        XCTAssertEqual(result.items, source)
        XCTAssertNotNil(result.warning)
        XCTAssertFalse(result.canCleanupOrphans)
        XCTAssertEqual(try decode(fixture.fileData), source)
        XCTAssertEqual(fixture.legacyData, changedLegacy)
        XCTAssertFalse(fixture.events.contains(.removeLegacy))
        XCTAssertTrue(fixture.removedCacheIDs.isEmpty)
        fixture.duringWrite = nil
        fixture.events.removeAll()
        XCTAssertThrowsError(try store.save(source))
        XCTAssertEqual(fixture.events, [.readLegacy])
        XCTAssertEqual(fixture.legacyData, changedLegacy)
    }
}

@MainActor
private final class ClipboardHistoryStoreFixture {
    enum Failure: Error, Equatable {
        case read, write, backup
    }

    enum Event: Equatable {
        case readFile, writeFile, preserveRecoveryFile, readLegacy, removeLegacy
        case removeCache(UUID)
    }

    var fileData: Data?
    var legacyData: Data?
    var readError: Failure?
    var writeError: Failure?
    var backupError: Failure?
    var duringWrite: (() -> Void)?
    var events: [Event] = []
    var writes: [Data] = []
    var backups: [Data] = []
    var removedCacheIDs: [UUID] = []

    func makeStore() -> ClipboardHistoryStore {
        ClipboardHistoryStore(dependencies: .init(
            readFile: {
                self.events.append(.readFile)
                if let error = self.readError { throw error }
                return self.fileData
            },
            writeFile: { data in
                self.events.append(.writeFile)
                if let error = self.writeError { throw error }
                self.duringWrite?()
                self.fileData = data
                self.writes.append(data)
            },
            preserveRecoveryFile: { data in
                self.events.append(.preserveRecoveryFile)
                if let error = self.backupError { throw error }
                self.backups.append(data)
            },
            readLegacy: {
                self.events.append(.readLegacy)
                return self.legacyData
            },
            removeLegacy: {
                self.events.append(.removeLegacy)
                self.legacyData = nil
            },
            removeCache: { id in
                self.events.append(.removeCache(id))
                self.removedCacheIDs.append(id)
            },
            hasRecoveryBackup: { !self.backups.isEmpty }
        ))
    }
}
