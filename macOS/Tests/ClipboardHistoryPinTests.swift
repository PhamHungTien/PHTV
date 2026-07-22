//
//  ClipboardHistoryPinTests.swift
//  PHTV
//
//  Pinned clipboard items must be kept until the user unpins or deletes them:
//  they survive the retention window, the item-count limit, and never consume
//  the regular history's budget.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import XCTest
@testable import PHTV

final class ClipboardHistoryPinTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func item(ageDays: Double, text: String = "x", pinned: Bool = false) -> ClipboardHistoryItem {
        ClipboardHistoryItem(
            id: UUID(),
            timestamp: now.addingTimeInterval(-ageDays * 86_400),
            textContent: text,
            imageData: nil,
            filePaths: nil,
            fileReferences: nil,
            sourceApp: nil,
            imageFilePath: nil,
            isPinned: pinned
        )
    }

    // MARK: - Retention window never expires pinned items

    func testPinnedItemSurvivesRetentionWindow() {
        let pinnedOld = item(ageDays: 400, text: "pinned", pinned: true)
        let staleOld = item(ageDays: 400, text: "stale")

        let kept = ClipboardHistoryStoragePolicy.retained(
            [pinnedOld, staleOld], retention: .threeDays, now: now
        )

        XCTAssertEqual(kept.map(\.textContent), ["pinned"],
                       "A pinned item must never expire, no matter its age")
    }

    // MARK: - Item-count limit never trims pinned items

    func testPinnedItemsAreNeverTrimmedByCountLimit() {
        // 15 pinned + 20 unpinned, limit 10: all pinned stay, unpinned trimmed to 10.
        let pinned = (0..<15).map { item(ageDays: 0, text: "p\($0)", pinned: true) }
        let unpinned = (0..<20).map { item(ageDays: 0, text: "u\($0)") }

        let kept = ClipboardHistoryStoragePolicy.trimmed(pinned + unpinned, maxItems: 10)

        XCTAssertEqual(kept.filter(\.isPinned).count, 15)
        XCTAssertEqual(kept.filter { !$0.isPinned }.count, 10)
    }

    func testPinnedItemsDoNotConsumeTheUnpinnedBudget() {
        // Pinned items interleaved before unpinned ones must not push recent
        // unpinned items out of the limit.
        let items = [
            item(ageDays: 0, text: "p0", pinned: true),
            item(ageDays: 0, text: "u0"),
            item(ageDays: 0, text: "p1", pinned: true),
            item(ageDays: 0, text: "u1"),
            item(ageDays: 0, text: "u2")
        ]

        let kept = ClipboardHistoryStoragePolicy.trimmed(items, maxItems: 10)
        XCTAssertEqual(kept.count, 5, "Below the limit nothing is trimmed")

        // minimumItems clamps maxItems to >= 10, so build a real overflow:
        let many = (0..<12).map { item(ageDays: 0, text: "u\($0)") }
        let keptWithPins = ClipboardHistoryStoragePolicy.trimmed(
            [item(ageDays: 0, text: "pin", pinned: true)] + many, maxItems: 10
        )
        XCTAssertEqual(keptWithPins.filter { !$0.isPinned }.map(\.textContent).count, 10)
        XCTAssertTrue(keptWithPins.contains { $0.textContent == "pin" })
        XCTAssertTrue(keptWithPins.contains { $0.textContent == "u9" },
                      "The 10th unpinned item stays — the pin must not consume its slot")
        XCTAssertFalse(keptWithPins.contains { $0.textContent == "u10" })
    }

    // MARK: - enforced(): both limits combined

    func testEnforcedKeepsOldPinnedItemButAppliesLimitsToRest() {
        let pinnedAncient = item(ageDays: 999, text: "pinned", pinned: true)
        let fresh = (0..<12).map { item(ageDays: 0, text: "f\($0)") }
        let stale = item(ageDays: 30, text: "stale")

        let kept = ClipboardHistoryStoragePolicy.enforced(
            [pinnedAncient] + fresh + [stale], retention: .oneWeek, maxItems: 10, now: now
        )

        XCTAssertTrue(kept.contains { $0.textContent == "pinned" })
        XCTAssertFalse(kept.contains { $0.textContent == "stale" })
        XCTAssertEqual(kept.filter { !$0.isPinned }.count, 10)
    }

    // MARK: - Persistence compatibility

    func testHistoryWrittenBeforePinFeatureDecodesAsUnpinned() throws {
        let legacyJSON = """
        [{"id":"11111111-2222-3333-4444-555555555555",
          "timestamp":700000000,
          "textContent":"legacy"}]
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode([ClipboardHistoryItem].self, from: legacyJSON)

        XCTAssertEqual(decoded.count, 1)
        XCTAssertFalse(decoded[0].isPinned)
    }

    func testPinnedFlagRoundTripsThroughEncoding() throws {
        let original = [
            item(ageDays: 0, text: "pinned", pinned: true),
            item(ageDays: 0, text: "regular")
        ]

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode([ClipboardHistoryItem].self, from: data)

        XCTAssertEqual(decoded.map(\.isPinned), [true, false])
        XCTAssertEqual(decoded.map(\.textContent), ["pinned", "regular"])
    }

    func testWithPinnedPreservesEveryOtherField() {
        let original = ClipboardHistoryItem(
            id: UUID(),
            timestamp: now,
            textContent: "text",
            imageData: nil,
            filePaths: ["/tmp/a"],
            fileReferences: [ClipboardHistoryFileReference(originalPath: "/tmp/a")],
            sourceApp: "com.example.app",
            imageFilePath: "/tmp/img.png",
            isPinned: false
        )

        let pinned = original.withPinned(true)

        XCTAssertTrue(pinned.isPinned)
        XCTAssertEqual(pinned.id, original.id)
        XCTAssertEqual(pinned.timestamp, original.timestamp)
        XCTAssertEqual(pinned.textContent, original.textContent)
        XCTAssertEqual(pinned.filePaths, original.filePaths)
        XCTAssertEqual(pinned.fileReferences, original.fileReferences)
        XCTAssertEqual(pinned.sourceApp, original.sourceApp)
        XCTAssertEqual(pinned.imageFilePath, original.imageFilePath)
        XCTAssertFalse(pinned.withPinned(false).isPinned)
    }
}
