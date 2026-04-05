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
            inputMonitoringGranted: true,
            eventTapReady: true
        )

        XCTAssertEqual(state, .ready)
        XCTAssertTrue(state.hasAccessibilityPermission)
        XCTAssertTrue(state.isTypingPermissionReady)
    }

    func testResolveReturnsWaitingWhenAccessibilityExistsButEventTapIsNotReady() {
        let state = PHTVTypingPermissionState.resolve(
            accessibilityTrusted: true,
            inputMonitoringGranted: true,
            eventTapReady: false
        )

        XCTAssertEqual(state, .waitingForEventTap)
        XCTAssertTrue(state.hasAccessibilityPermission)
        XCTAssertFalse(state.isTypingPermissionReady)
    }

    func testResolveReturnsInputMonitoringRequiredWhenAccessibilityExistsButListenAccessIsMissing() {
        let state = PHTVTypingPermissionState.resolve(
            accessibilityTrusted: true,
            inputMonitoringGranted: false,
            eventTapReady: false
        )

        XCTAssertEqual(state, .inputMonitoringRequired)
        XCTAssertTrue(state.hasAccessibilityPermission)
        XCTAssertFalse(state.isTypingPermissionReady)
    }

    func testResolveRejectsImpossibleReadyStateWithoutAccessibility() {
        let state = PHTVTypingPermissionState.resolve(
            accessibilityTrusted: false,
            inputMonitoringGranted: true,
            eventTapReady: true
        )

        XCTAssertEqual(state, .accessibilityRequired)
        XCTAssertFalse(state.hasAccessibilityPermission)
        XCTAssertFalse(state.isTypingPermissionReady)
    }

    func testGuidancePrefersAccessibilityWhilePostEventAccessIsStillMissing() {
        let step = PHTVPermissionGuidanceStep.resolve(
            accessibilityTrusted: true,
            postEventGranted: false,
            inputMonitoringGranted: true,
            eventTapReady: false
        )

        XCTAssertEqual(step, .accessibility)
    }

    func testGuidanceAdvancesToInputMonitoringAfterAccessibilityIsReady() {
        let step = PHTVPermissionGuidanceStep.resolve(
            accessibilityTrusted: true,
            postEventGranted: true,
            inputMonitoringGranted: false,
            eventTapReady: false
        )

        XCTAssertEqual(step, .inputMonitoring)
    }

    func testGuidanceFallsBackToRetryWhenPermissionsExistButTapIsNotReady() {
        let step = PHTVPermissionGuidanceStep.resolve(
            accessibilityTrusted: true,
            postEventGranted: true,
            inputMonitoringGranted: true,
            eventTapReady: false
        )

        XCTAssertEqual(step, .waitingForEventTap)
    }
}
