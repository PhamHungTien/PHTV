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
}
