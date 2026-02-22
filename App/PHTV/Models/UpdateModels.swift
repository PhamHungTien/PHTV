//
//  UpdateModels.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation

// MARK: - Update Check Frequency

enum UpdateCheckFrequency: Int, CaseIterable, Identifiable, Sendable {
    case never = 0
    case daily = 86400        // 24 hours
    case weekly = 604800      // 7 days
    case monthly = 2592000    // 30 days

    nonisolated var id: Int { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .never: return "Không bao giờ"
        case .daily: return "Hàng ngày"
        case .weekly: return "Hàng tuần"
        case .monthly: return "Hàng tháng"
        }
    }

    static func from(interval: Int) -> UpdateCheckFrequency {
        switch interval {
        case 0: return .never
        case 86400: return .daily
        case 604800: return .weekly
        case 2592000: return .monthly
        default: return .daily
        }
    }
}

// MARK: - Update Banner Info

struct UpdateBannerInfo: Equatable {
    let version: String
    let releaseNotes: String
    let downloadURL: String
}
