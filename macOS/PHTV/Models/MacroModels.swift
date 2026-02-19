//
//  MacroModels.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

// MARK: - Macro Category

/// Danh mục gõ tắt
struct MacroCategory: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var icon: String  // SF Symbol name
    var color: String // Hex color

    init(id: UUID = UUID(), name: String, icon: String = "folder.fill", color: String = "#007AFF") {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
    }

    /// Danh mục mặc định "Chung"
    static let defaultCategory = MacroCategory(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
        name: "Chung",
        icon: "folder.fill",
        color: "#007AFF"
    )

    /// Chuyển hex string sang Color
    var swiftUIColor: Color {
        Color(hex: color) ?? .blue
    }
}

// MARK: - Snippet Type

enum SnippetType: String, Codable, CaseIterable {
    case `static` = "static"      // Fixed text (default)
    case date = "date"            // Current date
    case time = "time"            // Current time
    case datetime = "datetime"    // Date and time
    case clipboard = "clipboard"  // Clipboard content
    case random = "random"        // Random from list
    case counter = "counter"      // Auto-increment number

    var displayName: String {
        switch self {
        case .static: return "Văn bản tĩnh"
        case .date: return "Ngày hiện tại"
        case .time: return "Giờ hiện tại"
        case .datetime: return "Ngày và giờ"
        case .clipboard: return "Clipboard"
        case .random: return "Ngẫu nhiên"
        case .counter: return "Bộ đếm"
        }
    }

    var placeholder: String {
        switch self {
        case .static: return "Nội dung mở rộng..."
        case .date: return "dd/MM/yyyy"
        case .time: return "HH:mm:ss"
        case .datetime: return "dd/MM/yyyy HH:mm"
        case .clipboard: return "(Sẽ dán nội dung từ clipboard)"
        case .random: return "giá trị 1, giá trị 2, giá trị 3"
        case .counter: return "prefix"
        }
    }

    var helpText: String {
        switch self {
        case .static: return "Văn bản cố định sẽ được thay thế"
        case .date: return "Định dạng: d=ngày, M=tháng, y=năm. VD: dd/MM/yyyy"
        case .time: return "Định dạng: H=giờ, m=phút, s=giây. VD: HH:mm:ss"
        case .datetime: return "Kết hợp ngày và giờ. VD: dd/MM/yyyy HH:mm"
        case .clipboard: return "Dán nội dung hiện tại từ clipboard"
        case .random: return "Chọn ngẫu nhiên từ danh sách, phân cách bằng dấu phẩy"
        case .counter: return "Số tự động tăng. VD: prefix → prefix1, prefix2..."
        }
    }
}

// MARK: - Macro Item

struct MacroItem: Identifiable, Hashable, Codable {
    let id: UUID
    var shortcut: String
    var expansion: String
    var categoryId: UUID?  // nil = default category
    var snippetType: SnippetType = .static  // NEW: snippet type

    // MACRO INTELLIGENCE: Usage tracking for smart features
    var usageCount: Int = 0  // Number of times this macro was triggered
    var lastUsed: Date? = nil  // Last time this macro was used
    var createdDate: Date = Date()  // When this macro was created

    init(shortcut: String, expansion: String, categoryId: UUID? = nil, snippetType: SnippetType = .static) {
        self.id = UUID()
        self.shortcut = shortcut
        self.expansion = expansion
        self.categoryId = categoryId
        self.snippetType = snippetType
        self.usageCount = 0
        self.lastUsed = nil
        self.createdDate = Date()
    }

    // Backward compatible decoder
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        shortcut = try container.decode(String.self, forKey: .shortcut)
        expansion = try container.decode(String.self, forKey: .expansion)
        categoryId = try container.decodeIfPresent(UUID.self, forKey: .categoryId)
        snippetType = try container.decodeIfPresent(SnippetType.self, forKey: .snippetType) ?? .static

