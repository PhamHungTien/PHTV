//
//  HotkeyConfigView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import Carbon
import AudioToolbox
import AppKit
import Observation

struct HotkeyConfigView: View {
    @Environment(AppState.self) private var appState
    @State private var isRecording = false
    @State private var isRecordingSingle = false
    @State private var showSecondaryHotkey = false
    
    private let modifierOnlyKeyCode: UInt16 = KeyCode.noKey
    private var bindable: Bindable<AppState> { Bindable(appState) }

    // Check if hotkey conflicts with restore key
    private var hasRestoreHotkeyConflict: Bool {
        guard appState.restoreOnEscape else { return false }

        switch appState.restoreKey {
        case .esc:
            return false // ESC never conflicts
        case .option:
            return appState.switchKeyOption || appState.switchKey2Option
        case .control:
            return appState.switchKeyControl || appState.switchKey2Control
        }
    }

    private var hasSecondaryHotkey: Bool {
        appState.switchKey2KeyCode != modifierOnlyKeyCode || appState.switchKey2Control || appState.switchKey2Option || appState.switchKey2Command || appState.switchKey2Shift || appState.switchKey2Fn
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Hotkey 1 Selection - Compact inline row
            HStack(alignment: .center, spacing: 16) {
                HStack(spacing: 4) {
                    Text("Phím tắt chuyển đổi")
                        .font(.body)
                        .foregroundStyle(.primary)
                }
                .layoutPriority(1)

                Spacer(minLength: 12)

                HStack(spacing: 6) {
                    // Clear button
                    if !isRecording && (appState.switchKeyCode != modifierOnlyKeyCode || appState.switchKeyControl || appState.switchKeyOption || appState.switchKeyCommand || appState.switchKeyShift || appState.switchKeyFn) {
                        Button(action: {
                            appState.switchKeyCode = modifierOnlyKeyCode
                            appState.switchKeyControl = false
                            appState.switchKeyOption = false
                            appState.switchKeyCommand = false
                            appState.switchKeyShift = false
                            appState.switchKeyFn = false
                            appState.switchKeyName = KeyCode.modifierOnlyDisplayName
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .imageScale(.small)
                        }
                        .buttonStyle(.plain)
                    }

                    // Key capture button
                    Button(action: {
                        isRecording = true
                    }) {
                        SettingsShortcutRecorderLabel(text: keyDisplayText, isRecording: isRecording)
                    }
                    .buttonStyle(SettingsShortcutRecorderButtonStyle(isRecording: isRecording))
                    .background(UnifiedHotkeyEventHandler(
                        isRecording: $isRecording,
                        onCaptured: { keyCode, modifiers, rawFlags in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                appState.switchKeyCode = keyCode
                                appState.switchKeyControl = modifiers.contains(.control)
                                appState.switchKeyOption = modifiers.contains(.option)
                                appState.switchKeyCommand = modifiers.contains(.command)
                                appState.switchKeyShift = modifiers.contains(.shift)
                                appState.switchKeyFn = modifiers.contains(.function)
                                
                                let raw = rawFlags
                                appState.switchKeyLeftControl = (raw & 0x0001) != 0
                                appState.switchKeyRightControl = (raw & 0x2000) != 0
                                appState.switchKeyLeftShift = (raw & 0x0002) != 0
                                appState.switchKeyRightShift = (raw & 0x0004) != 0
                                appState.switchKeyLeftOption = (raw & 0x0020) != 0
                                appState.switchKeyRightOption = (raw & 0x0040) != 0
                                appState.switchKeyLeftCommand = (raw & 0x0008) != 0
                                appState.switchKeyRightCommand = (raw & 0x0010) != 0
                                
                                appState.switchKeyName = SettingsHotkeyKeyNameResolver.name(for: keyCode)
                                isRecording = false
                            }
                        },
                        onCancelled: {
                            isRecording = false
                        }
                    ))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, SettingsLayout.rowVerticalPadding)

            Divider()

            if hasSecondaryHotkey || showSecondaryHotkey {
                // Hotkey 2 Selection - Compact inline row
                HStack(alignment: .center, spacing: 16) {
                    HStack(spacing: 4) {
                        Text("Phím tắt chuyển đổi phụ")
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 12)

                    HStack(spacing: 6) {
                        // Clear button
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                appState.switchKey2KeyCode = modifierOnlyKeyCode
                                appState.switchKey2Control = false
                                appState.switchKey2Option = false
                                appState.switchKey2Command = false
                                appState.switchKey2Shift = false
                                appState.switchKey2Fn = false
                                appState.switchKey2Name = KeyCode.modifierOnlyDisplayName
                                showSecondaryHotkey = false
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .imageScale(.small)
                        }
                        .buttonStyle(.plain)

                        // Key capture button
                        Button(action: {
                            isRecordingSingle = true
                        }) {
                            SettingsShortcutRecorderLabel(text: switchKey2DisplayText, isRecording: isRecordingSingle)
                        }
                        .buttonStyle(SettingsShortcutRecorderButtonStyle(isRecording: isRecordingSingle))
                        .background(UnifiedHotkeyEventHandler(
                            isRecording: $isRecordingSingle,
                            onCaptured: { keyCode, modifiers, rawFlags in
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    appState.switchKey2KeyCode = keyCode
                                    appState.switchKey2Control = modifiers.contains(.control)
                                    appState.switchKey2Option = modifiers.contains(.option)
                                    appState.switchKey2Command = modifiers.contains(.command)
                                    appState.switchKey2Shift = modifiers.contains(.shift)
                                    appState.switchKey2Fn = modifiers.contains(.function)
                                    
                                    let raw = rawFlags
                                    appState.switchKey2LeftControl = (raw & 0x0001) != 0
                                    appState.switchKey2RightControl = (raw & 0x2000) != 0
                                    appState.switchKey2LeftShift = (raw & 0x0002) != 0
                                    appState.switchKey2RightShift = (raw & 0x0004) != 0
                                    appState.switchKey2LeftOption = (raw & 0x0020) != 0
                                    appState.switchKey2RightOption = (raw & 0x0040) != 0
                                    appState.switchKey2LeftCommand = (raw & 0x0008) != 0
                                    appState.switchKey2RightCommand = (raw & 0x0010) != 0
                                    
                                    appState.switchKey2Name = SettingsHotkeyKeyNameResolver.name(for: keyCode)
                                    isRecordingSingle = false
                                }
                            },
                            onCancelled: {
                                isRecordingSingle = false
                            }
                        ))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, SettingsLayout.rowVerticalPadding)

                Divider()
            } else {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showSecondaryHotkey = true
                        isRecordingSingle = true
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.accentColor)
                        Text("Thêm phím tắt chuyển đổi phụ")
                            .font(.body)
                            .foregroundStyle(Color.accentColor)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, SettingsLayout.rowVerticalPadding)

