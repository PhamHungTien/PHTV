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
final class ClipboardHotkeyManager {

    static let shared = ClipboardHotkeyManager()

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var globalFlagsMonitor: Any?
    private var localFlagsMonitor: Any?
    private var settingsObservationTask: Task<Void, Never>?
    private var settingsRefreshTask: Task<Void, Never>?
    private var initialSyncTask: Task<Void, Never>?
    private let carbonHotkeyRegistration = PHTVCarbonHotkeyRegistration(
        signature: 0x50434C50 // "PCLP"
    ) {
        Task { @MainActor in
            ClipboardHistoryManager.shared.toggleVisibility()
        }
    }
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
        settingsObservationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await _ in NotificationCenter.default.notifications(named: NotificationName.clipboardHotkeySettingsChanged) {
                guard !Task.isCancelled else { break }
                self.handleSettingsChanged()
            }
        }

        initialSyncTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(100))
            guard let self, !Task.isCancelled else { return }
            self.syncFromAppState(AppState.shared)
        }
    }

    private func handleSettingsChanged() {
        settingsRefreshTask?.cancel()
        settingsRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(50))
            guard let self, !Task.isCancelled else { return }
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

        let deviceFlagsMask = NSEvent.ModifierFlags(rawValue: 0x0001 | 0x0002 | 0x0004 | 0x0008 | 0x0010 | 0x0020 | 0x0040 | 0x2000)
        let allowedModifiersMask = Self.relevantModifiers.union(deviceFlagsMask)
        let filteredModifiers = modifiers.intersection(allowedModifiersMask)
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
        } else if carbonHotkeyRegistration.register(modifiers: capturedModifiers, keyCode: capturedKeyCode) {
            // Carbon global hotkeys consume the key combo system-wide, preventing printable Option shortcuts from leaking through.
        } else {
            registerKeyDownHotkey(capturedKeyCode: capturedKeyCode, capturedModifiers: capturedModifiers, relevantModifiers: capturedRelevantModifiers)
        }
    }

    private func registerKeyDownHotkey(capturedKeyCode: UInt16, capturedModifiers: NSEvent.ModifierFlags, relevantModifiers: NSEvent.ModifierFlags) {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleKeyEvent(event)
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard event.keyCode == capturedKeyCode else { return event }
            
            guard self.matchesModifiers(expected: capturedModifiers, actual: event.modifierFlags) else {
                return event
            }

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
            Task { @MainActor [weak self] in
                self?.keyPressedWhileModifiersHeld = true
            }
            return event
        }

        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleFlagsChanged(event, capturedModifiers: filteredCapturedModifiers, relevantModifiers: relevantModifiers)
            }
        }

        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleFlagsChanged(event, capturedModifiers: filteredCapturedModifiers, relevantModifiers: relevantModifiers)
            }
            return event
        }
    }

    private func handleFlagsChanged(_ event: NSEvent, capturedModifiers: NSEvent.ModifierFlags, relevantModifiers: NSEvent.ModifierFlags) {
        let currentFlags = event.modifierFlags
        let currentIndependent = currentFlags.intersection(relevantModifiers)
        let lastIndependent = lastModifierFlags.intersection(relevantModifiers)

        if currentIndependent.rawValue > lastIndependent.rawValue {
            lastModifierFlags = currentFlags
            keyPressedWhileModifiersHeld = false
        } else if currentIndependent.rawValue < lastIndependent.rawValue {
            if !keyPressedWhileModifiersHeld && matchesModifiers(expected: capturedModifiers, actual: lastModifierFlags) {
                Task { @MainActor in
                    ClipboardHotkeyManager.shared.openClipboardHistory()
                }
            }
            lastModifierFlags = currentFlags
            if currentIndependent.isEmpty {
                keyPressedWhileModifiersHeld = false
            }
        }
    }

    func unregisterHotkey() {
        carbonHotkeyRegistration.unregister()

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
        
        guard matchesModifiers(expected: modifiers, actual: event.modifierFlags) else {
            return false
        }
        
        openClipboardHistory()
        return true
    }

    private func matchesModifiers(expected: NSEvent.ModifierFlags, actual: NSEvent.ModifierFlags) -> Bool {
        let relevant = expected.intersection(Self.relevantModifiers)
        let actualRelevant = actual.intersection(Self.relevantModifiers)
        guard relevant == actualRelevant else { return false }
        
        let expectedRaw = UInt64(expected.rawValue)
        let actualRaw = UInt64(actual.rawValue)
        
        // Alternate/Option
        if expected.contains(.option) {
            let leftExpected = (expectedRaw & 0x0020) != 0
            let rightExpected = (expectedRaw & 0x0040) != 0
            if leftExpected || rightExpected {
                let leftActual = (actualRaw & 0x0020) != 0
                let rightActual = (actualRaw & 0x0040) != 0
                if leftExpected && !leftActual { return false }
                if rightExpected && !rightActual { return false }
            }
        }
        
        // Command
        if expected.contains(.command) {
            let leftExpected = (expectedRaw & 0x0008) != 0
            let rightExpected = (expectedRaw & 0x0010) != 0
            if leftExpected || rightExpected {
                let leftActual = (actualRaw & 0x0008) != 0
                let rightActual = (actualRaw & 0x0010) != 0
                if leftExpected && !leftActual { return false }
                if rightExpected && !rightActual { return false }
            }
        }
        
        // Control
        if expected.contains(.control) {
            let leftExpected = (expectedRaw & 0x0001) != 0
            let rightExpected = (expectedRaw & 0x2000) != 0
            if leftExpected || rightExpected {
                let leftActual = (actualRaw & 0x0001) != 0
                let rightActual = (actualRaw & 0x2000) != 0
                if leftExpected && !leftActual { return false }
                if rightExpected && !rightActual { return false }
            }
        }
        
        // Shift
        if expected.contains(.shift) {
            let leftExpected = (expectedRaw & 0x0002) != 0
            let rightExpected = (expectedRaw & 0x0004) != 0
            if leftExpected || rightExpected {
                let leftActual = (actualRaw & 0x0002) != 0
                let rightActual = (actualRaw & 0x0004) != 0
                if leftExpected && !leftActual { return false }
                if rightExpected && !rightActual { return false }
            }
        }
        
        return true
    }

    private func openClipboardHistory() {
        ClipboardHistoryManager.shared.toggleVisibility()
    }
}
