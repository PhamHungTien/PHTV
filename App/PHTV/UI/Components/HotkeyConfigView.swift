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
    
    private let modifierOnlyKeyCode: UInt16 = KeyCode.noKey
    private var bindable: Bindable<AppState> { Bindable(appState) }

    // Check if hotkey conflicts with restore key
    private var hasRestoreHotkeyConflict: Bool {
        guard appState.restoreOnEscape else { return false }

        switch appState.restoreKey {
        case .esc:
            return false // ESC never conflicts
        case .option:
            return appState.switchKeyOption
        case .control:
            return appState.switchKeyControl
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Modifier Keys Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Phím bổ trợ")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                HStack(spacing: 12) {
                    ModifierKeyButton(symbol: "⌃", name: "Control", isOn: bindable.switchKeyControl)
                    ModifierKeyButton(symbol: "⇧", name: "Shift", isOn: bindable.switchKeyShift)
                    ModifierKeyButton(symbol: "⌘", name: "Command", isOn: bindable.switchKeyCommand)
                    ModifierKeyButton(symbol: "⌥", name: "Option", isOn: bindable.switchKeyOption)
                    ModifierKeyButton(symbol: "fn", name: "Fn", isOn: bindable.switchKeyFn)
                }
                
                Text("Mặc định: Ctrl + Shift (bấm rồi thả)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Conflict warning
                if hasRestoreHotkeyConflict {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.system(size: 14))

                        Text("Phím bổ trợ trùng với phím khôi phục")
                            .font(.caption)
                            .foregroundStyle(.orange)

                        Spacer()
                    }
                    .padding(10)
                    .background {
                        if #available(macOS 26.0, *), SettingsVisualEffects.enableMaterials {
                            ZStack {
                                PHTVRoundedRect(cornerRadius: 8)
                                    .fill(.ultraThinMaterial)
                                PHTVRoundedRect(cornerRadius: 8)
                                    .fill(Color.orange.opacity(0.1))
                            }
                            .settingsGlassEffect(cornerRadius: 8)
                            .overlay(
                                PHTVRoundedRect(cornerRadius: 8)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                        } else {
                            PHTVRoundedRect(cornerRadius: 8)
                                .fill(Color.orange.opacity(0.1))
                                .overlay(
                                    PHTVRoundedRect(cornerRadius: 8)
                                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }

            Divider()
            
            // Key Selection Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Phím chính")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Text("(tùy chọn)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 16) {
                    // Key selector button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isRecording = true
                        }
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: isRecording ? "keyboard.badge.ellipsis" : "keyboard")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(isRecording ? Color.accentColor : .secondary)

                            Text(keyDisplayText)
                                .font(.body)
                                .foregroundStyle(isRecording ? Color.accentColor : .primary)
                                .animation(.easeInOut(duration: 0.2), value: keyDisplayText)

                            Spacer()

                            // Clear button - only show if a real key is set
                            if !isRecording && appState.switchKeyCode != modifierOnlyKeyCode {
                                Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            appState.switchKeyCode = modifierOnlyKeyCode
                                            appState.switchKeyName = KeyCode.modifierOnlyDisplayName
                                        }
                                    }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                        .imageScale(.medium)
                                }
                                .buttonStyle(.plain)
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(minWidth: 180)
                        .background {
                            if #available(macOS 26.0, *), SettingsVisualEffects.enableMaterials {
                                if isRecording {
                                    PHTVRoundedRect(cornerRadius: 10)
                                        .fill(Color.accentColor.opacity(0.1))
                                        .overlay(
                                            PHTVRoundedRect(cornerRadius: 10)
                                                .stroke(Color.accentColor, lineWidth: 1)
                                        )
                                } else {
                                    PHTVRoundedRect(cornerRadius: 10)
                                        .fill(.ultraThinMaterial)
                                        .settingsGlassEffect(cornerRadius: 10)
                                }
                            } else {
                                PHTVRoundedRect(cornerRadius: 10)
                                    .fill(isRecording ? .accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
                                    .overlay(
                                        PHTVRoundedRect(cornerRadius: 10)
                                            .stroke(isRecording ? .accentColor : Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.2), value: isRecording)
                    .background(KeyEventHandler(isRecording: $isRecording, appState: appState))
                    
                    // Current Hotkey Display
                    if hasValidHotkey {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tổ hợp hiện tại")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(currentHotkeyDisplay)
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundStyle(.tint)
                                .animation(.easeInOut(duration: 0.2), value: currentHotkeyDisplay)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background {
                            if #available(macOS 26.0, *), SettingsVisualEffects.enableMaterials {
                                ZStack {
                                    PHTVRoundedRect(cornerRadius: 10)
                                        .fill(.ultraThinMaterial)
                                    PHTVRoundedRect(cornerRadius: 10)
                                        .fill(Color.accentColor.opacity(0.08))
                                }
                                .settingsGlassEffect(cornerRadius: 10)
                            } else {
                                PHTVRoundedRect(cornerRadius: 10)
                                    .fill(Color.accentColor.opacity(0.08))
                            }
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                
                // Help text
                if appState.switchKeyCode == modifierOnlyKeyCode {
                    Text("💡 Chế độ chỉ dùng phím bổ trợ: Bấm và thả tổ hợp phím để chuyển đổi")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.top, 4)
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
    }
    
    private var keyDisplayText: String {
        if isRecording {
            return "Nhấn phím..."
        }
        if appState.switchKeyCode == modifierOnlyKeyCode {
            return "Không dùng (chỉ modifier)"
        }
        return appState.switchKeyName
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isOn.toggle()
            }
        }) {
            VStack(spacing: 6) {
                Text(symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isOn ? .white : .primary)

                Text(name)
                    .font(.caption2)
                    .foregroundStyle(isOn ? .white.opacity(0.9) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background {
                if isOn {
                    PHTVRoundedRect(cornerRadius: 10)
                        .fill(Color.accentColor)
                } else {
                    // Clearer unselected state with subtle fill and visible border
                    PHTVRoundedRect(cornerRadius: 10)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(colorScheme == .dark ? 0.5 : 0.8))
                        .overlay(
                            PHTVRoundedRect(cornerRadius: 10)
                                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.2 : 0.15), lineWidth: 1)
                        )
                }
            }
            .scaleEffect(isOn ? 1.0 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isOn)
    }
}

