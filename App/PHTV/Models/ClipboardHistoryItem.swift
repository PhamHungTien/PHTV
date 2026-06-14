//
//  ClipboardHistoryItem.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation
import AppKit

struct ClipboardHistoryFileReference: Codable, Equatable, Sendable {
    let originalPath: String
    let cachedPath: String?
    let displayName: String
    let sizeBytes: Int64?

    init(
        originalPath: String,
        cachedPath: String? = nil,
        displayName: String? = nil,
        sizeBytes: Int64? = nil
    ) {
        self.originalPath = originalPath
        self.cachedPath = cachedPath
        self.displayName = displayName ?? URL(fileURLWithPath: originalPath).lastPathComponent
        self.sizeBytes = sizeBytes
    }

    func bestAvailablePath(fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }) -> String? {
        if let cachedPath, fileExists(cachedPath) {
            return cachedPath
        }
        if fileExists(originalPath) {
            return originalPath
        }
        return nil
    }
}

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

struct ClipboardHistoryItem: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let timestamp: Date
    let textContent: String?
    let imageData: Data?
    let filePaths: [String]?
    let fileReferences: [ClipboardHistoryFileReference]?
    let sourceApp: String?

    init(
        id: UUID,
        timestamp: Date,
        textContent: String?,
        imageData: Data?,
        filePaths: [String]?,
        fileReferences: [ClipboardHistoryFileReference]? = nil,
        sourceApp: String?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.textContent = textContent
        self.imageData = imageData
        self.filePaths = filePaths
        self.fileReferences = fileReferences
        self.sourceApp = sourceApp
    }

    enum ContentType: String, Codable, Sendable {
        case text
        case image
        case file
        case mixed
    }

    var contentType: ContentType {
        let hasText = textContent != nil && !(textContent?.isEmpty ?? true)
        let hasImage = imageData != nil
        let hasFiles = hasFileContent

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
        let names = displayFileNames
        if !names.isEmpty {
            return names.joined(separator: ", ")
        }
        return "[Trống]"
    }

    var previewImage: NSImage? {
        guard let data = imageData else { return nil }
        return NSImage(data: data)
    }

    var hasFileContent: Bool {
        if let references = fileReferences, !references.isEmpty {
            return true
        }
        return filePaths != nil && !(filePaths?.isEmpty ?? true)
    }

    var displayFileNames: [String] {
        if let references = fileReferences, !references.isEmpty {
            return references.map(\.displayName)
        }
        return (filePaths ?? []).map { URL(fileURLWithPath: $0).lastPathComponent }
    }

    func resolvedFilePastePaths(fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }) -> [String] {
        if let references = fileReferences, !references.isEmpty {
            return references.compactMap { $0.bestAvailablePath(fileExists: fileExists) }
        }
        return (filePaths ?? []).filter(fileExists)
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
        if let r1 = fileReferences, let r2 = other.fileReferences, r1.map(\.originalPath) == r2.map(\.originalPath) { return true }
        return false
    }
}
