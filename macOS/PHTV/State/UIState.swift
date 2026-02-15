//
//  UIState.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import Combine

/// Manages UI settings, hotkeys, and display preferences
@MainActor
final class UIState: ObservableObject {
    // Hotkey settings - Default: Ctrl + Shift (modifier only mode)
    // KeyCode.noKey = no key needed, just use modifiers
    @Published var switchKeyCommand: Bool = false
    @Published var switchKeyOption: Bool = false
    @Published var switchKeyControl: Bool = true
    @Published var switchKeyShift: Bool = true
    @Published var switchKeyFn: Bool = false
    @Published var switchKeyCode: UInt16 = KeyCode.noKey  // KeyCode.noKey = modifier only mode
    @Published var switchKeyName: String = KeyCode.modifierOnlyDisplayName  // Display name for the key
    @Published var beepOnModeSwitch: Bool = false  // Play beep sound when switching mode

    // Audio and Display settings
    @Published var beepVolume: Double = 0.5  // Range: 0.0 to 1.0
    @Published var menuBarIconSize: Double = 18.0
    @Published var useVietnameseMenubarIcon: Bool = false  // Use Vietnamese menubar icon in Vietnamese mode

    private var cancellables = Set<AnyCancellable>()
    var isLoadingSettings = false

    private static var liveDebugEnabled: Bool {
        let env = ProcessInfo.processInfo.environment["PHTV_LIVE_DEBUG"]
        if let env, !env.isEmpty {
            return env != "0"
        }
        return UserDefaults.standard.integer(forKey: UserDefaultsKey.liveDebug) != 0
    }

    private func liveLog(_ message: String) {
        guard Self.liveDebugEnabled else { return }
        NSLog("[PHTV Live] %@", message)
    }

    init() {}

    // MARK: - Load/Save Settings

    private func applyDefaultSwitchHotkey() {
        switchKeyCode = Defaults.switchKeyCode
        switchKeyControl = Defaults.switchKeyControl
        switchKeyOption = Defaults.switchKeyOption
        switchKeyCommand = Defaults.switchKeyCommand
        switchKeyShift = Defaults.switchKeyShift
        switchKeyFn = Defaults.switchKeyFn
        switchKeyName = Defaults.switchKeyName
    }

    func loadSettings() {
        let defaults = UserDefaults.standard

        // Load hotkey from SwitchKeyStatus (backend format)
        let switchKeyStatus = defaults.integer(forKey: UserDefaultsKey.switchKeyStatus)
        if switchKeyStatus != 0 {
            decodeSwitchKeyStatus(switchKeyStatus)
        } else {
            applyDefaultSwitchHotkey()
        }
        beepOnModeSwitch = defaults.bool(forKey: UserDefaultsKey.beepOnModeSwitch)

        // Load audio and display settings
        beepVolume = defaults.double(forKey: UserDefaultsKey.beepVolume)
        if beepVolume == 0 { beepVolume = 0.5 } // Default if not set
        liveLog("Loaded beepVolume: \(beepVolume)")

        menuBarIconSize = defaults.double(forKey: UserDefaultsKey.menuBarIconSize)
        if menuBarIconSize == 0 { menuBarIconSize = 18.0 } // Default if not set
        liveLog("Loaded menuBarIconSize: \(menuBarIconSize)")

        useVietnameseMenubarIcon = defaults.bool(forKey: UserDefaultsKey.useVietnameseMenubarIcon)
    }

    func saveSettings() {
        SettingsObserver.shared.suspendNotifications()
        let defaults = UserDefaults.standard

        // Save hotkey in backend format (SwitchKeyStatus)
        let switchKeyStatus = encodeSwitchKeyStatus()
        defaults.set(switchKeyStatus, forKey: UserDefaultsKey.switchKeyStatus)
        defaults.set(beepOnModeSwitch, forKey: UserDefaultsKey.beepOnModeSwitch)

        // Save audio and display settings
        defaults.set(beepVolume, forKey: UserDefaultsKey.beepVolume)
        defaults.set(menuBarIconSize, forKey: UserDefaultsKey.menuBarIconSize)
        defaults.set(useVietnameseMenubarIcon, forKey: UserDefaultsKey.useVietnameseMenubarIcon)

        defaults.synchronize()
    }

    // MARK: - Hotkey Encoding/Decoding

    /// Decode vSwitchKeyStatus from backend format
    private func decodeSwitchKeyStatus(_ status: Int) {
        switchKeyCode = UInt16(status & KeyCode.keyMask)
        switchKeyControl = (status & KeyCode.controlMask) != 0
        switchKeyOption = (status & KeyCode.optionMask) != 0
        switchKeyCommand = (status & KeyCode.commandMask) != 0
        switchKeyShift = (status & KeyCode.shiftMask) != 0
        switchKeyFn = (status & KeyCode.fnMask) != 0
        beepOnModeSwitch = (status & KeyCode.beepMask) != 0
        switchKeyName = keyCodeToName(switchKeyCode)
    }

