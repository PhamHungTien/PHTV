//
//  DebugBuildUpdatePolicyTests.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import XCTest
@testable import PHTV

final class DebugBuildUpdatePolicyTests: XCTestCase {
    func testDebugBuildDisablesSparkleUpdates() {
        #if DEBUG
        XCTAssertTrue(PHTVBuildInfo.isDebugBuild)
        XCTAssertFalse(PHTVBuildInfo.updatesEnabled)
        XCTAssertTrue(PHTVBuildInfo.displayVersion.contains("Debug"))
        #else
        XCTAssertFalse(PHTVBuildInfo.isDebugBuild)
        XCTAssertTrue(PHTVBuildInfo.updatesEnabled)
        XCTAssertFalse(PHTVBuildInfo.displayVersion.contains("Debug"))
        #endif
    }
}