        // MACRO INTELLIGENCE: Backward compatible - default to 0/nil/now for old macros
        usageCount = try container.decodeIfPresent(Int.self, forKey: .usageCount) ?? 0
        lastUsed = try container.decodeIfPresent(Date.self, forKey: .lastUsed)
        createdDate = try container.decodeIfPresent(Date.self, forKey: .createdDate) ?? Date()
    }

    private enum CodingKeys: String, CodingKey {
        case id, shortcut, expansion, categoryId, snippetType
        case usageCount, lastUsed, createdDate  // MACRO INTELLIGENCE fields
    }
}

// MARK: - Macro Storage

enum MacroStorage {
    static func load(defaults: UserDefaults = .standard) -> [MacroItem] {
        guard let data = defaults.data(forKey: UserDefaultsKey.macroList) else {
            return []
        }
        return decode(data) ?? []
    }

    static func decode(_ data: Data) -> [MacroItem]? {
        do {
            return try JSONDecoder().decode([MacroItem].self, from: data)
        } catch {
            PHTVLogger.shared.error("[MacroStorage] Failed to decode macro list: \(error.localizedDescription)")
            return nil
        }
    }

    static func save(_ macros: [MacroItem], defaults: UserDefaults = .standard) -> Data? {
        do {
            let encoded = try JSONEncoder().encode(macros)
            defaults.set(encoded, forKey: UserDefaultsKey.macroList)
            return encoded
        } catch {
            PHTVLogger.shared.error("[MacroStorage] Failed to encode macro list: \(error.localizedDescription)")
            return nil
        }
    }

    static func postUpdated(macroId: UUID? = nil, action: String? = nil) {
        if let macroId, let action {
            NotificationCenter.default.post(
                name: NotificationName.macrosUpdated,
                object: nil,
                userInfo: ["macroId": macroId, "action": action]
            )
            return
        }
        NotificationCenter.default.post(name: NotificationName.macrosUpdated, object: nil)
    }
}

// MARK: - Macro Intelligence Extension

extension MacroItem {
    /// MACRO INTELLIGENCE: Find conflicts with other macros
    /// Returns array of conflicting macro IDs and conflict type
    func findConflicts(in macros: [MacroItem]) -> [(MacroItem, ConflictType)] {
        var conflicts: [(MacroItem, ConflictType)] = []

        for macro in macros {
            // Skip self
            if macro.id == self.id { continue }

            let thisShortcut = self.shortcut.lowercased()
            let otherShortcut = macro.shortcut.lowercased()

            // Exact duplicate
            if thisShortcut == otherShortcut {
                conflicts.append((macro, .exactDuplicate))
            }
            // This is prefix of other (e.g., "btw" is prefix of "btwn")
            else if otherShortcut.hasPrefix(thisShortcut) {
                conflicts.append((macro, .thisIsPrefix))
            }
            // Other is prefix of this (e.g., "btw" when checking "btwn")
            else if thisShortcut.hasPrefix(otherShortcut) {
                conflicts.append((macro, .otherIsPrefix))
            }
        }

        return conflicts
    }

    /// Check if this macro is rarely used (not used in last 30 days)
    var isRarelyUsed: Bool {
        guard let lastUsed = lastUsed else {
            // Never used - check if created more than 30 days ago
            return createdDate.timeIntervalSinceNow < -30 * 24 * 3600
        }
        return lastUsed.timeIntervalSinceNow < -30 * 24 * 3600
    }

    /// Check if this is a popular macro (used 10+ times)
    var isPopular: Bool {
        return usageCount >= 10
    }
}

// MARK: - Conflict Type

enum ConflictType: String {
    case exactDuplicate = "Exact duplicate"
    case thisIsPrefix = "This shortcut is prefix of another"
    case otherIsPrefix = "Another shortcut is prefix of this"

    var icon: String {
        switch self {
        case .exactDuplicate: return "exclamationmark.triangle.fill"
        case .thisIsPrefix: return "exclamationmark.circle.fill"
        case .otherIsPrefix: return "info.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .exactDuplicate: return "red"
        case .thisIsPrefix: return "orange"
        case .otherIsPrefix: return "yellow"
        }
    }
}
