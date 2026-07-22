//
//  ClipboardHistoryRetentionTests.swift
//  PHTV
//
//  Coverage for time-based clipboard history retention (issue #209).
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import XCTest
@testable import PHTV

final class ClipboardHistoryRetentionTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func item(ageDays: Double, text: String = "x") -> ClipboardHistoryItem {
        ClipboardHistoryItem(
            id: UUID(),
            timestamp: now.addingTimeInterval(-ageDays * 86_400),
            textContent: text,
            imageData: nil,
            filePaths: nil,
            fileReferences: nil,
            sourceApp: nil,
            imageFilePath: nil
        )
    }

    // MARK: - Retention window mapping

    func testRetentionWindowsMapToExpectedAges() {
        XCTAssertNil(ClipboardHistoryRetention.forever.maxAge)
        XCTAssertEqual(ClipboardHistoryRetention.threeDays.maxAge, 3 * 86_400)
        XCTAssertEqual(ClipboardHistoryRetention.oneWeek.maxAge, 7 * 86_400)
        XCTAssertEqual(ClipboardHistoryRetention.oneMonth.maxAge, 30 * 86_400)
        XCTAssertEqual(ClipboardHistoryRetention.threeMonths.maxAge, 90 * 86_400)
    }

    func testFromRawValueFallsBackSafely() {
        XCTAssertEqual(ClipboardHistoryRetention.from(rawValue: 0), .forever)
        XCTAssertEqual(ClipboardHistoryRetention.from(rawValue: -1), .forever)
        XCTAssertEqual(ClipboardHistoryRetention.from(rawValue: 604_800), .oneWeek)
        // Unknown positive value snaps to the nearest known window.
        XCTAssertEqual(ClipboardHistoryRetention.from(rawValue: 600_000), .oneWeek)
    }

    // MARK: - retained()

    func testForeverKeepsEverything() {
        let items = [item(ageDays: 0), item(ageDays: 400)]
        let kept = ClipboardHistoryStoragePolicy.retained(items, retention: .forever, now: now)
        XCTAssertEqual(kept.count, 2)
    }

    func testExpiredItemsAreDropped() {
        let fresh = item(ageDays: 1, text: "fresh")
        let stale = item(ageDays: 5, text: "stale")

        let kept = ClipboardHistoryStoragePolicy.retained([fresh, stale], retention: .threeDays, now: now)

        XCTAssertEqual(kept.map(\.textContent), ["fresh"])
    }

    func testItemExactlyAtBoundaryIsKept() {
        let boundary = item(ageDays: 3, text: "boundary")
        let kept = ClipboardHistoryStoragePolicy.retained([boundary], retention: .threeDays, now: now)
        XCTAssertEqual(kept.count, 1, "An item exactly at the window edge must not be deleted")
    }

    func testFutureDatedItemsAreKept() {
        // Clock changes / restored backups must never trigger deletion.
        let future = item(ageDays: -2, text: "future")
        let kept = ClipboardHistoryStoragePolicy.retained([future], retention: .threeDays, now: now)
        XCTAssertEqual(kept.count, 1)
    }

    func testLongerWindowsKeepMore() {
        let items = [item(ageDays: 2), item(ageDays: 10), item(ageDays: 45), item(ageDays: 200)]

        XCTAssertEqual(ClipboardHistoryStoragePolicy.retained(items, retention: .threeDays, now: now).count, 1)
        XCTAssertEqual(ClipboardHistoryStoragePolicy.retained(items, retention: .oneWeek, now: now).count, 1)
        XCTAssertEqual(ClipboardHistoryStoragePolicy.retained(items, retention: .oneMonth, now: now).count, 2)
        XCTAssertEqual(ClipboardHistoryStoragePolicy.retained(items, retention: .threeMonths, now: now).count, 3)
    }

    // MARK: - enforced(): age + count together

    func testEnforcedAppliesAgeThenCountLimit() {
        // 5 fresh items, 2 stale ones; max 3 items.
        var items = (0..<5).map { item(ageDays: Double($0) * 0.1, text: "fresh\($0)") }
        items += [item(ageDays: 40, text: "old1"), item(ageDays: 60, text: "old2")]

        let kept = ClipboardHistoryStoragePolicy.enforced(
            items, retention: .oneWeek, maxItems: 10, now: now
        )
        XCTAssertEqual(kept.count, 5, "Stale items removed by the retention window")

        let cappedKept = ClipboardHistoryStoragePolicy.enforced(
            items, retention: .oneWeek, maxItems: 10, now: now
        )
        XCTAssertFalse(cappedKept.contains { $0.textContent == "old1" })
        XCTAssertFalse(cappedKept.contains { $0.textContent == "old2" })
    }

    func testEnforcedStillHonoursMaxItemsWhenRetentionIsForever() {
        let items = (0..<40).map { item(ageDays: Double($0) * 0.01, text: "i\($0)") }

        let kept = ClipboardHistoryStoragePolicy.enforced(
            items, retention: .forever, maxItems: 10, now: now
        )

        XCTAssertEqual(kept.count, 10)
        XCTAssertEqual(kept.first?.textContent, "i0", "Newest items are kept")
    }
}