    /// Encode hotkey settings to backend vSwitchKeyStatus format
    func encodeSwitchKeyStatus() -> Int {
        var status = Int(switchKeyCode)
        if switchKeyControl { status |= KeyCode.controlMask }
        if switchKeyOption { status |= KeyCode.optionMask }
        if switchKeyCommand { status |= KeyCode.commandMask }
        if switchKeyShift { status |= KeyCode.shiftMask }
        if switchKeyFn { status |= KeyCode.fnMask }
        if beepOnModeSwitch { status |= KeyCode.beepMask }
        return status
    }

    /// Convert key code to display name
    private func keyCodeToName(_ keyCode: UInt16) -> String {
        KeyCode.name(for: keyCode)
    }

    // MARK: - Setup Observers

    func setupObservers() {
        // Observer for hotkey settings
        let hotkeyChanges = Publishers.MergeMany([
            $switchKeyCode.map { _ in () }.eraseToAnyPublisher(),
            $switchKeyCommand.map { _ in () }.eraseToAnyPublisher(),
            $switchKeyOption.map { _ in () }.eraseToAnyPublisher(),
            $switchKeyControl.map { _ in () }.eraseToAnyPublisher(),
            $switchKeyShift.map { _ in () }.eraseToAnyPublisher(),
            $switchKeyFn.map { _ in () }.eraseToAnyPublisher(),
            $beepOnModeSwitch.map { _ in () }.eraseToAnyPublisher()
        ])

        hotkeyChanges
            .debounce(for: .milliseconds(Timing.hotkeyDebounce), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self, !self.isLoadingSettings else { return }
                SettingsObserver.shared.suspendNotifications()
                let switchKeyStatus = self.encodeSwitchKeyStatus()
                UserDefaults.standard.set(switchKeyStatus, forKey: UserDefaultsKey.switchKeyStatus)
                UserDefaults.standard.set(self.beepOnModeSwitch, forKey: UserDefaultsKey.beepOnModeSwitch)
                UserDefaults.standard.synchronize()
                // Notify backend about hotkey change
                self.liveLog("posting HotkeyChanged (0x\(String(switchKeyStatus, radix: 16)))")
                NotificationCenter.default.post(
                    name: NotificationName.hotkeyChanged, object: NSNumber(value: switchKeyStatus)
                )
            }.store(in: &cancellables)

        // Immediate UI update for menu bar icon size
        $menuBarIconSize
            .sink { [weak self] value in
                guard let self = self, !self.isLoadingSettings else { return }
                NotificationCenter.default.post(
                    name: NotificationName.menuBarIconSizeChanged,
                    object: NSNumber(value: value)
                )
            }.store(in: &cancellables)

        // Immediate UI update for Vietnamese menubar icon preference
        $useVietnameseMenubarIcon
            .sink { [weak self] _ in
                guard let self = self, !self.isLoadingSettings else { return }
                NotificationCenter.default.post(
                    name: NotificationName.menuBarIconPreferenceChanged,
                    object: nil
                )
            }.store(in: &cancellables)

        // Debounced persistence for beep volume slider
        $beepVolume
            .debounce(for: .milliseconds(Timing.audioSliderDebounce), scheduler: RunLoop.main)
            .sink { [weak self] value in
                guard let self = self, !self.isLoadingSettings else { return }
                SettingsObserver.shared.suspendNotifications()
                let defaults = UserDefaults.standard
                defaults.set(value, forKey: UserDefaultsKey.beepVolume)
            }.store(in: &cancellables)

        // Debounced persistence for menu bar icon size
        $menuBarIconSize
            .debounce(for: .milliseconds(Timing.settingsDebounce), scheduler: RunLoop.main)
            .sink { [weak self] value in
                guard let self = self, !self.isLoadingSettings else { return }
                SettingsObserver.shared.suspendNotifications()
                let defaults = UserDefaults.standard
                defaults.set(value, forKey: UserDefaultsKey.menuBarIconSize)
                defaults.synchronize()
                self.liveLog("Saved menuBarIconSize: \(value)")
            }.store(in: &cancellables)

        // Debounced persistence for Vietnamese menubar icon
        $useVietnameseMenubarIcon
            .debounce(for: .milliseconds(Timing.settingsDebounce), scheduler: RunLoop.main)
            .sink { [weak self] value in
                guard let self = self, !self.isLoadingSettings else { return }
                SettingsObserver.shared.suspendNotifications()
                let defaults = UserDefaults.standard
                defaults.set(value, forKey: UserDefaultsKey.useVietnameseMenubarIcon)
                defaults.synchronize()
                self.liveLog("Saved useVietnameseMenubarIcon: \(value)")
            }.store(in: &cancellables)
    }

    func resetToDefaults() {
        isLoadingSettings = true
        defer { isLoadingSettings = false }

        switchKeyCommand = Defaults.switchKeyCommand
        switchKeyOption = Defaults.switchKeyOption
        switchKeyControl = Defaults.switchKeyControl
        switchKeyShift = Defaults.switchKeyShift
        switchKeyFn = Defaults.switchKeyFn
        switchKeyCode = Defaults.switchKeyCode
        switchKeyName = Defaults.switchKeyName
        beepOnModeSwitch = Defaults.beepOnModeSwitch

        beepVolume = Defaults.beepVolume
        menuBarIconSize = Defaults.menuBarIconSize
        useVietnameseMenubarIcon = Defaults.useVietnameseMenubarIcon

        saveSettings()
    }
}
