//
//  ClipboardHistoryRetention.swift
//  PHTV
//
//  How long clipboard history items are kept before being auto-deleted.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation

/// Retention window for clipboard history. The raw value is the maximum age in
/// seconds; `0` means "keep forever" (the default — PHTV never deletes the
/// user's history unless they opt in).
enum ClipboardHistoryRetention: Int, CaseIterable, Identifiable, Sendable {
    case forever = 0
    case threeDays = 259_200        // 3 × 24h
    case oneWeek = 604_800          // 7 × 24h
    case oneMonth = 2_592_000       // 30 × 24h
    case threeMonths = 7_776_000    // 90 × 24h

    nonisolated var id: Int { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .forever: return "Không giới hạn"
        case .threeDays: return "3 ngày"
        case .oneWeek: return "1 tuần"
        case .oneMonth: return "1 tháng"
        case .threeMonths: return "3 tháng"
        }
    }

    /// Maximum age of a kept item; `nil` when history is kept forever.
    nonisolated var maxAge: TimeInterval? {
        rawValue > 0 ? TimeInterval(rawValue) : nil
    }

    /// Maps a persisted raw value onto a known case, falling back to the
    /// nearest window so a corrupted or legacy value never deletes more than
    /// the user asked for.
    static func from(rawValue: Int) -> ClipboardHistoryRetention {
        if rawValue <= 0 { return .forever }
        if let exact = ClipboardHistoryRetention(rawValue: rawValue) { return exact }

        let windows = allCases.filter { $0 != .forever }
        return windows.min { abs($0.rawValue - rawValue) < abs($1.rawValue - rawValue) } ?? .forever
    }
}
