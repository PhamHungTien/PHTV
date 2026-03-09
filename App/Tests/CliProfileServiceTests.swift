import XCTest
@testable import PHTV

final class CliProfileServiceTests: XCTestCase {

    func testContainsClaudeCodeKeywordMatchesStandaloneCommand() {
        XCTAssertTrue(PHTVAppDetectionService.containsClaudeCodeKeyword("claude"))
        XCTAssertTrue(PHTVAppDetectionService.containsClaudeCodeKeyword("claude-code"))
        XCTAssertTrue(PHTVAppDetectionService.containsClaudeCodeKeyword("Claude Code - Session"))
        XCTAssertTrue(PHTVAppDetectionService.containsClaudeCodeKeyword("Running claude-2 in terminal"))
    }

    func testContainsClaudeCodeKeywordRejectsUnrelatedWindowTitles() {
        XCTAssertFalse(PHTVAppDetectionService.containsClaudeCodeKeyword("Terminal — zsh"))
        XCTAssertFalse(PHTVAppDetectionService.containsClaudeCodeKeyword("claudette project notes"))
        XCTAssertFalse(PHTVAppDetectionService.containsClaudeCodeKeyword(nil))
    }

    func testClaudeCodeSessionUsesDedicatedCliProfileForTerminalApps() {
        XCTAssertEqual(
            PHTVCliProfileService.profileCode(
                forBundleId: "com.googlecode.iterm2",
                isClaudeCodeSession: true
            ),
            5
        )
    }

    func testClaudeCodeSessionUsesDedicatedCliProfileForIDEApps() {
        XCTAssertEqual(
            PHTVCliProfileService.profileCode(
                forBundleId: "com.microsoft.vscode",
                isClaudeCodeSession: true
            ),
            5
        )
    }

    func testNonCliAppsDoNotReceiveClaudeCodeProfile() {
        XCTAssertEqual(
            PHTVCliProfileService.profileCode(
                forBundleId: "com.apple.Safari",
                isClaudeCodeSession: true
            ),
            0
        )
    }
}
