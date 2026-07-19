//
//  SettingsAppRuleTerminologyTests.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import XCTest
@testable import PHTV

final class SettingsAppRuleTerminologyTests: XCTestCase {
    func testAppRulesUseDistinctOutcomeBasedNames() {
        let appSettingTitles = SettingsItem.allItems
            .filter { $0.tab == .apps }
            .map(\.title)

        XCTAssertTrue(appSettingTitles.contains("Ghi nhớ chế độ theo ứng dụng"))
        XCTAssertTrue(appSettingTitles.contains("Tiếng Anh theo ứng dụng"))
        XCTAssertFalse(appSettingTitles.contains("Loại trừ ứng dụng"))
    }

    func testAlwaysEnglishRuleRemainsDiscoverableByLegacySearchTerms() throws {
        let item = try XCTUnwrap(
            SettingsItem.allItems.first { $0.title == "Tiếng Anh theo ứng dụng" }
        )

        XCTAssertTrue(item.keywords.contains("loại trừ"))
        XCTAssertTrue(item.keywords.contains("exclude"))
        XCTAssertTrue(item.keywords.contains("không gõ tiếng Việt"))
        XCTAssertTrue(item.keywords.contains("luôn dùng tiếng Anh"))
        XCTAssertTrue(item.keywords.contains("chỉ dùng tiếng Anh"))
    }
}
