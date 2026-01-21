//
//  MediaStorageHelper.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation
import AppKit

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
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        try? FileManager.default.removeItem(at: fileURL)
        NSLog("[PHTPPicker] Cleaned up file: %@", fileURL.lastPathComponent)
    }
}
