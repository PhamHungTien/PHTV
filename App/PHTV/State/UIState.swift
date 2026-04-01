//
//  UIState.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit
import Observation

/// Manages UI settings, hotkeys, and display preferences
@MainActor
@Observable
final class UIState {
    // Hotkey settings - Default: Ctrl + Shift (modifier only mode)
    // KeyCode.noKey = no key needed, just use modifiers
    var switchKeyCommand: Bool = false {
        didSet { handleHotkeySettingDidChange(oldValue: oldValue, newValue: switchKeyCommand) }
    }
    var switchKeyOption: Bool = false {
        didSet { handleHotkeySettingDidChange(oldValue: oldValue, newValue: switchKeyOption) }
    }
    var switchKeyControl: Bool = true {
        didSet { handleHotkeySettingDidChange(oldValue: oldValue, newValue: switchKeyControl) }
    }
    var switchKeyShift: Bool = true {
        didSet { handleHotkeySettingDidChange(oldValue: oldValue, newValue: switchKeyShift) }
    }
    var switchKeyFn: Bool = false {
        didSet { handleHotkeySettingDidChange(oldValue: oldValue, newValue: switchKeyFn) }
    }
    var switchKeyCode: UInt16 = KeyCode.noKey {  // KeyCode.noKey = modifier only mode
        didSet { handleHotkeySettingDidChange(oldValue: oldValue, newValue: switchKeyCode) }
    }
    var switchKeyName: String = KeyCode.modifierOnlyDisplayName {  // Display name for the key
        didSet {
            guard switchKeyName != oldValue else { return }
            onChange?()
        }
    }
    var beepOnModeSwitch: Bool = false {  // Play beep sound when switching mode
        didSet { handleHotkeySettingDidChange(oldValue: oldValue, newValue: beepOnModeSwitch) }
    }

    // Audio and Display settings
    var beepVolume: Double = 0.5 {  // Range: 0.0 to 1.0
        didSet {
            handleObservedChange(oldValue: oldValue, newValue: beepVolume) {
                self.scheduleBeepVolumeSave()
            }
        }
    }
    var menuBarIconSize: Double = 18.0 {
        didSet {
            let sanitized = sanitizeMenuBarIconSize(menuBarIconSize)
            if sanitized != menuBarIconSize {
                menuBarIconSize = sanitized
                return
            }
            guard menuBarIconSize != oldValue else { return }
            onChange?()
            guard !isLoadingSettings else { return }
            NotificationCenter.default.post(
                name: NotificationName.menuBarIconSizeChanged,
                object: NSNumber(value: sanitized)
            )
            scheduleMenuBarIconSizeSave()
        }
    }
    var useVietnameseMenubarIcon: Bool = false {  // Use Vietnamese menubar icon in Vietnamese mode
        didSet {
            handleObservedChange(oldValue: oldValue, newValue: useVietnameseMenubarIcon) {
                NotificationCenter.default.post(
                    name: NotificationName.menuBarIconPreferenceChanged,
                    object: nil
                )
                self.persistVietnameseMenubarIconPreference(self.useVietnameseMenubarIcon)
            }
        }
    }

    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored var isLoadingSettings = false
    @ObservationIgnored private var hotkeyNotificationTask: Task<Void, Never>?
    @ObservationIgnored private var beepVolumeSaveTask: Task<Void, Never>?
    @ObservationIgnored private var menuBarIconSizeSaveTask: Task<Void, Never>?

    private static var liveDebugEnabled: Bool {
        let env = ProcessInfo.processInfo.environment["PHTV_LIVE_DEBUG"]
        if let env, !env.isEmpty {
            return env != "0"
        }
        return UserDefaults.standard.integer(forKey: UserDefaultsKey.liveDebug, default: 0) != 0
    }

    private func liveLog(_ message: String) {
        guard Self.liveDebugEnabled else { return }
        NSLog("[PHTV Live] %@", message)
    }

