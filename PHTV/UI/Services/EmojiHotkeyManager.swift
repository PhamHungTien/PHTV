//
//  EmojiHotkeyManager.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit
import Carbon
import Combine

// MARK: - Emoji Hotkey Manager

/// Singleton manager for PHTV Picker hotkey
/// Monitors global keyboard events and triggers PHTV Picker when hotkey is pressed
@MainActor
final class EmojiHotkeyManager: ObservableObject {

    static let shared = EmojiHotkeyManager()

    nonisolated(unsafe) private var globalMonitor: Any?
    nonisolated(unsafe) private var localMonitor: Any?
    nonisolated(unsafe) private var settingsObserver: NSObjectProtocol?
    private var isEnabled: Bool = false
    private var modifiers: NSEvent.ModifierFlags = .command
    private var keyCode: UInt16 = 14  // E key default

    private init() {
        // Use block-based observer with .main queue for thread safety
        settingsObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("EmojiHotkeySettingsChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleSettingsChanged()
            }
        }

        // CRITICAL: Delay sync to avoid circular dependency during AppState.shared initialization
        // Use asyncAfter with minimal delay to break the dispatch_once recursion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                self.syncFromAppState(AppState.shared)
            }
        }
    }

    private func handleSettingsChanged() {
        // Delay to avoid circular dependency if called during AppState.shared initialization
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                self.syncFromAppState(AppState.shared)
            }
        }
    }
    
    @MainActor
    func syncFromAppState(_ appState: AppState) {
        let wasEnabled = isEnabled
        let oldModifiers = modifiers
        let oldKeyCode = keyCode

        isEnabled = appState.enableEmojiHotkey
        modifiers = appState.emojiHotkeyModifiers
        keyCode = appState.emojiHotkeyKeyCode

        if wasEnabled != isEnabled || oldModifiers != modifiers || oldKeyCode != keyCode {
            // CRITICAL: Save desired state BEFORE unregisterHotkey() modifies isEnabled
            let shouldEnable = isEnabled
            unregisterHotkey()

            if shouldEnable {
                registerHotkey(modifiers: modifiers, keyCode: keyCode)
            }
        }
    }
    
    func registerHotkey(modifiers: NSEvent.ModifierFlags, keyCode: UInt16) {
        unregisterHotkey()

        self.modifiers = modifiers
        self.keyCode = keyCode
        self.isEnabled = true

        // Capture values to avoid main-actor access from background thread
        let capturedKeyCode = self.keyCode
        let capturedModifiers = self.modifiers

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Dispatch to main thread to access self properties safely
            Task { @MainActor [weak self] in
                self?.handleKeyEvent(event)
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Quick check to consume event IMMEDIATELY if it matches hotkey
            // This prevents system beep sound
            // Use captured values to avoid main-actor isolation issues
            guard event.keyCode == capturedKeyCode else {
                return event
            }

            let relevantModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
            let eventModifiers = event.modifierFlags.intersection(relevantModifiers)

            guard eventModifiers == capturedModifiers else {
                return event
            }

            // Match! Consume event immediately to prevent beep
            Task { @MainActor in
                EmojiHotkeyManager.shared.openEmojiPicker()
            }

            // Return nil to consume the event and prevent system beep
            return nil
        }
    }
    
    func unregisterHotkey() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }

        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }

        isEnabled = false
    }

    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard event.keyCode == keyCode else {
            return false
        }

        let relevantModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        let eventModifiers = event.modifierFlags.intersection(relevantModifiers)

        guard eventModifiers == modifiers else {
            return false
        }

        openEmojiPicker()
        return true
    }

    private func openEmojiPicker() {
        DispatchQueue.main.async {
            EmojiPickerManager.shared.show()
        }
    }
    
    private func modifierSymbols(_ modifiers: NSEvent.ModifierFlags) -> String {
        var symbols = ""
        if modifiers.contains(.control) { symbols += "⌃" }
        if modifiers.contains(.option) { symbols += "⌥" }
        if modifiers.contains(.shift) { symbols += "⇧" }
        if modifiers.contains(.command) { symbols += "⌘" }
        return symbols
    }
    
    private func keyCodeSymbol(_ keyCode: UInt16) -> String {
        switch keyCode {
        case 41: return ";"
        case 14: return "E"
        case 49: return "Space"
        case 44: return "/"
        case 39: return "'"
        case 43: return ","
        case 47: return "."
        default:
            if let char = keyCodeToCharacter(keyCode) {
                return String(char)
            }
            return "Key\(keyCode)"
        }
    }
    
    private func keyCodeToCharacter(_ keyCode: UInt16) -> Character? {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: true)
        var length = 0
        event?.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: nil)

        if length > 0 {
            var chars: [UniChar] = Array(repeating: 0, count: length)
            event?.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &chars)
            if let scalar = UnicodeScalar(chars[0]) {
                return Character(scalar)
            }
        }

        return nil
    }

    deinit {
        if let observer = settingsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        // Cleanup monitors manually since we can't call main actor methods in deinit
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
