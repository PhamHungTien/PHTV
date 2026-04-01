//
//  ClipboardMonitor.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit

struct ClipboardHistoryCapturePayload: Equatable {
    let textContent: String?
    let imageData: Data?
    let filePaths: [String]?
}

enum ClipboardHistoryCaptureSanitizer {
    static let maxImageBytes = 5_000_000

    static func sanitizedPayload(
        textContent: String?,
        imageData: Data?,
        filePaths: [String]?
    ) -> ClipboardHistoryCapturePayload? {
        var sanitizedImageData = imageData
        if let data = sanitizedImageData, data.count > maxImageBytes {
            sanitizedImageData = nil
        }

        let hasText = textContent != nil
        let hasImage = sanitizedImageData != nil
        let hasFiles = !(filePaths?.isEmpty ?? true)
        guard hasText || hasImage || hasFiles else { return nil }

        return ClipboardHistoryCapturePayload(
            textContent: textContent,
            imageData: sanitizedImageData,
            filePaths: hasFiles ? filePaths : nil
        )
    }
}

enum ClipboardHistoryPrivacyPolicy {
    private static let sensitiveBundleIdentifiers: Set<String> = [
        "com.1password.1password",
        "com.agilebits.onepassword7",
        "com.agilebits.onepassword",
        "com.bitwarden.desktop",
        "com.lastpass.LastPass",
        "com.dashlane.dashlanephonefinal",
        "org.keepassxc.keepassxc",
        "com.apple.keychainaccess",
        "com.apple.Passwords"
    ]

    static func shouldCaptureContent(from bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier, !bundleIdentifier.isEmpty else { return true }
        return !sensitiveBundleIdentifiers.contains(bundleIdentifier)
    }
}

/// Monitors the system pasteboard for changes and records clipboard history
@MainActor
final class ClipboardMonitor {
    static let shared = ClipboardMonitor()

    private var monitoringTask: Task<Void, Never>?
    private var lastChangeCount: Int = 0
    private var isMonitoring = false

    private init() {
        lastChangeCount = NSPasteboard.general.changeCount
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        lastChangeCount = NSPasteboard.general.changeCount

        monitoringTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled, self.isMonitoring else { break }
                self.checkForChanges()
            }
        }
    }

    func stopMonitoring() {
        isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil
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
        let sourceApp = PHTVAppContextService.currentFrontmostBundleId()
        guard ClipboardHistoryPrivacyPolicy.shouldCaptureContent(from: sourceApp) else {
            return nil
        }

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

        guard let payload = ClipboardHistoryCaptureSanitizer.sanitizedPayload(
            textContent: textContent,
            imageData: imageData,
            filePaths: filePaths
        ) else {
            return nil
        }

        return ClipboardHistoryItem(
            id: UUID(),
            timestamp: Date(),
            textContent: payload.textContent,
            imageData: payload.imageData,
            filePaths: payload.filePaths,
            sourceApp: sourceApp
        )
    }
}
