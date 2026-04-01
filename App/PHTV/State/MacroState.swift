//
//  MacroState.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit
import Observation

/// Manages macro and emoji hotkey settings
@MainActor
@Observable
final class MacroState {
    // Macro settings
    var useMacro: Bool = true {
        didSet { handleMacroSettingsDidChange(oldValue: oldValue, newValue: useMacro) }
    }
    var useMacroInEnglishMode: Bool = false {
        didSet { handleMacroSettingsDidChange(oldValue: oldValue, newValue: useMacroInEnglishMode) }
    }
    var useSystemTextReplacements: Bool = false {
        didSet {
            handleObservedChange(oldValue: oldValue, newValue: useSystemTextReplacements) {
                self.saveSettings()
                self.scheduleSystemTextReplacementNotification()
            }
        }
    }
    var autoCapsMacro: Bool = false {
        didSet { handleMacroSettingsDidChange(oldValue: oldValue, newValue: autoCapsMacro) }
    }
    var macroCategories: [MacroCategory] = [] {
        didSet {
            guard macroCategories != oldValue else { return }
            onChange?()
        }
    }

    // Emoji Hotkey Settings
    var enableEmojiHotkey: Bool = true {
        didSet { handleEmojiHotkeySettingDidChange(oldValue: oldValue, newValue: enableEmojiHotkey) }
    }
    var emojiHotkeyModifiersRaw: Int = Int(NSEvent.ModifierFlags.command.rawValue) {
        didSet { handleEmojiHotkeySettingDidChange(oldValue: oldValue, newValue: emojiHotkeyModifiersRaw) }
    }
    var emojiHotkeyKeyCode: UInt16 = KeyCode.eKey {  // E key default
        didSet { handleEmojiHotkeySettingDidChange(oldValue: oldValue, newValue: emojiHotkeyKeyCode) }
    }

    /// Computed property for emoji hotkey modifiers
    var emojiHotkeyModifiers: NSEvent.ModifierFlags {
        get {
            NSEvent.ModifierFlags(rawValue: UInt(emojiHotkeyModifiersRaw))
        }
        set {
            emojiHotkeyModifiersRaw = Int(newValue.rawValue)
        }
    }

    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored var isLoadingSettings = false
    @ObservationIgnored private var macroSettingsNotificationTask: Task<Void, Never>?
    @ObservationIgnored private var systemTextReplacementNotificationTask: Task<Void, Never>?
    @ObservationIgnored private var emojiHotkeyNotificationTask: Task<Void, Never>?

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

