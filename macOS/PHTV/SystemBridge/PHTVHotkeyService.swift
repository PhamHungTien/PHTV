//
//  PHTVHotkeyService.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation
import AppKit
import Carbon

@objcMembers
final class PHTVHotkeyService: NSObject {
    private static let hotkeyKeyMask: UInt32 = 0x00FF
    private static let hotkeyControlMask: UInt32 = 0x0100
    private static let hotkeyOptionMask: UInt32 = 0x0200
    private static let hotkeyCommandMask: UInt32 = 0x0400
    private static let hotkeyShiftMask: UInt32 = 0x0800
    private static let hotkeyFnMask: UInt32 = 0x1000
    private static let hotkeyBeepMask: UInt32 = 0x8000
    private static let hotkeyNoKey: UInt32 = 0x00FE
    private static let emptyHotkey: UInt32 = 0xFE0000FE

    private static let controlFlagMask = CGEventFlags.maskControl.rawValue
    private static let optionFlagMask = CGEventFlags.maskAlternate.rawValue
    private static let commandFlagMask = CGEventFlags.maskCommand.rawValue
    private static let shiftFlagMask = CGEventFlags.maskShift.rawValue
    private static let fnFlagMask = CGEventFlags.maskSecondaryFn.rawValue
    private static let layoutCacheNoValue: UInt16 = .max

    // Reverse mapping from layout character -> US keycode
    private static let layoutKeyStringToKeyCodeMap: [String: UInt16] = [
        // Number row
        "`": 50, "~": 50, "1": 18, "!": 18, "2": 19, "@": 19, "3": 20, "#": 20, "4": 21, "$": 21,
        "5": 23, "%": 23, "6": 22, "^": 22, "7": 26, "&": 26, "8": 28, "*": 28, "9": 25, "(": 25,
        "0": 29, ")": 29, "-": 27, "_": 27, "=": 24, "+": 24,
        // First row (QWERTY)
        "q": 12, "w": 13, "e": 14, "r": 15, "t": 17, "y": 16, "u": 32, "i": 34, "o": 31, "p": 35,
        "[": 33, "{": 33, "]": 30, "}": 30, "\\": 42, "|": 42,
        // Second row (home row)
        "a": 0, "s": 1, "d": 2, "f": 3, "g": 5, "h": 4, "j": 38, "k": 40, "l": 37,
        ";": 41, ":": 41, "'": 39, "\"": 39,
        // Third row
        "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "n": 45, "m": 46,
        ",": 43, "<": 43, ".": 47, ">": 47, "/": 44, "?": 44,

        // International layout characters
        "ß": 27, "ü": 33, "ö": 41, "ä": 39, "é": 19, "è": 26, "ù": 39, "²": 50,
        "«": 30, "»": 42, "µ": 42, "ñ": 41, "¡": 24, "¿": 27, "¬": 50, "ò": 41,
        "ì": 24, "ç": 41, "º": 50, "ª": 50, "å": 33, "æ": 39, "ø": 41, "§": 50,
        "½": 50, "¤": 21, "ą": 0, "ć": 8, "ę": 14, "ł": 37, "ń": 45, "ó": 31, "ś": 1,
        "ź": 7, "ż": 6, "ě": 19, "š": 20, "č": 21, "ř": 23, "ž": 22, "ý": 26, "á": 28,
        "í": 25, "ú": 41, "ů": 33, "ď": 30, "ť": 39, "ň": 42, "ő": 27, "ű": 42,
        "ğ": 33, "ş": 41, "ı": 34, "´": 24, "¨": 33, "à": 29, "€": 14, "£": 20,
        "¥": 16, "¢": 8, "©": 8, "®": 15, "™": 17, "°": 28, "±": 24, "×": 7,
        "÷": 44, "≠": 24, "≤": 43, "≥": 47, "∞": 23, "…": 41, "–": 27, "—": 27,
        "‘": 39, "’": 39, "“": 39, "”": 39
    ]

    private static let azertyShiftedToNumber: [String: UInt16] = [
        "&": 18,
        "é": 19,
        "\"": 20,
        "'": 21,
        "(": 23,
        "-": 22,
        "è": 26,
        "_": 28,
        "ç": 25,
        "à": 29
    ]

    private class func hasMask(_ data: UInt32, mask: UInt32) -> Bool {
        (data & mask) != 0
    }

    private class func flagSet(_ flags: UInt64, mask: UInt64) -> Bool {
        (flags & mask) != 0
    }

    private class func isEmptyHotkey(_ data: UInt32) -> Bool {
        (data & ~hotkeyBeepMask) == emptyHotkey
    }

    private class func hasHotkeyKey(_ data: UInt32) -> Bool {
        (data & hotkeyKeyMask) != hotkeyNoKey
    }

    private class func keyMatches(_ data: UInt32, currentKeycode: UInt16) -> Bool {
        (data & hotkeyKeyMask) == UInt32(currentKeycode & UInt16(hotkeyKeyMask))
    }

