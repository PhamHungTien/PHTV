//
//  AutoRestoreSettingsPersistenceTests.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import XCTest
@testable import PHTV

final class AutoRestoreSettingsPersistenceTests: XCTestCase {
    private let keysUnderTest = [
        UserDefaultsKey.autoRestoreEnglishWord,
        UserDefaultsKey.autoRestoreEnglishWordMode,
        UserDefaultsKey.restoreIfWrongSpelling,
        UserDefaultsKey.quickTelex,
        UserDefaultsKey.menuBarIconSize
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

    func testFirstModeChangePersistsBeforeReload() async {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: UserDefaultsKey.autoRestoreEnglishWord)
        defaults.set(AutoRestoreEnglishMode.englishOnly.rawValue, forKey: UserDefaultsKey.autoRestoreEnglishWordMode)
        defaults.set(false, forKey: UserDefaultsKey.restoreIfWrongSpelling)

        let persistedMode = await MainActor.run { () -> AutoRestoreEnglishMode in
            let state = InputMethodState()
            state.isLoadingSettings = true
            state.loadSettings()
            state.isLoadingSettings = false
            state.setupObservers()

            state.autoRestoreEnglishWordMode = .nonVietnamese
            state.saveSettings()

            state.isLoadingSettings = true
            state.reloadFromDefaults()
            state.isLoadingSettings = false

            return state.autoRestoreEnglishWordMode
        }

        XCTAssertEqual(persistedMode, .nonVietnamese)
        XCTAssertEqual(
            defaults.integer(forKey: UserDefaultsKey.autoRestoreEnglishWordMode),
            AutoRestoreEnglishMode.nonVietnamese.rawValue
        )
        XCTAssertTrue(defaults.bool(forKey: UserDefaultsKey.restoreIfWrongSpelling))
    }

    func testSaveSettingsPersistsPendingDebouncedSettingsWithoutWaitingForDebounce() async {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: UserDefaultsKey.quickTelex)
        defaults.set(18.0, forKey: UserDefaultsKey.menuBarIconSize)
        defaults.set(true, forKey: UserDefaultsKey.autoRestoreEnglishWord)
        defaults.set(AutoRestoreEnglishMode.englishOnly.rawValue, forKey: UserDefaultsKey.autoRestoreEnglishWordMode)
        defaults.set(false, forKey: UserDefaultsKey.restoreIfWrongSpelling)

        let states = await MainActor.run { () -> (InputMethodState, UIState) in
            let inputState = InputMethodState()
            inputState.isLoadingSettings = true
            inputState.loadSettings()
            inputState.isLoadingSettings = false

            let uiState = UIState()
            uiState.isLoadingSettings = true
            uiState.loadSettings()
            uiState.isLoadingSettings = false

            inputState.quickTelex = true
            inputState.autoRestoreEnglishWordMode = .nonVietnamese
            uiState.menuBarIconSize = 16.0

            return (inputState, uiState)
        }

        XCTAssertFalse(defaults.bool(forKey: UserDefaultsKey.quickTelex))
        XCTAssertEqual(defaults.double(forKey: UserDefaultsKey.menuBarIconSize), 18.0)
        XCTAssertEqual(defaults.integer(forKey: UserDefaultsKey.autoRestoreEnglishWordMode), AutoRestoreEnglishMode.englishOnly.rawValue)

        await MainActor.run {
            states.0.saveSettings()
            states.1.saveSettings()
        }

        XCTAssertTrue(defaults.bool(forKey: UserDefaultsKey.quickTelex))
        XCTAssertEqual(defaults.double(forKey: UserDefaultsKey.menuBarIconSize), 16.0)
        XCTAssertEqual(
            defaults.integer(forKey: UserDefaultsKey.autoRestoreEnglishWordMode),
            AutoRestoreEnglishMode.nonVietnamese.rawValue
        )
        XCTAssertTrue(defaults.bool(forKey: UserDefaultsKey.restoreIfWrongSpelling))
    }
}
