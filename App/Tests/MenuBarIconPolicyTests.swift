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
                isUsingNonLatinInputSource: true
            ),
            .currentInputSource(fallbackAssetName: "menubar_english")
        )
    }

    func testNonLatinInputSourceFallsBackToEnglishWhenUserWasAlreadyInEnglishMode() {
        XCTAssertEqual(
            presentation(
                isVietnameseEnabled: false,
                isUsingNonLatinInputSource: true
            ),
            .currentInputSource(fallbackAssetName: "menubar_english")
        )
    }

    func testNonLatinInputSourceWinsBeforeTemporaryLanguageSuspensionCompletes() {
        XCTAssertEqual(
            presentation(
                isVietnameseEnabled: true,
                isUsingNonLatinInputSource: true
            ),
            .currentInputSource(fallbackAssetName: "menubar_english")
        )
    }

    func testEnglishAppLockOverridesCurrentSystemInputSourceIcon() {
        XCTAssertEqual(
            presentation(
                isVietnameseEnabled: true,
                isUsingNonLatinInputSource: true,
                isEnglishLocked: true
            ),
            .bundledAsset("menubar_english")
        )
    }

    func testSavedVietnameseLanguageDoesNotOverrideEnglishAfterLeavingNonLatinInputSource() {
        XCTAssertEqual(
            presentation(
                isVietnameseEnabled: false,
                isUsingNonLatinInputSource: false
            ),
            .bundledAsset("menubar_english")
        )
    }

    private func presentation(
        isVietnameseEnabled: Bool,
        useVietnameseIcon: Bool = true,
        isUsingNonLatinInputSource: Bool = false,
        isEnglishLocked: Bool = false
    ) -> PHTVMenuBarIconPresentation {
        PHTVMenuBarIconPolicy.presentation(
            isVietnameseEnabled: isVietnameseEnabled,
            useVietnameseIcon: useVietnameseIcon,
            isUsingNonLatinInputSource: isUsingNonLatinInputSource,
            isEnglishLocked: isEnglishLocked
        )
    }
}
