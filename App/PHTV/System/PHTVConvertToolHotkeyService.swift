//
//  PHTVConvertToolHotkeyService.swift
//  PHTV
//
//  Runtime quick-convert hotkey resolver from UserDefaults.
//

import Foundation

@objcMembers
final class PHTVConvertToolHotkeyService: NSObject {
    private static let keyHotKey = "convertToolHotKey"
    private static let defaultHotkey = Int32(bitPattern: 0xFE0000FE) // EMPTY_HOTKEY

    private static let hotkeyKeyMask: UInt32 = 0x00FF
    private static let hotkeyControlMask: UInt32 = 0x0100
    private static let hotkeyOptionMask: UInt32 = 0x0200
    private static let hotkeyCommandMask: UInt32 = 0x0400
    private static let hotkeyShiftMask: UInt32 = 0x0800
    private static let hotkeyNoKey: UInt32 = 0x00FE

    @objc(currentHotkey)
    class func currentHotkey() -> Int32 {
        let defaultsHotkey = Int32(UserDefaults.standard.integer(forKey: keyHotKey))
        if defaultsHotkey != 0 {
            return defaultsHotkey
        }
        return defaultHotkey
    }

    class func hasControl(_ hotkey: Int32) -> Bool {
        (UInt32(bitPattern: hotkey) & hotkeyControlMask) != 0
    }

    class func hasOption(_ hotkey: Int32) -> Bool {
        (UInt32(bitPattern: hotkey) & hotkeyOptionMask) != 0
    }

    class func hasCommand(_ hotkey: Int32) -> Bool {
        (UInt32(bitPattern: hotkey) & hotkeyCommandMask) != 0
    }

    class func hasShift(_ hotkey: Int32) -> Bool {
        (UInt32(bitPattern: hotkey) & hotkeyShiftMask) != 0
    }

    class func hasKey(_ hotkey: Int32) -> Bool {
        (UInt32(bitPattern: hotkey) & hotkeyKeyMask) != hotkeyNoKey
    }

    class func switchKey(_ hotkey: Int32) -> UInt16 {
        UInt16(UInt32(bitPattern: hotkey) & hotkeyKeyMask)
    }
}
