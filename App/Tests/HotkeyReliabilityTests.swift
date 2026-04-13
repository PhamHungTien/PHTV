//
//  HotkeyReliabilityTests.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import XCTest
import AppKit
@testable import PHTV

final class HotkeyReliabilityTests: XCTestCase {
    private let trackedDefaultsKeys = [
        UserDefaultsKey.switchKeyStatus,
        "convertToolHotKey",
        UserDefaultsKey.enableEmojiHotkey,
        UserDefaultsKey.emojiHotkeyModifiers,
        UserDefaultsKey.emojiHotkeyKeyCode,
        UserDefaultsKey.inputMethod,
        UserDefaultsKey.inputType,
        UserDefaultsKey.codeTable
    ]

    private var defaultsBackup: [String: Any] = [:]
    private var missingDefaultsKeys: Set<String> = []

    override func setUp() {
        super.setUp()
        let defaults = UserDefaults.standard
        defaultsBackup.removeAll(keepingCapacity: true)
        missingDefaultsKeys.removeAll(keepingCapacity: true)
        PHTVConvertToolHotkeyService.invalidateCache()

        for key in trackedDefaultsKeys {
            if let value = defaults.object(forKey: key) {
                defaultsBackup[key] = value
            } else {
                missingDefaultsKeys.insert(key)
            }
        }
    }

