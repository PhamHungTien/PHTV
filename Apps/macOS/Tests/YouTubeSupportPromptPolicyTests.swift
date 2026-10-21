import XCTest
@testable import PHTV

final class YouTubeSupportPromptPolicyTests: XCTestCase {
    func testInvitationAppearsForExistingUserOnNewVersion() {
        XCTAssertTrue(YouTubeSupportPromptPolicy.shouldPresent(version: "3.6.9", lastPresentedVersion: "3.6.8", onboardingCompleted: true))
        XCTAssertTrue(YouTubeSupportPromptPolicy.shouldPresent(version: "3.6.9", lastPresentedVersion: "", onboardingCompleted: true))
    }

    func testInvitationDoesNotRepeatOrInterruptNewUser() {
        XCTAssertFalse(YouTubeSupportPromptPolicy.shouldPresent(version: "3.6.9", lastPresentedVersion: "3.6.9", onboardingCompleted: true))
        XCTAssertFalse(YouTubeSupportPromptPolicy.shouldPresent(version: "3.6.9", lastPresentedVersion: "", onboardingCompleted: false))
        XCTAssertFalse(YouTubeSupportPromptPolicy.shouldPresent(version: "", lastPresentedVersion: "", onboardingCompleted: true))
    }
}
