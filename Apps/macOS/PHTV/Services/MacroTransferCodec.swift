import Foundation

struct MacroTransferArchive: Codable {
    var version: String? = "1.0"
    var categories: [MacroCategory]?
    var macros: [MacroItem]
}

enum MacroTransferCodec {
    /// Limits the engine binary format can hold, unique IDs, and categories
    /// that exist.
    static func validate(_ macros: [MacroItem], categories: [MacroCategory]?) throws {
        guard macros.count <= 65535, Set(macros.map(\.id)).count == macros.count,
              macros.allSatisfy({ !$0.shortcut.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  && $0.shortcut.utf8.count <= 255 && $0.expansion.utf8.count <= 65535 && $0.usageCount >= 0 })
        else { throw BackupError.invalid("gõ tắt trống, trùng ID hoặc vượt giới hạn engine") }
        if let categories {
            guard Set(categories.map(\.id)).count == categories.count else { throw BackupError.invalid("trùng danh mục") }
            let ids = Set(categories.map(\.id)).union([MacroCategory.defaultCategory.id])
            guard macros.allSatisfy({ $0.categoryId == nil || ids.contains($0.categoryId!) })
            else { throw BackupError.invalid("danh mục gõ tắt không tồn tại") }
        }
    }

    static func encode(macros: [MacroItem], categories: [MacroCategory]) throws -> Data {
        try validate(macros, categories: categories)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(MacroTransferArchive(categories: categories, macros: macros))
        guard data.count <= 64 * 1024 * 1024 else { throw BackupError.invalid("file gõ tắt vượt 64 MB") }
        return data
    }

    static func decode(_ data: Data, json: Bool) throws -> MacroTransferArchive {
        guard data.count <= 64 * 1024 * 1024 else { throw BackupError.invalid("file gõ tắt vượt 64 MB") }
        let archive: MacroTransferArchive
        if json {
            // Some editors prepend a UTF-8 BOM, including to legacy arrays.
            let jsonData = data.starts(with: [0xEF, 0xBB, 0xBF]) ? Data(data.dropFirst(3)) : data
            if let first = jsonData.first(where: { ![9, 10, 13, 32].contains($0) }), first == 91 {
                archive = MacroTransferArchive(categories: nil, macros: try JSONDecoder().decode([MacroItem].self, from: jsonData))
            } else {
                archive = try JSONDecoder().decode(MacroTransferArchive.self, from: jsonData)
            }
            guard archive.version == nil || archive.version == "1.0" else { throw BackupError.invalid("phiên bản gõ tắt") }
        } else {
            guard let text = String(data: data, encoding: .utf8) else { throw BackupError.invalid("file gõ tắt không phải UTF-8") }
            archive = MacroTransferArchive(categories: nil, macros: try csv(text))
        }
        try validate(archive.macros, categories: archive.categories)
        return archive
    }

    static func merged(_ archive: MacroTransferArchive, macros: [MacroItem], categories: [MacroCategory]) throws -> MacroTransferArchive {
        try validate(macros, categories: categories)
        try validate(archive.macros, categories: archive.categories)
        var groups = categories
        var groupIndices = Dictionary(uniqueKeysWithValues: groups.enumerated().map { ($0.element.id, $0.offset) })
        for group in archive.categories ?? [] {
            if let index = groupIndices[group.id] { groups[index] = group }
            else { groupIndices[group.id] = groups.count; groups.append(group) }
        }
        func key(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines).precomposedStringWithCanonicalMapping.lowercased() }
        var byID: [UUID: MacroItem] = [:]
        var byShortcut: [String: UUID] = [:]
        for item in macros + archive.macros {
            if let previous = byID[item.id] { byShortcut.removeValue(forKey: key(previous.shortcut)) }
            let shortcut = key(item.shortcut)
            if let previousID = byShortcut[shortcut] { byID.removeValue(forKey: previousID) }
            byID[item.id] = item
            byShortcut[shortcut] = item.id
        }
        let merged = byID.values.sorted { $0.shortcut.localizedCompare($1.shortcut) == .orderedAscending }
        try validate(merged, categories: groups)
        return MacroTransferArchive(categories: groups, macros: merged)
    }

    /// Quoted CSV supports commas, escaped quotes and multiline content. Legacy
    /// unquoted text after the first comma remains one expansion, without trimming.
    private static func csv(_ text: String) throws -> [MacroItem] {
        let characters = Array(text.replacingOccurrences(of: "\r\n", with: "\n"))
        var result: [MacroItem] = []
        var fields: [String] = []
        var field = ""
        var quoted = false
        var closedQuote = false
        var index = characters.first == "\u{feff}" ? 1 : 0
        func finishRow() throws {
            fields.append(field)
            defer { fields = []; field = ""; closedQuote = false }
            if fields.count == 1, fields[0].trimmingCharacters(in: .whitespaces).isEmpty { return }
            if fields.first?.hasPrefix("#") == true { return }
            guard fields.count >= 2 else { throw BackupError.invalid("dòng CSV thiếu dấu phẩy") }
            let shortcut = fields[0].trimmingCharacters(in: .whitespaces).precomposedStringWithCanonicalMapping
            let expansion = fields.dropFirst().joined(separator: ",")
            guard !shortcut.isEmpty, !expansion.isEmpty else { throw BackupError.invalid("dòng CSV có nội dung trống") }
            result.append(MacroItem(shortcut: shortcut, expansion: expansion))
        }
        while index < characters.count {
            let c = characters[index]
            if quoted {
                if c == "\"" {
                    if index + 1 < characters.count, characters[index + 1] == "\"" { field.append(c); index += 1 }
                    else { quoted = false; closedQuote = true }
                } else { field.append(c) }
            } else if c == "," {
                fields.append(field); field = ""; closedQuote = false
            } else if c == "\n" || c == "\r" {
                try finishRow()
            } else if c == "\"", field.isEmpty, !closedQuote {
                quoted = true
            } else {
                guard !closedQuote else { throw BackupError.invalid("ký tự sau dấu nháy CSV") }
                field.append(c)
            }
            index += 1
        }
        guard !quoted else { throw BackupError.invalid("dấu nháy CSV chưa đóng") }
        if !fields.isEmpty || !field.isEmpty || closedQuote { try finishRow() }
        return result
    }
}
