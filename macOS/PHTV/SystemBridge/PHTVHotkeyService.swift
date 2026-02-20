//
//  PHTVHotkeyService.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation
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
}
