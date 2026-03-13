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
}
