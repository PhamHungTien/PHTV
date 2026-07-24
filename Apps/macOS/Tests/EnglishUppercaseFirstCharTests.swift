//
//  EnglishUppercaseFirstCharTests.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import XCTest
@testable import PHTV

final class EnglishUppercaseFirstCharTests: XCTestCase {

    private func transition(
        _ state: PHTVEnglishUppercaseState,
        keyCode: UInt16,
        flags: CGEventFlags = [],
        enabled: Bool = true,
        excluded: Bool = false,
        doubleSpacePeriod: Bool = false
    ) -> (state: PHTVEnglishUppercaseState, forceUppercase: Bool) {
        let result = PHTVEventCallbackService.englishUppercaseTransition(
            state: state,
            keyCode: keyCode,
            flags: flags,
            uppercaseEnabled: enabled,
            uppercaseExcluded: excluded,
            doubleSpacePeriodEnabled: doubleSpacePeriod
        )
        return (result.nextState, result.shouldForceUppercase)
    }

    func testDotSpaceLetterForcesUppercase() {
        var state = PHTVEnglishUppercaseState.idle

        let dot = transition(state, keyCode: KEY_DOT)
        XCTAssertTrue(dot.state.pending)
        XCTAssertTrue(dot.state.needsSpaceConfirm)
        XCTAssertFalse(dot.forceUppercase)
        state = dot.state

        let space = transition(state, keyCode: KEY_SPACE)
        XCTAssertTrue(space.state.pending)
        XCTAssertFalse(space.state.needsSpaceConfirm)
        XCTAssertFalse(space.forceUppercase)
        state = space.state

        let letter = transition(state, keyCode: KEY_A)
        XCTAssertTrue(letter.forceUppercase)
        XCTAssertFalse(letter.state.pending)
        XCTAssertFalse(letter.state.needsSpaceConfirm)
    }

    func testDotWithoutSpaceDoesNotForceUppercase() {
        var state = PHTVEnglishUppercaseState.idle

        let dot = transition(state, keyCode: KEY_DOT)
        state = dot.state

        let letter = transition(state, keyCode: KEY_B)
        XCTAssertFalse(letter.forceUppercase)
        XCTAssertFalse(letter.state.pending)
        XCTAssertFalse(letter.state.needsSpaceConfirm)
    }

    func testEllipsisSpaceLetterDoesNotForceUppercase() {
        var state = PHTVEnglishUppercaseState.idle

        state = transition(state, keyCode: KEY_DOT).state

        let secondDot = transition(state, keyCode: KEY_DOT)
        XCTAssertFalse(secondDot.forceUppercase)
        XCTAssertFalse(secondDot.state.pending)
        XCTAssertTrue(secondDot.state.ellipsisContinuation)
        state = secondDot.state

        state = transition(state, keyCode: KEY_DOT).state
        state = transition(state, keyCode: KEY_SPACE).state

        let letter = transition(state, keyCode: KEY_A)
        XCTAssertFalse(letter.forceUppercase)
        XCTAssertFalse(letter.state.pending)
        XCTAssertFalse(letter.state.ellipsisContinuation)
    }

    func testEnterThenLetterForcesUppercaseWithoutSpace() {
        var state = PHTVEnglishUppercaseState.idle

        let enter = transition(state, keyCode: KEY_ENTER)
        XCTAssertTrue(enter.state.pending)
        XCTAssertFalse(enter.state.needsSpaceConfirm)
        state = enter.state

        let letter = transition(state, keyCode: KEY_C)
        XCTAssertTrue(letter.forceUppercase)
        XCTAssertFalse(letter.state.pending)
    }

    func testSkippablePunctuationKeepsPendingUppercaseState() {
        var state = PHTVEnglishUppercaseState.idle
        state = transition(state, keyCode: KEY_DOT).state
        state = transition(state, keyCode: KEY_SPACE).state

        let quote = transition(state, keyCode: KEY_QUOTE)
        XCTAssertTrue(quote.state.pending)
        XCTAssertFalse(quote.state.needsSpaceConfirm)
        XCTAssertFalse(quote.forceUppercase)
        state = quote.state

        let letter = transition(state, keyCode: KEY_D)
        XCTAssertTrue(letter.forceUppercase)
    }

    func testQuestionMarkStartsPendingAndNeedsSpace() {
        let result = transition(
            .idle,
            keyCode: KEY_SLASH,
            flags: [.maskShift]
        )
        XCTAssertTrue(result.state.pending)
        XCTAssertTrue(result.state.needsSpaceConfirm)
        XCTAssertFalse(result.forceUppercase)
    }

