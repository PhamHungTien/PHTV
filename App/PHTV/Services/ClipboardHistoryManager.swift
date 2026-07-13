//
//  ClipboardHistoryManager.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import AppKit
import Carbon

enum ClipboardHistoryStoragePolicy {
    static let minimumItems = 10
    static let maximumItems = 100

    static func clampedMaxItems(_ value: Int) -> Int {
        min(max(value, minimumItems), maximumItems)
    }

    static func maxItems(from defaults: UserDefaults = .standard) -> Int {
        let rawValue = defaults.integer(
            forKey: UserDefaultsKey.clipboardHistoryMaxItems,
            default: Defaults.clipboardHistoryMaxItems
        )
        return clampedMaxItems(rawValue)
    }

    static func trimmed(_ items: [ClipboardHistoryItem], maxItems: Int) -> [ClipboardHistoryItem] {
        let limit = clampedMaxItems(maxItems)
        guard items.count > limit else { return items }
        return Array(items.prefix(limit))
    }

    static func retention(from defaults: UserDefaults = .standard) -> ClipboardHistoryRetention {
        ClipboardHistoryRetention.from(
            rawValue: defaults.integer(
                forKey: UserDefaultsKey.clipboardHistoryRetention,
                default: Defaults.clipboardHistoryRetention
            )
        )
    }

    /// Drops items older than the retention window. Items dated in the future
    /// (clock changes, restored backups) are kept — expiry must never be
    /// triggered by a clock going backwards.
    static func retained(
        _ items: [ClipboardHistoryItem],
        retention: ClipboardHistoryRetention,
        now: Date = Date()
    ) -> [ClipboardHistoryItem] {
        guard let maxAge = retention.maxAge else { return items }
        return items.filter { now.timeIntervalSince($0.timestamp) <= maxAge }
    }

    /// Single place that applies both limits: age first, then item count.
    static func enforced(
        _ items: [ClipboardHistoryItem],
        retention: ClipboardHistoryRetention,
        maxItems: Int,
        now: Date = Date()
    ) -> [ClipboardHistoryItem] {
        trimmed(retained(items, retention: retention, now: now), maxItems: maxItems)
    }
}

enum ClipboardHistoryPastePayload: Equatable {
    case image(Data)
    case files([String])
    case text(String)
}

enum ClipboardHistoryPastePayloadResolver {
    static func resolve(
        _ item: ClipboardHistoryItem,
        fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) -> ClipboardHistoryPastePayload? {
        // In-memory imageData is present only for items captured in the same session
        // before they were serialized. After a restart imageFilePath is used instead.
        if let data = item.imageData {
            return .image(data)
        }
        if let path = item.imageFilePath,
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
            return .image(data)
        }

        let filePaths = item.resolvedFilePastePaths(fileExists: fileExists)
        if !filePaths.isEmpty {
            return .files(filePaths)
        }

        if let text = item.textContent {
            return .text(text)
        }

        return nil
    }
}

@Observable
@MainActor
final class ClipboardHistoryManager {
    static let shared = ClipboardHistoryManager()

    private(set) var items: [ClipboardHistoryItem] = []

    private let showDebounceInterval: CFAbsoluteTime = 0.20
    private var panel: FloatingPanel<ClipboardHistoryView>?
    private var previousApp: NSRunningApplication?
    private var lastShowRequestTime: CFAbsoluteTime = 0
    /// Hourly: fine enough for the shortest window offered (3 days) while
    /// costing one wakeup per hour.
    private static let retentionSweepInterval: TimeInterval = 3600

    private var settingsObservationTask: Task<Void, Never>?
    private var retentionSweepTask: Task<Void, Never>?
    private var panelResignKeyTask: Task<Void, Never>?
    private var restoreFocusTask: Task<Void, Never>?
    private var pendingPasteTask: Task<Void, Never>?
    private var clearPastingTask: Task<Void, Never>?
    var isPasting = false

    var isVisible: Bool {
        panel?.isVisible == true
    }

    private init() {
        loadHistory()

        settingsObservationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await _ in NotificationCenter.default.notifications(named: NotificationName.clipboardHotkeySettingsChanged) {
                guard !Task.isCancelled else { break }
                self.enforceStoragePolicies()
            }
        }

