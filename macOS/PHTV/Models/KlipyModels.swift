//
//  KlipyModels.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation

// MARK: - Klipy API Response Models

struct KlipyResponse: Codable {
    let result: Bool
    let data: KlipyData
}

struct KlipyData: Codable {
    let data: [KlipyGIF]
    let current_page: Int
    let per_page: Int
    let has_next: Bool
}

struct KlipyGIF: Codable, Identifiable {
    let id: Int64
    let slug: String
    let title: String
    let file: KlipyFile
    let tags: [String]?  // Optional - API có thể trả về null
    let type: String

    // Ad-specific fields (optional, only present when type == "ad")
    let impression_url: String?
    let click_url: String?
    let target_url: String?
    let advertiser: String?

    var isAd: Bool {
        type == "ad"
    }

    var previewURL: String {
        // Use small size for preview, fallback to any available size
        file.sm?.gif?.url ?? file.xs?.gif?.url ?? file.hd?.gif?.url ?? ""
    }

    var fullURL: String {
        // Use HD GIF for full quality, fallback to smaller sizes
        file.hd?.gif?.url ?? file.sm?.gif?.url ?? file.xs?.gif?.url ?? ""
    }

    // Safe check for empty URLs
    var hasValidURL: Bool {
        !previewURL.isEmpty && !fullURL.isEmpty
    }
}

struct KlipyFile: Codable {
    let hd: KlipyFileSize?  // Optional - API có thể không trả về hd
    let sm: KlipyFileSize?
    let xs: KlipyFileSize?
}

struct KlipyFileSize: Codable {
    let gif: KlipyMedia?
    let webp: KlipyMedia?
    let mp4: KlipyMedia?
}

struct KlipyMedia: Codable {
    let url: String
    let width: Int?
    let height: Int?
    let size: Int?
}
