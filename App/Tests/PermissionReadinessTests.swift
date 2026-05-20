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
            inputMonitoringTrusted: true,
            eventTapReady: true
        )

        XCTAssertEqual(state, .ready)
        XCTAssertTrue(state.hasAccessibilityPermission)
        XCTAssertTrue(state.hasInputMonitoringPermission)
        XCTAssertTrue(state.isTypingPermissionReady)
    }

    func testResolveReturnsWaitingWhenAccessibilityExistsButEventTapIsNotReady() {
        let state = PHTVTypingPermissionState.resolve(
            accessibilityTrusted: true,
            inputMonitoringTrusted: true,
            eventTapReady: false
        )

        XCTAssertEqual(state, .waitingForEventTap)
        XCTAssertTrue(state.hasAccessibilityPermission)
        XCTAssertTrue(state.hasInputMonitoringPermission)
        XCTAssertFalse(state.isTypingPermissionReady)
    }

    func testResolveReturnsInputMonitoringRequiredWhenInputMonitoringIsMissing() {
        let state = PHTVTypingPermissionState.resolve(
            accessibilityTrusted: true,
            inputMonitoringTrusted: false,
            eventTapReady: false
        )

        XCTAssertEqual(state, .inputMonitoringRequired)
        XCTAssertTrue(state.hasAccessibilityPermission)
        XCTAssertFalse(state.hasInputMonitoringPermission)
        XCTAssertFalse(state.isTypingPermissionReady)
    }

    func testResolveReturnsAccessibilityRequiredWhenAccessibilityIsMissing() {
        let state = PHTVTypingPermissionState.resolve(
            accessibilityTrusted: false,
            inputMonitoringTrusted: false,
            eventTapReady: false
        )

        XCTAssertEqual(state, .accessibilityRequired)
        XCTAssertFalse(state.hasAccessibilityPermission)
        XCTAssertFalse(state.hasInputMonitoringPermission)
        XCTAssertFalse(state.isTypingPermissionReady)
    }

    func testResolveRejectsImpossibleReadyStateWithoutAccessibility() {
        let state = PHTVTypingPermissionState.resolve(
            accessibilityTrusted: false,
            inputMonitoringTrusted: true,
            eventTapReady: true
        )

        XCTAssertEqual(state, .accessibilityRequired)
        XCTAssertFalse(state.hasAccessibilityPermission)
        XCTAssertFalse(state.hasInputMonitoringPermission)
        XCTAssertFalse(state.isTypingPermissionReady)
    }

    func testGuidancePrefersAccessibilityWhenAccessibilityIsMissing() {
        let step = PHTVPermissionGuidanceStep.resolve(
            accessibilityTrusted: false,
            inputMonitoringTrusted: false,
            eventTapReady: false
        )

        XCTAssertEqual(step, .accessibility)
    }

    func testGuidanceOpensInputMonitoringAfterAccessibilityIsGranted() {
        let step = PHTVPermissionGuidanceStep.resolve(
            accessibilityTrusted: true,
            inputMonitoringTrusted: false,
            eventTapReady: false
        )

        XCTAssertEqual(step, .inputMonitoring)
    }

    func testGuidanceFallsBackToRetryWhenAccessibilityExistsButTapIsNotReady() {
        let step = PHTVPermissionGuidanceStep.resolve(
            accessibilityTrusted: true,
            inputMonitoringTrusted: true,
            eventTapReady: false
        )

        XCTAssertEqual(step, .waitingForEventTap)
    }

    func testGuidanceReturnsReadyWhenAccessibilityAndTapAreAvailable() {
        let step = PHTVPermissionGuidanceStep.resolve(
            accessibilityTrusted: true,
            inputMonitoringTrusted: true,
            eventTapReady: true
        )

        XCTAssertEqual(step, .ready)
    }
}
