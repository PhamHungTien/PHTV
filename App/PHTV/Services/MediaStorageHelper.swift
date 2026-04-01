//
//  MediaStorageHelper.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation

// MARK: - Helper Functions for Media Storage

/// Get or create the PHTV media directory for temporary GIF/Sticker storage
func getPHTPMediaDirectory() -> URL {
    let tempDir = FileManager.default.temporaryDirectory
    let phtpDir = tempDir.appendingPathComponent("PHTPMedia", isDirectory: true)

    // Create directory if it doesn't exist
    if !FileManager.default.fileExists(atPath: phtpDir.path) {
        try? FileManager.default.createDirectory(at: phtpDir, withIntermediateDirectories: true)
    }

    return phtpDir
}

/// Delete a file after a delay to ensure paste is complete
func deleteFileAfterDelay(_ fileURL: URL, delay: TimeInterval = 5.0) {
    Task {
        try? await Task.sleep(for: .seconds(delay))
        guard !Task.isCancelled else { return }
        try? FileManager.default.removeItem(at: fileURL)
        NSLog("[PHTPPicker] Cleaned up file: %@", fileURL.lastPathComponent)
    }
}

/// Download remote media data using async/await with consistent logging.
func downloadRemoteData(
    from url: URL,
    logPrefix: String,
    itemDescription: String,
    identifier: String? = nil
) async -> Data? {
    do {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard !Task.isCancelled else { return nil }

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            NSLog("\(logPrefix) \(itemDescription) download HTTP error: \(httpResponse.statusCode)")
            return nil
        }

        guard !data.isEmpty else {
            let suffix = identifier.map { ": \($0)" } ?? ""
            NSLog("\(logPrefix) No data received for \(itemDescription)\(suffix)")
            return nil
        }

        return data
    } catch is CancellationError {
        return nil
    } catch {
        NSLog("\(logPrefix) \(itemDescription) download error: \(error.localizedDescription)")
        return nil
    }
}