    private static let legacyMenuBarIconSizeKeys: [String] = [
        "MenuBarIconSize",
        "menuBarIconSize",
        "StatusBarIconSize",
        "statusBarIconSize",
        "vStatusBarIconSize"
    ]

    private func menuBarIconSizeBounds() -> ClosedRange<Double> {
        let minSize = 12.0
        let nativeCap = Double(NSStatusBar.system.thickness - 4.0)
        let maxSize = max(minSize, nativeCap)
        return minSize...maxSize
    }

    private func sanitizeMenuBarIconSize(_ value: Double) -> Double {
        let bounds = menuBarIconSizeBounds()
        guard value.isFinite else {
            return min(max(Defaults.menuBarIconSize, bounds.lowerBound), bounds.upperBound)
        }
        return min(max(value, bounds.lowerBound), bounds.upperBound)
    }

    private func decodeDoublePreference(_ value: Any?) -> Double? {
        if let doubleValue = value as? Double {
            return doubleValue
        }
        if let numberValue = value as? NSNumber {
            return numberValue.doubleValue
        }
        if let stringValue = value as? String {
            return Double(stringValue)
        }
        return nil
    }

    private func resolveMenuBarIconSize(from defaults: UserDefaults) -> (value: Double, sourceKey: String?) {
        if let currentValue = decodeDoublePreference(
            defaults.persistedObject(forKey: UserDefaultsKey.menuBarIconSize)
        ) {
            return (currentValue, UserDefaultsKey.menuBarIconSize)
        }

        for legacyKey in Self.legacyMenuBarIconSizeKeys {
            if let legacyValue = decodeDoublePreference(
                defaults.persistedObject(forKey: legacyKey)
            ) {
                return (legacyValue, legacyKey)
            }
        }

        return (Defaults.menuBarIconSize, nil)
    }

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

    private func handleHotkeySettingDidChange<Value: Equatable>(oldValue: Value, newValue: Value) {
        handleObservedChange(oldValue: oldValue, newValue: newValue) {
            self.persistHotkeySettings()
            self.scheduleHotkeyChangeNotification()
        }
    }

