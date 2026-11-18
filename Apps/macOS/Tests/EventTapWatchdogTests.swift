//
//  EventTapWatchdogTests.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import XCTest
@testable import PHTV

final class EventTapWatchdogTests: XCTestCase {
    func testKeystrokesSeenByTheTapNeverTriggerRecovery() {
        var state = PHTVKeystrokeWatchdogState()
        for index in 1...20 {
            let timestamp = UInt64(index * 1_000)
            state.noteMainTap(timestamp: timestamp)
            XCTAssertFalse(state.observePhysicalKeyDown(timestamp: timestamp, uptime: Double(index)))
        }
        XCTAssertEqual(state.recoveryCount, 0)
    }

    func testThreeMissedKeystrokesTriggerOneRecovery() {
        var state = PHTVKeystrokeWatchdogState()
        state.noteMainTap(timestamp: 1_000)
        XCTAssertFalse(state.observePhysicalKeyDown(timestamp: 2_000, uptime: 10))
        XCTAssertFalse(state.observePhysicalKeyDown(timestamp: 3_000, uptime: 10.1))
        XCTAssertTrue(state.lastObservationMissed)
        XCTAssertTrue(state.observePhysicalKeyDown(timestamp: 4_000, uptime: 10.2))
        XCTAssertEqual(state.recoveryCount, 1)
        state.noteMainTap(timestamp: 5_000)
        XCTAssertFalse(state.observePhysicalKeyDown(timestamp: 5_000, uptime: 10.3))
        XCTAssertFalse(state.lastObservationMissed)
    }

    func testOccasionalMissIsForgivenWhenTheTapCatchesUp() {
        var state = PHTVKeystrokeWatchdogState()
        XCTAssertFalse(state.observePhysicalKeyDown(timestamp: 2_000, uptime: 1))
        XCTAssertFalse(state.observePhysicalKeyDown(timestamp: 3_000, uptime: 1.1))
        state.noteMainTap(timestamp: 4_000)
        XCTAssertFalse(state.observePhysicalKeyDown(timestamp: 4_000, uptime: 1.2))
        XCTAssertFalse(state.observePhysicalKeyDown(timestamp: 5_000, uptime: 1.3))
        XCTAssertFalse(state.observePhysicalKeyDown(timestamp: 6_000, uptime: 1.4))
        XCTAssertEqual(state.recoveryCount, 0)
    }

    func testRecoveriesAreRateLimited() {
        var state = PHTVKeystrokeWatchdogState()
        var recoveries = 0
        for index in 1...30 {
            if state.observePhysicalKeyDown(timestamp: UInt64(index * 1_000), uptime: Double(index) * 0.1) {
                recoveries += 1
            }
        }
        // 3 seconds of continuous misses: one recovery, then the cooldown.
        XCTAssertEqual(recoveries, 1)
        XCTAssertTrue(state.observePhysicalKeyDown(timestamp: 100_000, uptime: 10)
            || state.observePhysicalKeyDown(timestamp: 101_000, uptime: 10.1)
            || state.observePhysicalKeyDown(timestamp: 102_000, uptime: 10.2))
    }

    func testSecureInputOwnerIsReadFromSessionDictionary() {
        XCTAssertEqual(
            PHTVSecureInputService.ownerPID(fromSessionDictionary: ["kCGSSessionSecureInputPID": NSNumber(value: 4242)]),
            4242)
        XCTAssertNil(PHTVSecureInputService.ownerPID(fromSessionDictionary: ["kCGSSessionSecureInputPID": NSNumber(value: 0)]))
        XCTAssertNil(PHTVSecureInputService.ownerPID(fromSessionDictionary: nil))
        XCTAssertEqual(PHTVSecureInputService.Status.disabled.reportDescription, "Off")
    }
}
