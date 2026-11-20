//
//  PHTVEngineConstants.swift
//  PHTV
//
//  Bit masks, packed output and key maps shared by the engine and its
//  callers. Foundation only, so the engine stays free of AppKit.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation

enum EngineBitMask {
    static let caps: UInt32 = 0x0001_0000
    static let charCode: UInt32 = 0x0200_0000
    static let pureCharacter: UInt32 = 0x8000_0000
}

enum EnginePackedData {
    static let unicodeCompoundMarks: [UInt16] = [0x0301, 0x0300, 0x0309, 0x0303, 0x0323]

    static func lowByte(_ value: UInt32) -> UInt16 {
        UInt16(truncatingIfNeeded: value & 0x00FF)
    }

    static func highByte(_ value: UInt32) -> UInt16 {
        UInt16(truncatingIfNeeded: (value >> 8) & 0x00FF)
    }

    static func unicodeCompoundMark(at index: Int32) -> UInt16 {
        let safeIndex = Int(index)
        guard unicodeCompoundMarks.indices.contains(safeIndex) else {
            return 0
        }
        return unicodeCompoundMarks[safeIndex]
    }
}

enum EngineSignalCode {
    static let doNothing: Int32 = 0
    static let willProcess: Int32 = 1
    static let restore: Int32 = 3
    static let replaceMacro: Int32 = 4
    static let restoreAndStartNewSession: Int32 = 5
    static let maxBuffer: Int32 = 32
}

enum EngineMacroKeyMap {
    private static let keyMask: UInt16 = 0x00FF

    // US layout key codes to characters, without and with Shift.
    private static let unshifted: [UInt16: UInt16] = [
        0: 0x0061, 11: 0x0062, 8: 0x0063, 2: 0x0064, 14: 0x0065, 3: 0x0066, 5: 0x0067, 4: 0x0068,
        34: 0x0069, 38: 0x006A, 40: 0x006B, 37: 0x006C, 46: 0x006D, 45: 0x006E, 31: 0x006F, 35: 0x0070,
        12: 0x0071, 15: 0x0072, 1: 0x0073, 17: 0x0074, 32: 0x0075, 9: 0x0076, 13: 0x0077, 7: 0x0078,
        16: 0x0079, 6: 0x007A,
        18: 0x0031, 19: 0x0032, 20: 0x0033, 21: 0x0034, 23: 0x0035, 22: 0x0036, 26: 0x0037, 28: 0x0038,
        25: 0x0039, 29: 0x0030,
        50: 0x0060, 27: 0x002D, 24: 0x003D, 33: 0x005B, 30: 0x005D, 42: 0x005C, 41: 0x003B, 39: 0x0027,
        43: 0x002C, 47: 0x002E, 44: 0x002F,
        49: 0x0020
    ]

    private static let shifted: [UInt16: UInt16] = [
        0: 0x0041, 11: 0x0042, 8: 0x0043, 2: 0x0044, 14: 0x0045, 3: 0x0046, 5: 0x0047, 4: 0x0048,
        34: 0x0049, 38: 0x004A, 40: 0x004B, 37: 0x004C, 46: 0x004D, 45: 0x004E, 31: 0x004F, 35: 0x0050,
        12: 0x0051, 15: 0x0052, 1: 0x0053, 17: 0x0054, 32: 0x0055, 9: 0x0056, 13: 0x0057, 7: 0x0058,
        16: 0x0059, 6: 0x005A,
        18: 0x0021, 19: 0x0040, 20: 0x0023, 21: 0x0024, 23: 0x0025, 22: 0x005E, 26: 0x0026, 28: 0x002A,
        25: 0x0028, 29: 0x0029,
        50: 0x007E, 27: 0x005F, 24: 0x002B, 33: 0x007B, 30: 0x007D, 42: 0x007C, 41: 0x003A, 39: 0x0022,
        43: 0x003C, 47: 0x003E, 44: 0x003F
    ]

    static func character(for keyData: UInt32) -> UInt16 {
        let allowedMask = UInt32(keyMask) | EngineBitMask.caps
        guard (keyData & ~allowedMask) == 0 else {
            return 0
        }

        let keyCode = UInt16(truncatingIfNeeded: keyData & UInt32(keyMask))
        if (keyData & EngineBitMask.caps) != 0 {
            return shifted[keyCode] ?? 0
        }
        return unshifted[keyCode] ?? 0
    }
}
