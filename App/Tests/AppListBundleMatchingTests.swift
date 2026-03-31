//
//  AppListBundleMatchingTests.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import XCTest
@testable import PHTV

final class AppListBundleMatchingTests: XCTestCase {
    func testSpotlightAliasesShareCanonicalBundleId() {
        XCTAssertEqual(
            PHTVAppDetectionService.canonicalBundleIdForAppListMatching("com.apple.Spotlight"),
            "com.apple.spotlight"
        )
        XCTAssertEqual(
            PHTVAppDetectionService.canonicalBundleIdForAppListMatching("com.apple.systemuiserver"),
            "com.apple.spotlight"
        )
        XCTAssertEqual(
            PHTVAppDetectionService.canonicalBundleIdForAppListMatching("com.apple.apps.launcher"),
            "com.apple.spotlight"
        )
    }

    func testLaunchpadAliasesShareCanonicalBundleId() {
        XCTAssertEqual(
            PHTVAppDetectionService.canonicalBundleIdForAppListMatching("com.apple.launchpad"),
            "com.apple.launchpad"
        )
        XCTAssertEqual(
            PHTVAppDetectionService.canonicalBundleIdForAppListMatching("com.apple.launchpad.launcher"),
            "com.apple.launchpad"
        )
    }

    func testAppListBundleMatchingUsesAliasesAndIgnoresCase() {
        XCTAssertTrue(
            PHTVAppDetectionService.bundleId(
                "com.apple.systemuiserver",
                matchesAppListBundleId: "COM.APPLE.SPOTLIGHT"
            )
        )
        XCTAssertTrue(
            PHTVAppDetectionService.bundleId(
                "com.apple.launchpad.launcher",
                matchesAppListBundleId: "com.apple.launchpad"
            )
        )
        XCTAssertFalse(
            PHTVAppDetectionService.bundleId(
                "com.apple.finder",
                matchesAppListBundleId: "com.apple.spotlight"
            )
        )
    }
}
