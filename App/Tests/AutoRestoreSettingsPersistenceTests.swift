//
//  AutoRestoreSettingsPersistenceTests.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import XCTest
@testable import PHTV

@MainActor
final class AutoRestoreSettingsPersistenceTests: XCTestCase {
    private let keysUnderTest = [
        UserDefaultsKey.autoRestoreEnglishWord,
        UserDefaultsKey.autoRestoreEnglishWordMode,
        UserDefaultsKey.restoreIfWrongSpelling
    ]

    private var savedValues: [String: Any] = [:]

    override func setUp() {
        super.setUp()

        let defaults = UserDefaults.standard
        savedValues.removeAll()

        for key in keysUnderTest {
            if let value = defaults.persistedObject(forKey: key) {
                savedValues[key] = value
            } else {
                defaults.removeObject(forKey: key)
            }
        }
    }

    override func tearDown() {
        let defaults = UserDefaults.standard

        for key in keysUnderTest {
            defaults.removeObject(forKey: key)
        }

        for (key, value) in savedValues {
            defaults.set(value, forKey: key)
        }

        super.tearDown()
    }

    func testFirstModeChangePersistsBeforeReload() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: UserDefaultsKey.autoRestoreEnglishWord)
        defaults.set(AutoRestoreEnglishMode.englishOnly.rawValue, forKey: UserDefaultsKey.autoRestoreEnglishWordMode)
        defaults.set(false, forKey: UserDefaultsKey.restoreIfWrongSpelling)

        let state = InputMethodState()
        state.isLoadingSettings = true
        state.loadSettings()
        state.isLoadingSettings = false
        state.setupObservers()

        state.autoRestoreEnglishWordMode = .nonVietnamese

        state.isLoadingSettings = true
        state.reloadFromDefaults()
        state.isLoadingSettings = false

        XCTAssertEqual(state.autoRestoreEnglishWordMode, .nonVietnamese)
        XCTAssertEqual(
            defaults.integer(forKey: UserDefaultsKey.autoRestoreEnglishWordMode),
            AutoRestoreEnglishMode.nonVietnamese.rawValue
        )
        XCTAssertTrue(defaults.bool(forKey: UserDefaultsKey.restoreIfWrongSpelling))
    }
}