    func testManualShiftDoesNotForceUppercaseAgain() {
        let state = transition(.idle, keyCode: KEY_RETURN).state

        let letterWithShift = transition(state, keyCode: KEY_E, flags: [.maskShift])
        XCTAssertFalse(letterWithShift.forceUppercase)
        XCTAssertFalse(letterWithShift.state.pending)
        XCTAssertFalse(letterWithShift.state.needsSpaceConfirm)
    }

    func testDisabledOrExcludedUppercaseClearsPendingState() {
        let pendingState = PHTVEnglishUppercaseState(pending: true, needsSpaceConfirm: false)

        let disabled = transition(pendingState, keyCode: KEY_F, enabled: false)
        XCTAssertFalse(disabled.forceUppercase)
        XCTAssertFalse(disabled.state.pending)
        XCTAssertFalse(disabled.state.needsSpaceConfirm)

        let excluded = transition(pendingState, keyCode: KEY_F, enabled: true, excluded: true)
        XCTAssertFalse(excluded.forceUppercase)
        XCTAssertFalse(excluded.state.pending)
        XCTAssertFalse(excluded.state.needsSpaceConfirm)
    }

    func testBlockedModifierKeepsPendingStateUntouched() {
        var state = transition(.idle, keyCode: KEY_RETURN).state

        let blocked = transition(state, keyCode: KEY_G, flags: [.maskCommand])
        XCTAssertFalse(blocked.forceUppercase)
        XCTAssertTrue(blocked.state.pending)
        XCTAssertFalse(blocked.state.needsSpaceConfirm)

        state = blocked.state
        let nextLetter = transition(state, keyCode: KEY_G)
        XCTAssertTrue(nextLetter.forceUppercase)
    }

    // MARK: - Double-space → period (issue: capitalize still works)

    func testDoubleSpaceThenLetterForcesUppercaseWhenEnabled() {
        var state = PHTVEnglishUppercaseState.idle

        // A word letter first so a real sentence context exists.
        state = transition(state, keyCode: KEY_A, doubleSpacePeriod: true).state

        let space1 = transition(state, keyCode: KEY_SPACE, doubleSpacePeriod: true)
        XCTAssertFalse(space1.forceUppercase)
        XCTAssertTrue(space1.state.trailingSpace)
        state = space1.state

        let space2 = transition(state, keyCode: KEY_SPACE, doubleSpacePeriod: true)
        XCTAssertTrue(space2.state.pending)
        XCTAssertFalse(space2.state.needsSpaceConfirm)
        XCTAssertFalse(space2.forceUppercase)
        state = space2.state

        let letter = transition(state, keyCode: KEY_B, doubleSpacePeriod: true)
        XCTAssertTrue(letter.forceUppercase)
        XCTAssertFalse(letter.state.pending)
    }

    func testDoubleSpaceDoesNotForceUppercaseWhenDisabled() {
        var state = PHTVEnglishUppercaseState.idle
        state = transition(state, keyCode: KEY_A, doubleSpacePeriod: false).state
        state = transition(state, keyCode: KEY_SPACE, doubleSpacePeriod: false).state
        state = transition(state, keyCode: KEY_SPACE, doubleSpacePeriod: false).state

        let letter = transition(state, keyCode: KEY_B, doubleSpacePeriod: false)
        XCTAssertFalse(letter.forceUppercase)
    }

    func testSingleSpaceDoesNotForceUppercaseWhenEnabled() {
        var state = PHTVEnglishUppercaseState.idle
        state = transition(state, keyCode: KEY_A, doubleSpacePeriod: true).state
        state = transition(state, keyCode: KEY_SPACE, doubleSpacePeriod: true).state

        // Only one space: this is a normal word gap, not a sentence end.
        let letter = transition(state, keyCode: KEY_B, doubleSpacePeriod: true)
        XCTAssertFalse(letter.forceUppercase)
    }

    func testDoubleSpacePeriodStillCapitalizesAfterManualPeriodPath() {
        // Manual "period + space" continues to work with the feature enabled.
        var state = PHTVEnglishUppercaseState.idle
        state = transition(state, keyCode: KEY_DOT, doubleSpacePeriod: true).state
        state = transition(state, keyCode: KEY_SPACE, doubleSpacePeriod: true).state

        let letter = transition(state, keyCode: KEY_C, doubleSpacePeriod: true)
        XCTAssertTrue(letter.forceUppercase)
    }
}
