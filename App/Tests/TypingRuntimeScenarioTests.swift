//
//  TypingRuntimeScenarioTests.swift
//  PHTV
//
//  Service-level scenario smoke tests for runtime typing lifecycle.
//

import XCTest
@testable import PHTV

final class TypingRuntimeScenarioTests: XCTestCase {
    private struct TypingScenario {
        let name: String
        let snapshot: PHTVTypingRuntimeHealthSnapshot
        let expectedPhase: PHTVTypingRuntimePhase
        let expectedPermissionState: PHTVTypingPermissionState
        let expectedGuidanceStep: PHTVPermissionGuidanceStep
    }

    func testScenarioFixturesCoverCoreRuntimePhases() {
        let scenarios: [TypingScenario] = [
            TypingScenario(
                name: "first-install-without-accessibility",
                snapshot: .resolve(
                    axTrusted: false,
                    inputMonitoringTrusted: false,
                    eventTapReady: false,
                    relaunchPending: false,
                    safeModeEnabled: false,
                    activeAppProfile: .generic
                ),
                expectedPhase: .accessibilityRequired,
                expectedPermissionState: .accessibilityRequired,
                expectedGuidanceStep: .accessibility
            ),
            TypingScenario(
                name: "input-monitoring-absent-does-not-block",
                snapshot: .resolve(
                    axTrusted: true,
                    inputMonitoringTrusted: false,
                    eventTapReady: false,
                    relaunchPending: false,
                    safeModeEnabled: false,
                    activeAppProfile: .generic
                ),
                // Input Monitoring is not required: with Accessibility trusted the
                // runtime proceeds straight to waiting for the session tap.
                expectedPhase: .waitingForEventTap,
                expectedPermissionState: .waitingForEventTap,
                expectedGuidanceStep: .waitingForEventTap
            ),
            TypingScenario(
                name: "grant-accepted-and-relaunch-scheduled",
                snapshot: .resolve(
                    axTrusted: true,
                    inputMonitoringTrusted: true,
                    eventTapReady: false,
                    relaunchPending: true,
                    safeModeEnabled: false,
                    activeAppProfile: .generic
                ),
                expectedPhase: .relaunchPending,
                expectedPermissionState: .waitingForEventTap,
                expectedGuidanceStep: .waitingForEventTap
            ),
            TypingScenario(
                name: "accessibility-granted-waiting-for-session-tap",
                snapshot: .resolve(
                    axTrusted: true,
                    inputMonitoringTrusted: true,
                    eventTapReady: false,
                    relaunchPending: false,
                    safeModeEnabled: false,
                    activeAppProfile: .browser
                ),
                expectedPhase: .waitingForEventTap,
                expectedPermissionState: .waitingForEventTap,
                expectedGuidanceStep: .waitingForEventTap
            ),
            TypingScenario(
                name: "typing-ready-in-chat-app",
                snapshot: .resolve(
                    axTrusted: true,
                    inputMonitoringTrusted: true,
                    eventTapReady: true,
                    relaunchPending: false,
                    safeModeEnabled: false,
                    activeAppProfile: .chat
                ),
                expectedPhase: .ready,
                expectedPermissionState: .ready,
                expectedGuidanceStep: .ready
            )
        ]

        for scenario in scenarios {
            XCTAssertEqual(scenario.snapshot.phase, scenario.expectedPhase, scenario.name)
            XCTAssertEqual(scenario.snapshot.permissionState, scenario.expectedPermissionState, scenario.name)
            XCTAssertEqual(scenario.snapshot.guidanceStep, scenario.expectedGuidanceStep, scenario.name)
        }
    }

    func testRelaunchAfterGrantRecommendationMatchesFirstInstallScenario() {
        let snapshot = PHTVTypingRuntimeStateMachine.snapshot(
            axTrusted: true,
            inputMonitoringTrusted: true,
            eventTapReady: false,
            relaunchPending: false,
            safeModeEnabled: false,
            activeAppProfile: .generic
        )

        XCTAssertTrue(
            PHTVTypingRuntimeStateMachine.shouldRelaunchAfterGrant(
                snapshot: snapshot,
                needsRelaunchAfterPermission: true,
                isEventTapInitialized: false
            )
        )
    }

    func testInProcessRecoveryIsSuppressedOnceRelaunchIsPending() {
        let snapshot = PHTVTypingRuntimeStateMachine.snapshot(
            axTrusted: true,
            inputMonitoringTrusted: true,
            eventTapReady: false,
            relaunchPending: true,
            safeModeEnabled: false,
            activeAppProfile: .generic
        )

        XCTAssertFalse(
            PHTVTypingRuntimeStateMachine.shouldPerformInProcessRecovery(snapshot: snapshot)
        )
        XCTAssertFalse(
            PHTVTypingRuntimeStateMachine.shouldFallbackRelaunchAfterEventTapFailures(
                snapshot: snapshot,
                needsRelaunchAfterPermission: true
            )
        )
    }

    func testWaitingForEventTapSchedulesInProcessRecoveryWhenAccessibilityIsTrusted() {
        let snapshot = PHTVTypingRuntimeStateMachine.snapshot(
            axTrusted: true,
            inputMonitoringTrusted: true,
            eventTapReady: false,
            relaunchPending: false,
            safeModeEnabled: false,
            activeAppProfile: .browser
        )

        XCTAssertTrue(PHTVTypingRuntimeStateMachine.shouldScheduleEventTapRecovery(snapshot: snapshot))
    }

    func testEventTapRecoverySchedulingIsSuppressedWithoutAccessibilityOrDuringRelaunch() {
        let missingAccessibility = PHTVTypingRuntimeStateMachine.snapshot(
            axTrusted: false,
            inputMonitoringTrusted: false,
            eventTapReady: false,
            relaunchPending: false,
            safeModeEnabled: false,
            activeAppProfile: .generic
        )
        let relaunchPending = PHTVTypingRuntimeStateMachine.snapshot(
            axTrusted: true,
            inputMonitoringTrusted: true,
            eventTapReady: false,
            relaunchPending: true,
            safeModeEnabled: false,
            activeAppProfile: .generic
        )

        XCTAssertFalse(PHTVTypingRuntimeStateMachine.shouldScheduleEventTapRecovery(snapshot: missingAccessibility))
        XCTAssertFalse(PHTVTypingRuntimeStateMachine.shouldScheduleEventTapRecovery(snapshot: relaunchPending))
    }

    func testEventTapRecoverySchedulingProceedsWithoutInputMonitoring() {
        // Input Monitoring is no longer required: with Accessibility trusted and the
        // tap not yet ready, recovery must still be scheduled.
        let missingInputMonitoring = PHTVTypingRuntimeStateMachine.snapshot(
            axTrusted: true,
            inputMonitoringTrusted: false,
            eventTapReady: false,
            relaunchPending: false,
            safeModeEnabled: false,
            activeAppProfile: .generic
        )

        XCTAssertTrue(PHTVTypingRuntimeStateMachine.shouldScheduleEventTapRecovery(snapshot: missingInputMonitoring))
    }
}
