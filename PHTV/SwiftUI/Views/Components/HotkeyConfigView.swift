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

struct HotkeyConfigView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isRecording = false
    
    // 0xFE = modifier only mode (no key needed, just press and release modifiers)
    private let modifierOnlyKeyCode: UInt16 = 0xFE
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Modifier Keys Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Phím bổ trợ")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                HStack(spacing: 12) {
                    ModifierKeyButton(symbol: "⌃", name: "Control", isOn: $appState.switchKeyControl)
                    ModifierKeyButton(symbol: "⇧", name: "Shift", isOn: $appState.switchKeyShift)
                    ModifierKeyButton(symbol: "⌘", name: "Command", isOn: $appState.switchKeyCommand)
                    ModifierKeyButton(symbol: "⌥", name: "Option", isOn: $appState.switchKeyOption)
                    ModifierKeyButton(symbol: "fn", name: "Fn", isOn: $appState.switchKeyFn)
                }
                
                Text("Mặc định: Ctrl + Shift (bấm rồi thả)")
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
                                .foregroundStyle(isRecording ? themeManager.themeColor : .secondary)

                            Text(keyDisplayText)
                                .font(.body)
                                .foregroundStyle(isRecording ? themeManager.themeColor : .primary)
                                .animation(.easeInOut(duration: 0.2), value: keyDisplayText)

                            Spacer()

                            // Clear button - only show if a real key is set
                            if !isRecording && appState.switchKeyCode != modifierOnlyKeyCode {
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        appState.switchKeyCode = modifierOnlyKeyCode
                                        appState.switchKeyName = "Không"
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
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isRecording ? themeManager.themeColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(isRecording ? themeManager.themeColor : Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        )
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
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(themeManager.themeColor.opacity(0.08))
                        )
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
                HStack(spacing: 14) {
                    ZStack {
                        if #available(macOS 26.0, *) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(themeManager.themeColor.opacity(0.12))
                                .frame(width: 36, height: 36)
                                .glassEffect(in: .rect(cornerRadius: 8))
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(themeManager.themeColor.opacity(0.12))
                                .frame(width: 36, height: 36)
                        }

                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(themeManager.themeColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Phát âm thanh khi chuyển chế độ")
                            .font(.body)
                            .foregroundStyle(.primary)

                        Text("Phát beep khi bấm phím tắt")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: $appState.beepOnModeSwitch)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(themeManager.themeColor)
                }
                .padding(.vertical, 6)
                .padding(.top, 8)

                // Beep volume slider (under the toggle)
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "speaker.wave.2")
                            .foregroundStyle(.secondary)
                        Text("Âm lượng beep")
                        Spacer()
                        Text(String(format: "%.0f%%", appState.beepVolume * 100))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .font(.body)

                    Slider(
                        value: $appState.beepVolume,
                        in: 0.0...1.0,
                        step: 0.01,
                        onEditingChanged: { editing in
                            // Play pop sound on slider release
                            if !editing && appState.beepVolume > 0 {
                                BeepManager.shared.play(volume: appState.beepVolume)
                            }
                        }
                    )
                    .tint(themeManager.themeColor)
                    // The slider should still adjust volume even if the mode beep is disabled
                }
                .padding(.leading, 50)
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
        if appState.switchKeyCode != modifierOnlyKeyCode && !appState.switchKeyName.isEmpty && appState.switchKeyName != "Không" {
            parts.append(appState.switchKeyName)
        }
        
        return parts.isEmpty ? "Chưa đặt" : parts.joined(separator: " + ")
    }
}

struct ModifierKeyButton: View {
    @EnvironmentObject var themeManager: ThemeManager
    let symbol: String
    let name: String
    @Binding var isOn: Bool

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isOn.toggle()
            }
        }) {
            VStack(spacing: 6) {
                Text(symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isOn ? .white : .primary)

                Text(name)
                    .font(.caption2)
                    .foregroundStyle(isOn ? .white.opacity(0.9) : .secondary)
            }
            .frame(width: 70, height: 56)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isOn ? themeManager.themeColor : Color(NSColor.controlBackgroundColor))
                    .shadow(color: isOn ? themeManager.themeColor.opacity(0.3) : Color.clear, radius: 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isOn ? Color.clear : Color.gray.opacity(0.25), lineWidth: 1)
            )
            .scaleEffect(isOn ? 1.0 : 0.98)
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
        DispatchQueue.main.async {
            context.coordinator.view = view
        }
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

        // Call with animation on main thread
        DispatchQueue.main.async { [weak self] in
            self?.onKeyPress?(keyCode, keyName)
        }
    }
    
    private func getKeyName(for keyCode: UInt16) -> String {
        // Map common keycodes to readable names
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
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
        default: return "Key \(keyCode)"
        }
    }
}

#Preview {
    HotkeyConfigView()
        .environmentObject(AppState.shared)
}
