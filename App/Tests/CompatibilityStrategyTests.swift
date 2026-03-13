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
}
