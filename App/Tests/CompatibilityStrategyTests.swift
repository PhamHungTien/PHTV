//
//  CompatibilityStrategyTests.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import XCTest
@testable import PHTV

final class CompatibilityStrategyTests: XCTestCase {

    func testOutlookNeedsLegacySpaceCommitFix() {
        XCTAssertTrue(PHTVAppDetectionService.needsLegacySpaceCommitFix("com.microsoft.Outlook"))
        XCTAssertTrue(PHTVAppDetectionService.needsLegacySpaceCommitFix("com.microsoft.outlook"))
        XCTAssertFalse(PHTVAppDetectionService.needsLegacySpaceCommitFix("com.apple.TextEdit"))
    }

    func testOutlookSpaceRestoreEnablesLegacyNonBrowserFix() {
        let plan = PHTVInputStrategyService.processSignalPlan(
            forBundleId: "com.microsoft.Outlook",
            keyCode: Int32(KeyCode.space),
            spaceKeyCode: Int32(KeyCode.space),
            slashKeyCode: Int32(KeyCode.slash),
            extCode: 0,
            backspaceCount: 4,
            newCharCount: 1,
            isBrowserApp: false,
            isSpotlightTarget: false,
            needsPrecomposedBatched: false,
            browserFixEnabled: true
        )

        XCTAssertFalse(plan.shouldSkipSpace)
        XCTAssertTrue(plan.shouldTryLegacyNonBrowserFix)
        XCTAssertFalse(plan.shouldLogSpaceSkip)
    }

    func testRegularNonBrowserSpaceRestoreStillSkipsLegacyNonBrowserFix() {
        let plan = PHTVInputStrategyService.processSignalPlan(
            forBundleId: "com.apple.TextEdit",
            keyCode: Int32(KeyCode.space),
            spaceKeyCode: Int32(KeyCode.space),
            slashKeyCode: Int32(KeyCode.slash),
            extCode: 0,
            backspaceCount: 4,
            newCharCount: 1,
            isBrowserApp: false,
            isSpotlightTarget: false,
            needsPrecomposedBatched: false,
            browserFixEnabled: true
        )

        XCTAssertFalse(plan.shouldSkipSpace)
        XCTAssertFalse(plan.shouldTryLegacyNonBrowserFix)
        XCTAssertTrue(plan.shouldLogSpaceSkip)
    }

    func testCocCocNeedsStrictAddressBarDetection() {
        XCTAssertTrue(PHTVAppDetectionService.needsStrictAddressBarDetection("com.coccoc.browser"))
        XCTAssertFalse(PHTVAppDetectionService.needsStrictAddressBarDetection("com.google.Chrome"))
    }

    func testStrictAddressBarDetectionRejectsGenericTextFieldOutsideWebArea() {
        XCTAssertFalse(
            PHTVAccessibilityService.addressBarClassification(
                role: "AXTextField",
                positiveKeywordMatch: false,
                foundWebArea: false,
                strictDetection: true
            )
        )
    }

    func testStrictAddressBarDetectionStillAcceptsOmniboxKeywordMatch() {
        XCTAssertTrue(
            PHTVAccessibilityService.addressBarClassification(
                role: "AXTextField",
                positiveKeywordMatch: true,
                foundWebArea: false,
                strictDetection: true
            )
        )
    }

    func testLegacyAddressBarDetectionKeepsFallbackForGenericTextField() {
        XCTAssertTrue(
            PHTVAccessibilityService.addressBarClassification(
                role: "AXTextField",
                positiveKeywordMatch: false,
                foundWebArea: false,
                strictDetection: false
            )
        )
    }