    override func tearDown() {
        let defaults = UserDefaults.standard

        for key in trackedDefaultsKeys {
            if missingDefaultsKeys.contains(key) {
                defaults.removeObject(forKey: key)
            } else if let value = defaultsBackup[key] {
                defaults.set(value, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
        PHTVConvertToolHotkeyService.invalidateCache()

        super.tearDown()
    }

    func testLoadRuntimeSettingsNormalizesInvalidSwitchHotkey() {
        let defaults = UserDefaults.standard
        defaults.set(Int(Int32(bitPattern: 0xFFFF_FFFF)), forKey: UserDefaultsKey.switchKeyStatus)

        _ = PHTVManager.loadRuntimeSettingsFromUserDefaults()

        XCTAssertEqual(PHTVManager.currentSwitchKeyStatus(), Int32(Defaults.defaultSwitchKeyStatus))
        XCTAssertEqual(defaults.integer(forKey: UserDefaultsKey.switchKeyStatus), Defaults.defaultSwitchKeyStatus)
    }

    func testLoadRuntimeSettingsNormalizesNegativeCoreSettings() {
        let defaults = UserDefaults.standard
        defaults.set(-9, forKey: UserDefaultsKey.inputMethod)
        defaults.set(-5, forKey: UserDefaultsKey.inputType)
        defaults.set(-3, forKey: UserDefaultsKey.codeTable)

        _ = PHTVManager.loadRuntimeSettingsFromUserDefaults()

        XCTAssertEqual(PHTVEngineRuntimeFacade.currentLanguage(), 1)
        XCTAssertEqual(PHTVEngineRuntimeFacade.currentInputType(), 0)
        XCTAssertEqual(PHTVEngineRuntimeFacade.currentCodeTable(), 0)
        XCTAssertEqual(defaults.integer(forKey: UserDefaultsKey.inputMethod), 1)
        XCTAssertEqual(defaults.integer(forKey: UserDefaultsKey.inputType), 0)
        XCTAssertEqual(defaults.integer(forKey: UserDefaultsKey.codeTable), 0)
    }

    func testLoadRuntimeSettingsNormalizesOutOfRangeCoreSettings() {
        let defaults = UserDefaults.standard
        defaults.set(99, forKey: UserDefaultsKey.inputMethod)
        defaults.set(42, forKey: UserDefaultsKey.inputType)
        defaults.set(17, forKey: UserDefaultsKey.codeTable)

        _ = PHTVManager.loadRuntimeSettingsFromUserDefaults()

        XCTAssertEqual(PHTVEngineRuntimeFacade.currentLanguage(), 1)
        XCTAssertEqual(PHTVEngineRuntimeFacade.currentInputType(), 0)
        XCTAssertEqual(PHTVEngineRuntimeFacade.currentCodeTable(), 0)
        XCTAssertEqual(defaults.integer(forKey: UserDefaultsKey.inputMethod), 1)
        XCTAssertEqual(defaults.integer(forKey: UserDefaultsKey.inputType), 0)
        XCTAssertEqual(defaults.integer(forKey: UserDefaultsKey.codeTable), 0)
    }

    func testConvertHotkeyNormalizationFallsBackToEmptyHotkey() {
        let defaults = UserDefaults.standard
        defaults.set(0x0041, forKey: "convertToolHotKey")

        let resolved = PHTVConvertToolHotkeyService.currentHotkey()
        let expected = Int32(bitPattern: 0xFE0000FE)

        XCTAssertEqual(resolved, expected)
        XCTAssertEqual(
            Int32(truncatingIfNeeded: defaults.integer(forKey: "convertToolHotKey")),
            expected
        )
    }

    func testConvertHotkeyRefreshesCacheWhenDefaultsChange() {
        let defaults = UserDefaults.standard
        let validHotkey = Int32(bitPattern: 0x010E)
        let expected = Int32(bitPattern: 0xFE0000FE)

        defaults.set(Int(validHotkey), forKey: "convertToolHotKey")
        XCTAssertEqual(PHTVConvertToolHotkeyService.currentHotkey(), validHotkey)

        defaults.set(0x0041, forKey: "convertToolHotKey")

        let resolved = PHTVConvertToolHotkeyService.currentHotkey()
        XCTAssertEqual(resolved, expected)
        XCTAssertEqual(
            Int32(truncatingIfNeeded: defaults.integer(forKey: "convertToolHotKey")),
            expected
        )
    }

    func testEmojiHotkeyNormalizationRepairsInvalidValues() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "vEnableEmojiHotkey")
        defaults.set(0, forKey: "vEmojiHotkeyModifiers")
        defaults.set(999, forKey: "vEmojiHotkeyKeyCode")

        PHTVManager.loadEmojiHotkeySettingsFromDefaults()
        let snapshot = PHTVManager.runtimeSettingsSnapshot()

        XCTAssertEqual(snapshot["enableEmojiHotkey"]?.intValue, 1)
        XCTAssertEqual(
            snapshot["emojiHotkeyModifiers"]?.intValue,
            Int(NSEvent.ModifierFlags.command.rawValue)
        )
        XCTAssertEqual(snapshot["emojiHotkeyKeyCode"]?.intValue, Int(KeyCode.eKey))
        XCTAssertEqual(
            defaults.integer(forKey: "vEmojiHotkeyModifiers"),
            Int(NSEvent.ModifierFlags.command.rawValue)
        )
        XCTAssertEqual(defaults.integer(forKey: "vEmojiHotkeyKeyCode"), Int(KeyCode.eKey))
    }

    func testEmojiHotkeyPreservesKeyCodeZero() {
        let defaults = UserDefaults.standard
        let commandModifiers = Int(NSEvent.ModifierFlags.command.rawValue)
        defaults.set(true, forKey: "vEnableEmojiHotkey")
        defaults.set(commandModifiers, forKey: "vEmojiHotkeyModifiers")
        defaults.set(0, forKey: "vEmojiHotkeyKeyCode")

        PHTVManager.loadEmojiHotkeySettingsFromDefaults()
        let snapshot = PHTVManager.runtimeSettingsSnapshot()

        XCTAssertEqual(snapshot["emojiHotkeyKeyCode"]?.intValue, 0)
        XCTAssertEqual(defaults.integer(forKey: "vEmojiHotkeyKeyCode"), 0)
        XCTAssertTrue(
            PHTVHotkeyService.checkEmojiHotkey(
                enabled: 1,
                keycode: 0,
                flags: UInt64(CGEventFlags.maskCommand.rawValue),
                emojiModifiers: Int32(commandModifiers),
                emojiHotkeyKeyCode: 0
            )
        )
    }

    func testCarbonHotkeyRegistrationSupportsPrintableOptionCombos() {
        XCTAssertTrue(
            PHTVCarbonHotkeyRegistration.canRegisterWithCarbon(
                modifiers: [.option],
                keyCode: KeyCode.vKey
            )
        )
        XCTAssertFalse(
            PHTVCarbonHotkeyRegistration.canRegisterWithCarbon(
                modifiers: [.option, .function],
                keyCode: KeyCode.vKey
            )
        )
        XCTAssertFalse(
            PHTVCarbonHotkeyRegistration.canRegisterWithCarbon(
                modifiers: [.option],
                keyCode: KeyCode.noKey
            )
        )
    }

    func testModifierOnlySwitchReleasePassesThroughFlagsChangedEvent() {
        let modifierOnlySwitchHotkey = Int32(bitPattern: 0x000009FE)
        let emptyConvertHotkey = Int32(bitPattern: 0xFE0000FE)

        XCTAssertTrue(
            PHTVHotkeyService.shouldPassThroughModifierReleaseEvent(
                forReleaseAction: PHTVModifierReleaseAction.switchLanguage.rawValue,
                switchHotkey: modifierOnlySwitchHotkey,
                convertHotkey: emptyConvertHotkey,
                emojiEnabled: 0,
                emojiHotkeyKeyCode: Int32(KeyCode.eKey)
            )
        )
    }

    func testKeyedSwitchReleaseStillConsumesEvent() {
        let commandSpaceSwitchHotkey = Int32(bitPattern: 0x00000431)
        let emptyConvertHotkey = Int32(bitPattern: 0xFE0000FE)

        XCTAssertFalse(
            PHTVHotkeyService.shouldPassThroughModifierReleaseEvent(
                forReleaseAction: PHTVModifierReleaseAction.switchLanguage.rawValue,
                switchHotkey: commandSpaceSwitchHotkey,
                convertHotkey: emptyConvertHotkey,
                emojiEnabled: 0,
                emojiHotkeyKeyCode: Int32(KeyCode.eKey)
            )
        )
    }

    func testModifierOnlyEmojiReleasePassesThroughFlagsChangedEvent() {
        let emptyConvertHotkey = Int32(bitPattern: 0xFE0000FE)

        XCTAssertTrue(
            PHTVHotkeyService.shouldPassThroughModifierReleaseEvent(
                forReleaseAction: PHTVModifierReleaseAction.emojiPicker.rawValue,
                switchHotkey: Int32(bitPattern: 0x00000431),
                convertHotkey: emptyConvertHotkey,
                emojiEnabled: 1,
                emojiHotkeyKeyCode: Int32(bitPattern: 0x000000FE)
            )
        )
    }
}
