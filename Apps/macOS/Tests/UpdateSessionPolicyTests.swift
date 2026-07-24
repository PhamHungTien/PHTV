//
//  UpdateSessionPolicyTests.swift
//  PHTV
//
//  Regression coverage for issue #196: update activity must be blocked for
//  off-console sessions so a background account's instance never replaces
//  the app bundle underneath the active account's instance.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import XCTest
@testable import PHTV

final class UpdateSessionPolicyTests: XCTestCase {

    func testOnConsoleSessionAllowsUpdates() {
        XCTAssertTrue(PHTVUpdateSessionPolicy.shouldAllowUpdateActivity(onConsole: true))
    }

    func testOffConsoleSessionBlocksUpdates() {
        XCTAssertFalse(PHTVUpdateSessionPolicy.shouldAllowUpdateActivity(onConsole: false))
    }

    func testUnknownSessionStateAllowsUpdates() {
        // Exotic contexts without a session dictionary must not permanently
        // lose updates; the freeze scenario always reports onConsole == false.
        XCTAssertTrue(PHTVUpdateSessionPolicy.shouldAllowUpdateActivity(onConsole: nil))
    }
}
