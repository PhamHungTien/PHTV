//
//  TypingRuntimeScenarioTests.swift
//  PHTV
//
//  Service-level scenario smoke tests for runtime typing lifecycle.
//

import XCTest
@testable import PHTV

final class TypingRuntimeScenarioTests: XCTestCase {
    func testSecureInputBlocksReadinessEvenWhenTapIsEnabledInAnotherApp() {
        for tapReady in [false, true] {
            let snapshot = PHTVTypingRuntimeStateMachine.snapshot(
                axTrusted: true,
                eventTapReady: tapReady,
                relaunchPending: false,
                safeModeEnabled: false,
                activeAppProfile: .chat,
                activeBundleId: "ru.keepcoder.Telegram",
                secureInputEnabled: true
            )
            XCTAssertEqual(snapshot.phase, .secureInputActive)
            XCTAssertEqual(snapshot.permissionState, .secureInputActive)
            XCTAssertEqual(snapshot.guidanceStep, .secureInputActive)
            XCTAssertTrue(snapshot.hasAccessibilityPermission)
            XCTAssertTrue(snapshot.hasInputMonitoringPermission)
            XCTAssertFalse(snapshot.isTypingPermissionReady)
            XCTAssertFalse(PHTVTypingRuntimeStateMachine.shouldScheduleEventTapRecovery(snapshot: snapshot))
            XCTAssertFalse(PHTVTypingRuntimeStateMachine.shouldPerformInProcessRecovery(snapshot: snapshot))
            XCTAssertFalse(PHTVTypingRuntimeStateMachine.shouldRelaunchAfterGrant(
                snapshot: snapshot, needsRelaunchAfterPermission: true, isEventTapInitialized: false
            ))
            XCTAssertFalse(PHTVTypingRuntimeStateMachine.shouldFallbackRelaunchAfterEventTapFailures(
                snapshot: snapshot, needsRelaunchAfterPermission: true
            ))
        }
    }

    func testSecureInputDoesNotHideMissingPermissions() {
        for axTrusted in [false, true] {
            let snapshot = PHTVTypingRuntimeHealthSnapshot.resolve(
                axTrusted: axTrusted,
                inputMonitoringTrusted: false,
                eventTapReady: true,
                relaunchPending: false,
                safeModeEnabled: false,
                activeAppProfile: .browser,
                secureInputEnabled: true
            )
            XCTAssertEqual(snapshot.phase, axTrusted ? .inputMonitoringRequired : .accessibilityRequired)
        }
    }

    func testSecureInputReleaseRestoresReadinessOrSchedulesTapRecovery() {
        for tapReady in [false, true] {
            let snapshot = PHTVTypingRuntimeHealthSnapshot.resolve(
                axTrusted: true,
                eventTapReady: tapReady,
                relaunchPending: false,
                safeModeEnabled: false,
                activeAppProfile: .chat,
                secureInputEnabled: false
            )
            XCTAssertEqual(snapshot.phase, tapReady ? .ready : .waitingForEventTap)
            XCTAssertEqual(snapshot.isTypingPermissionReady, tapReady)
            XCTAssertEqual(
                PHTVTypingRuntimeStateMachine.shouldScheduleEventTapRecovery(snapshot: snapshot),
                !tapReady
            )
        }
    }

    @MainActor
    func testSecureInputRecoveryClearsMissedModifierEventsWithoutChangingLanguage() {
        let language = PHTVEngineRuntimeFacade.currentLanguage()
        defer { PHTVEventTapService.resetAfterSecureInput() }
        PHTVModifierRuntimeStateService.setLastFlagsValue(UInt64.max)
        PHTVModifierRuntimeStateService.setPausePressedValue(true)
        PHTVModifierRuntimeStateService.setRestoreModifierPressedValue(true)

        PHTVEventTapService.resetAfterSecureInput()

        XCTAssertEqual(PHTVModifierRuntimeStateService.lastFlagsValue(), 0)
        XCTAssertFalse(PHTVModifierRuntimeStateService.pausePressedValue())
        XCTAssertFalse(PHTVModifierRuntimeStateService.restoreModifierPressedValue())
        XCTAssertEqual(PHTVEngineRuntimeFacade.currentLanguage(), language)
    }

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
                name: "first-install-without-input-monitoring",
                snapshot: .resolve(
                    axTrusted: true,
                    inputMonitoringTrusted: false,
                    eventTapReady: false,
                    relaunchPending: false,
                    safeModeEnabled: false,
                    activeAppProfile: .generic
                ),
                expectedPhase: .inputMonitoringRequired,
                expectedPermissionState: .inputMonitoringRequired,
                expectedGuidanceStep: .inputMonitoring
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

    func testEventTapRecoverySchedulingIsSuppressedWithoutInputMonitoring() {
        let missingInputMonitoring = PHTVTypingRuntimeStateMachine.snapshot(
            axTrusted: true,
            inputMonitoringTrusted: false,
            eventTapReady: false,
            relaunchPending: false,
            safeModeEnabled: false,
            activeAppProfile: .generic
        )

        XCTAssertFalse(PHTVTypingRuntimeStateMachine.shouldScheduleEventTapRecovery(snapshot: missingInputMonitoring))
    }
}
