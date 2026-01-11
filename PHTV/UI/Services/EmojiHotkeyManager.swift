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
final class EmojiHotkeyManager: ObservableObject, @unchecked Sendable {

    static let shared = EmojiHotkeyManager()

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isEnabled: Bool = false
    private var modifiers: NSEvent.ModifierFlags = .command
    private var keyCode: UInt16 = 14  // E key default

    private init() {
        NSLog("[EmojiHotkey] EmojiHotkeyManager initialized")

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsChanged),
            name: NSNotification.Name("EmojiHotkeySettingsChanged"),
            object: nil
        )

        // CRITICAL: Delay sync to avoid circular dependency during AppState.shared initialization
        // Use asyncAfter with minimal delay to break the dispatch_once recursion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                self.syncFromAppState(AppState.shared)
            }
        }
    }

    @objc private func handleSettingsChanged() {
        NSLog("[EmojiHotkey] Settings changed notification received")
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
        NSLog("SYNC-START: enabled=%d, modifiers=%lu, keyCode=%d", appState.enableEmojiHotkey ? 1 : 0, UInt(appState.emojiHotkeyModifiers.rawValue), appState.emojiHotkeyKeyCode)

        let wasEnabled = isEnabled
        let oldModifiers = modifiers
        let oldKeyCode = keyCode

        isEnabled = appState.enableEmojiHotkey
        modifiers = appState.emojiHotkeyModifiers
        keyCode = appState.emojiHotkeyKeyCode

        NSLog("SYNC-CHANGE-CHECK: wasEnabled=%d, isEnabled=%d", wasEnabled ? 1 : 0, isEnabled ? 1 : 0)

        if wasEnabled != isEnabled || oldModifiers != modifiers || oldKeyCode != keyCode {
            NSLog("SYNC-WILL-UPDATE")
            // CRITICAL: Save desired state BEFORE unregisterHotkey() modifies isEnabled
            let shouldEnable = isEnabled
            unregisterHotkey()

            if shouldEnable {
                NSLog("SYNC-WILL-REGISTER")
                registerHotkey(modifiers: modifiers, keyCode: keyCode)
            }

            if shouldEnable {
                NSLog("[EmojiHotkey] Registered: %@%@", modifierSymbols(modifiers), keyCodeSymbol(keyCode))
            } else {
                NSLog("[EmojiHotkey] Disabled")
            }
        } else {
            NSLog("SYNC-NO-CHANGE")
        }
    }
    
    func registerHotkey(modifiers: NSEvent.ModifierFlags, keyCode: UInt16) {
        NSLog("REGISTER-START: modifiers=%lu, keyCode=%d", UInt(modifiers.rawValue), keyCode)
        unregisterHotkey()

        self.modifiers = modifiers
        self.keyCode = keyCode
        self.isEnabled = true

        NSLog("REGISTER-ADDING-MONITORS")
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            NSLog("GLOBAL-MONITOR-FIRED")
            self?.handleKeyEvent(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

            // Quick check to consume event IMMEDIATELY if it matches hotkey
            // This prevents system beep sound
            guard event.keyCode == self.keyCode else {
                return event
            }

            let relevantModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
            let eventModifiers = event.modifierFlags.intersection(relevantModifiers)

            guard eventModifiers == self.modifiers else {
                return event
            }

            // Match! Consume event immediately to prevent beep
            NSLog("[EmojiHotkey] Hotkey matched, opening picker")
            DispatchQueue.main.async {
                self.openEmojiPicker()
            }

            // Return nil to consume the event and prevent system beep
            return nil
        }

        NSLog("REGISTER-COMPLETE: globalMonitor=%@, localMonitor=%@", globalMonitor != nil ? "YES" : "NO", localMonitor != nil ? "YES" : "NO")
        NSLog("[EmojiHotkey] Hotkey registered: %@%@", modifierSymbols(modifiers), keyCodeSymbol(keyCode))
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

        NSLog("[EmojiHotkey] Hotkey unregistered")
    }
    
    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        NSLog("HANDLE-KEY: keyCode=%d (expecting %d)", event.keyCode, keyCode)

        guard event.keyCode == keyCode else {
            return false
        }

        let relevantModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        let eventModifiers = event.modifierFlags.intersection(relevantModifiers)

        NSLog("HANDLE-KEY-MODIFIERS: event=%lu, expected=%lu", UInt(eventModifiers.rawValue), UInt(modifiers.rawValue))

        guard eventModifiers == modifiers else {
            return false
        }

        NSLog("HANDLE-KEY-MATCH! Opening PHTV Picker")

        openEmojiPicker()
        return true
    }
    
    private func openEmojiPicker() {
        NSLog("[EmojiHotkey] Opening PHTV Picker...")

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
}
