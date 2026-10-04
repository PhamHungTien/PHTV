import XCTest
import ApplicationServices
@testable import PHTV

final class TextFocusSessionTests: XCTestCase {
    func testTimelineMarkerAndNotesAreIndependentSessions() {
        var state = PHTVTextFocusSessionState<String>()
        var result = state.update(focus: "timeline", editable: false)
        XCTAssertTrue(result.reset)
        XCTAssertTrue(result.bypass)
        result = state.update(focus: "timeline", editable: false)
        XCTAssertFalse(result.reset)
        XCTAssertTrue(result.bypass)
        result = state.update(focus: "marker-name", editable: true)
        XCTAssertTrue(result.reset)
        XCTAssertFalse(result.bypass)
        result = state.update(focus: "marker-name", editable: true)
        XCTAssertFalse(result.reset)
        XCTAssertFalse(result.bypass)
        XCTAssertTrue(state.update(focus: "marker-notes", editable: true).reset)
        XCTAssertTrue(state.update(focus: "timeline", editable: false).bypass)
        XCTAssertTrue(state.update(focus: "marker-name", editable: true).reset)
    }

    func testFailedAccessibilityReadDoesNotResetMidWord() {
        var state = PHTVTextFocusSessionState<String>()
        _ = state.update(focus: "name", editable: true)
        let failure = state.update(focus: nil, editable: nil)
        XCTAssertFalse(failure.reset)
        XCTAssertFalse(failure.bypass)
        XCTAssertFalse(state.update(focus: "name", editable: true).reset)
    }

    func testSameElementBecomingEditableStartsSession() {
        var state = PHTVTextFocusSessionState<String>()
        _ = state.update(focus: "custom", editable: false)
        XCTAssertTrue(state.update(focus: "custom", editable: true).reset)
    }

    func testOnlyFinalCutUsesFocusGuard() {
        XCTAssertTrue(PHTVTextFocusSessionService.isSupported(bundleId: "com.apple.FinalCut"))
        for bundle in [nil, "com.apple.TextEdit", "com.apple.FinalCut.fake"] {
            XCTAssertFalse(PHTVTextFocusSessionService.isSupported(bundleId: bundle))
        }
        let result = PHTVTextFocusSessionService.transition(bundleId: "com.apple.FinalCut", pid: 0, safeMode: true)
        XCTAssertFalse(result.reset)
        XCTAssertFalse(result.bypass)
    }
    func testUnknownCustomEditorResetsBoundaryWithoutDisablingVietnamese() {
        var state = PHTVTextFocusSessionState<String>()
        _ = state.update(focus: "timeline", editable: false)
        let result = state.update(focus: "custom-title-editor", editable: nil)
        XCTAssertTrue(result.reset)
        XCTAssertFalse(result.bypass)
        XCTAssertFalse(state.update(focus: "custom-title-editor", editable: nil).reset)
        XCTAssertFalse(state.update(focus: "custom-title-editor", editable: true).reset)
    }

    func testUnknownRoleOnSameElementDoesNotBreakComposition() {
        var state = PHTVTextFocusSessionState<String>()
        _ = state.update(focus: "name", editable: true)
        XCTAssertFalse(state.update(focus: "name", editable: nil).reset)
        XCTAssertFalse(state.update(focus: "name", editable: true).reset)
    }

    func testEvidenceRequiresKnownNonTextRoleBeforeBypassing() {
        for role in ["AXLayoutArea", "AXLayoutItem", kAXButtonRole] {
            XCTAssertEqual(PHTVTextFocusEvidence.editable(role: role, hasTextSelection: false), false)
            XCTAssertEqual(PHTVTextFocusEvidence.editable(role: role, hasTextSelection: true), true)
        }
        for role in [kAXGroupRole, kAXWindowRole, "FutureCustomEditor"] {
            XCTAssertNil(PHTVTextFocusEvidence.editable(role: role, hasTextSelection: false))
            XCTAssertEqual(PHTVTextFocusEvidence.editable(role: role, hasTextSelection: true), true)
        }
        for role in [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole] {
            XCTAssertEqual(PHTVTextFocusEvidence.editable(role: role, hasTextSelection: false), true)
        }
    }

    func testReadsShareOneBudgetAndNeverUseZeroTimeout() throws {
        let budget = PHTVFocusReadBudget(startedAt: 100)
        XCTAssertEqual(try XCTUnwrap(budget.remaining(at: 100)), 0.01, accuracy: 0.000001)
        XCTAssertEqual(try XCTUnwrap(budget.remaining(at: 100.006)), 0.004, accuracy: 0.000001)
        XCTAssertNil(budget.remaining(at: 100.011))
        XCTAssertNil(budget.remaining(at: 200))
    }

    func testFocusResetPreservesHeldModifierUntilRelease() {
        PHTVModifierRuntimeStateService.resetTransientHotkeyState(savedLanguage: 1)
        defer { PHTVModifierRuntimeStateService.resetTransientHotkeyState(savedLanguage: 1) }
        let option = CGEventFlags.maskAlternate.rawValue
        let press = PHTVEventContextBridgeService.handleModifierPress(
            withFlags: option, keyCode: 58,
            restoreOnEscape: 0, customEscapeKey: 0,
            pauseKeyEnabled: 1, pauseKeyCode: 58, currentLanguage: 1,
            switchHotkey: 0, switchHotkey2: 0)
        XCTAssertTrue(press.shouldUpdateLanguage)
        XCTAssertEqual(press.language, 0)
        PHTVEngineSessionService.requestNewSessionInternal(
            allowUppercasePrime: false, preserveModifierState: true)
        XCTAssertEqual(PHTVModifierRuntimeStateService.lastFlagsValue(), option)
        XCTAssertTrue(PHTVModifierRuntimeStateService.pausePressedValue())
        let release = PHTVEventContextBridgeService.handleModifierRelease(
            oldFlags: PHTVModifierRuntimeStateService.lastFlagsValue(), newFlags: 0, keyCode: 58,
            restoreOnEscape: 0, customEscapeKey: 0,
            switchHotkey: 0, switchHotkey2: 0, convertHotkey: 0,
            emojiEnabled: 0, emojiModifiers: 0, emojiKeyCode: 0,
            tempOffSpellingEnabled: 0, tempOffEngineEnabled: 0,
            pauseKeyEnabled: 1, pauseKeyCode: 58, currentLanguage: 0)
        XCTAssertTrue(release.shouldUpdateLanguage)
        XCTAssertEqual(release.language, 1)
        XCTAssertFalse(PHTVModifierRuntimeStateService.pausePressedValue())
    }

}
