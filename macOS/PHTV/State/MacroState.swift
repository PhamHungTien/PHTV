//
//  MacroState.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import AppKit
import Combine

/// Manages macro and emoji hotkey settings
@MainActor
final class MacroState: ObservableObject {
    // Macro settings
    @Published var useMacro: Bool = true
    @Published var useMacroInEnglishMode: Bool = false
    @Published var autoCapsMacro: Bool = false
    @Published var macroCategories: [MacroCategory] = []

    // Emoji Hotkey Settings
    @Published var enableEmojiHotkey: Bool = true
    @Published var emojiHotkeyModifiersRaw: Int = Int(NSEvent.ModifierFlags.command.rawValue)
    @Published var emojiHotkeyKeyCode: UInt16 = KeyCode.eKey  // E key default

    /// Computed property for emoji hotkey modifiers
    var emojiHotkeyModifiers: NSEvent.ModifierFlags {
        get {
            NSEvent.ModifierFlags(rawValue: UInt(emojiHotkeyModifiersRaw))
        }
        set {
            emojiHotkeyModifiersRaw = Int(newValue.rawValue)
            // Trigger sync when modifiers change
            NotificationCenter.default.post(name: NotificationName.emojiHotkeySettingsChanged, object: nil)
        }
    }

    private var cancellables = Set<AnyCancellable>()
    var isLoadingSettings = false

    init() {}

    // MARK: - Load/Save Settings

    func loadSettings() {
        let defaults = UserDefaults.standard

        // Load macro settings
        useMacro = defaults.bool(forKey: UserDefaultsKey.useMacro, default: Defaults.useMacro)
        useMacroInEnglishMode = defaults.bool(
            forKey: UserDefaultsKey.useMacroInEnglishMode,
            default: Defaults.useMacroInEnglishMode
        )
        autoCapsMacro = defaults.bool(forKey: UserDefaultsKey.autoCapsMacro, default: Defaults.autoCapsMacro)

        // Load macro categories (filter out default category if present)
        if let categoriesData = defaults.data(forKey: UserDefaultsKey.macroCategories) {
            do {
                let categories = try JSONDecoder().decode([MacroCategory].self, from: categoriesData)
                macroCategories = categories.filter { $0.id != MacroCategory.defaultCategory.id }
            } catch {
                NSLog("[MacroState] Failed to decode macro categories: %@", error.localizedDescription)
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
        let savedKeyCode = defaults.integer(
            forKey: UserDefaultsKey.emojiHotkeyKeyCode,
            default: Int(Defaults.emojiHotkeyKeyCode)
        )
        emojiHotkeyKeyCode = savedKeyCode > 0 ? UInt16(savedKeyCode) : Defaults.emojiHotkeyKeyCode
    }

    func saveSettings() {
        SettingsObserver.shared.suspendNotifications()
        let defaults = UserDefaults.standard

        // Save macro settings
        defaults.set(useMacro, forKey: UserDefaultsKey.useMacro)
        defaults.set(useMacroInEnglishMode, forKey: UserDefaultsKey.useMacroInEnglishMode)
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

    // MARK: - Setup Observers

    func setupObservers() {
        // Observer for macro settings
        Publishers.Merge3(
            $useMacro,
            $useMacroInEnglishMode,
            $autoCapsMacro
        )
        .debounce(for: .milliseconds(Timing.settingsDebounce), scheduler: RunLoop.main)
        .dropFirst()
        .sink { [weak self] _ in
            guard let self = self, !self.isLoadingSettings else { return }
            self.saveSettings()
            NotificationCenter.default.post(
                name: NotificationName.phtvSettingsChanged, object: nil
            )
        }.store(in: &cancellables)

        // Observer for emoji hotkey settings
        Publishers.Merge3(
            $enableEmojiHotkey.map { _ in () },
            $emojiHotkeyModifiersRaw.map { _ in () },
            $emojiHotkeyKeyCode.map { _ in () }
        )
        .debounce(for: .milliseconds(Timing.settingsDebounce), scheduler: RunLoop.main)
        .dropFirst()
        .sink { [weak self] in
            guard let self = self, !self.isLoadingSettings else { return }
            // Save settings when emoji hotkey changes
            self.saveSettings()
            // Post notification to trigger sync in EmojiHotkeyManager
            PHTVLogger.shared.debug("[MacroState] Posting EmojiHotkeySettingsChanged notification")
            NotificationCenter.default.post(name: NotificationName.emojiHotkeySettingsChanged, object: nil)
        }.store(in: &cancellables)
    }

    func resetToDefaults() {
        isLoadingSettings = true
        defer { isLoadingSettings = false }

        useMacro = Defaults.useMacro
        useMacroInEnglishMode = Defaults.useMacroInEnglishMode
        autoCapsMacro = Defaults.autoCapsMacro
        macroCategories = []

        enableEmojiHotkey = Defaults.enableEmojiHotkey
        emojiHotkeyModifiersRaw = Int(Defaults.emojiHotkeyModifiers)
        emojiHotkeyKeyCode = Defaults.emojiHotkeyKeyCode

        saveSettings()
    }
}
