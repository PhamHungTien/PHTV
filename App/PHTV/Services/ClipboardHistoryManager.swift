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

@MainActor
final class ClipboardHistoryManager: ObservableObject {
    static let shared = ClipboardHistoryManager()

    @Published private(set) var items: [ClipboardHistoryItem] = []

    private let showDebounceInterval: CFAbsoluteTime = 0.20
    private var panel: FloatingPanel<ClipboardHistoryView>?
    private var previousApp: NSRunningApplication?
    private var lastShowRequestTime: CFAbsoluteTime = 0
    var isPasting = false

    private init() {
        loadHistory()
    }

    // MARK: - Data Management

    func addItem(_ item: ClipboardHistoryItem) {
        // Remove duplicate if exists
        items.removeAll { $0.isDuplicate(of: item) }

        // Insert at beginning
        items.insert(item, at: 0)

        // Trim to max items
        let maxItems = AppState.shared.clipboardHistoryMaxItems
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }

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

    // MARK: - UI Show/Hide

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
    }

    func hide() {
        panel?.close()
        panel = nil

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
