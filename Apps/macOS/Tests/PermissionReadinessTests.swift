//
//  PermissionReadinessTests.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import XCTest
@testable import PHTV

final class PermissionReadinessTests: XCTestCase {

    func testResolveReturnsReadyWhenAccessibilityAndEventTapAreAvailable() {
        let state = PHTVTypingPermissionState.resolve(
            accessibilityTrusted: true,
            eventTapReady: true
        )

        XCTAssertEqual(state, .ready)
        XCTAssertTrue(state.hasAccessibilityPermission)
        XCTAssertTrue(state.isTypingPermissionReady)
    }

    func testResolveReturnsWaitingWhenAccessibilityExistsButEventTapIsNotReady() {
        let state = PHTVTypingPermissionState.resolve(
            accessibilityTrusted: true,
            eventTapReady: false
        )

        XCTAssertEqual(state, .waitingForEventTap)
        XCTAssertTrue(state.hasAccessibilityPermission)
        XCTAssertFalse(state.isTypingPermissionReady)
    }

    func testResolveReturnsAccessibilityRequiredWhenAccessibilityIsMissing() {
        let state = PHTVTypingPermissionState.resolve(
            accessibilityTrusted: false,
            eventTapReady: false
        )

        XCTAssertEqual(state, .accessibilityRequired)
        XCTAssertFalse(state.hasAccessibilityPermission)
        XCTAssertFalse(state.isTypingPermissionReady)
    }

    func testResolveRejectsImpossibleReadyStateWithoutAccessibility() {
        let state = PHTVTypingPermissionState.resolve(
            accessibilityTrusted: false,
            eventTapReady: true
        )

        XCTAssertEqual(state, .accessibilityRequired)
        XCTAssertFalse(state.hasAccessibilityPermission)
        XCTAssertFalse(state.isTypingPermissionReady)
    }

    func testGuidancePrefersAccessibilityWhenAccessibilityIsMissing() {
        let step = PHTVPermissionGuidanceStep.resolve(
            accessibilityTrusted: false,
            eventTapReady: false
        )

        XCTAssertEqual(step, .accessibility)
    }

    func testGuidanceFallsBackToRetryWhenAccessibilityExistsButTapIsNotReady() {
        let step = PHTVPermissionGuidanceStep.resolve(
            accessibilityTrusted: true,
            eventTapReady: false
        )

        XCTAssertEqual(step, .waitingForEventTap)
    }

    func testGuidanceReturnsReadyWhenAccessibilityAndTapAreAvailable() {
        let step = PHTVPermissionGuidanceStep.resolve(
            accessibilityTrusted: true,
            eventTapReady: true
        )

        XCTAssertEqual(step, .ready)
    }

    func testProbePolicyRetriesUntilReady() {
        var results: [PHTVEventTapProbeAttemptResult] = [
            .creationFailed,
            .enableFailed,
            .ready
        ]
        var delays = 0

        let outcome = PHTVPermissionService.runEventTapProbe(
            maxRetries: 3,
            retryDelay: { delays += 1 },
            attempt: { results.removeFirst() }
        )

        XCTAssertEqual(outcome, PHTVEventTapProbeOutcome(result: .ready, attempts: 3))
        XCTAssertEqual(delays, 2)
    }

    func testProbePolicyRejectsFinalDisabledTap() {
        var invalidAttempts = 0
        let outcome = PHTVPermissionService.runEventTapProbe(
            maxRetries: 3,
            retryDelay: { },
            attempt: {
                invalidAttempts += 1
                return .enableFailed
            }
        )

        XCTAssertEqual(outcome.result, .enableFailed)
        XCTAssertEqual(outcome.attempts, 3)
        XCTAssertEqual(invalidAttempts, 3)
        XCTAssertFalse(outcome.isReady)
    }

    func testAccessibilityPermissionNameChangesAtMacOS27() {
        XCTAssertEqual(
            PHTVAccessibilityPermissionNaming.displayName(
                operatingSystemVersion: OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0)
            ),
            "Trợ năng"
        )
        XCTAssertEqual(
            PHTVAccessibilityPermissionNaming.displayName(
                operatingSystemVersion: OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 0)
            ),
            "Device Control and Data Access"
        )
        XCTAssertEqual(
            PHTVAccessibilityPermissionNaming.displayName(
                operatingSystemVersion: OperatingSystemVersion(majorVersion: 28, minorVersion: 0, patchVersion: 0)
            ),
            "Device Control and Data Access"
        )
    }
}