                Divider()
            }

            
            // Beep on mode switch toggle
            SettingsToggleRow(
                icon: "speaker.wave.2.fill",
                iconColor: .accentColor,
                title: "Phát âm thanh khi chuyển chế độ",
                subtitle: "Phát beep khi bấm phím tắt",
                isOn: bindable.beepOnModeSwitch
            )
            .padding(.top, 8)

            // Beep volume slider (only show when beep is enabled)
            if appState.beepOnModeSwitch {
                SettingsDivider()

                SettingsSliderRow(
                    icon: "speaker.wave.2",
                    iconColor: .accentColor,
                    title: "Âm lượng beep",
                    subtitle: "Điều chỉnh mức âm lượng tiếng beep",
                    minValue: 0.0,
                    maxValue: 1.0,
                    step: 0.01,
                    value: bindable.beepVolume,
                    valueFormatter: { String(format: "%.0f%%", $0 * 100) },
                    onEditingChanged: { editing in
                        // Play pop sound on slider release
                        if !editing && appState.beepVolume > 0 {
                            BeepManager.shared.play(volume: appState.beepVolume)
                        }
                    }
                )
            }
        }
    }
    
    private var keyDisplayText: String {
        if isRecording {
            return "Nhấn phím..."
        }
        if appState.switchKeyCode == modifierOnlyKeyCode && !appState.switchKeyControl && !appState.switchKeyOption && !appState.switchKeyCommand && !appState.switchKeyShift && !appState.switchKeyFn {
            return "Chưa đặt"
        }
        return HotkeyFormatter.switchHotkeyString(
            control: appState.switchKeyControl,
            leftControl: appState.switchKeyLeftControl,
            rightControl: appState.switchKeyRightControl,
            option: appState.switchKeyOption,
            leftOption: appState.switchKeyLeftOption,
            rightOption: appState.switchKeyRightOption,
            shift: appState.switchKeyShift,
            leftShift: appState.switchKeyLeftShift,
            rightShift: appState.switchKeyRightShift,
            command: appState.switchKeyCommand,
            leftCommand: appState.switchKeyLeftCommand,
            rightCommand: appState.switchKeyRightCommand,
            fn: appState.switchKeyFn,
            keyCode: appState.switchKeyCode,
            keyName: appState.switchKeyName
        )
    }

    private var switchKey2DisplayText: String {
        if isRecordingSingle {
            return "Nhấn phím..."
        }
        if appState.switchKey2KeyCode == modifierOnlyKeyCode && !appState.switchKey2Control && !appState.switchKey2Option && !appState.switchKey2Command && !appState.switchKey2Shift && !appState.switchKey2Fn {
            return "Chưa đặt"
        }
        return HotkeyFormatter.switchHotkeyString(
            control: appState.switchKey2Control,
            leftControl: appState.switchKey2LeftControl,
            rightControl: appState.switchKey2RightControl,
            option: appState.switchKey2Option,
            leftOption: appState.switchKey2LeftOption,
            rightOption: appState.switchKey2RightOption,
            shift: appState.switchKey2Shift,
            leftShift: appState.switchKey2LeftShift,
            rightShift: appState.switchKey2RightShift,
            command: appState.switchKey2Command,
            leftCommand: appState.switchKey2LeftCommand,
            rightCommand: appState.switchKey2RightCommand,
            fn: appState.switchKey2Fn,
            keyCode: appState.switchKey2KeyCode,
            keyName: appState.switchKey2Name
        )
    }
    
    private var hasValidHotkey: Bool {
        // Valid if at least one modifier is selected
        return appState.switchKeyControl || appState.switchKeyOption || 
               appState.switchKeyCommand || appState.switchKeyShift || appState.switchKeyFn
    }
    
    private var currentHotkeyDisplay: String {
        var parts: [String] = []
        if appState.switchKeyFn { parts.append("fn") }
        if appState.switchKeyControl { parts.append("⌃") }
        if appState.switchKeyShift { parts.append("⇧") }
        if appState.switchKeyCommand { parts.append("⌘") }
        if appState.switchKeyOption { parts.append("⌥") }
        
        // Only add key name if it's a real key (not modifier-only mode)
        if appState.switchKeyCode != modifierOnlyKeyCode &&
            !appState.switchKeyName.isEmpty &&
            appState.switchKeyName != KeyCode.modifierOnlyDisplayName {
            parts.append(appState.switchKeyName)
        }
        
        return parts.isEmpty ? "Chưa đặt" : parts.joined(separator: " + ")
    }

}

