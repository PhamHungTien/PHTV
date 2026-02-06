//
//  EmojiModels.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation

// MARK: - Emoji Item Model

struct EmojiItem: Identifiable, Codable, Equatable {
    let id = UUID()
    let emoji: String
    let name: String // English name
    let keywords: [String] // English + Vietnamese keywords
    let category: String

    enum CodingKeys: String, CodingKey {
        case emoji, name, keywords, category
    }
}