    private class func matchesFlags(_ data: UInt32, currentFlags: UInt64) -> Bool {
        if hasMask(data, mask: hotkeyControlMask) != flagSet(currentFlags, mask: controlFlagMask) {
            return false
        }
        if hasMask(data, mask: hotkeyOptionMask) != flagSet(currentFlags, mask: optionFlagMask) {
            return false
        }
        if hasMask(data, mask: hotkeyCommandMask) != flagSet(currentFlags, mask: commandFlagMask) {
            return false
        }
        if hasMask(data, mask: hotkeyShiftMask) != flagSet(currentFlags, mask: shiftFlagMask) {
            return false
        }
        if hasMask(data, mask: hotkeyFnMask) != flagSet(currentFlags, mask: fnFlagMask) {
            return false
        }
        return true
    }

    private class func modifiersHeld(_ data: UInt32, currentFlags: UInt64) -> Bool {
        if hasMask(data, mask: hotkeyControlMask) && !flagSet(currentFlags, mask: controlFlagMask) {
            return false
        }
        if hasMask(data, mask: hotkeyOptionMask) && !flagSet(currentFlags, mask: optionFlagMask) {
            return false
        }
        if hasMask(data, mask: hotkeyCommandMask) && !flagSet(currentFlags, mask: commandFlagMask) {
            return false
        }
        if hasMask(data, mask: hotkeyShiftMask) && !flagSet(currentFlags, mask: shiftFlagMask) {
            return false
        }
        if hasMask(data, mask: hotkeyFnMask) && !flagSet(currentFlags, mask: fnFlagMask) {
            return false
        }
        return true
    }

    @objc(checkHotKey:checkKeyCode:currentKeycode:currentFlags:)
    class func checkHotKey(
        _ hotKeyData: Int32,
        checkKeyCode: Bool,
        currentKeycode: UInt16,
        currentFlags: UInt64
    ) -> Bool {
        let data = UInt32(bitPattern: hotKeyData)
        if isEmptyHotkey(data) {
            return false
        }
        if !matchesFlags(data, currentFlags: currentFlags) {
            return false
        }
        if checkKeyCode && !keyMatches(data, currentKeycode: currentKeycode) {
            return false
        }
        return true
    }

    @objc(hotkeyModifiersAreHeld:currentFlags:)
    class func hotkeyModifiersAreHeld(_ hotKeyData: Int32, currentFlags: UInt64) -> Bool {
        let data = UInt32(bitPattern: hotKeyData)
        if isEmptyHotkey(data) {
            return false
        }
        return modifiersHeld(data, currentFlags: currentFlags)
    }

    @objc(isModifierOnlyHotkey:)
    class func isModifierOnlyHotkey(_ hotKeyData: Int32) -> Bool {
        let data = UInt32(bitPattern: hotKeyData)
        return !hasHotkeyKey(data)
    }

    @objc(convertKeyStringToKeyCode:fallback:)
    class func convertKeyStringToKeyCode(_ keyString: String?, fallback: UInt16) -> Int32 {
        guard let keyString, !keyString.isEmpty else {
            return Int32(fallback)
        }

        if let keycode = layoutKeyStringToKeyCodeMap[keyString] {
            return Int32(keycode)
        }

        let lower = keyString.lowercased()
        if lower != keyString, let keycode = layoutKeyStringToKeyCodeMap[lower] {
            return Int32(keycode)
        }

        return Int32(fallback)
    }

    @objc class func invalidateLayoutCache() {
        PHTVCacheStateService.invalidateLayoutCache()
    }

    @objc(convertEventToKeyboardLayoutCompatKeyCode:fallback:)
    class func convertEventToKeyboardLayoutCompatKeyCode(_ event: CGEvent?, fallback: UInt16) -> UInt16 {
        guard let event else {
            return fallback
        }

        let rawKeyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        if rawKeyCode < 256 {
            let cached = PHTVCacheStateService.cachedLayoutConversion(rawKeyCode)
            if cached != layoutCacheNoValue {
                return cached
            }
        }

        guard let layoutEvent = NSEvent(cgEvent: event) else {
            return fallback
        }

        var result = fallback
        let baseCharacters = layoutEvent.charactersIgnoringModifiers ?? ""
        let convertedBase = UInt16(
            truncatingIfNeeded: convertKeyStringToKeyCode(baseCharacters, fallback: layoutCacheNoValue)
        )
        if convertedBase != layoutCacheNoValue {
            result = convertedBase
        } else {
            let actualCharacters = layoutEvent.characters
            if let actualCharacters,
               actualCharacters != baseCharacters {
                let convertedActual = UInt16(
                    truncatingIfNeeded: convertKeyStringToKeyCode(actualCharacters, fallback: layoutCacheNoValue)
                )
                if convertedActual != layoutCacheNoValue {
                    result = convertedActual
                }
            }
        }

        if result == fallback,
           baseCharacters.count == 1,
           let azertyKeycode = azertyShiftedToNumber[baseCharacters] {
            result = azertyKeycode
        }

        if rawKeyCode < 256 {
            PHTVCacheStateService.setCachedLayoutConversion(rawKeyCode, result: result)
        }

        return result
    }
}