struct ModifierKeyButton: View {
    let symbol: String
    let name: String
    @Binding var isOn: Bool

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isOn.toggle()
            }
        }) {
            HStack(spacing: 4) {
                Text(symbol)
                    .font(.system(size: 14, weight: .semibold))

                if !name.isEmpty {
                    Text(name)
                        .font(.system(size: 11))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .settingsControlButtonStyle(isProminent: isOn)
        .controlSize(.small)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isOn)
    }
}




enum SettingsHotkeyKeyNameResolver {
    static func name(for keyCode: UInt16) -> String {
        // First try to get the actual character from the current keyboard layout.
        // This keeps display correct on QWERTZ, AZERTY, and other layouts.
        if let layoutKeyName = nameFromCurrentLayout(for: keyCode) {
            return layoutKeyName
        }

        switch Int(keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Delete: return "Delete"
        case kVK_Escape: return "Esc"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_Home: return "Home"
        case kVK_End: return "End"
        case kVK_PageUp: return "PgUp"
        case kVK_PageDown: return "PgDn"
        case kVK_ForwardDelete: return "⌦"
        default: return KeyCode.name(for: keyCode)
        }
    }

    private static func nameFromCurrentLayout(for keyCode: UInt16) -> String? {
        guard let inputSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let layoutDataRef = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }

        let propertyValue = Unmanaged<CFTypeRef>.fromOpaque(layoutDataRef).takeUnretainedValue()
        guard CFGetTypeID(propertyValue) == CFDataGetTypeID() else {
            return nil
        }
        let layoutData = unsafeDowncast(propertyValue, to: CFData.self)
        guard let keyboardLayoutPtr = CFDataGetBytePtr(layoutData) else {
            return nil
        }

        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length: Int = 0
        let keyboardLayout = UnsafeRawPointer(keyboardLayoutPtr).bindMemory(
            to: UCKeyboardLayout.self,
            capacity: 1
        )

        let error = UCKeyTranslate(
            keyboardLayout,
            keyCode,
            UInt16(kUCKeyActionDown),
            0,
            UInt32(LMGetKbdType()),
            UInt32(kUCKeyTranslateNoDeadKeysMask),
            &deadKeyState,
            chars.count,
            &length,
            &chars
        )

