//
//  CliProfileServiceTests.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import XCTest
import Darwin
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

    func testRawCliPassThroughSchedulesSettleBlock() {
        PHTVCliRuntimeStateService.applyProfile(PHTVCliProfileService.profile(forCode: 3))
        PHTVCliRuntimeStateService.resetSpeedState()

        let now = mach_absolute_time()
        PHTVCliRuntimeStateService.scheduleRawKeyPassThroughBlock(nowMachTime: now)

        let remainingUs = PHTVCliRuntimeStateService.remainingBlockMicroseconds(forNowMachTime: now)
        XCTAssertGreaterThanOrEqual(remainingUs, UInt64(42_000))
        XCTAssertLessThanOrEqual(remainingUs, UInt64(43_000))

        PHTVCliRuntimeStateService.applyProfile(nil)
    }

    func testFastRawCliPassThroughUsesProfileWaitDelay() {
        PHTVCliRuntimeStateService.applyProfile(PHTVCliProfileService.profile(forCode: 2))
        PHTVCliRuntimeStateService.resetSpeedState()

        let now = mach_absolute_time()
        PHTVCliRuntimeStateService.scheduleRawKeyPassThroughBlock(nowMachTime: now)

        let remainingUs = PHTVCliRuntimeStateService.remainingBlockMicroseconds(forNowMachTime: now)
        XCTAssertGreaterThanOrEqual(remainingUs, UInt64(25_000))
        XCTAssertLessThanOrEqual(remainingUs, UInt64(26_000))

        PHTVCliRuntimeStateService.applyProfile(nil)
    }

    func testFastTerminalProfileUsesStableDelays() {
        let profile = PHTVCliProfileService.profile(forCode: 2)

        XCTAssertEqual(profile.backspaceDelayUs, 8_000)
        XCTAssertEqual(profile.waitAfterBackspaceUs, 25_000)
        XCTAssertEqual(profile.textDelayUs, 8_000)
        XCTAssertEqual(profile.textChunkSize, 1)
    }
}
