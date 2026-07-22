//
//  KeyboardCleaningServiceTests.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import ApplicationServices
import XCTest
@testable import PHTV

final class KeyboardCleaningServiceTests: XCTestCase {
    override func tearDown() {
        PHTVKeyboardCleaningService.stopCleaning()
        super.tearDown()
    }

    func testCleaningModeBlocksKeyboardEventsOnlyWhileActive() {
        let now = Date(timeIntervalSince1970: 100)
        PHTVKeyboardCleaningService.startCleaning(durationSeconds: 60, now: now)

        XCTAssertTrue(PHTVKeyboardCleaningService.shouldBlockKeyboardEvent(type: .keyDown, now: now))
        XCTAssertTrue(PHTVKeyboardCleaningService.shouldBlockKeyboardEvent(type: .keyUp, now: now))
        XCTAssertTrue(PHTVKeyboardCleaningService.shouldBlockKeyboardEvent(type: .flagsChanged, now: now))
        XCTAssertFalse(PHTVKeyboardCleaningService.shouldBlockKeyboardEvent(type: .leftMouseDown, now: now))
        XCTAssertFalse(PHTVKeyboardCleaningService.shouldBlockKeyboardEvent(type: .rightMouseDown, now: now))

        let afterExpiration = now.addingTimeInterval(61)
        XCTAssertFalse(PHTVKeyboardCleaningService.shouldBlockKeyboardEvent(type: .keyDown, now: afterExpiration))
    }

    func testStopCleaningReleasesKeyboardImmediately() {
        let now = Date(timeIntervalSince1970: 200)
        PHTVKeyboardCleaningService.startCleaning(durationSeconds: 60, now: now)

        PHTVKeyboardCleaningService.stopCleaning()

        XCTAssertFalse(PHTVKeyboardCleaningService.shouldBlockKeyboardEvent(type: .keyDown, now: now))
        XCTAssertFalse(PHTVKeyboardCleaningService.snapshot(now: now).isActive)
    }

    func testDurationIsClampedToSafeBounds() {
        let now = Date(timeIntervalSince1970: 300)

        var snapshot = PHTVKeyboardCleaningService.startCleaning(durationSeconds: 1, now: now)
        XCTAssertEqual(snapshot.durationSeconds, 15)
        XCTAssertEqual(snapshot.remainingSeconds, 15)

        snapshot = PHTVKeyboardCleaningService.startCleaning(durationSeconds: 9999, now: now)
        XCTAssertEqual(snapshot.durationSeconds, 600)
        XCTAssertEqual(snapshot.remainingSeconds, 600)
    }
}
