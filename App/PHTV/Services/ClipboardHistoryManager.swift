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
        items.removeAll { $0.isDuplicate(of: item) }

        // Insert at beginning
        items.insert(item, at: 0)
        items = ClipboardHistoryStoragePolicy.trimmed(
            items,
            maxItems: ClipboardHistoryStoragePolicy.maxItems()
        )

        saveHistory()
    }

    func removeItem(_ item: ClipboardHistoryItem) {
        items.removeAll { $0.id == item.id }
        saveHistory()
    }

    func clearAll() {
        items.removeAll()
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
        items = trimmedItems
        saveHistory()
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

        // Set pasteboard content based on item type
        if let filePaths = item.filePaths, !filePaths.isEmpty {
            let urls = filePaths.compactMap { URL(fileURLWithPath: $0) as NSURL }
            pasteboard.writeObjects(urls)
        } else if let imageData = item.imageData, let image = NSImage(data: imageData) {
            pasteboard.writeObjects([image])
        } else if let text = item.textContent {
            pasteboard.setString(text, forType: .string)
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

        clearPastingTask?.cancel()
        clearPastingTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            self?.isPasting = false
        }
    }
}
