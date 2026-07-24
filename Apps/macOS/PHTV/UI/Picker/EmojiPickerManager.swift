//
//  EmojiPickerManager.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import AppKit
import Carbon

@MainActor
class EmojiPickerManager {
    static let shared = EmojiPickerManager()

    private let panelSession = FloatingPanelSession<EmojiPickerView>()
    private var previousApp: NSRunningApplication?
    private var hotkeyGate = FloatingPanelHotkeyGate()
    private var restoreFocusTask: Task<Void, Never>?
    private var pendingPasteTask: Task<Void, Never>?

    private init() {}

    /// Shows the PHTV Picker at current mouse position
    func show() {
        guard hotkeyGate.shouldAccept(at: ProcessInfo.processInfo.systemUptime) else {
            NSLog("[PHTPPicker] Ignored duplicate show request (debounced)")
            return
        }

        restoreFocusTask?.cancel()
        restoreFocusTask = nil

        if panelSession.focusIfVisible() {
            return
        }

        NSLog("[PHTPPicker] Showing PHTV Picker at mouse position")

        // Save the currently active app so we can restore focus later
        previousApp = NSWorkspace.shared.frontmostApplication
        if let appName = previousApp?.localizedName {
            NSLog("[PHTPPicker] Saved previous app: %@", appName)
        }

        // Create new panel with PHTV Picker view
        let emojiPickerView = EmojiPickerView(
            onEmojiSelected: { [weak self] emoji in
                self?.handleEmojiSelected(emoji)
            },
            onClose: { [weak self] in
                self?.hide()
            }
        )

        let contentRect = NSRect(x: 0, y: 0, width: 380, height: 480)
        let newPanel = FloatingPanel(view: emojiPickerView, contentRect: contentRect)
        panelSession.present(newPanel) { [weak self] in
            self?.restorePreviousAppFocus()
        }

        NSLog("[EmojiPicker] Panel shown")
    }

    /// Hides the PHTV Picker and restores focus to previous app
    func hide() {
        NSLog("[PHTPPicker] Hiding PHTV Picker")
        panelSession.dismiss()
    }

    private func restorePreviousAppFocus() {
        // Restore focus to the previous app with a small delay
        // to ensure panel is fully closed first
        restoreFocusTask?.cancel()
        restoreFocusTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled, let app = self?.previousApp else { return }
            NSLog("[PHTPPicker] Restoring focus to: %@", app.localizedName ?? "Unknown")
            _ = app.activate()
        }
    }

    /// Handles emoji selection - pastes emoji to frontmost app
    private func handleEmojiSelected(_ emoji: String) {
        NSLog("[EmojiPicker] Emoji selected: %@", emoji)

        // Record emoji usage for recent & frequency tracking
        EmojiDatabase.shared.recordUsage(emoji)

        // Close panel
        hide()

        // Small delay to allow panel to close and frontmost app to regain focus
        pendingPasteTask?.cancel()
        pendingPasteTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(100))
            guard let self, !Task.isCancelled else { return }
            self.pasteEmoji(emoji)
        }
    }

    /// Pastes emoji using CGEvent to simulate typing
    private func pasteEmoji(_ emoji: String) {
        NSLog("[EmojiPicker] Pasting emoji: %@", emoji)

        // Method 1: Use pasteboard (most reliable)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(emoji, forType: .string)

        // Simulate Command+V to paste
        let source = CGEventSource(stateID: .hidSystemState)

        // Press Command
        if let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: true) {
            cmdDown.flags = .maskCommand
            cmdDown.post(tap: .cgSessionEventTap)
        }

        // Press V
        if let vDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true) {
            vDown.flags = .maskCommand
            vDown.post(tap: .cgSessionEventTap)
        }

        // Release V
        if let vUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false) {
            vUp.flags = .maskCommand
            vUp.post(tap: .cgSessionEventTap)
        }

        // Release Command
        if let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: false) {
            cmdUp.post(tap: .cgSessionEventTap)
        }

        NSLog("[EmojiPicker] Paste command sent")
    }
}
