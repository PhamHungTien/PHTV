//
//  ClipboardMonitor.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit

/// Monitors the system pasteboard for changes and records clipboard history
@MainActor
final class ClipboardMonitor {
    static let shared = ClipboardMonitor()

    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private var isMonitoring = false

    private init() {
        lastChangeCount = NSPasteboard.general.changeCount
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        lastChangeCount = NSPasteboard.general.changeCount

        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkForChanges()
            }
        }
    }

    func stopMonitoring() {
        isMonitoring = false
        timer?.invalidate()
        timer = nil
    }

    private func checkForChanges() {
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        // Don't capture items that we just pasted from clipboard history
        if ClipboardHistoryManager.shared.isPasting { return }

        let item = captureCurrentPasteboard(pasteboard)
        if let item = item {
            ClipboardHistoryManager.shared.addItem(item)
        }
    }

    private func captureCurrentPasteboard(_ pasteboard: NSPasteboard) -> ClipboardHistoryItem? {
        let textContent = pasteboard.string(forType: .string)

        var imageData: Data?
        if let tiffData = pasteboard.data(forType: .tiff) {
            if let bitmap = NSBitmapImageRep(data: tiffData) {
                imageData = bitmap.representation(using: .png, properties: [:])
            }
        } else if let pngData = pasteboard.data(forType: .png) {
            imageData = pngData
        }

        var filePaths: [String]?
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL], !urls.isEmpty {
            filePaths = urls.map { $0.path }
        }

        // Skip if nothing captured
        guard textContent != nil || imageData != nil || filePaths != nil else { return nil }

        // Skip very large image data (> 5MB) to avoid memory issues
        if let data = imageData, data.count > 5_000_000 {
            imageData = nil
        }

        let sourceApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        return ClipboardHistoryItem(
            id: UUID(),
            timestamp: Date(),
            textContent: textContent,
            imageData: imageData,
            filePaths: filePaths,
            sourceApp: sourceApp
        )
    }
}
