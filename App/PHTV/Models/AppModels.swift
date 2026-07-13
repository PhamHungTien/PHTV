//
//  AppModels.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation

protocol AppSelectionEntry: Identifiable, Hashable {
    init(bundleIdentifier: String, name: String, path: String)
    init?(from url: URL)
    var bundleIdentifier: String { get }
    var name: String { get }
    var path: String { get }
}

// MARK: - Auto-capitalize exclusion scope

/// Which typing language an "excluded from auto-capitalize" app applies to.
/// `both` reproduces the original behaviour and is what every pre-existing
/// entry decodes to, so upgrading never changes what a user already set up.
enum UpperCaseExcludeScope: Int, Codable, CaseIterable, Identifiable, Sendable {
    case both = 0
    case englishOnly = 1
    case vietnameseOnly = 2

    nonisolated var id: Int { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .both: return "Cả hai"
        case .englishOnly: return "Chỉ khi gõ tiếng Anh"
        case .vietnameseOnly: return "Chỉ khi gõ tiếng Việt"
        }
    }
}

/// Runtime encoding of the auto-capitalize exclusion for the frontmost app,
/// shared by the Vietnamese engine and the English-mode event callback.
enum PHTVUpperCaseExclusion {
    static let none: Int32 = 0
    static let both: Int32 = 1
    static let englishOnly: Int32 = 2
    static let vietnameseOnly: Int32 = 3

    /// `nil` scope means the app is not in the exclusion list at all.
    static func runtimeValue(for scope: UpperCaseExcludeScope?) -> Int32 {
        guard let scope else { return none }
        switch scope {
        case .both: return both
        case .englishOnly: return englishOnly
        case .vietnameseOnly: return vietnameseOnly
        }
    }

    /// Whether auto-capitalize is suppressed for the language currently typed.
    static func isExcluded(runtimeValue: Int32, typingVietnamese: Bool) -> Bool {
        switch runtimeValue {
        case both: return true
        case englishOnly: return !typingVietnamese
        case vietnameseOnly: return typingVietnamese
        default: return false
        }
    }
}

// MARK: - Excluded App Model

struct ExcludedApp: Codable, Identifiable, Hashable {
    var id: String { bundleIdentifier }
    let bundleIdentifier: String
    let name: String
    let path: String
    /// Only meaningful for the auto-capitalize exclusion list. Entries saved
    /// before this setting existed decode as `.both`.
    var upperCaseScope: UpperCaseExcludeScope

    /// Satisfies `AppSelectionEntry`; new entries start with the historical
    /// "both languages" behaviour.
    init(bundleIdentifier: String, name: String, path: String) {
        self.init(
            bundleIdentifier: bundleIdentifier,
            name: name,
            path: path,
            upperCaseScope: .both
        )
    }

    init(
        bundleIdentifier: String,
        name: String,
        path: String,
        upperCaseScope: UpperCaseExcludeScope
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.path = path
        self.upperCaseScope = upperCaseScope
    }

    init?(from url: URL) {
        guard let bundle = Bundle(url: url),
            let bundleId = bundle.bundleIdentifier,
            let name = bundle.infoDictionary?["CFBundleName"] as? String ?? bundle.infoDictionary?[
                "CFBundleDisplayName"] as? String
        else { return nil }

        self.bundleIdentifier = bundleId
        self.name = name
        self.path = url.path
        self.upperCaseScope = .both
    }

    private enum CodingKeys: String, CodingKey {
        case bundleIdentifier, name, path, upperCaseScope
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bundleIdentifier = try container.decode(String.self, forKey: .bundleIdentifier)
        name = try container.decode(String.self, forKey: .name)
        path = try container.decode(String.self, forKey: .path)
        upperCaseScope = try container.decodeIfPresent(
            UpperCaseExcludeScope.self, forKey: .upperCaseScope
        ) ?? .both
    }
}

// MARK: - Send Key Step By Step App Model

struct SendKeyStepByStepApp: Codable, Identifiable, Hashable {
    var id: String { bundleIdentifier }
    let bundleIdentifier: String
    let name: String
    let path: String

    init(bundleIdentifier: String, name: String, path: String) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.path = path
    }

    init?(from url: URL) {
        guard let bundle = Bundle(url: url),
            let bundleId = bundle.bundleIdentifier,
            let name = bundle.infoDictionary?["CFBundleName"] as? String ?? bundle.infoDictionary?[
                "CFBundleDisplayName"] as? String
        else { return nil }

        self.bundleIdentifier = bundleId
        self.name = name
        self.path = url.path
    }
}

extension ExcludedApp: AppSelectionEntry {}
extension SendKeyStepByStepApp: AppSelectionEntry {}
