import XCTest
@testable import PHTV

final class PermissionReadinessTests: XCTestCase {

    func testResolveReturnsReadyWhenAccessibilityAndEventTapAreAvailable() {
        let state = PHTVTypingPermissionState.resolve(
            accessibilityTrusted: true,
            eventTapReady: true
        )

        XCTAssertEqual(state, .ready)
        XCTAssertTrue(state.hasAccessibilityPermission)
        XCTAssertTrue(state.isTypingPermissionReady)
    }

    func testResolveReturnsWaitingWhenAccessibilityExistsButEventTapIsNotReady() {
        let state = PHTVTypingPermissionState.resolve(
            accessibilityTrusted: true,
            eventTapReady: false
        )

        XCTAssertEqual(state, .waitingForEventTap)
        XCTAssertTrue(state.hasAccessibilityPermission)
        XCTAssertFalse(state.isTypingPermissionReady)
    }

    func testResolveRejectsImpossibleReadyStateWithoutAccessibility() {
        let state = PHTVTypingPermissionState.resolve(
            accessibilityTrusted: false,
            eventTapReady: true
        )

        XCTAssertEqual(state, .accessibilityRequired)
        XCTAssertFalse(state.hasAccessibilityPermission)
        XCTAssertFalse(state.isTypingPermissionReady)
    }
}
