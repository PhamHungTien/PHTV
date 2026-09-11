//
//  ClipboardHistoryPasteServiceTests.swift
//  PHTV
//
//  Uses only private named pasteboards and temporary files, never the user's
//  general clipboard, history directory, preferences, or keyboard event stream.
//

import AppKit
import XCTest
@testable import PHTV

final class ClipboardHistoryPasteServiceTests: XCTestCase {
    @MainActor
    func testUnavailableContentLeavesExistingPasteboardUnchanged() throws {
        let fixture = try ClipboardPasteFixture()
        defer { fixture.cleanup() }
        let missing = fixture.directory.appendingPathComponent("missing.png").path
        let unavailableItems = [
            makeItem(imageFilePath: missing),
            makeItem(filePaths: [missing]),
            makeItem()
        ]

        for item in unavailableItems {
            let changeCount = fixture.pasteboard.changeCount
            XCTAssertThrowsError(try ClipboardHistoryPasteService.prepare(item)) {
                XCTAssertEqual($0 as? ClipboardHistoryPasteService.Failure, .unavailable)
            }
            fixture.assertUnchanged(since: changeCount)
        }
    }

    @MainActor
    func testInvalidInlineAndPathBackedImageLeavesPasteboardUnchanged() throws {
        let fixture = try ClipboardPasteFixture()
        defer { fixture.cleanup() }
        let invalid = Data("not an image".utf8)
        let png = try imageData(using: .png)
        let truncatedPNG = Data(png.prefix(png.count / 2))
        let corruptURL = fixture.directory.appendingPathComponent("corrupt.png")
        try invalid.write(to: corruptURL)

        for item in [
            makeItem(imageData: invalid),
            makeItem(imageData: truncatedPNG),
            makeItem(imageFilePath: corruptURL.path)
        ] {
            let changeCount = fixture.pasteboard.changeCount
            XCTAssertThrowsError(try ClipboardHistoryPasteService.prepare(item)) {
                XCTAssertEqual($0 as? ClipboardHistoryPasteService.Failure, .invalidImage)
            }
            fixture.assertUnchanged(since: changeCount)
        }
    }

    @MainActor
    func testPrepareDoesNotChangePasteboardAndCommitWritesTextOnce() throws {
        let fixture = try ClipboardPasteFixture()
        defer { fixture.cleanup() }
        let changeCount = fixture.pasteboard.changeCount
        let text = "Nội dung tiếng Việt 👨‍👩‍👧‍👦\nDòng tiếp theo"
        let prepared = try ClipboardHistoryPasteService.prepare(makeItem(text: text))
        fixture.assertUnchanged(since: changeCount)

        var writeCount = 0
        try ClipboardHistoryPasteService.commit(prepared, to: fixture.pasteboard) { objects in
            writeCount += 1
            XCTAssertEqual(objects.count, 1)
            return fixture.pasteboard.writeObjects(objects)
        }

        XCTAssertEqual(writeCount, 1)
        XCTAssertEqual(fixture.pasteboard.string(forType: .string), text)
    }

    @MainActor
    func testSavedTextPreparationSupportsEmptyText() throws {
        let fixture = try ClipboardPasteFixture()
        defer { fixture.cleanup() }
        let prepared = try ClipboardHistoryPasteService.prepare(text: "")
        try ClipboardHistoryPasteService.commit(prepared, to: fixture.pasteboard)
        XCTAssertEqual(fixture.pasteboard.string(forType: .string), "")
    }

    @MainActor
    func testValidPNGIsPreservedAndTIFFIsMaterialized() throws {
        let fixture = try ClipboardPasteFixture()
        defer { fixture.cleanup() }
        let png = try imageData(using: .png)
        let changeCount = fixture.pasteboard.changeCount
        let prepared = try ClipboardHistoryPasteService.prepare(makeItem(imageData: png))
        fixture.assertUnchanged(since: changeCount)

        try ClipboardHistoryPasteService.commit(prepared, to: fixture.pasteboard)
        XCTAssertEqual(fixture.pasteboard.data(forType: .png), png)
        let tiff = try XCTUnwrap(fixture.pasteboard.data(forType: .tiff))
        XCTAssertNotNil(NSBitmapImageRep(data: tiff))
        XCTAssertEqual(fixture.pasteboard.pasteboardItems?.count, 1)
    }

