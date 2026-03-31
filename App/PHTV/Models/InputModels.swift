//
//  InputModels.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation

// MARK: - Input Method

enum InputMethod: String, CaseIterable, Identifiable, Sendable {
    case telex = "Telex"
    case vni = "VNI"
    case simpleTelex1 = "Simple Telex 1"
    case simpleTelex2 = "Simple Telex 2"

    nonisolated var id: String { rawValue }

    nonisolated var displayName: String { rawValue }

    func toIndex() -> Int {
        switch self {
        case .telex: return 0
        case .vni: return 1
        case .simpleTelex1: return 2
        case .simpleTelex2: return 3
        }
    }

    static func from(index: Int) -> InputMethod {
        switch index {
        case 0: return .telex
        case 1: return .vni
        case 2: return .simpleTelex1
        case 3: return .simpleTelex2
        default: return .telex
        }
    }
}

// MARK: - Code Table

enum CodeTable: String, CaseIterable, Identifiable, Sendable {
    case unicode = "Unicode"
    case tcvn = "TCVN3"
    case vniWindows = "VNI Windows"
    case unicodeComposite = "Unicode Composite"
    case cp1258 = "Vietnamese Locale (CP1258)"

    nonisolated var id: String { rawValue }

    nonisolated var displayName: String { rawValue }

    func toIndex() -> Int {
        switch self {
        case .unicode: return 0
        case .tcvn: return 1
        case .vniWindows: return 2
        case .unicodeComposite: return 3
        case .cp1258: return 4
        }
    }

    static func from(index: Int) -> CodeTable {
        switch index {
        case 0: return .unicode
        case 1: return .tcvn
        case 2: return .vniWindows
        case 3: return .unicodeComposite
        case 4: return .cp1258
        default: return .unicode
        }
    }
}

// MARK: - Auto Restore Mode

enum AutoRestoreEnglishMode: Int, CaseIterable, Identifiable, Sendable {
    case nonVietnamese = 0
    case englishOnly = 1

    nonisolated var id: Int { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .nonVietnamese:
            return "Khôi phục nếu không phải là tiếng Việt"
        case .englishOnly:
            return "Khôi phục nếu là tiếng Anh"
        }
    }

    nonisolated var controlTitle: String {
        switch self {
        case .nonVietnamese:
            return "Không phải tiếng Việt"
        case .englishOnly:
            return "Tiếng Anh"
        }
    }

    nonisolated var descriptionText: String {
        switch self {
        case .nonVietnamese:
            return "Chỉ giữ nguyên dạng gõ thô khi từ sau biến đổi không phải tiếng Việt; từ Việt có trong từ điển sẽ không bị khôi phục."
        case .englishOnly:
            return "Chỉ khôi phục khi từ được nhận diện là tiếng Anh."
        }
    }

    nonisolated var reportLabel: String {
        switch self {
        case .nonVietnamese:
            return "Không phải tiếng Việt"
        case .englishOnly:
            return "Chỉ tiếng Anh"
        }
    }

    nonisolated var enablesWrongSpellingFallback: Bool {
        self == .nonVietnamese
    }

    static func from(index: Int) -> AutoRestoreEnglishMode {
        AutoRestoreEnglishMode(rawValue: index) ?? .englishOnly
    }

    static func from(persistedValue value: Any?) -> AutoRestoreEnglishMode? {
        if let mode = value as? AutoRestoreEnglishMode {
            return mode
        }
        if let intValue = value as? Int {
            return from(index: intValue)
        }
        if let numberValue = value as? NSNumber {
            return from(index: numberValue.intValue)
        }
        if let stringValue = value as? String, let rawValue = Int(stringValue) {
            return from(index: rawValue)
        }
        return nil
    }
}
