//
//  ClipboardMonitor.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit

struct ClipboardHistoryCapturePayload: Equatable, Sendable {
    let textContent: String?
    let imageData: Data?
    let filePaths: [String]?
    let fileReferences: [ClipboardHistoryFileReference]?

    init(
        textContent: String?,
        imageData: Data?,
        filePaths: [String]?,
        fileReferences: [ClipboardHistoryFileReference]? = nil
    ) {
        self.textContent = textContent
        self.imageData = imageData
        self.filePaths = filePaths
        self.fileReferences = fileReferences
    }
}

enum ClipboardHistoryCaptureSanitizer {
    static let maxImageBytes = 5_000_000

    static func sanitizedPayload(
        textContent: String?,
        imageData: Data?,
        filePaths: [String]?,
        fileReferences: [ClipboardHistoryFileReference]? = nil
    ) -> ClipboardHistoryCapturePayload? {
        var sanitizedImageData = imageData
        if let data = sanitizedImageData, data.count > maxImageBytes {
            sanitizedImageData = nil
        }

        let hasText = textContent != nil
        let hasImage = sanitizedImageData != nil
        let hasFiles = !(filePaths?.isEmpty ?? true) || !(fileReferences?.isEmpty ?? true)
        guard hasText || hasImage || hasFiles else { return nil }

        return ClipboardHistoryCapturePayload(
            textContent: textContent,
            imageData: sanitizedImageData,
            filePaths: hasFiles ? filePaths : nil,
            fileReferences: hasFiles ? fileReferences : nil
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
    private var captureTask: Task<Void, Never>?
    private var captureTimeoutTask: Task<Void, Never>?
    private var activeCaptureID: UUID?
    private var lastChangeCount: Int = 0
    private var isMonitoring = false
    private var captureBackoffUntil: CFAbsoluteTime = 0

    private let captureTimeoutSeconds: TimeInterval = 2.0
    private let captureBackoffSeconds: TimeInterval = 5.0

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
        captureTask?.cancel()
        captureTask = nil
        captureTimeoutTask?.cancel()
        captureTimeoutTask = nil
        activeCaptureID = nil
    }

    private func checkForChanges() {
        let now = CFAbsoluteTimeGetCurrent()
        guard now >= captureBackoffUntil else { return }

        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }

        guard captureTask == nil else {
            return
        }

        lastChangeCount = currentCount

        // Don't capture items that we just pasted from clipboard history
        if ClipboardHistoryManager.shared.isPasting ||
           PHTVTransientTextInsertionService.isPasteboardMutationActive {
            return
        }

        let sourceApp = PHTVAppContextService.currentFrontmostBundleId()
        guard ClipboardHistoryPrivacyPolicy.shouldCaptureContent(from: sourceApp) else {
            return
        }

        startCapture(sourceApp: sourceApp)
    }

    private func startCapture(sourceApp: String?) {
        let captureID = UUID()
        activeCaptureID = captureID

        captureTask = Task.detached(priority: .utility) { [captureID, sourceApp] in
            let item = Self.captureCurrentPasteboard(sourceApp: sourceApp)
            await ClipboardMonitor.shared.finishCapture(captureID: captureID, item: item)
        }

        captureTimeoutTask?.cancel()
        captureTimeoutTask = Task { @MainActor [weak self, captureID] in
            try? await Task.sleep(for: .seconds(self?.captureTimeoutSeconds ?? 2.0))
            self?.handleCaptureTimeout(captureID: captureID)
        }
    }

    private func finishCapture(captureID: UUID, item: ClipboardHistoryItem?) {
        guard activeCaptureID == captureID else { return }

        captureTask = nil
        activeCaptureID = nil
        captureTimeoutTask?.cancel()
        captureTimeoutTask = nil

        guard isMonitoring else { return }

        if let item {
            ClipboardHistoryManager.shared.addItem(item)
        }
    }

    private func handleCaptureTimeout(captureID: UUID) {
        guard activeCaptureID == captureID else { return }

        NSLog("[ClipboardHistory] Pasteboard capture timed out; keeping UI responsive and retrying later")
        captureTask?.cancel()
        captureTask = nil
        activeCaptureID = nil
        captureTimeoutTask = nil
        captureBackoffUntil = CFAbsoluteTimeGetCurrent() + captureBackoffSeconds
    }

    nonisolated private static func captureCurrentPasteboard(sourceApp: String?) -> ClipboardHistoryItem? {
        autoreleasepool {
            let pasteboard = NSPasteboard.general
            let itemID = UUID()

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
            var fileReferences: [ClipboardHistoryFileReference]?
            if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [
                .urlReadingFileURLsOnly: true
            ]) as? [URL], !urls.isEmpty {
                filePaths = urls.map { $0.path }
                fileReferences = ClipboardHistoryFileCache.references(for: urls, itemID: itemID)
            }

            guard let payload = ClipboardHistoryCaptureSanitizer.sanitizedPayload(
                textContent: textContent,
                imageData: imageData,
                filePaths: filePaths,
                fileReferences: fileReferences
            ) else {
                ClipboardHistoryFileCache.removeCache(for: itemID)
                return nil
            }

            // Save image to disk immediately so it is never held in RAM after capture
            var imageFilePath: String?
            if let data = payload.imageData {
                imageFilePath = ClipboardHistoryFileCache.saveImageData(data, for: itemID)?.path
            }

            return ClipboardHistoryItem(
                id: itemID,
                timestamp: Date(),
                textContent: payload.textContent,
                imageData: nil,
                filePaths: payload.filePaths,
                fileReferences: payload.fileReferences,
                sourceApp: sourceApp,
                imageFilePath: imageFilePath
            )
        }
    }
}
