//
//  ClipboardHistoryImageCodingTests.swift
//  PHTV
//
//  Legacy inline image decoding must preserve bytes without changing the cache.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import XCTest
@testable import PHTV

final class ClipboardHistoryImageCodingTests: XCTestCase {
    private let imageBytes = Data([0x89, 0x50, 0x4E, 0x47, 0x00, 0xFF])

    private func legacyRecord(id: UUID) -> [String: Any] {
        [
            "id": id.uuidString,
            "timestamp": 700_000_000,
            "imageData": imageBytes.base64EncodedString()
        ]
    }

    private func cacheDirectory(for id: UUID) throws -> URL {
        try XCTUnwrap(FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first)
            .appendingPathComponent("PHTV", isDirectory: true)
            .appendingPathComponent("ClipboardHistoryFiles", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
    }

    private func decode(_ record: [String: Any]) throws -> ClipboardHistoryItem {
        try JSONDecoder().decode(
            ClipboardHistoryItem.self,
            from: JSONSerialization.data(withJSONObject: record)
        )
    }

    private func encodedRecord(_ item: ClipboardHistoryItem) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(
            with: JSONEncoder().encode(item)
        ) as? [String: Any])
    }

    func testLegacyDecodeRetainsBytesWithoutCreatingCache() throws {
        let id = UUID()
        let directory = try cacheDirectory(for: id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
        // Remove only this test-owned UUID if a regression writes a cache entry.
        defer { ClipboardHistoryFileCache.removeCache(for: id) }

        let item = try decode(legacyRecord(id: id))

        XCTAssertEqual(item.imageData, imageBytes)
        XCTAssertNil(item.imageFilePath)
        XCTAssertTrue(item.hasImage)
        XCTAssertEqual(item.contentType, .image)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func testLegacyImageRoundTripPreservesPayloadAndMetadata() throws {
        let id = UUID()
        defer { ClipboardHistoryFileCache.removeCache(for: id) }
        let hotkey = ClipboardItemHotkey(modifiers: [.command, .shift], keyCode: 18)
        var record = legacyRecord(id: id)
        record["textContent"] = "Hình ảnh đã ghim"
        record["sourceApp"] = "com.example.image-coding-test"
        record["filePaths"] = ["/tmp/\(id.uuidString)/source.png"]
        record["fileReferences"] = [[
            "originalPath": "/tmp/\(id.uuidString)/source.png",
            "cachedPath": "/tmp/\(id.uuidString)/cached.png",
            "displayName": "source.png",
            "sizeBytes": 123
        ]]
        record["isPinned"] = true
        record["hotkey"] = ["modifiersRaw": hotkey.modifiersRaw, "keyCode": hotkey.keyCode]

        let item = try decode(record)
        let encoded = try JSONEncoder().encode(item)
        let restored = try JSONDecoder().decode(ClipboardHistoryItem.self, from: encoded)

        XCTAssertEqual(restored, item)
        XCTAssertEqual(restored.imageData, imageBytes)
        XCTAssertNil(restored.imageFilePath)
        XCTAssertEqual(restored.id, id)
        XCTAssertEqual(restored.timestamp, Date(timeIntervalSinceReferenceDate: 700_000_000))
        XCTAssertEqual(restored.textContent, "Hình ảnh đã ghim")
        XCTAssertEqual(restored.sourceApp, "com.example.image-coding-test")
        XCTAssertEqual(restored.filePaths, record["filePaths"] as? [String])
        XCTAssertEqual(restored.fileReferences?.first?.displayName, "source.png")
        XCTAssertEqual(restored.fileReferences?.first?.sizeBytes, 123)
        XCTAssertTrue(restored.isPinned)
        XCTAssertEqual(restored.hotkey, hotkey)
        XCTAssertEqual(try encodedRecord(item)["imageData"] as? String, imageBytes.base64EncodedString())
    }

    func testInvalidLaterArrayRecordCannotCreateImageCache() throws {
        let id = UUID()
        let directory = try cacheDirectory(for: id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
        defer { ClipboardHistoryFileCache.removeCache(for: id) }
        let records = [legacyRecord(id: id), ["id": "invalid-later-record"]]
        let data = try JSONSerialization.data(withJSONObject: records)

        XCTAssertThrowsError(try JSONDecoder().decode([ClipboardHistoryItem].self, from: data))

        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path),
                       "An unsuccessful history decode must not leave migrated images behind")
    }

    func testExistingImagePathTakesPrecedenceOverLegacyBytes() throws {
        let id = UUID()
        let path = "/tmp/\(id.uuidString)/image.png"
        var record = legacyRecord(id: id)
        record["imageFilePath"] = path
        // An obsolete inline field must not be decoded when the path is authoritative.
        record["imageData"] = "not valid base64!"

        let item = try decode(record)

        XCTAssertEqual(item.imageFilePath, path)
        XCTAssertNil(item.imageData)
        let encoded = try encodedRecord(item)
        XCTAssertEqual(encoded["imageFilePath"] as? String, path)
        XCTAssertNil(encoded["imageData"])
    }

    func testPathBackedCaptureDoesNotDuplicateInlinePayloadOnEncode() throws {
        let id = UUID()
        let path = "/tmp/\(id.uuidString)/image.png"
        let item = ClipboardHistoryItem(
            id: id,
            timestamp: Date(timeIntervalSinceReferenceDate: 700_000_000),
            textContent: nil,
            imageData: imageBytes,
            filePaths: nil,
            sourceApp: nil,
            imageFilePath: path
        )

        let record = try encodedRecord(item)

        XCTAssertEqual(record["imageFilePath"] as? String, path)
        XCTAssertNil(record["imageData"])
    }

    func testCaptureWithoutDurableImagePathRetainsPayloadOnEncode() throws {
        let id = UUID()
        defer { ClipboardHistoryFileCache.removeCache(for: id) }
        let item = ClipboardHistoryItem(
            id: id,
            timestamp: Date(timeIntervalSinceReferenceDate: 700_000_000),
            textContent: nil,
            imageData: imageBytes,
            filePaths: nil,
            sourceApp: nil
        )

        let restored = try JSONDecoder().decode(
            ClipboardHistoryItem.self, from: JSONEncoder().encode(item)
        )

        XCTAssertEqual(restored, item)
        XCTAssertEqual(restored.imageData, imageBytes)
    }

    func testPinAndHotkeyChangesRetainLegacyImageBytes() throws {
        let id = UUID()
        defer { ClipboardHistoryFileCache.removeCache(for: id) }
        let item = try decode(legacyRecord(id: id))
        let hotkey = ClipboardItemHotkey(modifiers: [.option, .command], keyCode: 19)
        let pinned = item.withPinned(true).withHotkey(hotkey)
        let restored = try JSONDecoder().decode(
            ClipboardHistoryItem.self, from: JSONEncoder().encode(pinned)
        )

        XCTAssertEqual(restored.imageData, imageBytes)
        XCTAssertTrue(restored.isPinned)
        XCTAssertEqual(restored.hotkey, hotkey)
        let unpinned = restored.withPinned(false)
        XCTAssertEqual(unpinned.imageData, imageBytes)
        XCTAssertNil(unpinned.hotkey)
    }
}
