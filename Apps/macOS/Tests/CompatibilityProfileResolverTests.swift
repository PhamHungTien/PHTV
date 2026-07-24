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
        XCTAssertFalse(profile.supportsNativeSystemTextReplacements)
        XCTAssertFalse(profile.shouldPostToHIDTap)
    }

    func testBrowserProfileForChatGPTAtlas() {
        for bundleId in ["com.openai.atlas", "com.openai.atlas.beta", "com.openai.atlas.app.Profile"] {
            let profile = PHTVCompatibilityProfileResolver.resolve(forBundleId: bundleId)

            XCTAssertEqual(profile.kind, .browser, bundleId)
            XCTAssertTrue(profile.isBrowser, bundleId)
            XCTAssertTrue(profile.containsUnicodeCompound, bundleId)
            XCTAssertFalse(profile.supportsNativeSystemTextReplacements, bundleId)
            XCTAssertFalse(profile.shouldPostToHIDTap, bundleId)
        }
    }

    func testEditorProfileForVSCode() {
        let profile = PHTVCompatibilityProfileResolver.resolve(forBundleId: "com.microsoft.VSCode")

        XCTAssertEqual(profile.kind, .editorIDE)
        XCTAssertTrue(profile.isIDEApp)
        XCTAssertNil(profile.cliProfileCode)
    }

    func testQoderKeepsEditorIdentityAndChromiumQuestCompatibility() {
        let profile = PHTVCompatibilityProfileResolver.resolve(forBundleId: "com.qoder.ide")

        XCTAssertEqual(profile.kind, .editorIDE)
        XCTAssertTrue(profile.isIDEApp)
        XCTAssertTrue(profile.isBrowser)
        XCTAssertTrue(profile.containsUnicodeCompound)
        XCTAssertFalse(profile.isCliTarget)
        XCTAssertNil(profile.cliProfileCode)
    }

    func testQoderIntegratedTerminalKeepsCliProfile() {
        let profile = PHTVCompatibilityProfileResolver.resolve(
            forBundleId: "com.qoder.ide",
            spotlightActive: false,
            isTerminalPanel: true,
            isClaudeCodeSession: false
        )

        XCTAssertEqual(profile.kind, .terminal)
        XCTAssertTrue(profile.isCliTarget)
        XCTAssertEqual(profile.cliProfileCode, 1)
    }

    func testJetBrainsEditorIsNotTreatedAsTerminal() {
        for bundleId in ["com.jetbrains.intellij", "com.google.android.studio"] {
            let profile = PHTVCompatibilityProfileResolver.resolve(
                forBundleId: bundleId,
                spotlightActive: false,
                isTerminalPanel: false,
                isClaudeCodeSession: false
            )

            XCTAssertEqual(profile.kind, .editorIDE, bundleId)
            XCTAssertTrue(profile.isIDEApp, bundleId)
            XCTAssertFalse(profile.isCliTarget, bundleId)
            XCTAssertNil(profile.cliProfileCode, bundleId)
        }
    }

    func testJetBrainsIntegratedTerminalKeepsCliProfile() {
        let profile = PHTVCompatibilityProfileResolver.resolve(
            forBundleId: "com.jetbrains.intellij",
            spotlightActive: false,
            isTerminalPanel: true,
            isClaudeCodeSession: false
        )

        XCTAssertEqual(profile.kind, .terminal)
        XCTAssertTrue(profile.isCliTarget)
        XCTAssertEqual(profile.cliProfileCode, 1)
    }

    func testChatProfileForSlack() {
        let profile = PHTVCompatibilityProfileResolver.resolve(forBundleId: "com.tinyspeck.slackmacgap")

        XCTAssertEqual(profile.kind, .chat)
        XCTAssertTrue(profile.isChatApp)
        XCTAssertFalse(profile.supportsNativeSystemTextReplacements)
    }

    func testZaloChatProfileUsesPHTVTextReplacementFallback() {
        let profile = PHTVCompatibilityProfileResolver.resolve(forBundleId: "com.vng.zalo")

        XCTAssertEqual(profile.kind, .chat)
        XCTAssertTrue(profile.isChatApp)
        XCTAssertFalse(profile.supportsNativeSystemTextReplacements)
    }

    func testMicrosoftTeamsProfilesUsePHTVTextReplacementFallback() {
        for bundleId in ["com.microsoft.teams2", "com.microsoft.teams"] {
            let profile = PHTVCompatibilityProfileResolver.resolve(forBundleId: bundleId)

            XCTAssertEqual(profile.kind, .chat, bundleId)
            XCTAssertTrue(profile.isChatApp, bundleId)
            XCTAssertFalse(profile.supportsNativeSystemTextReplacements, bundleId)
        }
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

    func testHeliumBrowserProfile() {
        let profile = PHTVCompatibilityProfileResolver.resolve(forBundleId: "net.imput.helium")

        XCTAssertEqual(profile.kind, .browser)
        XCTAssertTrue(profile.isBrowser)
        XCTAssertTrue(profile.containsUnicodeCompound)
    }
}
