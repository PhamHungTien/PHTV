//
//  MenuBarIconPolicyTests.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import XCTest
@testable import PHTV

final class MenuBarIconPolicyTests: XCTestCase {
    func testVietnameseModeUsesConfiguredVietnameseIcon() {
        XCTAssertEqual(
            assetName(isVietnameseEnabled: true, useVietnameseIcon: true),
            "menubar_vietnamese"
        )
    }

    func testVietnameseModeCanUseDefaultAppIcon() {
        XCTAssertEqual(
            assetName(isVietnameseEnabled: true, useVietnameseIcon: false),
            "menubar_icon"
        )
    }

    func testEnglishModeUsesEnglishIcon() {
        XCTAssertEqual(
            assetName(isVietnameseEnabled: false),
            "menubar_english"
        )
    }

    func testNonLatinInputSourceKeepsVietnameseIconWhileVietnameseIsTemporarilySuspended() {
        XCTAssertEqual(
            assetName(
                isVietnameseEnabled: false,
                isUsingNonLatinInputSource: true,
                languageBeforeNonLatinInputSource: 1
            ),
            "menubar_vietnamese"
        )
    }

    func testNonLatinInputSourceKeepsEnglishIconWhenUserWasAlreadyInEnglishMode() {
        XCTAssertEqual(
            assetName(
                isVietnameseEnabled: false,
                isUsingNonLatinInputSource: true,
                languageBeforeNonLatinInputSource: 0
            ),
            "menubar_english"
        )
    }

    func testSavedVietnameseLanguageDoesNotOverrideEnglishAfterLeavingNonLatinInputSource() {
        XCTAssertEqual(
            assetName(
                isVietnameseEnabled: false,
                isUsingNonLatinInputSource: false,
                languageBeforeNonLatinInputSource: 1
            ),
            "menubar_english"
        )
    }

    private func assetName(
        isVietnameseEnabled: Bool,
        useVietnameseIcon: Bool = true,
        isUsingNonLatinInputSource: Bool = false,
        languageBeforeNonLatinInputSource: Int = 0
    ) -> String {
        PHTVMenuBarIconPolicy.assetName(
            isVietnameseEnabled: isVietnameseEnabled,
            useVietnameseIcon: useVietnameseIcon,
            isUsingNonLatinInputSource: isUsingNonLatinInputSource,
            languageBeforeNonLatinInputSource: languageBeforeNonLatinInputSource
        )
    }
}
