//
//  ClipboardItemHotkeyManager.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit
import Observation

/// Registers the direct-paste shortcuts attached to pinned history and saved
/// clipboard items. It deliberately uses the same Carbon registration layer as
/// the Clipboard History and Emoji pickers, so registered shortcuts are global
/// and consumed instead of leaking into the app currently being typed in.
@Observable
@MainActor
final class ClipboardItemHotkeyManager {
    static let shared = ClipboardItemHotkeyManager()

    private enum Target: Hashable {
        case pinnedHistory(UUID)
        case savedItem(UUID)
    }

    private var registrations: [ClipboardItemHotkey: PHTVCarbonHotkeyRegistration] = [:]
    private var observationTasks: [Task<Void, Never>] = []
    private(set) var unavailableHotkeys: Set<ClipboardItemHotkey> = []

    private init() {
        observe(NotificationName.clipboardItemHotkeysChanged)
        // Existing PHTV picker shortcuts can change after an item shortcut was
        // configured; refresh to keep the item shortcut from shadowing them.
        observe(NotificationName.clipboardHotkeySettingsChanged)
        observe(NotificationName.emojiHotkeySettingsChanged)
    }

    func refreshRegistrations() {
        registrations.values.forEach { $0.unregister() }
        registrations.removeAll()
        unavailableHotkeys.removeAll()

        let assignments = currentAssignments()
        var seenHotkeys = Set<ClipboardItemHotkey>()
        for (offset, assignment) in assignments.enumerated() {
            let (hotkey, target) = assignment
            guard seenHotkeys.insert(hotkey).inserted else {
                unavailableHotkeys.insert(hotkey)
                continue
            }
            guard !conflictsWithPickerShortcut(hotkey) else {
                unavailableHotkeys.insert(hotkey)
                continue
            }

            let registration = PHTVCarbonHotkeyRegistration(
                signature: 0x50434954, // "PCIT" — PHTV Clipboard Item
                registrationID: UInt32(offset + 1)
            ) { [target] in
                Task { @MainActor in
                    switch target {
                    case .pinnedHistory(let id):
                        ClipboardHistoryManager.shared.pastePinnedItemImmediately(id: id)
                    case .savedItem(let id):
                        ClipboardHistoryManager.shared.pasteSavedItemImmediately(id: id)
                    }
                }
            }

            if registration.register(modifiers: hotkey.modifiers, keyCode: hotkey.keyCode) {
                registrations[hotkey] = registration
            } else {
                unavailableHotkeys.insert(hotkey)
            }
        }
    }

    func isAvailable(_ hotkey: ClipboardItemHotkey?) -> Bool {
        guard let hotkey else { return true }
        return !unavailableHotkeys.contains(hotkey)
    }

    private func observe(_ name: NSNotification.Name) {
        observationTasks.append(Task { @MainActor [weak self] in
            for await _ in NotificationCenter.default.notifications(named: name) {
                guard let self, !Task.isCancelled else { break }
                self.refreshRegistrations()
            }
        })
    }

    private func currentAssignments() -> [(ClipboardItemHotkey, Target)] {
        let manager = ClipboardHistoryManager.shared
        let pinnedItems = manager.items.compactMap { item -> (ClipboardItemHotkey, Target)? in
            guard item.isPinned, let hotkey = item.hotkey, hotkey.isValid else { return nil }
            return (hotkey, .pinnedHistory(item.id))
        }
        let savedItems = manager.savedLibrary.items.compactMap { item -> (ClipboardItemHotkey, Target)? in
            guard let hotkey = item.hotkey, hotkey.isValid else { return nil }
            return (hotkey, .savedItem(item.id))
        }
        return pinnedItems + savedItems
    }

    private func conflictsWithPickerShortcut(_ hotkey: ClipboardItemHotkey) -> Bool {
        let appState = AppState.shared
        if appState.enableClipboardHistory,
           ClipboardItemHotkey(
                modifiers: appState.clipboardHotkeyModifiers,
                keyCode: appState.clipboardHotkeyKeyCode
           ) == hotkey {
            return true
        }
        if appState.enableEmojiHotkey,
           ClipboardItemHotkey(
                modifiers: appState.emojiHotkeyModifiers,
                keyCode: appState.emojiHotkeyKeyCode
           ) == hotkey {
            return true
        }
        return false
    }
}