// MARK: - Key Event Handler
struct KeyEventHandler: NSViewRepresentable {
    @Binding var isRecording: Bool
    var appState: AppState
    
    func makeNSView(context: Context) -> NSView {
        let view = KeyCaptureView()
        view.onKeyPress = { keyCode, keyName in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                appState.switchKeyCode = keyCode
                appState.switchKeyName = keyName
                isRecording = false
            }
        }
        context.coordinator.view = view
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let keyView = nsView as? KeyCaptureView {
            keyView.isRecording = isRecording
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var view: KeyCaptureView?
    }
}

class KeyCaptureView: NSView {
    var onKeyPress: ((UInt16, String) -> Void)?
    var isRecording = false {
        didSet {
            if isRecording {
                window?.makeFirstResponder(self)
            }
        }
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        let keyCode = UInt16(event.keyCode)
        let keyName = getKeyName(for: keyCode)

        Task { @MainActor [weak self] in
            self?.onKeyPress?(keyCode, keyName)
        }
    }
    
    private func getKeyName(for keyCode: UInt16) -> String {
        // First try to get the actual character from the current keyboard layout
        // This ensures correct display on QWERTZ, AZERTY, and other layouts
        if let layoutKeyName = getKeyNameFromLayout(for: keyCode) {
            return layoutKeyName
        }

        // Fallback: Map common keycodes to readable names (special keys)
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
        default: return "Key \(keyCode)"
        }
    }

    /// Get the actual character produced by a keycode on the current keyboard layout
    /// This ensures correct display for international keyboards (QWERTZ, AZERTY, etc.)
    private func getKeyNameFromLayout(for keyCode: UInt16) -> String? {
        // Use TIS API to get the current keyboard layout and convert keycode to character
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

        // Convert UnsafePointer<UInt8> to UnsafePointer<UCKeyboardLayout>
        let keyboardLayout = UnsafeRawPointer(keyboardLayoutPtr).bindMemory(
            to: UCKeyboardLayout.self,
            capacity: 1
        )

        let error = UCKeyTranslate(
            keyboardLayout,
            keyCode,
            UInt16(kUCKeyActionDown),
            0,  // No modifiers
            UInt32(LMGetKbdType()),
            UInt32(kUCKeyTranslateNoDeadKeysMask),
            &deadKeyState,
            chars.count,
            &length,
            &chars
        )

        if error == noErr && length > 0 {
            let character = String(utf16CodeUnits: chars, count: length).uppercased()
            // Filter out control characters, empty strings, and whitespace (space key should use fallback)
            if !character.isEmpty && !character.trimmingCharacters(in: .whitespaces).isEmpty && character.unicodeScalars.first?.value ?? 0 >= 32 {
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
        VStack(alignment: .leading, spacing: 16) {
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

                // Key Selection Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Chọn phím tạm dừng")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

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
                }

                // Conflict warnings
                if hasPauseRestoreConflict {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.system(size: 14))

                        Text("Phím tạm dừng trùng với phím khôi phục")
                            .font(.caption)
                            .foregroundStyle(.orange)

                        Spacer()
                    }
                    .padding(10)
                    .background {
                        if #available(macOS 26.0, *), SettingsVisualEffects.enableMaterials {
                            ZStack {
                                PHTVRoundedRect(cornerRadius: 8)
                                    .fill(.ultraThinMaterial)
                                PHTVRoundedRect(cornerRadius: 8)
                                    .fill(Color.orange.opacity(0.1))
                            }
                            .settingsGlassEffect(cornerRadius: 8)
                            .overlay(
                                PHTVRoundedRect(cornerRadius: 8)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                        } else {
                            PHTVRoundedRect(cornerRadius: 8)
                                .fill(Color.orange.opacity(0.1))
                                .overlay(
                                    PHTVRoundedRect(cornerRadius: 8)
                                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                if hasPauseSwitchConflict {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.system(size: 14))

                        Text("Phím tạm dừng trùng với phím chuyển đổi ngôn ngữ")
                            .font(.caption)
                            .foregroundStyle(.orange)

                        Spacer()
                    }
                    .padding(10)
                    .background {
                        if #available(macOS 26.0, *), SettingsVisualEffects.enableMaterials {
                            ZStack {
                                PHTVRoundedRect(cornerRadius: 8)
                                    .fill(.ultraThinMaterial)
                                PHTVRoundedRect(cornerRadius: 8)
                                    .fill(Color.orange.opacity(0.1))
                            }
                            .settingsGlassEffect(cornerRadius: 8)
                            .overlay(
                                PHTVRoundedRect(cornerRadius: 8)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                        } else {
                            PHTVRoundedRect(cornerRadius: 8)
                                .fill(Color.orange.opacity(0.1))
                                .overlay(
                                    PHTVRoundedRect(cornerRadius: 8)
                                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
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
    @Environment(\.colorScheme) private var colorScheme

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
            VStack(spacing: 6) {
                Text(symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .primary)

                Text(name)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white.opacity(0.9) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background {
                if isSelected {
                    PHTVRoundedRect(cornerRadius: 10)
                        .fill(Color.accentColor)
                } else {
                    // Clearer unselected state with subtle fill and visible border
                    PHTVRoundedRect(cornerRadius: 10)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(colorScheme == .dark ? 0.5 : 0.8))
                        .overlay(
                            PHTVRoundedRect(cornerRadius: 10)
                                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.2 : 0.15), lineWidth: 1)
                        )
                }
            }
            .scaleEffect(isSelected ? 1.0 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Emoji Hotkey Configuration View
struct EmojiHotkeyConfigView: View {
    @Environment(AppState.self) private var appState
    @State private var isRecording = false

    private let modifierOnlyKeyCode: UInt16 = KeyCode.noKey
    private var bindable: Bindable<AppState> { Bindable(appState) }

    // Computed properties for modifier bindings
    private var emojiHotkeyControl: Binding<Bool> {
        Binding(
            get: { appState.emojiHotkeyModifiers.contains(.control) },
            set: { newValue in
                var modifiers = appState.emojiHotkeyModifiers
                if newValue {
                    modifiers.insert(.control)
                } else {
                    modifiers.remove(.control)
                }
                appState.emojiHotkeyModifiers = modifiers
            }
        )
    }

    private var emojiHotkeyShift: Binding<Bool> {
        Binding(
            get: { appState.emojiHotkeyModifiers.contains(.shift) },
            set: { newValue in
                var modifiers = appState.emojiHotkeyModifiers
                if newValue {
                    modifiers.insert(.shift)
                } else {
                    modifiers.remove(.shift)
                }
                appState.emojiHotkeyModifiers = modifiers
            }
        )
    }

    private var emojiHotkeyCommand: Binding<Bool> {
        Binding(
            get: { appState.emojiHotkeyModifiers.contains(.command) },
            set: { newValue in
                var modifiers = appState.emojiHotkeyModifiers
                if newValue {
                    modifiers.insert(.command)
                } else {
                    modifiers.remove(.command)
                }
                appState.emojiHotkeyModifiers = modifiers
            }
        )
    }

    private var emojiHotkeyOption: Binding<Bool> {
        Binding(
            get: { appState.emojiHotkeyModifiers.contains(.option) },
            set: { newValue in
                var modifiers = appState.emojiHotkeyModifiers
                if newValue {
                    modifiers.insert(.option)
                } else {
                    modifiers.remove(.option)
                }
                appState.emojiHotkeyModifiers = modifiers
            }
        )
    }

    private var emojiHotkeyFn: Binding<Bool> {
        Binding(
            get: { appState.emojiHotkeyModifiers.contains(.function) },
            set: { newValue in
                var modifiers = appState.emojiHotkeyModifiers
                if newValue {
                    modifiers.insert(.function)
                } else {
                    modifiers.remove(.function)
                }
                appState.emojiHotkeyModifiers = modifiers
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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

                // Modifier Keys Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Phím bổ trợ")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    HStack(spacing: 12) {
                        ModifierKeyButton(symbol: "⌃", name: "Control", isOn: emojiHotkeyControl)
                        ModifierKeyButton(symbol: "⇧", name: "Shift", isOn: emojiHotkeyShift)
                        ModifierKeyButton(symbol: "⌘", name: "Command", isOn: emojiHotkeyCommand)
                        ModifierKeyButton(symbol: "⌥", name: "Option", isOn: emojiHotkeyOption)
                        ModifierKeyButton(symbol: "fn", name: "Fn", isOn: emojiHotkeyFn)
                    }

                    Text("Mặc định: ⌘E")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Key Selection Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Phím chính")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)

                        Text("(tùy chọn)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 16) {
                        // Key selector button
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isRecording = true
                            }
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: isRecording ? "keyboard.badge.ellipsis" : "keyboard")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(isRecording ? Color.accentColor : .secondary)

                                Text(keyDisplayText)
                                    .font(.body)
                                    .foregroundStyle(isRecording ? Color.accentColor : .primary)
                                    .animation(.easeInOut(duration: 0.2), value: keyDisplayText)

                                Spacer()

                                // Clear button - only show if a real key is set
                                if !isRecording && appState.emojiHotkeyKeyCode != modifierOnlyKeyCode {
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            appState.emojiHotkeyKeyCode = modifierOnlyKeyCode
                                        }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                            .imageScale(.medium)
                                    }
                                    .buttonStyle(.plain)
                                    .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .frame(minWidth: 180)
                            .background {
                                if #available(macOS 26.0, *), SettingsVisualEffects.enableMaterials {
                                    if isRecording {
                                        PHTVRoundedRect(cornerRadius: 10)
                                            .fill(Color.accentColor.opacity(0.1))
                                            .overlay(
                                                PHTVRoundedRect(cornerRadius: 10)
                                                    .stroke(Color.accentColor, lineWidth: 1)
                                            )
                                    } else {
                                        PHTVRoundedRect(cornerRadius: 10)
                                            .fill(.ultraThinMaterial)
                                            .settingsGlassEffect(cornerRadius: 10)
                                    }
                                } else {
                                    PHTVRoundedRect(cornerRadius: 10)
                                        .fill(isRecording ? .accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
                                        .overlay(
                                            PHTVRoundedRect(cornerRadius: 10)
                                                .stroke(isRecording ? .accentColor : Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .animation(.easeInOut(duration: 0.2), value: isRecording)
                        .background(EmojiKeyEventHandler(isRecording: $isRecording, appState: appState))

                        // Current Hotkey Display
                        if hasValidHotkey {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Tổ hợp hiện tại")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text(currentHotkeyDisplay)
                                    .font(.system(.body, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.tint)
                                    .animation(.easeInOut(duration: 0.2), value: currentHotkeyDisplay)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background {
                                if #available(macOS 26.0, *), SettingsVisualEffects.enableMaterials {
                                    ZStack {
                                        PHTVRoundedRect(cornerRadius: 10)
                                            .fill(.ultraThinMaterial)
                                        PHTVRoundedRect(cornerRadius: 10)
                                            .fill(Color.accentColor.opacity(0.08))
                                    }
                                    .settingsGlassEffect(cornerRadius: 10)
                                } else {
                                    PHTVRoundedRect(cornerRadius: 10)
                                        .fill(Color.accentColor.opacity(0.08))
                                }
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                    }

                    // Help text for modifier-only mode
                    if isModifierOnlyMode {
                        Text("💡 Chế độ chỉ dùng phím bổ trợ: Bấm và thả tổ hợp phím để mở emoji")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .padding(.top, 4)
                    } else {
                        Text("💡 Mẹo: Dùng tổ hợp phím như ⌘E hoặc ⌃⇧E để mở emoji nhanh")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                }
            }
        }
    }

    private var isModifierOnlyMode: Bool {
        appState.emojiHotkeyKeyCode == modifierOnlyKeyCode
    }

    private var keyDisplayText: String {
        if isRecording {
            return "Nhấn phím..."
        }
        if isModifierOnlyMode {
            return "Không dùng (chỉ modifier)"
        }
        return emojiKeyName
    }

    private var emojiKeyName: String {
        let keyCode = appState.emojiHotkeyKeyCode
        if keyCode == modifierOnlyKeyCode {
            return KeyCode.modifierOnlyDisplayName
        }
        // Common key codes for emoji hotkeys
        switch keyCode {
        case 41: return ";"
        case KeyCode.eKey: return "E"
        case KeyCode.space: return "Space"
        case 44: return "/"
        case 39: return "'"
        case 43: return ","
        case 47: return "."
        default:
            // Try to get character from key code
            if let char = keyCodeToCharacter(keyCode) {
                return String(char).uppercased()
            }
            return KeyCode.name(for: keyCode)
        }
    }

    private var hasValidHotkey: Bool {
        // Valid if at least one modifier is selected
        let modifiers = appState.emojiHotkeyModifiers
        return modifiers.contains(.control) || modifiers.contains(.shift) ||
               modifiers.contains(.command) || modifiers.contains(.option) ||
               modifiers.contains(.function)
    }

    private var currentHotkeyDisplay: String {
        var parts: [String] = []
        let modifiers = appState.emojiHotkeyModifiers

        if modifiers.contains(.function) { parts.append("fn") }
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.option) { parts.append("⌥") }

        // Only add key name if it's a real key (not modifier-only mode)
        if !isModifierOnlyMode {
            parts.append(emojiKeyName)
        }

        return parts.isEmpty ? "Chưa đặt" : parts.joined(separator: " + ")
    }

    private func keyCodeToCharacter(_ keyCode: UInt16) -> Character? {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: true)
        var length = 0
        event?.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: nil)

        if length > 0 {
            var chars: [UniChar] = Array(repeating: 0, count: length)
            event?.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &chars)
            if let scalar = UnicodeScalar(chars[0]) {
                return Character(scalar)
            }
        }
        return nil
    }
}

// MARK: - Emoji Key Event Handler
struct EmojiKeyEventHandler: NSViewRepresentable {
    @Binding var isRecording: Bool
    var appState: AppState

    func makeNSView(context: Context) -> NSView {
        let view = EmojiKeyCaptureView()
        view.onKeyPress = { keyCode in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                appState.emojiHotkeyKeyCode = keyCode
                isRecording = false
            }
        }
        context.coordinator.view = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let keyView = nsView as? EmojiKeyCaptureView {
            keyView.isRecording = isRecording
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var view: EmojiKeyCaptureView?
    }
}

class EmojiKeyCaptureView: NSView {
    var onKeyPress: ((UInt16) -> Void)?
    var isRecording = false {
        didSet {
            if isRecording {
                window?.makeFirstResponder(self)
            }
        }
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        let keyCode = UInt16(event.keyCode)

        Task { @MainActor [weak self] in
            self?.onKeyPress?(keyCode)
        }
    }
}

#Preview {
    HotkeyConfigView()
        .environment(AppState.shared)
}
