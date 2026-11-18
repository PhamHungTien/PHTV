//
//  PHTVHotkeyModifierOnlyNormalizer.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit

/// The shortcut recorder reports a modifier pressed and released on its own
/// (Fn, a single Command, Option...) as that modifier's physical key code with
/// no modifier flags. The PHTV Picker and Clipboard hotkeys store such
/// shortcuts as "modifier-only": `KeyCode.noKey` plus the modifier flag.
/// Without this conversion an Fn-only shortcut was saved as key code 63, which
/// never produces a keyDown, so the hotkey could never fire (issue #241).
enum PHTVHotkeyModifierOnlyNormalizer {
    struct Hotkey: Equatable {
        let keyCode: UInt16
        let modifiersRaw: UInt
    }

    /// Independent flag plus the device-side bit for each modifier key.
    private static func flags(forModifierKeyCode keyCode: UInt16) -> UInt? {
        let command = NSEvent.ModifierFlags.command.rawValue
        let option = NSEvent.ModifierFlags.option.rawValue
        let control = NSEvent.ModifierFlags.control.rawValue
        let shift = NSEvent.ModifierFlags.shift.rawValue
        let function = NSEvent.ModifierFlags.function.rawValue

        switch keyCode {
        case 55: return command | 0x0008  // Left Command
        case 54: return command | 0x0010  // Right Command
        case 58: return option | 0x0020   // Left Option
        case 61: return option | 0x0040   // Right Option
        case 59: return control | 0x0001  // Left Control
        case 62: return control | 0x2000  // Right Control
        case 56: return shift | 0x0002    // Left Shift
        case 60: return shift | 0x0004    // Right Shift
        case 63, 179: return function     // Fn / Globe
        default: return nil
        }
    }

    static func isModifierKeyCode(_ keyCode: UInt16) -> Bool {
        flags(forModifierKeyCode: keyCode) != nil
    }

    /// Converts a single-modifier key code into the modifier-only form and
    /// leaves every other shortcut untouched.
    static func normalized(keyCode: UInt16, modifiersRaw: UInt) -> Hotkey {
        guard let modifierFlags = flags(forModifierKeyCode: keyCode) else {
            return Hotkey(keyCode: keyCode, modifiersRaw: modifiersRaw)
        }
        return Hotkey(keyCode: KeyCode.noKey, modifiersRaw: modifiersRaw | modifierFlags)
    }

    /// Rewrites a hotkey saved by older versions in the single-modifier form.
    /// Returns true when the stored value changed.
    @discardableResult
    static func migrateStoredHotkey(
        defaults: UserDefaults,
        keyCodeKey: String,
        modifiersKey: String
    ) -> Bool {
        guard defaults.object(forKey: keyCodeKey) != nil else { return false }
        let storedKeyCode = defaults.integer(forKey: keyCodeKey)
        guard (0...Int(KeyCode.keyMask)).contains(storedKeyCode),
              isModifierKeyCode(UInt16(storedKeyCode)) else {
            return false
        }
        let storedModifiers = UInt(max(0, defaults.integer(forKey: modifiersKey)))
        let hotkey = normalized(keyCode: UInt16(storedKeyCode), modifiersRaw: storedModifiers)
        defaults.set(Int(hotkey.keyCode), forKey: keyCodeKey)
        defaults.set(Int(hotkey.modifiersRaw), forKey: modifiersKey)
        return true
    }

    static func normalized(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags
    ) -> (keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        let result = normalized(keyCode: keyCode, modifiersRaw: modifiers.rawValue)
        return (result.keyCode, NSEvent.ModifierFlags(rawValue: result.modifiersRaw))
    }
}
