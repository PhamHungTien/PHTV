//
//  HotkeyModifierOnlyNormalizerTests.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit
import XCTest
@testable import PHTV

final class HotkeyModifierOnlyNormalizerTests: XCTestCase {
    func testFnAloneBecomesModifierOnly() {
        let hotkey = PHTVHotkeyModifierOnlyNormalizer.normalized(keyCode: 63, modifiersRaw: 0)
        XCTAssertEqual(hotkey.keyCode, KeyCode.noKey)
        XCTAssertEqual(hotkey.modifiersRaw, NSEvent.ModifierFlags.function.rawValue)
    }

    func testSingleSidedModifiersKeepTheirSide() {
        let rightCommand = PHTVHotkeyModifierOnlyNormalizer.normalized(keyCode: 54, modifiersRaw: 0x0010)
        XCTAssertEqual(rightCommand.keyCode, KeyCode.noKey)
        XCTAssertEqual(rightCommand.modifiersRaw, NSEvent.ModifierFlags.command.rawValue | 0x0010)

        let leftOption = PHTVHotkeyModifierOnlyNormalizer.normalized(keyCode: 58, modifiersRaw: 0)
        XCTAssertEqual(leftOption.modifiersRaw, NSEvent.ModifierFlags.option.rawValue | 0x0020)
    }

    func testRegularShortcutsAreUntouched() {
        let raw = NSEvent.ModifierFlags.command.rawValue
        let hotkey = PHTVHotkeyModifierOnlyNormalizer.normalized(keyCode: KeyCode.eKey, modifiersRaw: raw)
        XCTAssertEqual(hotkey, .init(keyCode: KeyCode.eKey, modifiersRaw: raw))

        let modifierOnly = PHTVHotkeyModifierOnlyNormalizer.normalized(
            keyCode: KeyCode.noKey, modifiersRaw: NSEvent.ModifierFlags.function.rawValue)
        XCTAssertEqual(modifierOnly.keyCode, KeyCode.noKey)
    }

    func testStoredFnHotkeyFromOlderVersionIsMigrated() throws {
        let suiteName = "PHTVHotkeyNormalizerTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(63, forKey: "key")
        defaults.set(0, forKey: "mods")
        XCTAssertTrue(PHTVHotkeyModifierOnlyNormalizer.migrateStoredHotkey(
            defaults: defaults, keyCodeKey: "key", modifiersKey: "mods"))
        XCTAssertEqual(defaults.integer(forKey: "key"), Int(KeyCode.noKey))
        XCTAssertEqual(defaults.integer(forKey: "mods"), Int(NSEvent.ModifierFlags.function.rawValue))

        XCTAssertFalse(PHTVHotkeyModifierOnlyNormalizer.migrateStoredHotkey(
            defaults: defaults, keyCodeKey: "key", modifiersKey: "mods"))
    }
}