    private func scheduleHotkeyChangeNotification() {
        hotkeyNotificationTask?.cancel()
        hotkeyNotificationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Timing.hotkeyDebounce) * 1_000_000)
            guard let self, !Task.isCancelled else { return }
            let switchKeyStatus = self.encodeSwitchKeyStatus()
            self.liveLog("posting HotkeyChanged (0x\(String(switchKeyStatus, radix: 16)))")
            NotificationCenter.default.post(
                name: NotificationName.hotkeyChanged,
                object: NSNumber(value: switchKeyStatus)
            )
        }
    }

    private func scheduleBeepVolumeSave() {
        beepVolumeSaveTask?.cancel()
        beepVolumeSaveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Timing.audioSliderDebounce) * 1_000_000)
            guard let self, !Task.isCancelled else { return }
            SettingsObserver.shared.suspendNotifications()
            let defaults = UserDefaults.standard
            defaults.set(self.beepVolume, forKey: UserDefaultsKey.beepVolume)
        }
    }

    private func scheduleMenuBarIconSizeSave() {
        menuBarIconSizeSaveTask?.cancel()
        menuBarIconSizeSaveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Timing.settingsDebounce) * 1_000_000)
            guard let self, !Task.isCancelled else { return }
            SettingsObserver.shared.suspendNotifications()
            let defaults = UserDefaults.standard
            let sanitized = self.sanitizeMenuBarIconSize(self.menuBarIconSize)
            defaults.set(sanitized, forKey: UserDefaultsKey.menuBarIconSize)
            self.liveLog("Saved menuBarIconSize: \(sanitized)")
        }
    }

    // MARK: - Load/Save Settings

    func loadSettings() {
        let defaults = UserDefaults.standard

        // Load hotkey from SwitchKeyStatus (backend format)
        let storedSwitchKeyStatus = defaults.integer(
            forKey: UserDefaultsKey.switchKeyStatus,
            default: Defaults.defaultSwitchKeyStatus
        )
        let switchKeyStatus = normalizedSwitchKeyStatus(storedSwitchKeyStatus)
        if switchKeyStatus != storedSwitchKeyStatus {
            defaults.set(switchKeyStatus, forKey: UserDefaultsKey.switchKeyStatus)
            liveLog(
                "Normalized SwitchKeyStatus from 0x\(String(storedSwitchKeyStatus, radix: 16)) to 0x\(String(switchKeyStatus, radix: 16))"
            )
        }
        decodeSwitchKeyStatus(switchKeyStatus)
        beepOnModeSwitch = defaults.bool(
            forKey: UserDefaultsKey.beepOnModeSwitch,
            default: Defaults.beepOnModeSwitch
        )

        // Load audio and display settings
        beepVolume = defaults.double(forKey: UserDefaultsKey.beepVolume, default: Defaults.beepVolume)
        liveLog("Loaded beepVolume: \(beepVolume)")

        let resolvedMenuBarIconSize = resolveMenuBarIconSize(from: defaults)
        let loadedMenuBarIconSize = resolvedMenuBarIconSize.value
        menuBarIconSize = sanitizeMenuBarIconSize(loadedMenuBarIconSize)
        let needsWriteBack = loadedMenuBarIconSize != menuBarIconSize ||
            resolvedMenuBarIconSize.sourceKey != UserDefaultsKey.menuBarIconSize
        if needsWriteBack {
            defaults.set(menuBarIconSize, forKey: UserDefaultsKey.menuBarIconSize)
        }
        if let sourceKey = resolvedMenuBarIconSize.sourceKey, sourceKey != UserDefaultsKey.menuBarIconSize {
            liveLog("Migrated menuBarIconSize from legacy key '\(sourceKey)'")
        }
        liveLog("Loaded menuBarIconSize: \(menuBarIconSize)")

        useVietnameseMenubarIcon = defaults.bool(
            forKey: UserDefaultsKey.useVietnameseMenubarIcon,
            default: Defaults.useVietnameseMenubarIcon
        )
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
        defaults.set(sanitizeMenuBarIconSize(menuBarIconSize), forKey: UserDefaultsKey.menuBarIconSize)
        defaults.set(useVietnameseMenubarIcon, forKey: UserDefaultsKey.useVietnameseMenubarIcon)

    }

    private func persistHotkeySettings() {
        SettingsObserver.shared.suspendNotifications()
        let defaults = UserDefaults.standard
        defaults.set(encodeSwitchKeyStatus(), forKey: UserDefaultsKey.switchKeyStatus)
        defaults.set(beepOnModeSwitch, forKey: UserDefaultsKey.beepOnModeSwitch)
    }

    private func persistVietnameseMenubarIconPreference(_ value: Bool) {
        SettingsObserver.shared.suspendNotifications()
        UserDefaults.standard.set(value, forKey: UserDefaultsKey.useVietnameseMenubarIcon)
        liveLog("Saved useVietnameseMenubarIcon: \(value)")
    }

    func reloadFromDefaults() {
        loadSettings()
    }

    // MARK: - Hotkey Encoding/Decoding

    private func normalizedSwitchKeyStatus(_ status: Int) -> Int {
        let keyMask = KeyCode.keyMask
        let modifierMask = KeyCode.controlMask
            | KeyCode.optionMask
            | KeyCode.commandMask
            | KeyCode.shiftMask
            | KeyCode.fnMask
        let allowedMask = keyMask | modifierMask | KeyCode.beepMask

        let filtered = status & allowedMask
        let hasModifier = (filtered & modifierMask) != 0
        let key = filtered & keyMask
        let keyIsValid = key != KeyCode.keyMask

        guard hasModifier, keyIsValid else {
            return Defaults.defaultSwitchKeyStatus
        }
        return filtered
    }

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
        // Observation-based state now handles side effects in property observers.
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
