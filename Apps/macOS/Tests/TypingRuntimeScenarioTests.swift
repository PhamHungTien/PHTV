//
//  TypingRuntimeScenarioTests.swift
//  PHTV
//
//  Service-level scenario smoke tests for runtime typing lifecycle.
//

import XCTest
import Carbon
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

    func testSecureInputDoesNotHideMissingAccessibility() {
        let snapshot = PHTVTypingRuntimeHealthSnapshot.resolve(
            axTrusted: false,
            eventTapReady: true,
            relaunchPending: false,
            safeModeEnabled: false,
            activeAppProfile: .browser,
            secureInputEnabled: true
        )
        XCTAssertEqual(snapshot.phase, .accessibilityRequired)
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
        PHTVModifierRuntimeStateService.setSavedLanguageValue(language)
        PHTVModifierRuntimeStateService.setLastFlagsValue(UInt64.max)
        PHTVModifierRuntimeStateService.setPausePressedValue(true)
        PHTVModifierRuntimeStateService.setRestoreModifierPressedValue(true)

        PHTVEventTapService.resetAfterSecureInput()

        XCTAssertEqual(PHTVModifierRuntimeStateService.lastFlagsValue(), 0)
        XCTAssertFalse(PHTVModifierRuntimeStateService.pausePressedValue())
        XCTAssertFalse(PHTVModifierRuntimeStateService.restoreModifierPressedValue())
        XCTAssertEqual(PHTVEngineRuntimeFacade.currentLanguage(), language)
    }

    @MainActor
    func testLiveSecureInputTransitionResetsTypingStateExactlyOnce() throws {
        try XCTSkipIf(PHTVSecureInputStatus.isEnabled,
                      "Another application owns Secure Input; do not change its state")
        let delegate = AppDelegate()
        // This fixture must not create a real event tap or schedule relaunches.
        delegate.isRelaunchingAfterPermissionGrant = true
        delegate.publishTypingPermissionState(eventTapReady: false)
        PHTVModifierRuntimeStateService.setSavedLanguageValue(PHTVEngineRuntimeFacade.currentLanguage())
        PHTVModifierRuntimeStateService.setPausePressedValue(true)

        let enabled = EnableSecureEventInput()
        XCTAssertEqual(enabled, noErr)
        guard enabled == noErr else { return }
        var ownsSecureInput = true
        defer {
            if ownsSecureInput { _ = DisableSecureEventInput() }
            PHTVEventTapService.resetAfterSecureInput()
            delegate.cancelEventTapRecovery(reason: "secure-input-test-cleanup")
        }

        XCTAssertTrue(PHTVSecureInputStatus.isEnabled)
        delegate.publishTypingPermissionState(eventTapReady: false)
        delegate.publishTypingPermissionState(eventTapReady: false)
        XCTAssertEqual(delegate.lastPublishedTypingRuntimeHealth?.secureInputEnabled, true)
        XCTAssertTrue(PHTVModifierRuntimeStateService.pausePressedValue())

        let disabled = DisableSecureEventInput()
        XCTAssertEqual(disabled, noErr)
        guard disabled == noErr else { return }
        ownsSecureInput = false
        XCTAssertFalse(PHTVSecureInputStatus.isEnabled)
        delegate.publishTypingPermissionState(eventTapReady: false)
        XCTAssertEqual(delegate.lastPublishedTypingRuntimeHealth?.secureInputEnabled, false)
        XCTAssertFalse(PHTVModifierRuntimeStateService.pausePressedValue())

        // Repeated healthy polls must not reset a newly pressed modifier.
        PHTVModifierRuntimeStateService.setPausePressedValue(true)
        delegate.publishTypingPermissionState(eventTapReady: false)
        XCTAssertTrue(PHTVModifierRuntimeStateService.pausePressedValue())
    }

    @MainActor
    func testSecureInputRecoveryRestoresPausedLanguageAndHonorsEnglishLock() {
        let language = PHTVEngineRuntimeFacade.currentLanguage()
        let locked = PHTVEngineRuntimeFacade.isEnglishLanguageLocked()
        defer {
            PHTVEngineRuntimeFacade.setEnglishLanguageLocked(locked)
            PHTVEngineRuntimeFacade.setCurrentLanguage(language)
            PHTVModifierRuntimeStateService.resetTransientHotkeyState(savedLanguage: language)
        }
        for englishLocked in [false, true] {
            PHTVEngineRuntimeFacade.setEnglishLanguageLocked(englishLocked)
            PHTVEngineRuntimeFacade.setCurrentLanguage(0)
            PHTVModifierRuntimeStateService.setSavedLanguageValue(1)
            PHTVModifierRuntimeStateService.setPausePressedValue(true)
            // Secure Input swallowed release of the temporary-English modifier.
            PHTVEventTapService.resetAfterSecureInput()
            XCTAssertEqual(PHTVEngineRuntimeFacade.currentLanguage(), englishLocked ? 0 : 1)
            XCTAssertFalse(PHTVModifierRuntimeStateService.pausePressedValue())
        }
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
                name: "grant-accepted-and-relaunch-scheduled",
                snapshot: .resolve(
                    axTrusted: true,
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
            eventTapReady: false,
            relaunchPending: false,
            safeModeEnabled: false,
            activeAppProfile: .generic
        )
        let relaunchPending = PHTVTypingRuntimeStateMachine.snapshot(
            axTrusted: true,
            eventTapReady: false,
            relaunchPending: true,
            safeModeEnabled: false,
            activeAppProfile: .generic
        )

        XCTAssertFalse(PHTVTypingRuntimeStateMachine.shouldScheduleEventTapRecovery(snapshot: missingAccessibility))
        XCTAssertFalse(PHTVTypingRuntimeStateMachine.shouldScheduleEventTapRecovery(snapshot: relaunchPending))
    }

}