    private func scheduleMacroSettingsNotification() {
        macroSettingsNotificationTask?.cancel()
        macroSettingsNotificationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Timing.settingsDebounce) * 1_000_000)
            guard self != nil, !Task.isCancelled else { return }
            NotificationCenter.default.post(name: NotificationName.phtvSettingsChanged, object: nil)
        }
    }

    private func scheduleSystemTextReplacementNotification() {
        systemTextReplacementNotificationTask?.cancel()
        systemTextReplacementNotificationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Timing.settingsDebounce) * 1_000_000)
            guard self != nil, !Task.isCancelled else { return }
            NotificationCenter.default.post(name: NotificationName.phtvSettingsChanged, object: nil)
            NotificationCenter.default.post(name: NotificationName.macrosUpdated, object: nil)
        }
    }

    private func scheduleEmojiHotkeyNotification() {
        emojiHotkeyNotificationTask?.cancel()
        emojiHotkeyNotificationTask = Task { @MainActor [weak self] in
            guard self != nil else { return }
            try? await Task.sleep(nanoseconds: UInt64(Timing.settingsDebounce) * 1_000_000)
            guard self != nil, !Task.isCancelled else { return }
            PHTVLogger.shared.debug("[MacroState] Posting EmojiHotkeySettingsChanged notification")
            NotificationCenter.default.post(name: NotificationName.emojiHotkeySettingsChanged, object: nil)
        }
    }

    private func handleMacroSettingsDidChange<Value: Equatable>(oldValue: Value, newValue: Value) {
        handleObservedChange(oldValue: oldValue, newValue: newValue) {
            self.saveSettings()
            self.scheduleMacroSettingsNotification()
        }
    }

    private func handleEmojiHotkeySettingDidChange<Value: Equatable>(oldValue: Value, newValue: Value) {
        handleObservedChange(oldValue: oldValue, newValue: newValue) {
            self.saveSettings()
            self.scheduleEmojiHotkeyNotification()
        }
    }

    // MARK: - Load/Save Settings

    func loadSettings() {
        let defaults = UserDefaults.standard

        // Load macro settings
        useMacro = defaults.bool(forKey: UserDefaultsKey.useMacro, default: Defaults.useMacro)
        useMacroInEnglishMode = defaults.bool(
            forKey: UserDefaultsKey.useMacroInEnglishMode,
            default: Defaults.useMacroInEnglishMode
        )
        useSystemTextReplacements = defaults.bool(
            forKey: UserDefaultsKey.useSystemTextReplacements,
            default: Defaults.useSystemTextReplacements
        )
        autoCapsMacro = defaults.bool(forKey: UserDefaultsKey.autoCapsMacro, default: Defaults.autoCapsMacro)

        // Load macro categories (filter out default category if present)
        if let categoriesData = defaults.data(forKey: UserDefaultsKey.macroCategories) {
            do {
                let categories = try JSONDecoder().decode([MacroCategory].self, from: categoriesData)
                macroCategories = categories.filter { $0.id != MacroCategory.defaultCategory.id }
            } catch {
                NSLog("[MacroState] Failed to decode macro categories: %@", error.localizedDescription)
                let backupKey = UserDefaultsKey.macroCategories + ".corruptedBackup"
                defaults.set(categoriesData, forKey: backupKey)
                defaults.removeObject(forKey: UserDefaultsKey.macroCategories)
                NSLog("[MacroState] Corrupted macro categories were backed up to %@ and reset", backupKey)
                // Keep default empty array
                macroCategories = []
            }
        }

        // Load emoji hotkey settings
        enableEmojiHotkey = defaults.bool(
            forKey: UserDefaultsKey.enableEmojiHotkey,
            default: Defaults.enableEmojiHotkey
        )
        emojiHotkeyModifiersRaw = defaults.integer(
            forKey: UserDefaultsKey.emojiHotkeyModifiers,
            default: Int(Defaults.emojiHotkeyModifiers)
        )
        if emojiHotkeyModifiersRaw == 0 {
            emojiHotkeyModifiersRaw = Int(Defaults.emojiHotkeyModifiers)
        }
        let keyCodeObject = defaults.object(forKey: UserDefaultsKey.emojiHotkeyKeyCode)
        if keyCodeObject == nil {
            emojiHotkeyKeyCode = Defaults.emojiHotkeyKeyCode
        } else {
            let savedKeyCode = defaults.integer(
                forKey: UserDefaultsKey.emojiHotkeyKeyCode,
                default: Int(Defaults.emojiHotkeyKeyCode)
            )
            if (0...Int(KeyCode.keyMask)).contains(savedKeyCode) || savedKeyCode == Int(KeyCode.noKey) {
                emojiHotkeyKeyCode = UInt16(savedKeyCode)
            } else {
                emojiHotkeyKeyCode = Defaults.emojiHotkeyKeyCode
                defaults.set(Int(Defaults.emojiHotkeyKeyCode), forKey: UserDefaultsKey.emojiHotkeyKeyCode)
            }
        }
    }

    func saveSettings() {
        SettingsObserver.shared.suspendNotifications()
        let defaults = UserDefaults.standard

        // Save macro settings
        defaults.set(useMacro, forKey: UserDefaultsKey.useMacro)
        defaults.set(useMacroInEnglishMode, forKey: UserDefaultsKey.useMacroInEnglishMode)
        defaults.set(useSystemTextReplacements, forKey: UserDefaultsKey.useSystemTextReplacements)
        defaults.set(autoCapsMacro, forKey: UserDefaultsKey.autoCapsMacro)

        // Save macro categories (exclude default category)
        let categoriesToSave = macroCategories.filter { $0.id != MacroCategory.defaultCategory.id }
        do {
            let categoriesData = try JSONEncoder().encode(categoriesToSave)
            defaults.set(categoriesData, forKey: UserDefaultsKey.macroCategories)
        } catch {
            NSLog("[MacroState] Failed to encode macro categories: %@", error.localizedDescription)
        }

        // Save emoji hotkey settings
        defaults.set(enableEmojiHotkey, forKey: UserDefaultsKey.enableEmojiHotkey)
        defaults.set(emojiHotkeyModifiersRaw, forKey: UserDefaultsKey.emojiHotkeyModifiers)
        defaults.set(Int(emojiHotkeyKeyCode), forKey: UserDefaultsKey.emojiHotkeyKeyCode)

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

        useMacro = Defaults.useMacro
        useMacroInEnglishMode = Defaults.useMacroInEnglishMode
        useSystemTextReplacements = Defaults.useSystemTextReplacements
        autoCapsMacro = Defaults.autoCapsMacro
        macroCategories = []

        enableEmojiHotkey = Defaults.enableEmojiHotkey
        emojiHotkeyModifiersRaw = Int(Defaults.emojiHotkeyModifiers)
        emojiHotkeyKeyCode = Defaults.emojiHotkeyKeyCode

        saveSettings()
    }
}