    // Cốc Cốc: AXRow/AXList/AXGroup (search-history dropdown items) must NOT be
    // treated as address bars in strict mode — this prevented the browser fix from
    // incorrectly firing inside suggestion/history fields.
    func testStrictAddressBarDetectionRejectsUnknownRoleOutsideWebArea() {
        for role in ["AXRow", "AXList", "AXOutline", "AXGroup", "AXStaticText", "AXMenuItem"] {
            XCTAssertFalse(
                PHTVAccessibilityService.addressBarClassification(
                    role: role,
                    positiveKeywordMatch: false,
                    foundWebArea: false,
                    strictDetection: true
                ),
                "Expected strict mode to reject role '\(role)' as address bar"
            )
        }
    }

    func testLegacyAddressBarDetectionAcceptsUnknownRoleAsAddressBar() {
        for role in ["AXRow", "AXList", "AXOutline", "AXGroup"] {
            XCTAssertTrue(
                PHTVAccessibilityService.addressBarClassification(
                    role: role,
                    positiveKeywordMatch: false,
                    foundWebArea: false,
                    strictDetection: false
                ),
                "Expected non-strict mode to accept role '\(role)' as potential address bar"
            )
        }
    }

    func testComboBoxAlwaysAddressBarRegardlessOfStrictMode() {
        XCTAssertTrue(PHTVAccessibilityService.addressBarClassification(
            role: "AXComboBox", positiveKeywordMatch: false, foundWebArea: false, strictDetection: true
        ))
        XCTAssertTrue(PHTVAccessibilityService.addressBarClassification(
            role: "AXComboBox", positiveKeywordMatch: false, foundWebArea: false, strictDetection: false
        ))
    }

    func testUnicodeCompoundLegacyBackspaceUsesSelectionOverwritePlan() {
        let plan = PHTVInputStrategyService.resolvedBackspacePlan(
            forBrowserAddressBarFix: false,
            addressBarDetected: false,
            legacyNonBrowserFix: true,
            containsUnicodeCompound: true,
            notionCodeBlockDetected: false,
            backspaceCount: 4,
            maxBuffer: 20,
            safetyLimit: 15
        )

        XCTAssertEqual(
            plan.adjustmentAction,
            PHTVBackspaceAdjustmentAction.sendShiftLeftThenBackspace.rawValue
        )
        XCTAssertEqual(plan.adjustedBackspaceCount, 3)
        XCTAssertEqual(plan.sanitizedBackspaceCount, 3)
    }

    // Notion is a precomposedBatched app (isSpecialApp=true), but the legacy fix
    // must still be enabled so that code block inspection in PHTVEventCallbackService
    // is not skipped due to the !isSpecialApp gate.
    func testNotionPrecomposedBatchedStillEnablesLegacyNonBrowserFix() {
        let plan = PHTVInputStrategyService.processSignalPlan(
            forBundleId: "notion.id",
            keyCode: Int32(KeyCode.vKey),
            spaceKeyCode: Int32(KeyCode.space),
            slashKeyCode: Int32(KeyCode.slash),
            extCode: 0,
            backspaceCount: 4,
            newCharCount: 1,
            isBrowserApp: false,
            isSpotlightTarget: false,
            needsPrecomposedBatched: true,
            browserFixEnabled: true
        )

        XCTAssertTrue(plan.isNotionApp, "bundle notion.id must be flagged isNotionApp")
        XCTAssertTrue(plan.isSpecialApp, "precomposedBatched makes Notion a special app")
        // The legacy fix bypass (!isSpecialApp || isNotionApp) must still be true
        // so that the event callback can enter the code block inspection path.
        XCTAssertTrue(plan.shouldTryLegacyNonBrowserFix)
    }

    func testNotionCodeBlockAlwaysUsesSelectionOverwritePlan() {
        let plan = PHTVInputStrategyService.resolvedBackspacePlan(
            forBrowserAddressBarFix: false,
            addressBarDetected: false,
            legacyNonBrowserFix: true,
            containsUnicodeCompound: false,
            notionCodeBlockDetected: true,
            backspaceCount: 4,
            maxBuffer: 20,
            safetyLimit: 15
        )

        XCTAssertEqual(
            plan.adjustmentAction,
            PHTVBackspaceAdjustmentAction.sendShiftLeftThenBackspace.rawValue
        )
        XCTAssertEqual(plan.adjustedBackspaceCount, 3)
        XCTAssertEqual(plan.sanitizedBackspaceCount, 3)
    }

