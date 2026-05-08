//
//  DefaultSettingsFlowTests.swift
//  PHTV
//
//  Verifies default settings stay aligned across bootstrap, reset, and runtime flow.
//  Created by Phạm Hùng Tiến on 2026.
//

import XCTest
@testable import PHTV

final class DefaultSettingsFlowTests: XCTestCase {
    private let trackedDefaultsKeys = [
        UserDefaultsKey.inputMethod,
        UserDefaultsKey.inputType,
        UserDefaultsKey.codeTable,
        UserDefaultsKey.spelling,
        UserDefaultsKey.modernOrthography,
        UserDefaultsKey.quickTelex,
        UserDefaultsKey.useMacro,
        UserDefaultsKey.useMacroInEnglishMode,
        UserDefaultsKey.autoCapsMacro,
        UserDefaultsKey.sendKeyStepByStep,
        UserDefaultsKey.useSmartSwitchKey,
        UserDefaultsKey.upperCaseFirstChar,
        UserDefaultsKey.allowConsonantZFWJ,
        UserDefaultsKey.quickStartConsonant,
        UserDefaultsKey.quickEndConsonant,
        UserDefaultsKey.rememberCode,
        UserDefaultsKey.autoRestoreEnglishWord,
        UserDefaultsKey.autoRestoreEnglishWordMode,
        UserDefaultsKey.restoreIfWrongSpelling,
        UserDefaultsKey.restoreOnEscape,
        UserDefaultsKey.customEscapeKey,
        UserDefaultsKey.pauseKeyEnabled,
        UserDefaultsKey.pauseKey,
        UserDefaultsKey.pauseKeyName,
        UserDefaultsKey.switchKeyStatus,
        UserDefaultsKey.beepOnModeSwitch,
        UserDefaultsKey.beepVolume,
        UserDefaultsKey.menuBarIconSize,
        UserDefaultsKey.useVietnameseMenubarIcon,
        UserDefaultsKey.enableClipboardHistory,
        UserDefaultsKey.clipboardHotkeyModifiers,
        UserDefaultsKey.clipboardHotkeyKeyCode,
        UserDefaultsKey.clipboardHistoryMaxItems,
        UserDefaultsKey.showIconOnDock,
        UserDefaultsKey.performLayoutCompat,
        UserDefaultsKey.settingsWindowAlwaysOnTop,
        UserDefaultsKey.runOnStartup,
        UserDefaultsKey.runOnStartupLegacy,
        UserDefaultsKey.updateCheckInterval,
        UserDefaultsKey.automaticUpdateChecks,
        UserDefaultsKey.autoInstallUpdates,
        UserDefaultsKey.legacyAutoInstallUpdates,
        UserDefaultsKey.sparkleBetaChannel,
        UserDefaultsKey.includeSystemInfo,
        UserDefaultsKey.includeLogs,
        UserDefaultsKey.includeCrashLogs
    ]

    private var defaultsBackup: [String: Any] = [:]

    override func setUp() {
        super.setUp()

        SettingsBootstrap.registerDefaults()
        let defaults = UserDefaults.standard
        defaultsBackup.removeAll(keepingCapacity: true)

        for key in trackedDefaultsKeys {
            if let value = defaults.persistedObject(forKey: key) {
                defaultsBackup[key] = value
            }
            defaults.removeObject(forKey: key)
        }
    }

    override func tearDown() {
        let defaults = UserDefaults.standard

        for key in trackedDefaultsKeys {
            defaults.removeObject(forKey: key)
        }

        for (key, value) in defaultsBackup {
            defaults.set(value, forKey: key)
        }

        _ = PHTVManager.loadRuntimeSettingsFromUserDefaults()
        super.tearDown()
    }

    func testRegisteredDefaultsCoverClipboardHistorySettings() {
        let defaults = UserDefaults.standard
        SettingsBootstrap.registerDefaults()

        XCTAssertEqual(
            defaults.bool(forKey: UserDefaultsKey.enableClipboardHistory, default: true),
            Defaults.enableClipboardHistory
        )
        XCTAssertEqual(
            defaults.integer(forKey: UserDefaultsKey.clipboardHotkeyModifiers),
            Int(Defaults.clipboardHotkeyModifiers)
        )
        XCTAssertEqual(
            defaults.integer(forKey: UserDefaultsKey.clipboardHotkeyKeyCode),
            Int(Defaults.clipboardHotkeyKeyCode)
        )
        XCTAssertEqual(
            defaults.integer(forKey: UserDefaultsKey.clipboardHistoryMaxItems),
            Defaults.clipboardHistoryMaxItems
        )
    }

    func testSystemResetRestoresUpdateInstallDefault() async {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: UserDefaultsKey.autoInstallUpdates)
        defaults.set(true, forKey: UserDefaultsKey.legacyAutoInstallUpdates)

        let autoInstallAfterReset = await MainActor.run { () -> Bool in
            let state = SystemState()
            state.isLoadingSettings = true
            state.loadSettings(shouldRefreshRunOnStartupStatus: false)
            state.isLoadingSettings = false

            state.autoInstallUpdates = false
            state.resetToDefaults()
            return state.autoInstallUpdates
        }

