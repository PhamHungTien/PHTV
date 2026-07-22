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
    var switchKeyLeftCommand: Bool = false {
        didSet { handleHotkeySettingDidChange(oldValue: oldValue, newValue: switchKeyLeftCommand) }
    }
    var switchKeyRightCommand: Bool = false {
        didSet { handleHotkeySettingDidChange(oldValue: oldValue, newValue: switchKeyRightCommand) }
    }
    var switchKeyOption: Bool = false {
        didSet { handleHotkeySettingDidChange(oldValue: oldValue, newValue: switchKeyOption) }
    }
    var switchKeyLeftOption: Bool = false {
        didSet { handleHotkeySettingDidChange(oldValue: oldValue, newValue: switchKeyLeftOption) }
    }
    var switchKeyRightOption: Bool = false {
        didSet { handleHotkeySettingDidChange(oldValue: oldValue, newValue: switchKeyRightOption) }
    }
    var switchKeyControl: Bool = true {
        didSet { handleHotkeySettingDidChange(oldValue: oldValue, newValue: switchKeyControl) }
    }
    var switchKeyLeftControl: Bool = false {
        didSet { handleHotkeySettingDidChange(oldValue: oldValue, newValue: switchKeyLeftControl) }
    }
    var switchKeyRightControl: Bool = false {
        didSet { handleHotkeySettingDidChange(oldValue: oldValue, newValue: switchKeyRightControl) }
    }
    var switchKeyShift: Bool = true {
        didSet { handleHotkeySettingDidChange(oldValue: oldValue, newValue: switchKeyShift) }
    }
    var switchKeyLeftShift: Bool = false {
        didSet { handleHotkeySettingDidChange(oldValue: oldValue, newValue: switchKeyLeftShift) }
    }
    var switchKeyRightShift: Bool = false {
        didSet { handleHotkeySettingDidChange(oldValue: oldValue, newValue: switchKeyRightShift) }
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
    var switchKey2Command: Bool = false {
        didSet { handleHotkeySettingDidChange(oldValue: oldValue, newValue: switchKey2Command) }
    }
    var switchKey2LeftCommand: Bool = false {
        didSet { handleHotkeySettingDidChange(oldValue: oldValue, newValue: switchKey2LeftCommand) }
    }
    var switchKey2RightCommand: Bool = false {
        didSet { handleHotkeySettingDidChange(oldValue: oldValue, newValue: switchKey2RightCommand) }
    }
    var switchKey2Option: Bool = false {
        didSet { handleHotkeySettingDidChange(oldValue: oldValue, newValue: switchKey2Option) }
    }
    var switchKey2LeftOption: Bool = false {
        didSet { handleHotkeySettingDidChange(oldValue: oldValue, newValue: switchKey2LeftOption) }
    }
    var switchKey2RightOption: Bool = false {
        didSet { handleHotkeySettingDidChange(oldValue: oldValue, newValue: switchKey2RightOption) }
    }
    var switchKey2Control: Bool = false {
        didSet { handleHotkeySettingDidChange(oldValue: oldValue, newValue: switchKey2Control) }
    }
    var switchKey2LeftControl: Bool = false {
        didSet { handleHotkeySettingDidChange(oldValue: oldValue, newValue: switchKey2LeftControl) }
    }
    var switchKey2RightControl: Bool = false {
        didSet { handleHotkeySettingDidChange(oldValue: oldValue, newValue: switchKey2RightControl) }
    }
    var switchKey2Shift: Bool = false {
        didSet { handleHotkeySettingDidChange(oldValue: oldValue, newValue: switchKey2Shift) }
    }
    var switchKey2LeftShift: Bool = false {
        didSet { handleHotkeySettingDidChange(oldValue: oldValue, newValue: switchKey2LeftShift) }
    }
    var switchKey2RightShift: Bool = false {
        didSet { handleHotkeySettingDidChange(oldValue: oldValue, newValue: switchKey2RightShift) }
    }
    var switchKey2Fn: Bool = false {
        didSet { handleHotkeySettingDidChange(oldValue: oldValue, newValue: switchKey2Fn) }
    }
    var switchKey2KeyCode: UInt16 = KeyCode.noKey {
        didSet { handleHotkeySettingDidChange(oldValue: oldValue, newValue: switchKey2KeyCode) }
    }
    var switchKey2Name: String = KeyCode.modifierOnlyDisplayName {
        didSet {
            guard switchKey2Name != oldValue else { return }
            onChange?()
        }
    }
    var beepOnModeSwitch: Bool = false {  // Play beep sound when switching mode
        didSet { handleHotkeySettingDidChange(oldValue: oldValue, newValue: beepOnModeSwitch) }
    }
    var singleModifierSwitchKeys: Int = 0 {
        didSet {
            handleObservedChange(oldValue: oldValue, newValue: singleModifierSwitchKeys) {
                self.persistSingleModifierSettings()
                self.scheduleHotkeyChangeNotification()
            }
        }
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
            try? await Task.sleep(for: .milliseconds(Int64(Timing.hotkeyDebounce)))
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
            try? await Task.sleep(for: .milliseconds(Int64(Timing.audioSliderDebounce)))
            guard let self, !Task.isCancelled else { return }
            SettingsObserver.shared.suspendNotifications()
            let defaults = UserDefaults.standard
            defaults.set(self.beepVolume, forKey: UserDefaultsKey.beepVolume)
        }
    }

    private func scheduleMenuBarIconSizeSave() {
        menuBarIconSizeSaveTask?.cancel()
        menuBarIconSizeSaveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(Int64(Timing.settingsDebounce)))
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

        // Load hotkey 2 from SwitchKey2Status
        let switchKey2Migrated = defaults.bool(forKey: UserDefaultsKey.switchKey2Migrated)
        var storedSwitchKey2Status = defaults.integer(
            forKey: UserDefaultsKey.switchKey2Status,
            default: Int(KeyCode.noKey)
        )
        if !switchKey2Migrated {
            if defaults.object(forKey: UserDefaultsKey.switchKey2Status) == nil || storedSwitchKey2Status == 0 {
                storedSwitchKey2Status = Int(KeyCode.noKey)
                defaults.set(storedSwitchKey2Status, forKey: UserDefaultsKey.switchKey2Status)
            }
            defaults.set(true, forKey: UserDefaultsKey.switchKey2Migrated)
        }
        decodeSwitchKey2Status(storedSwitchKey2Status)

        beepOnModeSwitch = defaults.bool(
            forKey: UserDefaultsKey.beepOnModeSwitch,
            default: Defaults.beepOnModeSwitch
        )
        singleModifierSwitchKeys = defaults.integer(
            forKey: UserDefaultsKey.singleModifierSwitchKeys,
            default: 0
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
        defaults.set(encodeSwitchKey2Status(), forKey: UserDefaultsKey.switchKey2Status)
        defaults.set(beepOnModeSwitch, forKey: UserDefaultsKey.beepOnModeSwitch)
        defaults.set(singleModifierSwitchKeys, forKey: UserDefaultsKey.singleModifierSwitchKeys)

        // Save audio and display settings
        defaults.set(beepVolume, forKey: UserDefaultsKey.beepVolume)
        defaults.set(sanitizeMenuBarIconSize(menuBarIconSize), forKey: UserDefaultsKey.menuBarIconSize)
        defaults.set(useVietnameseMenubarIcon, forKey: UserDefaultsKey.useVietnameseMenubarIcon)

    }

    private func persistHotkeySettings() {
        SettingsObserver.shared.suspendNotifications()
        let defaults = UserDefaults.standard
        defaults.set(encodeSwitchKeyStatus(), forKey: UserDefaultsKey.switchKeyStatus)
        defaults.set(encodeSwitchKey2Status(), forKey: UserDefaultsKey.switchKey2Status)
        defaults.set(beepOnModeSwitch, forKey: UserDefaultsKey.beepOnModeSwitch)
    }

    private func persistSingleModifierSettings() {
        SettingsObserver.shared.suspendNotifications()
        let defaults = UserDefaults.standard
        defaults.set(singleModifierSwitchKeys, forKey: UserDefaultsKey.singleModifierSwitchKeys)
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
            | KeyCode.leftControlMask
            | KeyCode.rightControlMask
            | KeyCode.leftOptionMask
            | KeyCode.rightOptionMask
            | KeyCode.leftCommandMask
            | KeyCode.rightCommandMask
            | KeyCode.leftShiftMask
            | KeyCode.rightShiftMask
        let allowedMask = keyMask | modifierMask | KeyCode.beepMask

        let filtered = status & allowedMask
        let hasModifier = (filtered & modifierMask) != 0
        let key = filtered & keyMask
        let keyIsValid = key != KeyCode.keyMask
        
        let hasPhysicalKey = key != Int(KeyCode.noKey)
        let isNotSet = key == Int(KeyCode.noKey) && !hasModifier

        guard keyIsValid, (hasModifier || hasPhysicalKey || isNotSet) else {
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
        
        switchKeyLeftControl = (status & KeyCode.leftControlMask) != 0
        switchKeyRightControl = (status & KeyCode.rightControlMask) != 0
        switchKeyLeftOption = (status & KeyCode.leftOptionMask) != 0
        switchKeyRightOption = (status & KeyCode.rightOptionMask) != 0
        switchKeyLeftCommand = (status & KeyCode.leftCommandMask) != 0
        switchKeyRightCommand = (status & KeyCode.rightCommandMask) != 0
        switchKeyLeftShift = (status & KeyCode.leftShiftMask) != 0
        switchKeyRightShift = (status & KeyCode.rightShiftMask) != 0
        
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
        
        if switchKeyLeftControl { status |= KeyCode.leftControlMask }
        if switchKeyRightControl { status |= KeyCode.rightControlMask }
        if switchKeyLeftOption { status |= KeyCode.leftOptionMask }
        if switchKeyRightOption { status |= KeyCode.rightOptionMask }
        if switchKeyLeftCommand { status |= KeyCode.leftCommandMask }
        if switchKeyRightCommand { status |= KeyCode.rightCommandMask }
        if switchKeyLeftShift { status |= KeyCode.leftShiftMask }
        if switchKeyRightShift { status |= KeyCode.rightShiftMask }
        return status
    }

    private func decodeSwitchKey2Status(_ status: Int) {
        if status == Int(KeyCode.noKey) {
            switchKey2KeyCode = KeyCode.noKey
            switchKey2Control = false
            switchKey2LeftControl = false
            switchKey2RightControl = false
            switchKey2Option = false
            switchKey2LeftOption = false
            switchKey2RightOption = false
            switchKey2Command = false
            switchKey2LeftCommand = false
            switchKey2RightCommand = false
            switchKey2Shift = false
            switchKey2LeftShift = false
            switchKey2RightShift = false
            switchKey2Fn = false
            switchKey2Name = KeyCode.modifierOnlyDisplayName
            return
        }
        switchKey2KeyCode = UInt16(status & KeyCode.keyMask)
        switchKey2Control = (status & KeyCode.controlMask) != 0
        switchKey2Option = (status & KeyCode.optionMask) != 0
        switchKey2Command = (status & KeyCode.commandMask) != 0
        switchKey2Shift = (status & KeyCode.shiftMask) != 0
        switchKey2Fn = (status & KeyCode.fnMask) != 0
        
        switchKey2LeftControl = (status & KeyCode.leftControlMask) != 0
        switchKey2RightControl = (status & KeyCode.rightControlMask) != 0
        switchKey2LeftOption = (status & KeyCode.leftOptionMask) != 0
        switchKey2RightOption = (status & KeyCode.rightOptionMask) != 0
        switchKey2LeftCommand = (status & KeyCode.leftCommandMask) != 0
        switchKey2RightCommand = (status & KeyCode.rightCommandMask) != 0
        switchKey2LeftShift = (status & KeyCode.leftShiftMask) != 0
        switchKey2RightShift = (status & KeyCode.rightShiftMask) != 0
        
        switchKey2Name = keyCodeToName(switchKey2KeyCode)
    }

    func encodeSwitchKey2Status() -> Int {
        if switchKey2KeyCode == KeyCode.noKey && !switchKey2Control && !switchKey2Option && !switchKey2Command && !switchKey2Shift && !switchKey2Fn {
            return Int(KeyCode.noKey)
        }
        var status = Int(switchKey2KeyCode)
        if switchKey2Control { status |= KeyCode.controlMask }
        if switchKey2Option { status |= KeyCode.optionMask }
        if switchKey2Command { status |= KeyCode.commandMask }
        if switchKey2Shift { status |= KeyCode.shiftMask }
        if switchKey2Fn { status |= KeyCode.fnMask }
        
        if switchKey2LeftControl { status |= KeyCode.leftControlMask }
        if switchKey2RightControl { status |= KeyCode.rightControlMask }
        if switchKey2LeftOption { status |= KeyCode.leftOptionMask }
        if switchKey2RightOption { status |= KeyCode.rightOptionMask }
        if switchKey2LeftCommand { status |= KeyCode.leftCommandMask }
        if switchKey2RightCommand { status |= KeyCode.rightCommandMask }
        if switchKey2LeftShift { status |= KeyCode.leftShiftMask }
        if switchKey2RightShift { status |= KeyCode.rightShiftMask }
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
        switchKeyLeftCommand = false
        switchKeyRightCommand = false
        switchKeyOption = Defaults.switchKeyOption
        switchKeyLeftOption = false
        switchKeyRightOption = false
        switchKeyControl = Defaults.switchKeyControl
        switchKeyLeftControl = false
        switchKeyRightControl = false
        switchKeyShift = Defaults.switchKeyShift
        switchKeyLeftShift = false
        switchKeyRightShift = false
        switchKeyFn = Defaults.switchKeyFn
        switchKeyCode = Defaults.switchKeyCode
        switchKeyName = Defaults.switchKeyName

        switchKey2Command = false
        switchKey2LeftCommand = false
        switchKey2RightCommand = false
        switchKey2Option = false
        switchKey2LeftOption = false
        switchKey2RightOption = false
        switchKey2Control = false
        switchKey2LeftControl = false
        switchKey2RightControl = false
        switchKey2Shift = false
        switchKey2LeftShift = false
        switchKey2RightShift = false
        switchKey2Fn = false
        switchKey2KeyCode = KeyCode.noKey
        switchKey2Name = KeyCode.modifierOnlyDisplayName

        singleModifierSwitchKeys = 0
        beepOnModeSwitch = Defaults.beepOnModeSwitch

        beepVolume = Defaults.beepVolume
        menuBarIconSize = Defaults.menuBarIconSize
        useVietnameseMenubarIcon = Defaults.useVietnameseMenubarIcon

        saveSettings()
    }
}
