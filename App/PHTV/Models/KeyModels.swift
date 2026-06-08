//
//  KeyModels.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation

// MARK: - Restore Key

enum RestoreKey: Int, CaseIterable, Identifiable, Sendable {
    case esc = 53
    case option = 58         // Left Option (represents both L/R)
    case control = 59        // Left Control (represents both L/R)

    nonisolated var id: Int { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .esc: return "ESC"
        case .option: return "Option"
        case .control: return "Control"
        }
    }

    nonisolated var symbol: String {
        switch self {
        case .esc: return "esc"
        case .option: return "⌥"
        case .control: return "⌃"
        }
    }

    // Get all possible key codes for this restore key (for modifiers, includes both left and right)
    nonisolated var keyCodes: [Int] {
        switch self {
        case .esc: return [Int(KeyCode.escape)]
        case .option: return [Int(KeyCode.leftOption), Int(KeyCode.rightOption)]
        case .control: return [Int(KeyCode.leftControl), Int(KeyCode.rightControl)]
        }
    }

    static func from(keyCode: Int) -> RestoreKey {
        // SAFETY: Only allow valid restore keys to prevent conflicts with typing
        // Any invalid value defaults to ESC for safety
        switch keyCode {
        case Int(KeyCode.escape): return .esc
        case Int(KeyCode.leftOption), Int(KeyCode.rightOption): return .option
        case Int(KeyCode.leftControl), Int(KeyCode.rightControl): return .control
        default:
            // Invalid key code - log warning and default to ESC
            PHTVLogger.shared.warning("[KeyModels] Invalid restore key code: \(keyCode), defaulting to ESC")
            return .esc
        }
    }
}

// MARK: - Single Modifier Key

enum SingleModifierKey: Int, CaseIterable, Identifiable, Sendable {
    case leftControl = 0
    case rightControl = 1
    case leftOption = 2
    case rightOption = 3
    case leftShift = 4
    case rightShift = 5
    case leftCommand = 6
    case rightCommand = 7
    case fn = 8

    nonisolated var id: Int { rawValue }

    nonisolated var keyCode: UInt16 {
        switch self {
        case .leftControl: return 59
        case .rightControl: return 62
        case .leftOption: return 58
        case .rightOption: return 61
        case .leftShift: return 56
        case .rightShift: return 60
        case .leftCommand: return 55
        case .rightCommand: return 54
        case .fn: return 63
        }
    }

    nonisolated var displayName: String {
        switch self {
        case .leftControl: return "Control Trái"
        case .rightControl: return "Control Phải"
        case .leftOption: return "Option Trái"
        case .rightOption: return "Option Phải"
        case .leftShift: return "Shift Trái"
        case .rightShift: return "Shift Phải"
        case .leftCommand: return "Command Trái"
        case .rightCommand: return "Command Phải"
        case .fn: return "Fn"
        }
    }

    nonisolated var symbol: String {
        switch self {
        case .leftControl, .rightControl: return "⌃"
        case .leftOption, .rightOption: return "⌥"
        case .leftShift, .rightShift: return "⇧"
        case .leftCommand, .rightCommand: return "⌘"
        case .fn: return "fn"
        }
    }
}

