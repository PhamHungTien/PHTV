//
//  ClipboardHistoryFileCache.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation

enum ClipboardHistoryFileCache {
    static let maxCachedFileBytes: Int64 = 25_000_000

    private static var rootDirectoryURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("PHTV", isDirectory: true)
            .appendingPathComponent("ClipboardHistoryFiles", isDirectory: true)
    }

    static func references(for urls: [URL], itemID: UUID, fileManager: FileManager = .default) -> [ClipboardHistoryFileReference] {
        urls.map { url in
            let originalPath = url.path
            let size = regularFileSize(at: url, fileManager: fileManager)
            let cachedURL = cacheFileIfReasonable(url, itemID: itemID, size: size, fileManager: fileManager)

            return ClipboardHistoryFileReference(
                originalPath: originalPath,
                cachedPath: cachedURL?.path,
                displayName: url.lastPathComponent,
                sizeBytes: size
            )
        }
    }

    @discardableResult
    static func saveImageData(_ data: Data, for itemID: UUID, fileManager: FileManager = .default) -> URL? {
        let itemDir = rootDirectoryURL.appendingPathComponent(itemID.uuidString, isDirectory: true)
        do {
            try fileManager.createDirectory(at: itemDir, withIntermediateDirectories: true)
            let imageURL = itemDir.appendingPathComponent("image.png", isDirectory: false)
            try data.write(to: imageURL)
            return imageURL
        } catch {
            NSLog("[ClipboardHistory] Failed to save image for %@: %@", itemID.uuidString, error.localizedDescription)
            return nil
        }
    }

    static func loadImageData(for itemID: UUID) -> Data? {
        let imageURL = rootDirectoryURL
            .appendingPathComponent(itemID.uuidString, isDirectory: true)
            .appendingPathComponent("image.png", isDirectory: false)
        return try? Data(contentsOf: imageURL)
    }

    static func removeCache(for item: ClipboardHistoryItem, fileManager: FileManager = .default) {
        removeCache(for: item.id, fileManager: fileManager)
    }

    static func removeCache(for itemID: UUID, fileManager: FileManager = .default) {
        let itemURL = rootDirectoryURL.appendingPathComponent(itemID.uuidString, isDirectory: true)
        try? fileManager.removeItem(at: itemURL)
    }

    static func removeAll(fileManager: FileManager = .default) {
        try? fileManager.removeItem(at: rootDirectoryURL)
    }

    static func removeCaches(excluding itemIDs: Set<UUID>, fileManager: FileManager = .default) {
        guard let children = try? fileManager.contentsOfDirectory(
            at: rootDirectoryURL,
            includingPropertiesForKeys: nil
        ) else {
            return
        }

        for child in children {
            guard let itemID = UUID(uuidString: child.lastPathComponent),
                  itemIDs.contains(itemID) else {
                try? fileManager.removeItem(at: child)
                continue
            }
        }
    }

    private static func cacheFileIfReasonable(
        _ url: URL,
        itemID: UUID,
        size: Int64?,
        fileManager: FileManager
    ) -> URL? {
        guard url.isFileURL,
              let size,
              size <= maxCachedFileBytes,
              isRegularFile(url, fileManager: fileManager) else {
            return nil
        }

        let itemDirectory = rootDirectoryURL.appendingPathComponent(itemID.uuidString, isDirectory: true)
        do {
            try fileManager.createDirectory(at: itemDirectory, withIntermediateDirectories: true)
            let destination = uniqueDestinationURL(
                in: itemDirectory,
                preferredName: url.lastPathComponent,
                fileManager: fileManager
            )
            try fileManager.copyItem(at: url, to: destination)
            return destination
        } catch {
            NSLog("[ClipboardHistory] Failed to cache file %@: %@", url.path, error.localizedDescription)
            return nil
        }
    }

    private static func uniqueDestinationURL(
        in directory: URL,
        preferredName: String,
        fileManager: FileManager
    ) -> URL {
        let fallbackName = preferredName.isEmpty ? "Clipboard File" : preferredName
        var candidate = directory.appendingPathComponent(fallbackName, isDirectory: false)
        guard fileManager.fileExists(atPath: candidate.path) else { return candidate }

        let base = candidate.deletingPathExtension().lastPathComponent
        let pathExtension = candidate.pathExtension
        for index in 2...999 {
            let name = pathExtension.isEmpty ? "\(base) \(index)" : "\(base) \(index).\(pathExtension)"
            candidate = directory.appendingPathComponent(name, isDirectory: false)
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return directory.appendingPathComponent(UUID().uuidString, isDirectory: false)
    }

    private static func regularFileSize(at url: URL, fileManager: FileManager) -> Int64? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              attributes[.type] as? FileAttributeType == .typeRegular else {
            return nil
        }
        return attributes[.size] as? Int64
    }

    private static func isRegularFile(_ url: URL, fileManager: FileManager) -> Bool {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path) else { return false }
        return attributes[.type] as? FileAttributeType == .typeRegular
    }
}
