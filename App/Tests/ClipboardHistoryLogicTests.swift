//
//  ClipboardHistoryLogicTests.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import XCTest
@testable import PHTV

final class ClipboardHistoryLogicTests: XCTestCase {

    func testClipboardPanelToggleGateRejectsDuplicateHotkeyDelivery() {
        var gate = FloatingPanelHotkeyGate(minimumInterval: 0.20)

        XCTAssertTrue(gate.shouldAccept(at: 100))
        XCTAssertFalse(gate.shouldAccept(at: 100.05))
        XCTAssertFalse(gate.shouldAccept(at: 100.199))
        XCTAssertTrue(gate.shouldAccept(at: 100.20))
    }

    func testClipboardPanelToggleGateRecoversWhenUptimeMovesBackwards() {
        var gate = FloatingPanelHotkeyGate(minimumInterval: 0.20)

        XCTAssertTrue(gate.shouldAccept(at: 100))
        XCTAssertTrue(gate.shouldAccept(at: 1))
        XCTAssertFalse(gate.shouldAccept(at: 1.10))
    }

    func testOversizedImageWithoutOtherContentIsDiscarded() {
        let payload = ClipboardHistoryCaptureSanitizer.sanitizedPayload(
            textContent: nil,
            imageData: Data(repeating: 0, count: ClipboardHistoryCaptureSanitizer.maxImageBytes + 1),
            filePaths: nil
        )

        XCTAssertNil(payload)
    }

    func testOversizedImageKeepsTextPayload() {
        let payload = ClipboardHistoryCaptureSanitizer.sanitizedPayload(
            textContent: "hello",
            imageData: Data(repeating: 0, count: ClipboardHistoryCaptureSanitizer.maxImageBytes + 1),
            filePaths: nil
        )

        XCTAssertEqual(
            payload,
            ClipboardHistoryCapturePayload(
                textContent: "hello",
                imageData: nil,
                filePaths: nil
            )
        )
    }

    func testTrimmedItemsRespectsConfiguredLimit() {
        let items = (0..<12).map { index in
            ClipboardHistoryItem(
                id: UUID(),
                timestamp: Date().addingTimeInterval(TimeInterval(index)),
                textContent: "Item \(index)",
                imageData: nil,
                filePaths: nil,
                sourceApp: nil
            )
        }

        let trimmed = ClipboardHistoryStoragePolicy.trimmed(items, maxItems: 10)

        XCTAssertEqual(trimmed.count, 10)
        XCTAssertEqual(trimmed.map { $0.textContent ?? "" }, (0..<10).map { "Item \($0)" })
    }

    func testClampedMaxItemsStaysWithinAllowedRange() {
        XCTAssertEqual(ClipboardHistoryStoragePolicy.clampedMaxItems(1), 10)
        XCTAssertEqual(ClipboardHistoryStoragePolicy.clampedMaxItems(250), 100)
    }

    func testSensitiveAppsAreExcludedFromCapture() {
        XCTAssertFalse(
            ClipboardHistoryPrivacyPolicy.shouldCaptureContent(from: "com.1password.1password")
        )
        XCTAssertFalse(
            ClipboardHistoryPrivacyPolicy.shouldCaptureContent(from: "org.keepassxc.keepassxc")
        )
    }

    func testRegularAppsStillAllowCapture() {
        XCTAssertTrue(
            ClipboardHistoryPrivacyPolicy.shouldCaptureContent(from: "com.google.Chrome")
        )
        XCTAssertTrue(
            ClipboardHistoryPrivacyPolicy.shouldCaptureContent(from: nil)
        )
    }

    func testPastePayloadPrioritizesImageOverFileURL() {
        let item = ClipboardHistoryItem(
            id: UUID(),
            timestamp: Date(),
            textContent: nil,
            imageData: Data([0x89, 0x50, 0x4E, 0x47]),
            filePaths: ["/tmp/Screenshot 2026-05-21 at 22-02-42.png"],
            sourceApp: nil
        )

        XCTAssertEqual(
            ClipboardHistoryPastePayloadResolver.resolve(item, fileExists: { _ in true }),
            .image(Data([0x89, 0x50, 0x4E, 0x47]))
        )
    }

    func testPastePayloadUsesCachedFileBeforeOriginalPath() {
        let item = ClipboardHistoryItem(
            id: UUID(),
            timestamp: Date(),
            textContent: nil,
            imageData: nil,
            filePaths: ["/Users/example/Desktop/original.png"],
            fileReferences: [
                ClipboardHistoryFileReference(
                    originalPath: "/Users/example/Desktop/original.png",
                    cachedPath: "/Users/example/Library/Application Support/PHTV/ClipboardHistoryFiles/item/original.png",
                    displayName: "original.png",
                    sizeBytes: 12
                )
            ],
            sourceApp: nil
        )

        XCTAssertEqual(
            ClipboardHistoryPastePayloadResolver.resolve(item) { path in
                path.contains("ClipboardHistoryFiles")
            },
            .files(["/Users/example/Library/Application Support/PHTV/ClipboardHistoryFiles/item/original.png"])
        )
    }

    func testPastePayloadFallsBackToOriginalFileWhenCacheIsMissing() {
        let item = ClipboardHistoryItem(
            id: UUID(),
            timestamp: Date(),
            textContent: nil,
            imageData: nil,
            filePaths: ["/Users/example/Desktop/report.pdf"],
            fileReferences: [
                ClipboardHistoryFileReference(
                    originalPath: "/Users/example/Desktop/report.pdf",
                    cachedPath: "/missing/report.pdf",
                    displayName: "report.pdf",
                    sizeBytes: 12
                )
            ],
            sourceApp: nil
        )

        XCTAssertEqual(
            ClipboardHistoryPastePayloadResolver.resolve(item) { path in
                path == "/Users/example/Desktop/report.pdf"
            },
            .files(["/Users/example/Desktop/report.pdf"])
        )
    }

    func testLegacyClipboardHistoryJSONDecodesWithoutFileReferences() throws {
        let id = UUID()
        let json = """
        [
          {
            "id": "\(id.uuidString)",
            "timestamp": 0,
            "textContent": null,
            "imageData": null,
            "filePaths": ["/Users/example/Desktop/old.png"],
            "sourceApp": "com.apple.finder"
          }
        ]
        """.data(using: .utf8)!

        let items = try JSONDecoder().decode([ClipboardHistoryItem].self, from: json)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].id, id)
        XCTAssertEqual(items[0].filePaths, ["/Users/example/Desktop/old.png"])
        XCTAssertNil(items[0].fileReferences)
    }
}
