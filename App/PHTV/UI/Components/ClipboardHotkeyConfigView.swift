//
//  ClipboardHotkeyConfigView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import Observation

struct ClipboardHotkeyConfigView: View {
    @Environment(AppState.self) private var appState
    @State private var isRecording = false

    private let modifierOnlyKeyCode: UInt16 = KeyCode.noKey
    private var bindable: Bindable<AppState> { Bindable(appState) }

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
        VStack(alignment: .leading, spacing: 12) {
            // Enable toggle
            SettingsToggleRow(
                icon: "doc.on.clipboard.fill",
                iconColor: .accentColor,
                title: "Bật lịch sử Clipboard",
                subtitle: "Lưu lại nội dung đã sao chép và mở nhanh bằng phím tắt",
                isOn: bindable.enableClipboardHistory
            )

            if appState.enableClipboardHistory {
                Divider()

                // Modifier keys
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        ModifierKeyButton(symbol: "⌃", name: "Control", isOn: clipboardHotkeyControl)
                        ModifierKeyButton(symbol: "⇧", name: "Shift", isOn: clipboardHotkeyShift)
                        ModifierKeyButton(symbol: "⌘", name: "Command", isOn: clipboardHotkeyCommand)
                        ModifierKeyButton(symbol: "⌥", name: "Option", isOn: clipboardHotkeyOption)
                        ModifierKeyButton(symbol: "fn", name: "", isOn: clipboardHotkeyFn)
                    }

                    Text("Mặc định: ⌃V. Bấm lại phím tắt hoặc Esc để đóng.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Key Selection - Compact inline row
                HStack(alignment: .center, spacing: 16) {
                    HStack(spacing: 4) {
                        Text("Phím chính")
                            .font(.body)
                            .foregroundStyle(.primary)
                        Text("(tùy chọn)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 12)

                    HStack(spacing: 6) {
                        // Clear button
                        if !isRecording && appState.clipboardHotkeyKeyCode != modifierOnlyKeyCode {
                            Button(action: {
                                appState.clipboardHotkeyKeyCode = modifierOnlyKeyCode
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
                            HStack(spacing: 6) {
                                Image(systemName: isRecording ? "keyboard.badge.ellipsis" : "keyboard")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(isRecording ? Color.accentColor : .secondary)

                                Text(keyDisplayText)
                                    .font(.system(size: 12))
                                    .foregroundStyle(isRecording ? Color.accentColor : .primary)
                                    .lineLimit(1)
                            }
                        }
                        .settingsControlButtonStyle(isProminent: isRecording)
                        .controlSize(.small)
                        .background(
                            ClipboardKeyEventHandler(isRecording: $isRecording, appState: appState)
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, SettingsLayout.rowVerticalPadding)

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

                    Text("Clipboard từ password manager và ứng dụng nhạy cảm sẽ không được lưu vào lịch sử.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