        XCTAssertEqual(autoInstallAfterReset, Defaults.autoInstallUpdates)
        XCTAssertEqual(
            defaults.bool(forKey: UserDefaultsKey.autoInstallUpdates, default: false),
            Defaults.autoInstallUpdates
        )
        XCTAssertNil(defaults.object(forKey: UserDefaultsKey.legacyAutoInstallUpdates))
    }

    func testLegacyDefaultConfigMatchesCurrentDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: UserDefaultsKey.settingsWindowAlwaysOnTop)
        defaults.set(false, forKey: UserDefaultsKey.autoInstallUpdates)
        defaults.set(true, forKey: UserDefaultsKey.legacyAutoInstallUpdates)
        defaults.set(true, forKey: UserDefaultsKey.sparkleBetaChannel)
        defaults.set(0, forKey: UserDefaultsKey.customEscapeKey)

        PHTVManager.loadDefaultConfig()

        XCTAssertEqual(defaults.integer(forKey: UserDefaultsKey.inputMethod), 1)
        XCTAssertEqual(defaults.integer(forKey: UserDefaultsKey.inputType), Defaults.inputMethod.toIndex())
        XCTAssertEqual(defaults.integer(forKey: UserDefaultsKey.codeTable), Defaults.codeTable.toIndex())
        XCTAssertEqual(defaults.bool(forKey: UserDefaultsKey.quickTelex), Defaults.quickTelex)
        XCTAssertEqual(defaults.bool(forKey: UserDefaultsKey.modernOrthography), Defaults.useModernOrthography)
        XCTAssertEqual(defaults.bool(forKey: UserDefaultsKey.useMacro), Defaults.useMacro)
        XCTAssertEqual(defaults.bool(forKey: UserDefaultsKey.useMacroInEnglishMode), Defaults.useMacroInEnglishMode)
        XCTAssertEqual(defaults.bool(forKey: UserDefaultsKey.sendKeyStepByStep), Defaults.sendKeyStepByStep)
        XCTAssertEqual(defaults.bool(forKey: UserDefaultsKey.useSmartSwitchKey), Defaults.useSmartSwitchKey)
        XCTAssertEqual(defaults.bool(forKey: UserDefaultsKey.upperCaseFirstChar), Defaults.upperCaseFirstChar)
        XCTAssertEqual(defaults.bool(forKey: UserDefaultsKey.allowConsonantZFWJ), Defaults.allowConsonantZFWJ)
        XCTAssertEqual(defaults.bool(forKey: UserDefaultsKey.quickStartConsonant), Defaults.quickStartConsonant)
        XCTAssertEqual(defaults.bool(forKey: UserDefaultsKey.quickEndConsonant), Defaults.quickEndConsonant)
        XCTAssertEqual(defaults.bool(forKey: UserDefaultsKey.rememberCode), Defaults.rememberCode)
        XCTAssertEqual(defaults.bool(forKey: UserDefaultsKey.restoreOnEscape), Defaults.restoreOnEscape)
        XCTAssertEqual(defaults.integer(forKey: UserDefaultsKey.customEscapeKey), Int(Defaults.restoreKeyCode))
        XCTAssertEqual(defaults.bool(forKey: UserDefaultsKey.showIconOnDock), Defaults.showIconOnDock)
        XCTAssertEqual(defaults.bool(forKey: UserDefaultsKey.performLayoutCompat), Defaults.performLayoutCompat)
        XCTAssertEqual(defaults.bool(forKey: UserDefaultsKey.settingsWindowAlwaysOnTop), Defaults.settingsWindowAlwaysOnTop)
        XCTAssertEqual(defaults.bool(forKey: UserDefaultsKey.beepOnModeSwitch), Defaults.beepOnModeSwitch)
        XCTAssertEqual(defaults.double(forKey: UserDefaultsKey.beepVolume), Defaults.beepVolume, accuracy: 0.001)
        XCTAssertEqual(defaults.double(forKey: UserDefaultsKey.menuBarIconSize), Defaults.menuBarIconSize, accuracy: 0.001)
        XCTAssertEqual(defaults.bool(forKey: UserDefaultsKey.useVietnameseMenubarIcon), Defaults.useVietnameseMenubarIcon)
        XCTAssertEqual(defaults.integer(forKey: UserDefaultsKey.updateCheckInterval), Defaults.updateCheckInterval)
        XCTAssertEqual(defaults.bool(forKey: UserDefaultsKey.automaticUpdateChecks), Defaults.automaticUpdateChecks)
        XCTAssertEqual(defaults.bool(forKey: UserDefaultsKey.autoInstallUpdates), Defaults.autoInstallUpdates)
        XCTAssertNil(defaults.object(forKey: UserDefaultsKey.legacyAutoInstallUpdates))
        XCTAssertNil(defaults.object(forKey: UserDefaultsKey.sparkleBetaChannel))
        XCTAssertEqual(defaults.bool(forKey: UserDefaultsKey.includeSystemInfo), Defaults.includeSystemInfo)
        XCTAssertEqual(defaults.bool(forKey: UserDefaultsKey.includeLogs), Defaults.includeLogs)
        XCTAssertEqual(defaults.bool(forKey: UserDefaultsKey.includeCrashLogs), Defaults.includeCrashLogs)

        XCTAssertEqual(PHTVEngineRuntimeFacade.currentInputType(), Int32(Defaults.inputMethod.toIndex()))
        XCTAssertEqual(PHTVEngineRuntimeFacade.currentCodeTable(), Int32(Defaults.codeTable.toIndex()))
        XCTAssertEqual(PHTVEngineRuntimeFacade.customEscapeKey(), Int32(Defaults.restoreKeyCode))
    }
}
