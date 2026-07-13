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

    private var retentionFootnote: String {
        switch appState.clipboardHistoryRetention {
        case .forever:
            return "Lịch sử chỉ bị giới hạn bởi số mục tối đa ở trên."
        default:
            let window = appState.clipboardHistoryRetention.displayName.lowercased()
            return "Mục được sao chép quá \(window) sẽ tự động bị xóa."
        }
    }

    private var keyDisplayText: String {
        if isRecording { return "Nhấn phím..." }
        if appState.clipboardHotkeyKeyCode == modifierOnlyKeyCode && appState.clipboardHotkeyModifiers.isEmpty {
            return "Chưa đặt"
        }
        return HotkeyFormatter.switchHotkeyString(
            control: appState.clipboardHotkeyModifiers.contains(.control),
            leftControl: (appState.clipboardHotkeyModifiers.rawValue & 0x0001) != 0,
            rightControl: (appState.clipboardHotkeyModifiers.rawValue & 0x2000) != 0,
            option: appState.clipboardHotkeyModifiers.contains(.option),
            leftOption: (appState.clipboardHotkeyModifiers.rawValue & 0x0020) != 0,
            rightOption: (appState.clipboardHotkeyModifiers.rawValue & 0x0040) != 0,
            shift: appState.clipboardHotkeyModifiers.contains(.shift),
            leftShift: (appState.clipboardHotkeyModifiers.rawValue & 0x0002) != 0,
            rightShift: (appState.clipboardHotkeyModifiers.rawValue & 0x0004) != 0,
            command: appState.clipboardHotkeyModifiers.contains(.command),
            leftCommand: (appState.clipboardHotkeyModifiers.rawValue & 0x0008) != 0,
            rightCommand: (appState.clipboardHotkeyModifiers.rawValue & 0x0010) != 0,
            fn: appState.clipboardHotkeyModifiers.contains(.function),
            keyCode: appState.clipboardHotkeyKeyCode,
            keyName: SettingsHotkeyKeyNameResolver.name(for: appState.clipboardHotkeyKeyCode)
        )
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
                        if !isRecording && (appState.clipboardHotkeyKeyCode != modifierOnlyKeyCode || !appState.clipboardHotkeyModifiers.isEmpty) {
                            Button(action: {
                                appState.clipboardHotkeyKeyCode = modifierOnlyKeyCode
                                appState.clipboardHotkeyModifiers = []
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
                        .background(
                            UnifiedHotkeyEventHandler(
                                isRecording: $isRecording,
                                onCaptured: { keyCode, modifiers, rawFlags in
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        appState.clipboardHotkeyKeyCode = keyCode
                                        let deviceFlags = rawFlags & (0x0001 | 0x2000 | 0x0002 | 0x0004 | 0x0020 | 0x0040 | 0x0008 | 0x0010)
                                        let combinedRaw = UInt(modifiers.rawValue) | UInt(deviceFlags)
                                        appState.clipboardHotkeyModifiers = NSEvent.ModifierFlags(rawValue: combinedRaw)
                                        isRecording = false
                                    }
                                },
                                onCancelled: {
                                    isRecording = false
                                }
                            )
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, SettingsLayout.rowVerticalPadding)

                Text("Mặc định: ⌃V. Bấm lại phím tắt hoặc Esc để đóng.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, -4)

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

                Divider()

                // Retention window
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Tự động xóa mục cũ hơn")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)

                        Spacer()

                        Picker(
                            "",
                            selection: Binding(
                                get: { appState.clipboardHistoryRetention },
                                set: { appState.clipboardHistoryRetention = $0 }
                            )
                        ) {
                            ForEach(ClipboardHistoryRetention.allCases) { option in
                                Text(option.displayName).tag(option)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .fixedSize()
                    }

                    Text(retentionFootnote)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Clipboard từ password manager và ứng dụng nhạy cảm sẽ không được lưu vào lịch sử.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

