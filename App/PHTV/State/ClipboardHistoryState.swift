//
//  ClipboardHistoryState.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit
import Observation

/// Manages clipboard history settings
@MainActor
@Observable
final class ClipboardHistoryState {
    var enableClipboardHistory: Bool = false {
        didSet { handleClipboardSettingDidChange(oldValue: oldValue, newValue: enableClipboardHistory) }
    }
    var clipboardHotkeyModifiersRaw: Int = Int(NSEvent.ModifierFlags.control.rawValue) {
        didSet { handleClipboardSettingDidChange(oldValue: oldValue, newValue: clipboardHotkeyModifiersRaw) }
    }
    var clipboardHotkeyKeyCode: UInt16 = KeyCode.vKey {
        didSet { handleClipboardSettingDidChange(oldValue: oldValue, newValue: clipboardHotkeyKeyCode) }
    }
    var clipboardHistoryMaxItems: Int = 30 {
        didSet { handleClipboardSettingDidChange(oldValue: oldValue, newValue: clipboardHistoryMaxItems) }
    }

    var clipboardHotkeyModifiers: NSEvent.ModifierFlags {
        get {
            NSEvent.ModifierFlags(rawValue: UInt(clipboardHotkeyModifiersRaw))
        }
        set {
            clipboardHotkeyModifiersRaw = Int(newValue.rawValue)
        }
    }

    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored var isLoadingSettings = false
    @ObservationIgnored private var clipboardNotificationTask: Task<Void, Never>?

    init() {}

    private func handleObservedChange<Value: Equatable>(
        oldValue: Value,
        newValue: Value,
        action: (() -> Void)? = nil
    ) {
        guard newValue != oldValue else { return }
        onChange?()
        guard !isLoadingSettings else { return }
        action?()
    }

    private func scheduleClipboardHotkeyNotification() {
        clipboardNotificationTask?.cancel()
        clipboardNotificationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Timing.settingsDebounce) * 1_000_000)
            guard self != nil, !Task.isCancelled else { return }
            NotificationCenter.default.post(name: NotificationName.clipboardHotkeySettingsChanged, object: nil)
        }
    }

    private func handleClipboardSettingDidChange<Value: Equatable>(oldValue: Value, newValue: Value) {
        handleObservedChange(oldValue: oldValue, newValue: newValue) {
            self.saveSettings()
            self.scheduleClipboardHotkeyNotification()
        }
    }

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
        // Observation-based state now handles side effects in property observers.
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
