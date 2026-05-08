//
//  AutomaticTCCRepairRetryPolicyTests.swift
//  PHTV
//
//  Regression tests for automatic TCC repair retry policy.
//

import XCTest
@testable import PHTV

final class AutomaticTCCRepairRetryPolicyTests: XCTestCase {
    func testPolicyRejectsWhenAccessibilityIsNotTrusted() {
        XCTAssertFalse(
            phtvShouldScheduleAutomaticTCCRepair(
                accessibilityTrusted: false,
                isAttempting: false,
                attemptsInSession: 0,
                lastAttemptTime: 0,
                now: 100
            )
        )
    }

    func testPolicyRejectsWhileRepairIsRunning() {
        XCTAssertFalse(
            phtvShouldScheduleAutomaticTCCRepair(
                isAttempting: true,
                attemptsInSession: 0,
                lastAttemptTime: 0,
                now: 100
            )
        )
    }

    func testPolicyRejectsAtSessionAttemptLimit() {
        XCTAssertFalse(
            phtvShouldScheduleAutomaticTCCRepair(
                isAttempting: false,
                attemptsInSession: 3,
                lastAttemptTime: 0,
                now: 100,
                maxAttempts: 3,
                cooldown: 60
            )
        )
    }

    func testPolicyRejectsDuringCooldownWindow() {
        XCTAssertFalse(
            phtvShouldScheduleAutomaticTCCRepair(
                isAttempting: false,
                attemptsInSession: 1,
                lastAttemptTime: 100,
                now: 130,
                maxAttempts: 3,
                cooldown: 60
            )
        )
    }

    func testPolicyAllowsAfterCooldownWhenUnderLimit() {
        XCTAssertTrue(
            phtvShouldScheduleAutomaticTCCRepair(
                isAttempting: false,
                attemptsInSession: 2,
                lastAttemptTime: 100,
                now: 170,
                maxAttempts: 3,
                cooldown: 60
            )
        )
    }

    func testPolicyAllowsFirstAttemptWithoutHistory() {
        XCTAssertTrue(
            phtvShouldScheduleAutomaticTCCRepair(
                isAttempting: false,
                attemptsInSession: 0,
                lastAttemptTime: 0,
                now: 1
            )
        )
    }

    func testCorruptEntryRequiresTrustedAccessibilityAndMissingTCCRegistration() {
        XCTAssertFalse(
            phtvShouldTreatTCCEntryAsCorrupt(
                accessibilityTrusted: false,
                canCreateEventTap: false,
                isRegisteredInTCC: false
            )
        )

        XCTAssertFalse(
            phtvShouldTreatTCCEntryAsCorrupt(
                accessibilityTrusted: true,
                canCreateEventTap: true,
                isRegisteredInTCC: false
            )
        )

        XCTAssertFalse(
            phtvShouldTreatTCCEntryAsCorrupt(
                accessibilityTrusted: true,
                canCreateEventTap: false,
                isRegisteredInTCC: true
            )
        )

        XCTAssertTrue(
            phtvShouldTreatTCCEntryAsCorrupt(
                accessibilityTrusted: true,
                canCreateEventTap: false,
                isRegisteredInTCC: false
            )
        )
    }
}
