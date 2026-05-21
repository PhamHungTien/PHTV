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
        if let imageData = item.imageData {
            return .image(imageData)
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
    private var settingsObservationTask: Task<Void, Never>?
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
                self.trimItemsToConfiguredLimit()
            }
        }
    }

    // MARK: - Data Management

    func addItem(_ item: ClipboardHistoryItem) {
        // Remove duplicate if exists
        let duplicateItems = items.filter { $0.isDuplicate(of: item) }
        duplicateItems.forEach { ClipboardHistoryFileCache.removeCache(for: $0) }
        items.removeAll { duplicateItems.contains($0) }

        // Insert at beginning
        items.insert(item, at: 0)
        let trimmedItems = ClipboardHistoryStoragePolicy.trimmed(
            items,
            maxItems: ClipboardHistoryStoragePolicy.maxItems()
        )
        cleanupCaches(forRemovedItemsFrom: items, keeping: trimmedItems)
        items = trimmedItems

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

    private static var historyFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("PHTV", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("clipboard_history.json")
    }

    private func loadHistory() {
        // Migrate from UserDefaults if needed
        if let legacyData = UserDefaults.standard.data(forKey: UserDefaultsKey.clipboardHistoryData) {
            do {
                items = try JSONDecoder().decode([ClipboardHistoryItem].self, from: legacyData)
                trimItemsToConfiguredLimit()
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
            trimItemsToConfiguredLimit()
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

    private func trimItemsToConfiguredLimit() {
        let trimmedItems = ClipboardHistoryStoragePolicy.trimmed(
            items,
            maxItems: ClipboardHistoryStoragePolicy.maxItems()
        )
        guard trimmedItems != items else { return }
        cleanupCaches(forRemovedItemsFrom: items, keeping: trimmedItems)
        items = trimmedItems
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
