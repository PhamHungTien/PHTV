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
        UserDefaultsKey.allowConsonantZFWJ,
        UserDefaultsKey.quickTelex,
        UserDefaultsKey.menuBarIconSize,
        UserDefaultsKey.switchKeyStatus,
        UserDefaultsKey.useVietnameseMenubarIcon
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

    override func tearDown() async throws {
        let defaults = UserDefaults.standard

        for key in keysUnderTest {
            defaults.removeObject(forKey: key)
        }

        for (key, value) in savedValues {
            defaults.set(value, forKey: key)
        }

        await MainActor.run {
            AppState.shared.loadSettings()
        }

        try await super.tearDown()
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
        XCTAssertEqual(
            defaults.integer(forKey: UserDefaultsKey.autoRestoreEnglishWordMode),
            AutoRestoreEnglishMode.nonVietnamese.rawValue
        )
        XCTAssertTrue(defaults.bool(forKey: UserDefaultsKey.restoreIfWrongSpelling))

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

    func testWindowCloseFlushPersistsPendingSettingsWithoutWaitingForDebounce() async {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: UserDefaultsKey.quickTelex)
        defaults.set(18.0, forKey: UserDefaultsKey.menuBarIconSize)
        defaults.set(true, forKey: UserDefaultsKey.autoRestoreEnglishWord)
        defaults.set(AutoRestoreEnglishMode.englishOnly.rawValue, forKey: UserDefaultsKey.autoRestoreEnglishWordMode)
        defaults.set(false, forKey: UserDefaultsKey.restoreIfWrongSpelling)

        await MainActor.run {
            let appState = AppState.shared
            appState.loadSettings()

            appState.quickTelex = true
            appState.autoRestoreEnglishWordMode = .nonVietnamese
            appState.uiState.menuBarIconSize = 16.0

            appState.flushPendingSettingsForWindowClose()
        }

        XCTAssertTrue(defaults.bool(forKey: UserDefaultsKey.quickTelex))
        XCTAssertEqual(defaults.double(forKey: UserDefaultsKey.menuBarIconSize), 16.0)
        XCTAssertEqual(
            defaults.integer(forKey: UserDefaultsKey.autoRestoreEnglishWordMode),
            AutoRestoreEnglishMode.nonVietnamese.rawValue
        )
        XCTAssertTrue(defaults.bool(forKey: UserDefaultsKey.restoreIfWrongSpelling))
    }

    func testFirstConsonantToggleAfterObserverSetupPersists() async throws {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: UserDefaultsKey.allowConsonantZFWJ)

        let state = await MainActor.run { () -> InputMethodState in
            let state = InputMethodState()
            state.isLoadingSettings = true
            state.loadSettings()
            state.isLoadingSettings = false
            state.setupObservers()
            state.allowConsonantZFWJ = true
            return state
        }

        _ = state
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertTrue(defaults.bool(forKey: UserDefaultsKey.allowConsonantZFWJ))
    }

    func testConsonantToggleSurvivesImmediateRuntimeReload() async {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: UserDefaultsKey.allowConsonantZFWJ)

        await MainActor.run {
            let appState = AppState.shared
            appState.loadSettings()
            appState.allowConsonantZFWJ = true
        }

        try? await Task.sleep(nanoseconds: 50_000_000)

        let persistedValue = await MainActor.run { () -> Bool in
            let appState = AppState.shared
            appState.refreshFromRuntime()
            return appState.allowConsonantZFWJ
        }

        XCTAssertTrue(persistedValue)
        XCTAssertTrue(defaults.bool(forKey: UserDefaultsKey.allowConsonantZFWJ))
    }

    func testMenubarIconToggleSurvivesImmediateRuntimeReload() async {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: UserDefaultsKey.useVietnameseMenubarIcon)

        await MainActor.run {
            let appState = AppState.shared
            appState.loadSettings()
            appState.useVietnameseMenubarIcon = true
        }

        try? await Task.sleep(nanoseconds: 50_000_000)

        let persistedValue = await MainActor.run { () -> Bool in
            let appState = AppState.shared
            appState.refreshFromRuntime()
            return appState.useVietnameseMenubarIcon
        }

        XCTAssertTrue(persistedValue)
        XCTAssertTrue(defaults.bool(forKey: UserDefaultsKey.useVietnameseMenubarIcon))
    }

    func testFirstSwitchHotkeyChangeAfterObserverSetupPersists() async throws {
        let defaults = UserDefaults.standard
        defaults.set(Defaults.defaultSwitchKeyStatus, forKey: UserDefaultsKey.switchKeyStatus)

        let state = await MainActor.run { () -> UIState in
            let state = UIState()
            state.isLoadingSettings = true
            state.loadSettings()
            state.isLoadingSettings = false
            state.setupObservers()
            state.switchKeyOption = true
            return state
        }

        let expectedStatus = await MainActor.run { state.encodeSwitchKeyStatus() }
        _ = state
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(defaults.integer(forKey: UserDefaultsKey.switchKeyStatus), expectedStatus)
    }
}
