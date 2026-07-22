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
    /// Path to the image file on disk. Not kept in memory as raw bytes.
    let imageFilePath: String?
    let filePaths: [String]?
    let fileReferences: [ClipboardHistoryFileReference]?
    let sourceApp: String?
    /// Pinned items are kept until the user unpins or deletes them: they are
    /// exempt from the retention window, the item-count limit, and "Clear all".
    let isPinned: Bool

    // Non-Codable: only populated for freshly captured items before first save.
    // After decoding from disk this is always nil; use imageFilePath instead.
    let imageData: Data?

    init(
        id: UUID,
        timestamp: Date,
        textContent: String?,
        imageData: Data?,
        filePaths: [String]?,
        fileReferences: [ClipboardHistoryFileReference]? = nil,
        sourceApp: String?,
        imageFilePath: String? = nil,
        isPinned: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.textContent = textContent
        self.imageData = imageData
        self.imageFilePath = imageFilePath
        self.filePaths = filePaths
        self.fileReferences = fileReferences
        self.sourceApp = sourceApp
        self.isPinned = isPinned
    }

    /// Same item with a different pinned state (all fields are immutable).
    func withPinned(_ pinned: Bool) -> ClipboardHistoryItem {
        ClipboardHistoryItem(
            id: id,
            timestamp: timestamp,
            textContent: textContent,
            imageData: imageData,
            filePaths: filePaths,
            fileReferences: fileReferences,
            sourceApp: sourceApp,
            imageFilePath: imageFilePath,
            isPinned: pinned
        )
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case id, timestamp, textContent, imageFilePath, filePaths, fileReferences, sourceApp, isPinned
        // Legacy key for migration only — not written on encode
        case legacyImageData = "imageData"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        timestamp = try c.decode(Date.self, forKey: .timestamp)
        textContent = try c.decodeIfPresent(String.self, forKey: .textContent)
        filePaths = try c.decodeIfPresent([String].self, forKey: .filePaths)
        fileReferences = try c.decodeIfPresent([ClipboardHistoryFileReference].self, forKey: .fileReferences)
        sourceApp = try c.decodeIfPresent(String.self, forKey: .sourceApp)
        // Histories written before the pin feature have no key: default to unpinned.
        isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false

        if let existingPath = try c.decodeIfPresent(String.self, forKey: .imageFilePath) {
            // New format: image already on disk
            imageFilePath = existingPath
            imageData = nil
        } else if let legacyData = try c.decodeIfPresent(Data.self, forKey: .legacyImageData) {
            // Migration: old format stored imageData inline. Save to disk now.
            let savedURL = ClipboardHistoryFileCache.saveImageData(legacyData, for: id)
            imageFilePath = savedURL?.path
            imageData = nil
        } else {
            imageFilePath = nil
            imageData = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(timestamp, forKey: .timestamp)
        try c.encodeIfPresent(textContent, forKey: .textContent)
        try c.encodeIfPresent(imageFilePath, forKey: .imageFilePath)
        try c.encodeIfPresent(filePaths, forKey: .filePaths)
        try c.encodeIfPresent(fileReferences, forKey: .fileReferences)
        try c.encodeIfPresent(sourceApp, forKey: .sourceApp)
        if isPinned {
            try c.encode(isPinned, forKey: .isPinned)
        }
        // imageData is intentionally excluded — it lives on disk only
    }

    // MARK: - Content

    enum ContentType: String, Codable, Sendable {
        case text
        case image
        case file
        case mixed
    }

    var hasImage: Bool { imageData != nil || imageFilePath != nil }

    var contentType: ContentType {
        let hasText = textContent != nil && !(textContent?.isEmpty ?? true)
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
        if hasImage {
            return "[Hình ảnh]"
        }
        let names = displayFileNames
        if !names.isEmpty {
            return names.joined(separator: ", ")
        }
        return "[Trống]"
    }

    var previewImage: NSImage? {
        if let data = imageData { return NSImage(data: data) }
        guard let path = imageFilePath,
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
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
        if let f1 = filePaths, let f2 = other.filePaths, f1 == f2 { return true }
        if let r1 = fileReferences, let r2 = other.fileReferences, r1.map(\.originalPath) == r2.map(\.originalPath) { return true }
        return false
    }
}