        // Items age even when nothing new is copied, so sweep on a timer as
        // well; expired entries must not linger on disk until the next copy.
        retentionSweepTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.retentionSweepInterval))
                guard let self, !Task.isCancelled else { break }
                self.enforceStoragePolicies()
            }
        }
    }

    // MARK: - Data Management

    func addItem(_ item: ClipboardHistoryItem) {
        // Remove duplicate if exists
        let duplicateItems = items.filter { $0.isDuplicate(of: item) }
        duplicateItems.forEach { ClipboardHistoryFileCache.removeCache(for: $0) }
        let duplicateIDs = Set(duplicateItems.map(\.id))
        items.removeAll { duplicateIDs.contains($0.id) }

        // Insert at beginning
        items.insert(item, at: 0)
        let keptItems = ClipboardHistoryStoragePolicy.enforced(
            items,
            retention: ClipboardHistoryStoragePolicy.retention(),
            maxItems: ClipboardHistoryStoragePolicy.maxItems()
        )
        cleanupCaches(forRemovedItemsFrom: items, keeping: keptItems)
        items = keptItems

        saveHistory()
    }

    /// Move a just-used item to the top of the history (most-recently-used ordering)
    /// and refresh its timestamp so the list reflects real recency. The pasteboard
    /// monitor skips re-capturing content we paste ourselves (via `isPasting`), so the
    /// promotion is applied explicitly here.
    func promoteItemToTop(_ item: ClipboardHistoryItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        guard index != 0 else { return }

        let existing = items.remove(at: index)
        let promoted = ClipboardHistoryItem(
            id: existing.id,
            timestamp: Date(),
            textContent: existing.textContent,
            imageData: existing.imageData,
            filePaths: existing.filePaths,
            fileReferences: existing.fileReferences,
            sourceApp: existing.sourceApp,
            imageFilePath: existing.imageFilePath
        )
        items.insert(promoted, at: 0)
        saveHistory()
    }

    func removeItem(_ item: ClipboardHistoryItem) {
        items.removeAll { $0.id == item.id }
        ClipboardHistoryFileCache.removeCache(for: item)
        saveHistory()
    }

    func clearAll() {
        items.removeAll()
        ClipboardHistoryFileCache.removeAll()
        saveHistory()
    }

    // MARK: - Persistence

    private static let historyFileURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("PHTV", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("clipboard_history.json")
    }()

    private func loadHistory() {
        // Migrate from UserDefaults if needed
        if let legacyData = UserDefaults.standard.data(forKey: UserDefaultsKey.clipboardHistoryData) {
            do {
                items = try JSONDecoder().decode([ClipboardHistoryItem].self, from: legacyData)
                enforceStoragePolicies()
                saveHistory()
                UserDefaults.standard.removeObject(forKey: UserDefaultsKey.clipboardHistoryData)
                NSLog("[ClipboardHistory] Migrated history from UserDefaults to file storage")
            } catch {
                NSLog("[ClipboardHistory] Failed to migrate legacy history: %@", error.localizedDescription)
                UserDefaults.standard.removeObject(forKey: UserDefaultsKey.clipboardHistoryData)
            }
            return
        }

        let url = Self.historyFileURL
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return }
        do {
            items = try JSONDecoder().decode([ClipboardHistoryItem].self, from: data)
            enforceStoragePolicies()
            cleanupOrphanedCaches()
        } catch {
            NSLog("[ClipboardHistory] Failed to decode history: %@", error.localizedDescription)
        }
    }

    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: Self.historyFileURL, options: .atomic)
        } catch {
            NSLog("[ClipboardHistory] Failed to save history: %@", error.localizedDescription)
        }
    }

    /// Applies both storage limits: the retention window (age) and the maximum
    /// item count. Safe to call often — it only writes when something changed.
    private func enforceStoragePolicies() {
        let keptItems = ClipboardHistoryStoragePolicy.enforced(
            items,
            retention: ClipboardHistoryStoragePolicy.retention(),
            maxItems: ClipboardHistoryStoragePolicy.maxItems()
        )
        guard keptItems != items else { return }
        cleanupCaches(forRemovedItemsFrom: items, keeping: keptItems)
        items = keptItems
        saveHistory()
    }

    private func cleanupCaches(forRemovedItemsFrom oldItems: [ClipboardHistoryItem], keeping newItems: [ClipboardHistoryItem]) {
        let keptIDs = Set(newItems.map(\.id))
        oldItems
            .filter { !keptIDs.contains($0.id) }
            .forEach { ClipboardHistoryFileCache.removeCache(for: $0) }
    }

    private func cleanupOrphanedCaches() {
        ClipboardHistoryFileCache.removeCaches(excluding: Set(items.map(\.id)))
    }

    // MARK: - UI Show/Hide

    func toggleVisibility() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        let now = CFAbsoluteTimeGetCurrent()
        if (now - lastShowRequestTime) < showDebounceInterval {
            return
        }
        lastShowRequestTime = now

        // Never show an entry the retention window has already expired.
        enforceStoragePolicies()

        previousApp = NSWorkspace.shared.frontmostApplication

        panel?.close()

        let clipboardView = ClipboardHistoryView(
            onItemSelected: { [weak self] item in
                self?.handleItemSelected(item)
            },
            onClose: { [weak self] in
                self?.hide()
            }
        )

        let contentRect = NSRect(x: 0, y: 0, width: 380, height: 480)
        panel = FloatingPanel(view: clipboardView, contentRect: contentRect)

        panel?.standardWindowButton(.closeButton)?.isHidden = true
        panel?.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel?.standardWindowButton(.zoomButton)?.isHidden = true

        panel?.showAtMousePosition()
        panel?.makeKey()

        Task { @MainActor [weak self] in
            await Task.yield()
            self?.panel?.makeKey()
        }

        panelResignKeyTask?.cancel()
        if let panel {
            panelResignKeyTask = Task { @MainActor [weak self, panel] in
                for await _ in NotificationCenter.default.notifications(
                    named: NSWindow.didResignKeyNotification,
                    object: panel
                ) {
                    guard let self, !Task.isCancelled else { break }
                    self.hide()
                    break
                }
            }
        }
    }

    func hide() {
        panelResignKeyTask?.cancel()
        panelResignKeyTask = nil
        panel?.close()
        panel = nil
        lastShowRequestTime = 0

        restoreFocusTask?.cancel()
        restoreFocusTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled, let app = self?.previousApp else { return }
            _ = app.activate()
        }
    }

    // MARK: - Paste

    private func handleItemSelected(_ item: ClipboardHistoryItem) {
        hide()

        pendingPasteTask?.cancel()
        pendingPasteTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            self?.pasteItem(item)
        }
    }

    private func pasteItem(_ item: ClipboardHistoryItem) {
        isPasting = true

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        guard setPasteboardContents(for: item, pasteboard: pasteboard) else {
            NSLog("[ClipboardHistory] Unable to prepare pasteboard for item %@", item.id.uuidString)
            scheduleClearPasting()
            return
        }

        // Most-recently-used ordering: bump the pasted item back to the top.
        promoteItemToTop(item)

        // Simulate Command+V to paste
        let source = CGEventSource(stateID: .hidSystemState)

        if let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: true) {
            cmdDown.flags = .maskCommand
            cmdDown.post(tap: .cgSessionEventTap)
        }
        if let vDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true) {
            vDown.flags = .maskCommand
            vDown.post(tap: .cgSessionEventTap)
        }
        if let vUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false) {
            vUp.flags = .maskCommand
            vUp.post(tap: .cgSessionEventTap)
        }
        if let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: false) {
            cmdUp.post(tap: .cgSessionEventTap)
        }

        scheduleClearPasting()
    }

    private func setPasteboardContents(for item: ClipboardHistoryItem, pasteboard: NSPasteboard) -> Bool {
        guard let payload = ClipboardHistoryPastePayloadResolver.resolve(item) else { return false }

        switch payload {
        case .image(let imageData):
            var wroteContent = false
            if let image = NSImage(data: imageData) {
                wroteContent = pasteboard.writeObjects([image]) || wroteContent
                if let tiffData = image.tiffRepresentation {
                    wroteContent = pasteboard.setData(tiffData, forType: .tiff) || wroteContent
                }
            }
            wroteContent = pasteboard.setData(imageData, forType: .png) || wroteContent
            return wroteContent

        case .files(let filePaths):
            let urls = filePaths.map { URL(fileURLWithPath: $0) as NSURL }
            return pasteboard.writeObjects(urls)

        case .text(let text):
            return pasteboard.setString(text, forType: .string)
        }
    }

    private func scheduleClearPasting() {
        clearPastingTask?.cancel()
        clearPastingTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.isPasting = false
        }
    }
}
