//
//  ClipboardHistoryState.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import AppKit
import Combine

/// Manages clipboard history settings
@MainActor
final class ClipboardHistoryState: ObservableObject {
    @Published var enableClipboardHistory: Bool = false
    @Published var clipboardHotkeyModifiersRaw: Int = Int(NSEvent.ModifierFlags.control.rawValue)
    @Published var clipboardHotkeyKeyCode: UInt16 = KeyCode.vKey
    @Published var clipboardHistoryMaxItems: Int = 30

    var clipboardHotkeyModifiers: NSEvent.ModifierFlags {
        get {
            NSEvent.ModifierFlags(rawValue: UInt(clipboardHotkeyModifiersRaw))
        }
        set {
            clipboardHotkeyModifiersRaw = Int(newValue.rawValue)
            NotificationCenter.default.post(name: NotificationName.clipboardHotkeySettingsChanged, object: nil)
        }
    }

    private var cancellables = Set<AnyCancellable>()
    var isLoadingSettings = false

    init() {}

    // MARK: - Load/Save Settings

    func loadSettings() {
        let defaults = UserDefaults.standard

        enableClipboardHistory = defaults.bool(
            forKey: UserDefaultsKey.enableClipboardHistory,
            default: Defaults.enableClipboardHistory
        )
        clipboardHotkeyModifiersRaw = defaults.integer(
            forKey: UserDefaultsKey.clipboardHotkeyModifiers,
            default: Int(Defaults.clipboardHotkeyModifiers)
        )
        if clipboardHotkeyModifiersRaw == 0 {
            clipboardHotkeyModifiersRaw = Int(Defaults.clipboardHotkeyModifiers)
        }

        let keyCodeObject = defaults.object(forKey: UserDefaultsKey.clipboardHotkeyKeyCode)
        if keyCodeObject == nil {
            clipboardHotkeyKeyCode = Defaults.clipboardHotkeyKeyCode
        } else {
            let savedKeyCode = defaults.integer(
                forKey: UserDefaultsKey.clipboardHotkeyKeyCode,
                default: Int(Defaults.clipboardHotkeyKeyCode)
            )
            if (0...Int(KeyCode.keyMask)).contains(savedKeyCode) || savedKeyCode == Int(KeyCode.noKey) {
                clipboardHotkeyKeyCode = UInt16(savedKeyCode)
            } else {
                clipboardHotkeyKeyCode = Defaults.clipboardHotkeyKeyCode
                defaults.set(Int(Defaults.clipboardHotkeyKeyCode), forKey: UserDefaultsKey.clipboardHotkeyKeyCode)
            }
        }

        clipboardHistoryMaxItems = defaults.integer(
            forKey: UserDefaultsKey.clipboardHistoryMaxItems,
            default: Defaults.clipboardHistoryMaxItems
        )
        if clipboardHistoryMaxItems < 10 { clipboardHistoryMaxItems = 10 }
        if clipboardHistoryMaxItems > 100 { clipboardHistoryMaxItems = 100 }
    }

    func saveSettings() {
        SettingsObserver.shared.suspendNotifications()
        let defaults = UserDefaults.standard

        defaults.set(enableClipboardHistory, forKey: UserDefaultsKey.enableClipboardHistory)
        defaults.set(clipboardHotkeyModifiersRaw, forKey: UserDefaultsKey.clipboardHotkeyModifiers)
        defaults.set(Int(clipboardHotkeyKeyCode), forKey: UserDefaultsKey.clipboardHotkeyKeyCode)
        defaults.set(clipboardHistoryMaxItems, forKey: UserDefaultsKey.clipboardHistoryMaxItems)
    }

    func reloadFromDefaults() {
        loadSettings()
    }

    // MARK: - Setup Observers

    func setupObservers() {
        Publishers.Merge4(
            $enableClipboardHistory.map { _ in () },
            $clipboardHotkeyModifiersRaw.map { _ in () },
            $clipboardHotkeyKeyCode.map { _ in () },
            $clipboardHistoryMaxItems.map { _ in () }
        )
        .debounce(for: .milliseconds(Timing.settingsDebounce), scheduler: RunLoop.main)
        .dropFirst()
        .sink { [weak self] in
            guard let self = self, !self.isLoadingSettings else { return }
            self.saveSettings()
            NotificationCenter.default.post(name: NotificationName.clipboardHotkeySettingsChanged, object: nil)
        }.store(in: &cancellables)
    }

    func resetToDefaults() {
        isLoadingSettings = true
        defer { isLoadingSettings = false }

        enableClipboardHistory = Defaults.enableClipboardHistory
        clipboardHotkeyModifiersRaw = Int(Defaults.clipboardHotkeyModifiers)
        clipboardHotkeyKeyCode = Defaults.clipboardHotkeyKeyCode
        clipboardHistoryMaxItems = Defaults.clipboardHistoryMaxItems

        saveSettings()
    }
}
