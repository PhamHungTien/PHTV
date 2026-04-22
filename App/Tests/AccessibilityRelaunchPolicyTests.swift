//
//  AccessibilityRelaunchPolicyTests.swift
//  PHTV
//
//  Regression tests for the Accessibility grant relaunch policy.
//

import XCTest
@testable import PHTV

final class AccessibilityRelaunchPolicyTests: XCTestCase {
    func testRelaunchAfterGrantRequiresTrustedAccessibilityAndPendingRelaunch() {
        XCTAssertTrue(
            phtvShouldRelaunchAfterAccessibilityGrant(
                axTrusted: true,
                needsRelaunchAfterPermission: true,
                isEventTapInitialized: false,
                isRelaunchAlreadyScheduled: false
            )
        )
    }

    func testRelaunchAfterGrantDoesNotFireWhenAppLaunchedWithAccessibilityAlreadyTrusted() {
        XCTAssertFalse(
            phtvShouldRelaunchAfterAccessibilityGrant(
                axTrusted: true,
                needsRelaunchAfterPermission: false,
                isEventTapInitialized: false,
                isRelaunchAlreadyScheduled: false
            )
        )
    }

    func testRelaunchAfterGrantDoesNotFireWhenEventTapIsAlreadyInitialized() {
        XCTAssertFalse(
            phtvShouldRelaunchAfterAccessibilityGrant(
                axTrusted: true,
                needsRelaunchAfterPermission: true,
                isEventTapInitialized: true,
                isRelaunchAlreadyScheduled: false
            )
        )
    }

    func testRelaunchAfterGrantDoesNotDoubleSchedule() {
        XCTAssertFalse(
            phtvShouldRelaunchAfterAccessibilityGrant(
                axTrusted: true,
                needsRelaunchAfterPermission: true,
                isEventTapInitialized: false,
                isRelaunchAlreadyScheduled: true
            )
        )
    }

    func testFallbackRelaunchAfterEventTapFailuresRequiresAllPermissions() {
        XCTAssertTrue(
            phtvShouldFallbackRelaunchAfterEventTapFailures(
                accessibilityTrusted: true,
                postEventGranted: true,
                inputMonitoringGranted: true,
                isRelaunchAlreadyScheduled: false
            )
        )

        XCTAssertFalse(
            phtvShouldFallbackRelaunchAfterEventTapFailures(
                accessibilityTrusted: true,
                postEventGranted: true,
                inputMonitoringGranted: false,
                isRelaunchAlreadyScheduled: false
            )
        )
    }
}
