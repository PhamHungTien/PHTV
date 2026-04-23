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

    func testFallbackRelaunchAfterEventTapFailuresRequiresAccessibilityTrust() {
        XCTAssertTrue(
            phtvShouldFallbackRelaunchAfterEventTapFailures(
                accessibilityTrusted: true,
                isRelaunchAlreadyScheduled: false
            )
        )

        XCTAssertFalse(
            phtvShouldFallbackRelaunchAfterEventTapFailures(
                accessibilityTrusted: false,
                isRelaunchAlreadyScheduled: false
            )
        )

        XCTAssertFalse(
            phtvShouldFallbackRelaunchAfterEventTapFailures(
                accessibilityTrusted: true,
                isRelaunchAlreadyScheduled: true
            )
        )
    }

    func testInProcessRecoveryStopsWhenRelaunchIsAlreadyScheduled() {
        XCTAssertTrue(
            phtvShouldPerformInProcessRecovery(isRelaunchAlreadyScheduled: false)
        )
        XCTAssertFalse(
            phtvShouldPerformInProcessRecovery(isRelaunchAlreadyScheduled: true)
        )
    }

    func testDeferredRelaunchProcessArgumentsCarryParentPIDBundlePathAndLaunchArgs() {
        let arguments = phtvDeferredRelaunchProcessArguments(
            parentPID: 1234,
            bundlePath: "/Applications/PHTV.app",
            launchArguments: ["--phtv-relaunched-after-accessibility-grant"]
        )

        XCTAssertEqual(arguments[0], "-c")
        XCTAssertTrue(arguments[1].contains("kill -0"))
        XCTAssertTrue(arguments[1].contains("/usr/bin/open -n"))
        XCTAssertEqual(arguments[2], "sh")
        XCTAssertEqual(arguments[3], "1234")
        XCTAssertEqual(arguments[4], "/Applications/PHTV.app")
        XCTAssertEqual(arguments[5], "--phtv-relaunched-after-accessibility-grant")
    }
}
