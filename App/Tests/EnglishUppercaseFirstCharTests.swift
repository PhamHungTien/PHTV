import XCTest
@testable import PHTV

final class EnglishUppercaseFirstCharTests: XCTestCase {

    private func transition(
        _ state: PHTVEnglishUppercaseState,
        keyCode: UInt16,
        flags: CGEventFlags = [],
        enabled: Bool = true,
        excluded: Bool = false
    ) -> (state: PHTVEnglishUppercaseState, forceUppercase: Bool) {
        let result = PHTVEventCallbackService.englishUppercaseTransition(
            state: state,
            keyCode: keyCode,
            flags: flags,
            uppercaseEnabled: enabled,
            uppercaseExcluded: excluded
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
        var state = transition(.idle, keyCode: KEY_RETURN).state

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
}
