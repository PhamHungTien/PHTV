//
//  ClipboardHistoryItem.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation
import AppKit

@MainActor
final class ClipboardSourceAppResolver {
    static let shared = ClipboardSourceAppResolver()

    private var nameCache: [String: String] = [:]

    private init() {}

    func displayName(for bundleIdentifier: String?) -> String? {
        guard let bundleIdentifier, !bundleIdentifier.isEmpty else { return nil }

        if let cachedName = nameCache[bundleIdentifier] {
            return cachedName
        }

        let resolvedName = resolveDisplayName(for: bundleIdentifier) ?? bundleIdentifier
        nameCache[bundleIdentifier] = resolvedName
        return resolvedName
    }

    private func resolveDisplayName(for bundleIdentifier: String) -> String? {
        if let runningApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }),
           let localizedName = runningApp.localizedName,
           !localizedName.isEmpty {
            return localizedName
        }

        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier),
              let bundle = Bundle(url: appURL) else {
            return nil
        }

        return bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
    }
}

struct ClipboardHistoryItem: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let textContent: String?
    let imageData: Data?
    let filePaths: [String]?
    let sourceApp: String?

    enum ContentType: String, Codable {
        case text
        case image
        case file
        case mixed
    }

    var contentType: ContentType {
        let hasText = textContent != nil && !(textContent?.isEmpty ?? true)
        let hasImage = imageData != nil
        let hasFiles = filePaths != nil && !(filePaths?.isEmpty ?? true)

        if hasText && (hasImage || hasFiles) { return .mixed }
        if hasImage { return .image }
        if hasFiles { return .file }
        return .text
    }

    var displayText: String {
        if let text = textContent, !text.isEmpty {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count > 80 {
                return String(trimmed.prefix(80)) + "..."
            }
            return trimmed
        }
        if imageData != nil {
            return "[Hình ảnh]"
        }
        if let paths = filePaths, !paths.isEmpty {
            let names = paths.compactMap { URL(fileURLWithPath: $0).lastPathComponent }
            return names.joined(separator: ", ")
        }
        return "[Trống]"
    }

    var previewImage: NSImage? {
        guard let data = imageData else { return nil }
        return NSImage(data: data)
    }

    @MainActor
    var sourceAppDisplayName: String? {
        ClipboardSourceAppResolver.shared.displayName(for: sourceApp)
    }

    static func == (lhs: ClipboardHistoryItem, rhs: ClipboardHistoryItem) -> Bool {
        lhs.id == rhs.id
    }

    func isDuplicate(of other: ClipboardHistoryItem) -> Bool {
        if let t1 = textContent, let t2 = other.textContent, t1 == t2 { return true }
        if let d1 = imageData, let d2 = other.imageData, d1 == d2 { return true }
        if let f1 = filePaths, let f2 = other.filePaths, f1 == f2 { return true }
        return false
    }
}