    @MainActor
    func testLegacyTIFFIsConvertedToActualPNG() throws {
        let fixture = try ClipboardPasteFixture()
        defer { fixture.cleanup() }
        let tiff = try imageData(using: .tiff)
        let prepared = try ClipboardHistoryPasteService.prepare(makeItem(imageData: tiff))
        try ClipboardHistoryPasteService.commit(prepared, to: fixture.pasteboard)

        let png = try XCTUnwrap(fixture.pasteboard.data(forType: .png))
        XCTAssertTrue(png.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
        XCTAssertNotNil(NSBitmapImageRep(data: png))
        XCTAssertNotEqual(png, tiff)
    }

    @MainActor
    func testPathBackedImageRemainsAvailableAfterPreparation() throws {
        let fixture = try ClipboardPasteFixture()
        defer { fixture.cleanup() }
        let png = try imageData(using: .png)
        let url = fixture.directory.appendingPathComponent("image.png")
        try png.write(to: url)
        let prepared = try ClipboardHistoryPasteService.prepare(makeItem(imageFilePath: url.path))
        try FileManager.default.removeItem(at: url)

        try ClipboardHistoryPasteService.commit(prepared, to: fixture.pasteboard)
        XCTAssertEqual(fixture.pasteboard.data(forType: .png), png)
    }

    @MainActor
    func testFileURLsAreMaterializedAsSeparateItems() throws {
        let fixture = try ClipboardPasteFixture()
        defer { fixture.cleanup() }
        let first = try fixture.createFile(named: "tài liệu một.txt")
        let second = try fixture.createFile(named: "second #2.txt")
        let changeCount = fixture.pasteboard.changeCount
        let prepared = try ClipboardHistoryPasteService.prepare(
            makeItem(filePaths: [first.path, second.path])
        )
        fixture.assertUnchanged(since: changeCount)

        try ClipboardHistoryPasteService.commit(prepared, to: fixture.pasteboard)
        XCTAssertEqual(fileURLs(in: fixture.pasteboard), [first, second])
    }

    @MainActor
    func testFileDisappearingAfterPreparationLeavesPasteboardUnchanged() throws {
        let fixture = try ClipboardPasteFixture()
        defer { fixture.cleanup() }
        let first = try fixture.createFile(named: "keep.txt")
        let second = try fixture.createFile(named: "removed.txt")
        let prepared = try ClipboardHistoryPasteService.prepare(
            makeItem(filePaths: [first.path, second.path])
        )
        try FileManager.default.removeItem(at: second)
        let changeCount = fixture.pasteboard.changeCount
        var writeCount = 0

        XCTAssertThrowsError(
            try ClipboardHistoryPasteService.commit(prepared, to: fixture.pasteboard) { _ in
                writeCount += 1
                return true
            }
        ) {
            XCTAssertEqual($0 as? ClipboardHistoryPasteService.Failure, .unavailable)
        }
        XCTAssertEqual(writeCount, 0)
        fixture.assertUnchanged(since: changeCount)
    }

    @MainActor
    func testExistingPartialFileResolutionPolicyIsPreserved() throws {
        let fixture = try ClipboardPasteFixture()
        defer { fixture.cleanup() }
        let available = try fixture.createFile(named: "available.txt")
        let missing = fixture.directory.appendingPathComponent("missing.txt")
        let prepared = try ClipboardHistoryPasteService.prepare(
            makeItem(filePaths: [missing.path, available.path])
        )

        try ClipboardHistoryPasteService.commit(prepared, to: fixture.pasteboard)
        XCTAssertEqual(fileURLs(in: fixture.pasteboard), [available])
    }

    @MainActor
    func testMissingImageFallsBackToStoredText() throws {
        let fixture = try ClipboardPasteFixture()
        defer { fixture.cleanup() }
        let missing = fixture.directory.appendingPathComponent("missing.png")
        let prepared = try ClipboardHistoryPasteService.prepare(
            makeItem(text: "Nội dung dự phòng", imageFilePath: missing.path)
        )

        try ClipboardHistoryPasteService.commit(prepared, to: fixture.pasteboard)
        XCTAssertEqual(fixture.pasteboard.string(forType: .string), "Nội dung dự phòng")
    }

    @MainActor
    func testWriteFailureIsReportedAfterOneClearAndOneWriteAttempt() throws {
        let fixture = try ClipboardPasteFixture()
        defer { fixture.cleanup() }
        let prepared = try ClipboardHistoryPasteService.prepare(text: "new contents")
        let changeCount = fixture.pasteboard.changeCount
        var writeCount = 0

        XCTAssertThrowsError(
            try ClipboardHistoryPasteService.commit(prepared, to: fixture.pasteboard) { _ in
                writeCount += 1
                return false
            }
        ) {
            XCTAssertEqual($0 as? ClipboardHistoryPasteService.Failure, .writeFailed)
        }

        XCTAssertEqual(writeCount, 1)
        XCTAssertEqual(fixture.pasteboard.changeCount, changeCount + 1)
        XCTAssertNil(fixture.pasteboard.string(forType: .string))
    }

    private func makeItem(
        text: String? = nil,
        imageData: Data? = nil,
        imageFilePath: String? = nil,
        filePaths: [String]? = nil
    ) -> ClipboardHistoryItem {
        ClipboardHistoryItem(
            id: UUID(), timestamp: Date(), textContent: text,
            imageData: imageData, filePaths: filePaths, sourceApp: nil,
            imageFilePath: imageFilePath
        )
    }

    @MainActor
    private func imageData(using type: NSBitmapImageRep.FileType) throws -> Data {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 8, bitsPerPixel: 32
        ))
        for x in 0..<2 {
            for y in 0..<2 {
                bitmap.setColor(.red, atX: x, y: y)
            }
        }
        return try XCTUnwrap(bitmap.representation(using: type, properties: [:]))
    }

    @MainActor
    private func fileURLs(in pasteboard: NSPasteboard) -> [URL] {
        (pasteboard.pasteboardItems ?? []).compactMap { item in
            item.string(forType: .fileURL).flatMap { URL(string: $0) }
        }
    }
}

@MainActor
private final class ClipboardPasteFixture {
    let pasteboard: NSPasteboard
    let directory: URL
    private let sentinel = "Existing private test clipboard"

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PHTV-PasteServiceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        pasteboard = NSPasteboard.withUniqueName()
        XCTAssertTrue(pasteboard.setString(sentinel, forType: .string))
    }

    func createFile(named name: String) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try Data("test fixture".utf8).write(to: url)
        return url
    }

    func assertUnchanged(since changeCount: Int, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(pasteboard.changeCount, changeCount, file: file, line: line)
        XCTAssertEqual(pasteboard.string(forType: .string), sentinel, file: file, line: line)
    }

    func cleanup() {
        pasteboard.releaseGlobally()
        try? FileManager.default.removeItem(at: directory)
    }
}
