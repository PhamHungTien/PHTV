import Foundation

/// Additional initial consonants; standard Vietnamese initials remain available.
enum PHTVCustomConsonants {
    static let defaults = ["Z", "F", "W", "J", "DZ"]
    static let maximumCount = 64
    static let standardRows = vnConsonantTable.filter { !$0.contains { $0 & CONSONANT_ALLOW_MASK != 0 } }

    static func spellingRows(_ values: [String]) -> [[UInt16]] {
        (standardRows + rows(values)).sorted { $0.count > $1.count }
    }
    static let keyCodes: [Character: UInt16] = [
        "B": KEY_B, "C": KEY_C, "D": KEY_D, "F": KEY_F, "G": KEY_G,
        "H": KEY_H, "J": KEY_J, "K": KEY_K, "L": KEY_L, "M": KEY_M,
        "N": KEY_N, "P": KEY_P, "Q": KEY_Q, "R": KEY_R, "S": KEY_S,
        "T": KEY_T, "V": KEY_V, "W": KEY_W, "X": KEY_X, "Z": KEY_Z
    ]

    static func normalizedEntry(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.unicodeScalars.allSatisfy({ (65...90).contains($0.value) || (97...122).contains($0.value) }) else { return nil }
        let value = trimmed.uppercased()
        guard (1...2).contains(value.count), value.allSatisfy({ keyCodes[$0] != nil }) else { return nil }
        return value
    }

    static func normalized(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap(normalizedEntry).filter { seen.insert($0).inserted }.prefix(maximumCount).map { $0 }
    }

    static func rows(_ values: [String]) -> [[UInt16]] {
        normalized(values).map { $0.compactMap { keyCodes[$0] } }.sorted { $0.count > $1.count }
    }

    static func matchesPrefix(_ keys: [UInt16], rows: [[UInt16]]) -> Bool {
        rows.contains { row in keys.count >= row.count && keys.starts(with: row) }
    }
}
