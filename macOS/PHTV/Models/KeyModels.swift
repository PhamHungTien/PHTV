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
