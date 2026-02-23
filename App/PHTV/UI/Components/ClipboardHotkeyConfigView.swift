//
//  ClipboardHotkeyConfigView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

struct ClipboardHotkeyConfigView: View {
    @EnvironmentObject var appState: AppState
    @State private var isRecording = false

    private let modifierOnlyKeyCode: UInt16 = KeyCode.noKey

    private var clipboardHotkeyControl: Binding<Bool> {
        Binding(
            get: { appState.clipboardHotkeyModifiers.contains(.control) },
            set: { newValue in
                var modifiers = appState.clipboardHotkeyModifiers
                if newValue { modifiers.insert(.control) } else { modifiers.remove(.control) }
                appState.clipboardHotkeyModifiers = modifiers
            }
        )
    }

    private var clipboardHotkeyShift: Binding<Bool> {
        Binding(
            get: { appState.clipboardHotkeyModifiers.contains(.shift) },
            set: { newValue in
                var modifiers = appState.clipboardHotkeyModifiers
                if newValue { modifiers.insert(.shift) } else { modifiers.remove(.shift) }
                appState.clipboardHotkeyModifiers = modifiers
            }
        )
    }

    private var clipboardHotkeyCommand: Binding<Bool> {
        Binding(
            get: { appState.clipboardHotkeyModifiers.contains(.command) },
            set: { newValue in
                var modifiers = appState.clipboardHotkeyModifiers
                if newValue { modifiers.insert(.command) } else { modifiers.remove(.command) }
                appState.clipboardHotkeyModifiers = modifiers
            }
        )
    }

    private var clipboardHotkeyOption: Binding<Bool> {
        Binding(
            get: { appState.clipboardHotkeyModifiers.contains(.option) },
            set: { newValue in
                var modifiers = appState.clipboardHotkeyModifiers
                if newValue { modifiers.insert(.option) } else { modifiers.remove(.option) }
                appState.clipboardHotkeyModifiers = modifiers
            }
        )
    }

    private var clipboardHotkeyFn: Binding<Bool> {
        Binding(
            get: { appState.clipboardHotkeyModifiers.contains(.function) },
            set: { newValue in
                var modifiers = appState.clipboardHotkeyModifiers
                if newValue { modifiers.insert(.function) } else { modifiers.remove(.function) }
                appState.clipboardHotkeyModifiers = modifiers
            }
        )
    }

    private var keyDisplayText: String {
        if isRecording { return "Nhấn phím..." }
        if appState.clipboardHotkeyKeyCode == modifierOnlyKeyCode {
            return "Không dùng (chỉ modifier)"
        }
        return keyCodeToName(appState.clipboardHotkeyKeyCode)
    }

    private var hasValidHotkey: Bool {
        !appState.clipboardHotkeyModifiers.isEmpty
    }

    private var currentHotkeyString: String {
        var parts: [String] = []
        let mods = appState.clipboardHotkeyModifiers
        if mods.contains(.control) { parts.append("⌃") }
        if mods.contains(.shift) { parts.append("⇧") }
        if mods.contains(.command) { parts.append("⌘") }
        if mods.contains(.option) { parts.append("⌥") }
        if mods.contains(.function) { parts.append("fn") }
        if appState.clipboardHotkeyKeyCode != modifierOnlyKeyCode {
            parts.append(keyCodeToName(appState.clipboardHotkeyKeyCode))
        }
        return parts.isEmpty ? "Chưa đặt" : parts.joined(separator: " + ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Enable toggle
            SettingsToggleRow(
                icon: "doc.on.clipboard.fill",
                iconColor: .accentColor,
                title: "Bật lịch sử Clipboard",
                subtitle: "Lưu lại nội dung đã sao chép và mở nhanh bằng phím tắt",
                isOn: $appState.enableClipboardHistory
            )

            if appState.enableClipboardHistory {
                Divider()

                // Modifier Keys Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Phím bổ trợ")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    HStack(spacing: 12) {
                        ModifierKeyButton(symbol: "⌃", name: "Control", isOn: clipboardHotkeyControl)
                        ModifierKeyButton(symbol: "⇧", name: "Shift", isOn: clipboardHotkeyShift)
                        ModifierKeyButton(symbol: "⌘", name: "Command", isOn: clipboardHotkeyCommand)
                        ModifierKeyButton(symbol: "⌥", name: "Option", isOn: clipboardHotkeyOption)
                        ModifierKeyButton(symbol: "fn", name: "Fn", isOn: clipboardHotkeyFn)
                    }

                    Text("Mặc định: ⌃V")
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

                                if !isRecording && appState.clipboardHotkeyKeyCode != modifierOnlyKeyCode {
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            appState.clipboardHotkeyKeyCode = modifierOnlyKeyCode
                                        }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                            .imageScale(.medium)
                                    }
                                    .buttonStyle(.plain)
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
                        .background(
                            ClipboardKeyEventHandler(isRecording: $isRecording, appState: appState)
                        )

                        if hasValidHotkey {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Tổ hợp hiện tại")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(currentHotkeyString)
                                    .font(.system(.body, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.tint)
                                    .animation(.easeInOut(duration: 0.2), value: currentHotkeyString)
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
                }

                Divider()

                // Max items slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Số mục tối đa")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)

                        Spacer()

                        Text("\(appState.clipboardHistoryMaxItems)")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 30, alignment: .trailing)
                    }

                    Slider(
                        value: Binding(
                            get: { Double(appState.clipboardHistoryMaxItems) },
                            set: { appState.clipboardHistoryMaxItems = Int($0) }
                        ),
                        in: 10...100,
                        step: 10
                    )

                    HStack {
                        Text("10")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text("100")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private func keyCodeToName(_ keyCode: UInt16) -> String {
        if let name = KeyCode.keyNames[keyCode] { return name }
        let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: true)
        var length = 0
        event?.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: nil)
        if length > 0 {
            var chars: [UniChar] = Array(repeating: 0, count: length)
            event?.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &chars)
            if let scalar = UnicodeScalar(chars[0]) {
                return String(Character(scalar)).uppercased()
            }
        }
        return "Key\(keyCode)"
    }
}

// MARK: - Key Event Handler

struct ClipboardKeyEventHandler: NSViewRepresentable {
    @Binding var isRecording: Bool
    let appState: AppState

    func makeNSView(context: Context) -> ClipboardKeyCaptureView {
        let view = ClipboardKeyCaptureView()
        view.onKeyPress = { keyCode in
            Task { @MainActor in
                appState.clipboardHotkeyKeyCode = keyCode
                isRecording = false
            }
        }
        return view
    }

    func updateNSView(_ nsView: ClipboardKeyCaptureView, context: Context) {
        nsView.isActive = isRecording
        if isRecording {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

class ClipboardKeyCaptureView: NSView {
    var onKeyPress: ((UInt16) -> Void)?
    var isActive = false

    override var acceptsFirstResponder: Bool { isActive }

    override func keyDown(with event: NSEvent) {
        guard isActive else {
            super.keyDown(with: event)
            return
        }
        onKeyPress?(event.keyCode)
    }
}
