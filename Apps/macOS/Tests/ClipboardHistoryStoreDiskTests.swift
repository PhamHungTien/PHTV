//
//  ClipboardHistoryStoreDiskTests.swift
//  PHTV
//
//  Production persistence is exercised only in UUID-owned temporary directories
//  and UUID-scoped preferences suites. No shared clipboard or history is touched.
//

import XCTest
@testable import PHTV

final class ClipboardHistoryStoreDiskTests: XCTestCase {
    private struct Fixture {
        let directory: URL
        let historyURL: URL
        let suiteName: String
        let defaults: UserDefaults

        init() throws {
            let id = UUID().uuidString
            suiteName = "com.phamhungtien.phtv.debugtests.\(id)"
            defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
            directory = FileManager.default.temporaryDirectory.appendingPathComponent(
                "PHTV-ClipboardHistoryStoreDiskTests-\(id)", isDirectory: true
            )
            historyURL = directory.appendingPathComponent("clipboard_history.json")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        func cleanup() {
            defaults.removePersistentDomain(forName: suiteName)
            defaults.synchronize()
            phtvRemoveUserDefaultsSuiteFilesForTesting(suiteName)
            // This exact directory was generated and created by this fixture.
            try? FileManager.default.removeItem(at: directory)
        }
    }

    private func item(_ text: String, imageData: Data? = nil) -> ClipboardHistoryItem {
        ClipboardHistoryItem(
            id: UUID(),
            timestamp: Date(timeIntervalSinceReferenceDate: 700_000_000),
            textContent: text,
            imageData: imageData,
            filePaths: nil,
            sourceApp: "com.example.history-store-disk-test",
            isPinned: true
        )
    }

    @MainActor
    func testMissingHistoryCanBeSavedAndReopenedUsingProductionFileDependencies() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.historyURL.path))
        let store = ClipboardHistoryStore(fileURL: fixture.historyURL, defaults: fixture.defaults)

        let initial = store.load()

        XCTAssertTrue(initial.items.isEmpty)
        XCTAssertNil(initial.warning)
        let items = [item("new fixture", imageData: Data([0x89, 0x50, 0x00, 0xFF]))]
        try store.save(items)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.historyURL.path))
        let diskData = try Data(contentsOf: fixture.historyURL)
        XCTAssertEqual(try JSONDecoder().decode([ClipboardHistoryItem].self, from: diskData), items)

        let reopened = ClipboardHistoryStore(fileURL: fixture.historyURL, defaults: fixture.defaults)
        let restored = reopened.load()
        XCTAssertEqual(restored.items, items)
        XCTAssertNil(restored.warning)
        XCTAssertTrue(restored.canCleanupOrphans)
        // Preserve every UUID so the production cache-removal dependency is never called.
        try reopened.save(restored.items)
    }

    @MainActor
    func testLegacyMigrationPreservesDifferentDiskBytesAndRecognizesRecoveryAfterReopen() throws {
        let differentValidSnapshot = try JSONEncoder().encode([item("previous disk snapshot")])
        let unreadableSnapshot = Data("unreadable history fixture bytes".utf8)
        for oldBytes in [differentValidSnapshot, unreadableSnapshot] {
            let fixture = try Fixture()
            defer { fixture.cleanup() }
            let legacyItems = [item("legacy source", imageData: Data([1, 2, 3, 4]))]
            let legacyData = try JSONEncoder().encode(legacyItems)
            fixture.defaults.set(legacyData, forKey: UserDefaultsKey.clipboardHistoryData)
            try oldBytes.write(to: fixture.historyURL, options: .atomic)
            let store = ClipboardHistoryStore(fileURL: fixture.historyURL, defaults: fixture.defaults)

            let result = store.load()

            XCTAssertEqual(result.items, legacyItems)
            XCTAssertNotNil(result.warning)
            XCTAssertFalse(result.canCleanupOrphans)
            XCTAssertNil(fixture.defaults.data(forKey: UserDefaultsKey.clipboardHistoryData))
            XCTAssertEqual(try JSONDecoder().decode(
                [ClipboardHistoryItem].self, from: Data(contentsOf: fixture.historyURL)
            ), legacyItems)
            let backups = try FileManager.default.contentsOfDirectory(
                at: fixture.directory, includingPropertiesForKeys: nil
            ).filter {
                $0.lastPathComponent.hasPrefix("clipboard_history.recovery-") && $0.pathExtension == "json"
            }
            XCTAssertEqual(backups.count, 1)
            let backup = try XCTUnwrap(backups.first)
            XCTAssertEqual(try Data(contentsOf: backup), oldBytes)

            let reopened = ClipboardHistoryStore(fileURL: fixture.historyURL, defaults: fixture.defaults)
            let restored = reopened.load()
            XCTAssertEqual(restored.items, legacyItems)
            XCTAssertNotNil(restored.warning)
            XCTAssertFalse(restored.canCleanupOrphans,
                           "Recovery-file detection must protect caches after a real restart")
            try reopened.save(restored.items)
            XCTAssertEqual(try Data(contentsOf: backup), oldBytes)
        }
    }

    @MainActor
    func testUnusableDestinationPreservesRealLegacyDefaultsAndOriginalFile() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let legacyItems = [item("legacy cannot be written", imageData: Data([5, 6, 7]))]
        let legacyData = try JSONEncoder().encode(legacyItems)
        fixture.defaults.set(legacyData, forKey: UserDefaultsKey.clipboardHistoryData)
        let regularFile = fixture.directory.appendingPathComponent("not-a-directory")
        let barrierBytes = Data("fixture regular file".utf8)
        try barrierBytes.write(to: regularFile)
        let impossibleHistoryURL = regularFile.appendingPathComponent("clipboard_history.json")
        let store = ClipboardHistoryStore(fileURL: impossibleHistoryURL, defaults: fixture.defaults)

        let result = store.load()

        XCTAssertEqual(result.items, legacyItems)
        XCTAssertNotNil(result.warning)
        XCTAssertFalse(result.canCleanupOrphans)
        XCTAssertEqual(fixture.defaults.data(forKey: UserDefaultsKey.clipboardHistoryData), legacyData)
        XCTAssertEqual(try Data(contentsOf: regularFile), barrierBytes)
        XCTAssertFalse(FileManager.default.fileExists(atPath: impossibleHistoryURL.path))
        XCTAssertThrowsError(try store.save(result.items))
        XCTAssertEqual(fixture.defaults.data(forKey: UserDefaultsKey.clipboardHistoryData), legacyData)
        XCTAssertEqual(try Data(contentsOf: regularFile), barrierBytes)
    }
}