        if error == noErr && length > 0 {
            let character = String(utf16CodeUnits: chars, count: length).uppercased()
            if !character.isEmpty,
               !character.trimmingCharacters(in: .whitespaces).isEmpty,
               character.unicodeScalars.first?.value ?? 0 >= 32 {
                return character
            }
        }

        return nil
    }
}


// MARK: - Custom Slider without tick marks
struct CustomSlider: NSViewRepresentable {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let tintColor: Color
    var onEditingChanged: ((Bool) -> Void)? = nil

    func makeNSView(context: Context) -> NSSlider {
        let slider = NSSlider()
        slider.minValue = range.lowerBound
        slider.maxValue = range.upperBound
        slider.doubleValue = value
        slider.target = context.coordinator
        slider.action = #selector(Coordinator.valueChanged(_:))

        // Important: Remove tick marks
        slider.numberOfTickMarks = 0
        slider.allowsTickMarkValuesOnly = false

        // Set initial color
        if let nsColor = convertToNSColor(tintColor) {
            slider.trackFillColor = nsColor
            context.coordinator.lastColor = nsColor
        }

        return slider
    }

    func updateNSView(_ nsView: NSSlider, context: Context) {
        // Update value if changed
        if Swift.abs(nsView.doubleValue - value) > 0.001 {
            nsView.doubleValue = value
        }

        // Update range
        nsView.minValue = range.lowerBound
        nsView.maxValue = range.upperBound

        // Update tint color only if it actually changed
        if let newNSColor = convertToNSColor(tintColor) {
            if context.coordinator.lastColor != newNSColor {
                nsView.trackFillColor = newNSColor
                context.coordinator.lastColor = newNSColor
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    @MainActor
    class Coordinator: NSObject {
        var parent: CustomSlider
        var previousValue: Double?
        var debounceTask: Task<Void, Never>?
        var lastColor: NSColor?

        init(_ parent: CustomSlider) {
            self.parent = parent
        }

        @objc func valueChanged(_ sender: NSSlider) {
            // Round to step if needed
            let rawValue = sender.doubleValue
            let steppedValue = round(rawValue / parent.step) * parent.step

            // Detect editing state by checking if this is the first change
            if previousValue == nil {
                // Start of editing
                parent.onEditingChanged?(true)
            }

            parent.value = steppedValue
            previousValue = steppedValue

            // Cancel previous debounce task
            debounceTask?.cancel()

            // Use delay to detect end of editing (when user releases slider)
            debounceTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, !Task.isCancelled else { return }
                // Value hasn't changed for 0.1s, editing ended
                self.parent.onEditingChanged?(false)
                self.previousValue = nil
            }
        }
    }
}

// Helper to convert SwiftUI Color to NSColor
fileprivate func convertToNSColor(_ color: Color) -> NSColor? {
    guard let cgColor = color.cgColor else { return nil }
    return NSColor(cgColor: cgColor)
}

// MARK: - Pause Key Configuration View
struct PauseKeyConfigView: View {
    @Environment(AppState.self) private var appState
    private var bindable: Bindable<AppState> { Bindable(appState) }

    // Check if pause key conflicts with restore key
    private var hasPauseRestoreConflict: Bool {
        guard appState.pauseKeyEnabled && appState.restoreOnEscape else { return false }

        // Compare keyCode directly
        return appState.pauseKey == appState.restoreKey.rawValue
    }

    // Check if pause key conflicts with switch key
    private var hasPauseSwitchConflict: Bool {
        guard appState.pauseKeyEnabled else { return false }

        // Check if pause key matches switch key code (if set)
        if !KeyCode.isModifierOnly(appState.switchKeyCode) && appState.pauseKey == appState.switchKeyCode {
            return true
        }

        // Check if pause key matches any switch modifier
        if appState.pauseKey == KeyCode.leftOption && appState.switchKeyOption { return true }  // Option
        if appState.pauseKey == KeyCode.leftControl && appState.switchKeyControl { return true } // Control

        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Enable toggle
            SettingsToggleRow(
                icon: "pause.fill",
                iconColor: .accentColor,
                title: "Bật tính năng tạm dừng",
                subtitle: "Nhấn giữ phím để tạm thời chuyển sang tiếng Anh",
                isOn: bindable.pauseKeyEnabled
            )

            if appState.pauseKeyEnabled {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        PauseKeyButton(
                            symbol: "⌃",
                            name: "Control",
                            keyCode: KeyCode.leftControl,
                            selectedKeyCode: bindable.pauseKey,
                            selectedKeyName: bindable.pauseKeyName
                        )
                        PauseKeyButton(
                            symbol: "⌥",
                            name: "Option",
                            keyCode: KeyCode.leftOption,
                            selectedKeyCode: bindable.pauseKey,
                            selectedKeyName: bindable.pauseKeyName
                        )
                    }

                    Text("Mặc định: Option (⌥)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Conflict warnings
                    if hasPauseRestoreConflict {
                        Label("Phím tạm dừng trùng với phím khôi phục", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    if hasPauseSwitchConflict {
                        Label("Phím tạm dừng trùng với phím chuyển đổi ngôn ngữ", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }
}

// MARK: - Pause Key Button (Radio button style)
struct PauseKeyButton: View {
    let symbol: String
    let name: String
    let keyCode: UInt16
    @Binding var selectedKeyCode: UInt16
    @Binding var selectedKeyName: String

    private var isSelected: Bool {
        selectedKeyCode == keyCode
    }

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedKeyCode = keyCode
                selectedKeyName = name
            }
        }) {
            HStack(spacing: 4) {
                Text(symbol)
                    .font(.system(size: 14, weight: .semibold))

                Text(name)
                    .font(.system(size: 11))
            }
            .frame(maxWidth: .infinity)
        }
        .settingsControlButtonStyle(isProminent: isSelected)
        .controlSize(.small)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Emoji Hotkey Configuration View
// MARK: - Emoji Hotkey Configuration View
struct EmojiHotkeyConfigView: View {
    @Environment(AppState.self) private var appState
    @State private var isRecording = false

    private let modifierOnlyKeyCode: UInt16 = KeyCode.noKey
    private var bindable: Bindable<AppState> { Bindable(appState) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Enable toggle
            SettingsToggleRow(
                icon: "smiley.fill",
                iconColor: .accentColor,
                title: "Bật phím tắt PHTV Picker",
                subtitle: "Mở bảng tùy chọn Emoji, GIF, Sticker của PHTV",
                isOn: bindable.enableEmojiHotkey
            )

            if appState.enableEmojiHotkey {
                Divider()

                // Key Selection - Compact inline row
                HStack(alignment: .center, spacing: 16) {
                    HStack(spacing: 4) {
                        Text("Phím tắt")
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 12)

                    HStack(spacing: 6) {
                        // Clear button
                        if !isRecording && (appState.emojiHotkeyKeyCode != modifierOnlyKeyCode || !appState.emojiHotkeyModifiers.isEmpty) {
                            Button(action: {
                                appState.emojiHotkeyKeyCode = modifierOnlyKeyCode
                                appState.emojiHotkeyModifiers = []
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                                    .imageScale(.small)
                            }
                            .buttonStyle(.plain)
                        }

                        // Key capture button
                        Button(action: {
                            isRecording = true
                        }) {
                            SettingsShortcutRecorderLabel(text: keyDisplayText, isRecording: isRecording)
                        }
                        .buttonStyle(SettingsShortcutRecorderButtonStyle(isRecording: isRecording))
                        .background(UnifiedHotkeyEventHandler(
                            isRecording: $isRecording,
                            onCaptured: { keyCode, modifiers, _ in
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    appState.emojiHotkeyKeyCode = keyCode
                                    appState.emojiHotkeyModifiers = modifiers
                                    isRecording = false
                                }
                            },
                            onCancelled: {
                                isRecording = false
                            }
                        ))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, SettingsLayout.rowVerticalPadding)
            }
        }
    }

    private var keyDisplayText: String {
        if isRecording {
            return "Nhấn phím..."
        }
        if appState.emojiHotkeyKeyCode == modifierOnlyKeyCode && appState.emojiHotkeyModifiers.isEmpty {
            return "Chưa đặt"
        }
        return HotkeyFormatter.switchHotkeyString(
            control: appState.emojiHotkeyModifiers.contains(.control),
            option: appState.emojiHotkeyModifiers.contains(.option),
            shift: appState.emojiHotkeyModifiers.contains(.shift),
            command: appState.emojiHotkeyModifiers.contains(.command),
            fn: appState.emojiHotkeyModifiers.contains(.function),
            keyCode: appState.emojiHotkeyKeyCode,
            keyName: KeyCode.name(for: appState.emojiHotkeyKeyCode)
        )
    }
}

#Preview {
    HotkeyConfigView()
        .environment(AppState.shared)
}
