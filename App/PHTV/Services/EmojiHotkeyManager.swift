//
//  EmojiHotkeyManager.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit
import Carbon

// MARK: - Emoji Hotkey Manager

/// Singleton manager for PHTV Picker hotkey
/// Monitors global keyboard events and triggers PHTV Picker when hotkey is pressed
/// Supports both key+modifier combos and modifier-only mode (including Fn key)
@MainActor
final class EmojiHotkeyManager: ObservableObject {

    static let shared = EmojiHotkeyManager()

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var globalFlagsMonitor: Any?
    private var localFlagsMonitor: Any?
    private var settingsObserver: NSObjectProtocol?
    private var isEnabled: Bool = false
    private var modifiers: NSEvent.ModifierFlags = .command
    private var keyCode: UInt16 = KeyCode.eKey

    // Modifier-only mode tracking
    private var lastModifierFlags: NSEvent.ModifierFlags = []
    private var keyPressedWhileModifiersHeld: Bool = false

    private var isModifierOnlyMode: Bool {
        keyCode == KeyCode.noKey
    }

    /// Relevant modifiers including Fn (.function)
    private static let relevantModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift, .function]

    private init() {
        // Use block-based observer with .main queue for thread safety
        settingsObserver = NotificationCenter.default.addObserver(
            forName: NotificationName.emojiHotkeySettingsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleSettingsChanged()
            }
        }

        // CRITICAL: Delay sync to avoid circular dependency during AppState.shared initialization
        // Use asyncAfter with minimal delay to break the dispatch_once recursion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            self.syncFromAppState(AppState.shared)
        }
    }

    private func handleSettingsChanged() {
        // Delay to avoid circular dependency if called during AppState.shared initialization
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self else { return }
            self.syncFromAppState(AppState.shared)
        }
    }

    func syncFromAppState(_ appState: AppState, forceReregister: Bool = false) {
        let desiredEnabled = appState.enableEmojiHotkey
        let desiredModifiers = appState.emojiHotkeyModifiers
        let desiredKeyCode = appState.emojiHotkeyKeyCode
        let settingsChanged = (isEnabled != desiredEnabled)
            || (modifiers != desiredModifiers)
            || (keyCode != desiredKeyCode)

        guard settingsChanged || forceReregister else {
            return
        }

        // Keep manager state in sync before re-registering monitors.
        isEnabled = desiredEnabled
        modifiers = desiredModifiers
        keyCode = desiredKeyCode

        unregisterHotkey()
        if desiredEnabled {
            registerHotkey(modifiers: desiredModifiers, keyCode: desiredKeyCode)
        }
    }

    func refreshRegistrationFromAppState() {
        syncFromAppState(AppState.shared, forceReregister: true)
    }

    func registerHotkey(modifiers: NSEvent.ModifierFlags, keyCode: UInt16) {
        unregisterHotkey()

        self.modifiers = modifiers
        self.keyCode = keyCode
        self.isEnabled = true

        // Capture values to avoid main-actor access from background thread
        let capturedKeyCode = self.keyCode
        let capturedModifiers = self.modifiers
        let capturedRelevantModifiers = Self.relevantModifiers

        if keyCode == KeyCode.noKey {
            // Modifier-only mode: monitor flagsChanged events
            registerModifierOnlyHotkey(capturedModifiers: capturedModifiers, relevantModifiers: capturedRelevantModifiers)
        } else {
            // Key+modifier mode: monitor keyDown events
            registerKeyDownHotkey(capturedKeyCode: capturedKeyCode, capturedModifiers: capturedModifiers, relevantModifiers: capturedRelevantModifiers)
        }
    }

    private func registerKeyDownHotkey(capturedKeyCode: UInt16, capturedModifiers: NSEvent.ModifierFlags, relevantModifiers: NSEvent.ModifierFlags) {
        let filteredCapturedModifiers = capturedModifiers.intersection(relevantModifiers)

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleKeyEvent(event)
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Quick check to consume event IMMEDIATELY if it matches hotkey
            // This prevents system beep sound
            guard event.keyCode == capturedKeyCode else {
                return event
            }

            let eventModifiers = event.modifierFlags.intersection(relevantModifiers)

            guard eventModifiers == filteredCapturedModifiers else {
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

    private func registerModifierOnlyHotkey(capturedModifiers: NSEvent.ModifierFlags, relevantModifiers: NSEvent.ModifierFlags) {
        let filteredCapturedModifiers = capturedModifiers.intersection(relevantModifiers)

        // Also monitor keyDown to track if any key is pressed while modifiers are held
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.keyPressedWhileModifiersHeld = true
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if Thread.isMainThread {
                self?.keyPressedWhileModifiersHeld = true
            } else {
                Task { @MainActor [weak self] in
                    self?.keyPressedWhileModifiersHeld = true
                }
            }
            return event
        }

        // Monitor flagsChanged for modifier press/release
        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleFlagsChanged(
                    event,
                    capturedModifiers: filteredCapturedModifiers,
                    relevantModifiers: relevantModifiers
                )
            }
        }

        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            if Thread.isMainThread {
                self?.handleFlagsChanged(
                    event,
                    capturedModifiers: filteredCapturedModifiers,
                    relevantModifiers: relevantModifiers
                )
            } else {
                Task { @MainActor [weak self] in
                    self?.handleFlagsChanged(
                        event,
                        capturedModifiers: filteredCapturedModifiers,
                        relevantModifiers: relevantModifiers
                    )
                }
            }
            return event
        }
    }

    private func handleFlagsChanged(_ event: NSEvent, capturedModifiers: NSEvent.ModifierFlags, relevantModifiers: NSEvent.ModifierFlags) {
        let currentFlags = event.modifierFlags.intersection(relevantModifiers)

        if currentFlags.rawValue > lastModifierFlags.rawValue {
            // Pressing more modifiers
            lastModifierFlags = currentFlags
            keyPressedWhileModifiersHeld = false
        } else if currentFlags.rawValue < lastModifierFlags.rawValue {
            // Releasing modifiers - check if the combo matched
            if !keyPressedWhileModifiersHeld && lastModifierFlags == capturedModifiers {
                Task { @MainActor in
                    EmojiHotkeyManager.shared.openEmojiPicker()
                }
            }
            lastModifierFlags = currentFlags
            if currentFlags.isEmpty {
                keyPressedWhileModifiersHeld = false
            }
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

        if let monitor = globalFlagsMonitor {
            NSEvent.removeMonitor(monitor)
            globalFlagsMonitor = nil
        }

        if let monitor = localFlagsMonitor {
            NSEvent.removeMonitor(monitor)
            localFlagsMonitor = nil
        }

        isEnabled = false
        lastModifierFlags = []
        keyPressedWhileModifiersHeld = false
    }

    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard event.keyCode == keyCode else {
            return false
        }

        let eventModifiers = event.modifierFlags.intersection(Self.relevantModifiers)
        let expectedModifiers = modifiers.intersection(Self.relevantModifiers)

        guard eventModifiers == expectedModifiers else {
            return false
        }

        openEmojiPicker()
        return true
    }

    private func openEmojiPicker() {
        EmojiPickerManager.shared.show()
    }

    private func modifierSymbols(_ modifiers: NSEvent.ModifierFlags) -> String {
        var symbols = ""
        if modifiers.contains(.function) { symbols += "fn" }
        if modifiers.contains(.control) { symbols += "⌃" }
        if modifiers.contains(.option) { symbols += "⌥" }
        if modifiers.contains(.shift) { symbols += "⇧" }
        if modifiers.contains(.command) { symbols += "⌘" }
        return symbols
    }

    private func keyCodeSymbol(_ keyCode: UInt16) -> String {
        switch keyCode {
        case 41: return ";"
        case KeyCode.eKey: return "E"
        case KeyCode.space: return "Space"
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
