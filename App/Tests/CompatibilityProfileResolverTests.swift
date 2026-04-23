//
//  CompatibilityProfileResolverTests.swift
//  PHTV
//
//  Regression coverage for data-driven app compatibility profiles.
//

import XCTest
@testable import PHTV

final class CompatibilityProfileResolverTests: XCTestCase {
    func testBrowserProfileForChrome() {
        let profile = PHTVCompatibilityProfileResolver.resolve(forBundleId: "com.google.Chrome")

        XCTAssertEqual(profile.kind, .browser)
        XCTAssertTrue(profile.isBrowser)
        XCTAssertTrue(profile.supportsNativeSystemTextReplacements)
        XCTAssertFalse(profile.shouldPostToHIDTap)
    }

    func testEditorProfileForVSCode() {
        let profile = PHTVCompatibilityProfileResolver.resolve(forBundleId: "com.microsoft.VSCode")

        XCTAssertEqual(profile.kind, .editorIDE)
        XCTAssertTrue(profile.isIDEApp)
        XCTAssertNil(profile.cliProfileCode)
    }

    func testChatProfileForSlack() {
        let profile = PHTVCompatibilityProfileResolver.resolve(forBundleId: "com.tinyspeck.slackmacgap")

        XCTAssertEqual(profile.kind, .chat)
        XCTAssertTrue(profile.isChatApp)
    }

    func testOfficeProfileForOutlookCarriesLegacySpaceCommitFix() {
        let profile = PHTVCompatibilityProfileResolver.resolve(forBundleId: "com.microsoft.Outlook")

        XCTAssertEqual(profile.kind, .office)
        XCTAssertTrue(profile.isOfficeApp)
        XCTAssertTrue(profile.needsLegacySpaceCommitFix)
    }

    func testSpotlightProfileUsesHIDTapFallback() {
        let profile = PHTVCompatibilityProfileResolver.resolve(
            forBundleId: "com.apple.Spotlight",
            spotlightActive: true,
            isTerminalPanel: false,
            isClaudeCodeSession: false
        )

        XCTAssertEqual(profile.kind, .spotlightLike)
        XCTAssertTrue(profile.isSpotlightLike)
        XCTAssertTrue(profile.shouldPostToHIDTap)
    }

    func testClaudeCodeTerminalProfileUsesDedicatedCliTiming() {
        let profile = PHTVCompatibilityProfileResolver.resolve(
            forBundleId: "com.apple.Terminal",
            spotlightActive: false,
            isTerminalPanel: false,
            isClaudeCodeSession: true
        )

        XCTAssertEqual(profile.kind, .terminal)
        XCTAssertTrue(profile.isCliTarget)
        XCTAssertEqual(profile.cliProfileCode, 5)
    }

    func testCocCocProfileEnablesStrictAddressBarDetection() {
        let profile = PHTVCompatibilityProfileResolver.resolve(forBundleId: "com.coccoc.browser")

        XCTAssertEqual(profile.kind, .browser)
        XCTAssertTrue(profile.needsStrictAddressBarDetection)
    }
}