    func testNotionPrefersDecodedCharacterSendOverStepByStepReplay() {
        let plan = PHTVInputStrategyService.characterSendPlan(
            forSpotlightTarget: false,
            cliTarget: false,
            globalStepByStep: false,
            appNeedsStepByStep: PHTVAppDetectionService.needsStepByStep("notion.id"),
            appNeedsPrecomposedBatched: PHTVAppDetectionService.needsPrecomposedBatched("notion.id"),
            keyCode: Int32(KeyCode.vKey),
            engineCode: EngineSignalCode.willProcess,
            restoreCode: EngineSignalCode.restore,
            restoreAndStartNewSessionCode: EngineSignalCode.restoreAndStartNewSession,
            enterKeyCode: Int32(KeyCode.enter),
            returnKeyCode: Int32(KeyCode.returnKey)
        )

        XCTAssertFalse(plan.useStepByStepCharacterSend)
        XCTAssertFalse(plan.shouldSendRestoreTriggerKey)
        XCTAssertFalse(plan.shouldStartNewSessionAfterSend)
    }

    func testNotionMacrosPreferDecodedCharacterSendOverStepByStepReplay() {
        let plan = PHTVInputStrategyService.macroPlan(
            forPostToHIDTap: false,
            appIsSpotlightLike: false,
            browserFixEnabled: false,
            originalBackspaceCount: 0,
            cliTarget: false,
            globalStepByStep: false,
            appNeedsStepByStep: PHTVAppDetectionService.needsStepByStep("notion.id"),
            appNeedsPrecomposedBatched: PHTVAppDetectionService.needsPrecomposedBatched("notion.id")
        )

        XCTAssertFalse(plan.useStepByStepSend)
    }

    func testEnglishRestorePrefersDecodedCharacterSendEvenWhenStepByStepIsEnabled() {
        let plan = PHTVInputStrategyService.characterSendPlan(
            forSpotlightTarget: false,
            cliTarget: false,
            globalStepByStep: true,
            appNeedsStepByStep: true,
            appNeedsPrecomposedBatched: false,
            keyCode: Int32(KeyCode.space),
            engineCode: EngineSignalCode.restore,
            restoreCode: EngineSignalCode.restore,
            restoreAndStartNewSessionCode: EngineSignalCode.restoreAndStartNewSession,
            enterKeyCode: Int32(KeyCode.enter),
            returnKeyCode: Int32(KeyCode.returnKey)
        )

        XCTAssertFalse(plan.useStepByStepCharacterSend)
        XCTAssertFalse(plan.shouldSendRestoreTriggerKey)
        XCTAssertFalse(plan.shouldStartNewSessionAfterSend)
    }

    func testCliRestoreStillUsesStepByStepReplay() {
        let plan = PHTVInputStrategyService.characterSendPlan(
            forSpotlightTarget: false,
            cliTarget: true,
            globalStepByStep: true,
            appNeedsStepByStep: true,
            appNeedsPrecomposedBatched: false,
            keyCode: Int32(KeyCode.space),
            engineCode: EngineSignalCode.restore,
            restoreCode: EngineSignalCode.restore,
            restoreAndStartNewSessionCode: EngineSignalCode.restoreAndStartNewSession,
            enterKeyCode: Int32(KeyCode.enter),
            returnKeyCode: Int32(KeyCode.returnKey)
        )

        XCTAssertTrue(plan.useStepByStepCharacterSend)
        XCTAssertTrue(plan.shouldSendRestoreTriggerKey)
        XCTAssertFalse(plan.shouldStartNewSessionAfterSend)
    }
}
