//
//  ClipboardHotkeyManager.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit
import Carbon

/// Singleton manager for Clipboard History hotkey
/// Monitors global keyboard events and triggers Clipboard History panel when hotkey is pressed
@MainActor
final class ClipboardHotkeyManager: ObservableObject {

    static let shared = ClipboardHotkeyManager()

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var globalFlagsMonitor: Any?
    private var localFlagsMonitor: Any?
    private var settingsObserver: NSObjectProtocol?
    private var isEnabled: Bool = false
    private var modifiers: NSEvent.ModifierFlags = .control
    private var keyCode: UInt16 = KeyCode.vKey

    private var lastModifierFlags: NSEvent.ModifierFlags = []
    private var keyPressedWhileModifiersHeld: Bool = false

    private var isModifierOnlyMode: Bool {
        keyCode == KeyCode.noKey
    }

    private static let relevantModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift, .function]

    private init() {
        settingsObserver = NotificationCenter.default.addObserver(
            forName: NotificationName.clipboardHotkeySettingsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleSettingsChanged()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            self.syncFromAppState(AppState.shared)
        }
    }

    private func handleSettingsChanged() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self else { return }
            self.syncFromAppState(AppState.shared)
        }
    }

    func syncFromAppState(_ appState: AppState, forceReregister: Bool = false) {
        let desiredEnabled = appState.enableClipboardHistory
        let desiredModifiers = appState.clipboardHotkeyModifiers
        let desiredKeyCode = appState.clipboardHotkeyKeyCode
        let settingsChanged = (isEnabled != desiredEnabled)
            || (modifiers != desiredModifiers)
            || (keyCode != desiredKeyCode)

        guard settingsChanged || forceReregister else { return }

        isEnabled = desiredEnabled
        modifiers = desiredModifiers
        keyCode = desiredKeyCode

        unregisterHotkey()

        if desiredEnabled {
            registerHotkey(modifiers: desiredModifiers, keyCode: desiredKeyCode)

            // Start/ensure clipboard monitor is running
            ClipboardMonitor.shared.startMonitoring()
        } else {
            ClipboardMonitor.shared.stopMonitoring()
        }
    }

    func refreshRegistrationFromAppState() {
        syncFromAppState(AppState.shared, forceReregister: true)
    }

    func registerHotkey(modifiers: NSEvent.ModifierFlags, keyCode: UInt16) {
        unregisterHotkey()

        let filteredModifiers = modifiers.intersection(Self.relevantModifiers)
        let normalizedModifiers = filteredModifiers.isEmpty ? NSEvent.ModifierFlags.control : filteredModifiers
        let normalizedKeyCode: UInt16
        if keyCode <= KeyCode.keyMask || keyCode == KeyCode.noKey {
            normalizedKeyCode = keyCode
        } else {
            normalizedKeyCode = KeyCode.vKey
        }

        self.modifiers = normalizedModifiers
        self.keyCode = normalizedKeyCode
        self.isEnabled = true

        let capturedKeyCode = self.keyCode
        let capturedModifiers = self.modifiers
        let capturedRelevantModifiers = Self.relevantModifiers

        if capturedKeyCode == KeyCode.noKey {
            registerModifierOnlyHotkey(capturedModifiers: capturedModifiers, relevantModifiers: capturedRelevantModifiers)
        } else {
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
            guard event.keyCode == capturedKeyCode else { return event }
            let eventModifiers = event.modifierFlags.intersection(relevantModifiers)
            guard eventModifiers == filteredCapturedModifiers else { return event }

            Task { @MainActor in
                ClipboardHotkeyManager.shared.openClipboardHistory()
            }
            return nil
        }
    }

    private func registerModifierOnlyHotkey(capturedModifiers: NSEvent.ModifierFlags, relevantModifiers: NSEvent.ModifierFlags) {
        let filteredCapturedModifiers = capturedModifiers.intersection(relevantModifiers)

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

        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleFlagsChanged(event, capturedModifiers: filteredCapturedModifiers, relevantModifiers: relevantModifiers)
            }
        }

        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            if Thread.isMainThread {
                self?.handleFlagsChanged(event, capturedModifiers: filteredCapturedModifiers, relevantModifiers: relevantModifiers)
            } else {
                Task { @MainActor [weak self] in
                    self?.handleFlagsChanged(event, capturedModifiers: filteredCapturedModifiers, relevantModifiers: relevantModifiers)
                }
            }
            return event
        }
    }

    private func handleFlagsChanged(_ event: NSEvent, capturedModifiers: NSEvent.ModifierFlags, relevantModifiers: NSEvent.ModifierFlags) {
        let currentFlags = event.modifierFlags.intersection(relevantModifiers)

        if currentFlags.rawValue > lastModifierFlags.rawValue {
            lastModifierFlags = currentFlags
            keyPressedWhileModifiersHeld = false
        } else if currentFlags.rawValue < lastModifierFlags.rawValue {
            if !keyPressedWhileModifiersHeld && lastModifierFlags == capturedModifiers {
                Task { @MainActor in
                    ClipboardHotkeyManager.shared.openClipboardHistory()
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
        guard event.keyCode == keyCode else { return false }
        let eventModifiers = event.modifierFlags.intersection(Self.relevantModifiers)
        let expectedModifiers = modifiers.intersection(Self.relevantModifiers)
        guard eventModifiers == expectedModifiers else { return false }
        openClipboardHistory()
        return true
    }

    private func openClipboardHistory() {
        ClipboardHistoryManager.shared.show()
    }
}
