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
            presentation(isVietnameseEnabled: true, useVietnameseIcon: true),
            .bundledAsset("menubar_vietnamese")
        )
    }

    func testVietnameseModeCanUseDefaultAppIcon() {
        XCTAssertEqual(
            presentation(isVietnameseEnabled: true, useVietnameseIcon: false),
            .bundledAsset("menubar_icon")
        )
    }

    func testEnglishModeUsesEnglishIcon() {
        XCTAssertEqual(
            presentation(isVietnameseEnabled: false),
            .bundledAsset("menubar_english")
        )
    }

    func testNonLatinInputSourceUsesCurrentSystemInputSourceIcon() {
        XCTAssertEqual(
            presentation(
                isVietnameseEnabled: false,
                isUsingNonLatinInputSource: true,
                languageBeforeNonLatinInputSource: 1
            ),
            .currentInputSource(fallbackAssetName: "menubar_vietnamese")
        )
    }

    func testNonLatinInputSourceFallsBackToEnglishWhenUserWasAlreadyInEnglishMode() {
        XCTAssertEqual(
            presentation(
                isVietnameseEnabled: false,
                isUsingNonLatinInputSource: true,
                languageBeforeNonLatinInputSource: 0
            ),
            .currentInputSource(fallbackAssetName: "menubar_english")
        )
    }

    func testNonLatinInputSourceWinsBeforeTemporaryLanguageSuspensionCompletes() {
        XCTAssertEqual(
            presentation(
                isVietnameseEnabled: true,
                isUsingNonLatinInputSource: true,
                languageBeforeNonLatinInputSource: 1
            ),
            .currentInputSource(fallbackAssetName: "menubar_vietnamese")
        )
    }

    func testSavedVietnameseLanguageDoesNotOverrideEnglishAfterLeavingNonLatinInputSource() {
        XCTAssertEqual(
            presentation(
                isVietnameseEnabled: false,
                isUsingNonLatinInputSource: false,
                languageBeforeNonLatinInputSource: 1
            ),
            .bundledAsset("menubar_english")
        )
    }

    private func presentation(
        isVietnameseEnabled: Bool,
        useVietnameseIcon: Bool = true,
        isUsingNonLatinInputSource: Bool = false,
        languageBeforeNonLatinInputSource: Int = 0
    ) -> PHTVMenuBarIconPresentation {
        PHTVMenuBarIconPolicy.presentation(
            isVietnameseEnabled: isVietnameseEnabled,
            useVietnameseIcon: useVietnameseIcon,
            isUsingNonLatinInputSource: isUsingNonLatinInputSource,
            languageBeforeNonLatinInputSource: languageBeforeNonLatinInputSource
        )
    }
}
