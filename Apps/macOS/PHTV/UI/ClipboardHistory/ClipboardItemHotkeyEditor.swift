//
//  ClipboardItemHotkeyEditor.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

/// A focused editor for the shortcut that pastes one clipboard item directly.
/// It uses the app-wide recorder so its behavior matches the existing PHTV
/// shortcut settings.
struct ClipboardItemHotkeyEditor: View {
    let itemTitle: String
    let onCancel: () -> Void
    let onSave: (ClipboardItemHotkey?) throws -> Void

    @State private var hotkey: ClipboardItemHotkey?
    @State private var isRecording = false
    @State private var errorMessage: String?

    init(
        itemTitle: String,
        currentHotkey: ClipboardItemHotkey?,
        onCancel: @escaping () -> Void,
        onSave: @escaping (ClipboardItemHotkey?) throws -> Void
    ) {
        self.itemTitle = itemTitle
        self.onCancel = onCancel
        self.onSave = onSave
        _hotkey = State(initialValue: currentHotkey)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Huỷ", action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Text("Phím tắt dán ngay")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Button("Lưu", action: save)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("s", modifiers: .command)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(Color.primary.opacity(0.035))
            .overlay(alignment: .bottom) { Divider().opacity(0.5) }

            VStack(alignment: .leading, spacing: 15) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(itemTitle)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                    Text("Khi bấm tổ hợp này, PHTV sẽ dán mục vào ứng dụng đang mở.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Phím tắt")
                            .font(.subheadline.weight(.medium))
                        Text("Nhấn tổ hợp có ⌘, ⌥, ⌃ hoặc ⇧")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    HStack(spacing: 7) {
                        if hotkey != nil && !isRecording {
                            Button {
                                hotkey = nil
                                errorMessage = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Gỡ phím tắt")
                        }

                        Button { isRecording = true } label: {
                            SettingsShortcutRecorderLabel(
                                text: isRecording ? "Nhấn phím..." : hotkey?.displayText ?? "Chưa đặt",
                                isRecording: isRecording
                            )
                        }
                        .buttonStyle(SettingsShortcutRecorderButtonStyle(isRecording: isRecording))
                        .background(UnifiedHotkeyEventHandler(
                            isRecording: $isRecording,
                            onCaptured: { keyCode, modifiers, _ in
                                let captured = ClipboardItemHotkey(modifiers: modifiers, keyCode: keyCode)
                                guard captured.isValid else {
                                    errorMessage = ClipboardItemHotkeyError.invalidShortcut.localizedDescription
                                    isRecording = false
                                    return
                                }
                                hotkey = captured
                                errorMessage = nil
                                isRecording = false
                            },
                            onCancelled: { isRecording = false }
                        ))
                    }
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if hotkey != nil {
                    Label("Phím tắt này chỉ hoạt động khi PHTV đang chạy.", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Để trống nếu không muốn gán phím tắt cho mục này.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func save() {
        do {
            try onSave(hotkey)
            onCancel()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
