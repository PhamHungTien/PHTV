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

@MainActor
final class ClipboardHistoryManager: ObservableObject {
    static let shared = ClipboardHistoryManager()

    @Published private(set) var items: [ClipboardHistoryItem] = []

    private let showDebounceInterval: CFAbsoluteTime = 0.20
    private var panel: FloatingPanel<ClipboardHistoryView>?
    private var previousApp: NSRunningApplication?
    private var lastShowRequestTime: CFAbsoluteTime = 0
    private var settingsObserver: NSObjectProtocol?
    private var panelResignKeyObserver: NSObjectProtocol?
    var isPasting = false

    var isVisible: Bool {
        panel?.isVisible == true
    }

    private init() {
        loadHistory()

        settingsObserver = NotificationCenter.default.addObserver(
            forName: NotificationName.clipboardHotkeySettingsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.trimItemsToConfiguredLimit()
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

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: UserDefaultsKey.clipboardHistoryData) else { return }
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
            UserDefaults.standard.set(data, forKey: UserDefaultsKey.clipboardHistoryData)
        } catch {
            NSLog("[ClipboardHistory] Failed to encode history: %@", error.localizedDescription)
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

        DispatchQueue.main.async { [weak self] in
            self?.panel?.makeKey()
        }

        panelResignKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.hide() }
        }
    }

    func hide() {
        if let observer = panelResignKeyObserver {
            NotificationCenter.default.removeObserver(observer)
            panelResignKeyObserver = nil
        }
        panel?.close()
        panel = nil
        lastShowRequestTime = 0

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            if let app = self?.previousApp {
                app.activate(options: [.activateIgnoringOtherApps])
            }
        }
    }

    // MARK: - Paste

    private func handleItemSelected(_ item: ClipboardHistoryItem) {
        hide()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.isPasting = false
        }
    }
}
