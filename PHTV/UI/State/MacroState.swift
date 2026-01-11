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
    @Published var emojiHotkeyKeyCode: UInt16 = 14  // E key default

    /// Computed property for emoji hotkey modifiers
    var emojiHotkeyModifiers: NSEvent.ModifierFlags {
        get {
            NSEvent.ModifierFlags(rawValue: UInt(emojiHotkeyModifiersRaw))
        }
        set {
            emojiHotkeyModifiersRaw = Int(newValue.rawValue)
            // Trigger sync when modifiers change
            NotificationCenter.default.post(name: NSNotification.Name("EmojiHotkeySettingsChanged"), object: nil)
        }
    }

    private var cancellables = Set<AnyCancellable>()
    var isLoadingSettings = false

    init() {}

    // MARK: - Load/Save Settings

    func loadSettings() {
        let defaults = UserDefaults.standard

        // Load macro settings
        useMacro = defaults.bool(forKey: "UseMacro")
        useMacroInEnglishMode = defaults.bool(forKey: "UseMacroInEnglishMode")
        autoCapsMacro = defaults.bool(forKey: "vAutoCapsMacro")

        // Load macro categories (filter out default category if present)
        if let categoriesData = defaults.data(forKey: "macroCategories"),
           let categories = try? JSONDecoder().decode([MacroCategory].self, from: categoriesData) {
            macroCategories = categories.filter { $0.id != MacroCategory.defaultCategory.id }
        }

        // Load emoji hotkey settings (default true for first-time users)
        if defaults.object(forKey: "vEnableEmojiHotkey") != nil {
            enableEmojiHotkey = defaults.bool(forKey: "vEnableEmojiHotkey")
        } else {
            enableEmojiHotkey = true  // Default enabled for new users
        }
        emojiHotkeyModifiersRaw = defaults.integer(forKey: "vEmojiHotkeyModifiers")
        if emojiHotkeyModifiersRaw == 0 {
            emojiHotkeyModifiersRaw = Int(NSEvent.ModifierFlags.command.rawValue)  // Default: Command
        }
        let savedKeyCode = defaults.integer(forKey: "vEmojiHotkeyKeyCode")
        emojiHotkeyKeyCode = savedKeyCode > 0 ? UInt16(savedKeyCode) : 14  // Default: E key
    }

    func saveSettings() {
        let defaults = UserDefaults.standard

        // Save macro settings
        defaults.set(useMacro, forKey: "UseMacro")
        defaults.set(useMacroInEnglishMode, forKey: "UseMacroInEnglishMode")
        defaults.set(autoCapsMacro, forKey: "vAutoCapsMacro")

        // Save macro categories (exclude default category)
        let categoriesToSave = macroCategories.filter { $0.id != MacroCategory.defaultCategory.id }
        if let categoriesData = try? JSONEncoder().encode(categoriesToSave) {
            defaults.set(categoriesData, forKey: "macroCategories")
        }

        // Save emoji hotkey settings
        defaults.set(enableEmojiHotkey, forKey: "vEnableEmojiHotkey")
        defaults.set(emojiHotkeyModifiersRaw, forKey: "vEmojiHotkeyModifiers")
        defaults.set(Int(emojiHotkeyKeyCode), forKey: "vEmojiHotkeyKeyCode")

        defaults.synchronize()
    }

    // MARK: - Setup Observers

    func setupObservers() {
        // Observer for macro settings
        Publishers.Merge3(
            $useMacro,
            $useMacroInEnglishMode,
            $autoCapsMacro
        )
        .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
        .sink { [weak self] _ in
            guard let self = self, !self.isLoadingSettings else { return }
            self.saveSettings()
            NotificationCenter.default.post(
                name: NSNotification.Name("PHTVSettingsChanged"), object: nil
            )
        }.store(in: &cancellables)

        // Observer for emoji hotkey settings
        Publishers.Merge3(
            $enableEmojiHotkey.map { _ in () },
            $emojiHotkeyModifiersRaw.map { _ in () },
            $emojiHotkeyKeyCode.map { _ in () }
        )
        .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
        .sink { [weak self] in
            guard let self = self, !self.isLoadingSettings else { return }
            // Save settings when emoji hotkey changes
            self.saveSettings()
            // Post notification to trigger sync in EmojiHotkeyManager
            #if DEBUG
            print("[MacroState] Posting EmojiHotkeySettingsChanged notification")
            #endif
            NotificationCenter.default.post(name: NSNotification.Name("EmojiHotkeySettingsChanged"), object: nil)
        }.store(in: &cancellables)
    }

    func resetToDefaults() {
        isLoadingSettings = true
        defer { isLoadingSettings = false }

        useMacro = true
        useMacroInEnglishMode = false
        autoCapsMacro = false
        macroCategories = []

        enableEmojiHotkey = true
        emojiHotkeyModifiersRaw = Int(NSEvent.ModifierFlags.command.rawValue)
        emojiHotkeyKeyCode = 14

        saveSettings()
    }
}
