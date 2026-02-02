//
//  HotkeySettingsView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

struct HotkeySettingsView: View {
    @EnvironmentObject var appState: AppState

    // Check if restore key conflicts with hotkey
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

    private var hotkeyString: String {
        var parts: [String] = []
        if appState.switchKeyControl { parts.append("⌃") }
        if appState.switchKeyOption { parts.append("⌥") }
        if appState.switchKeyShift { parts.append("⇧") }
        if appState.switchKeyCommand { parts.append("⌘") }
        if appState.switchKeyCode != 0xFE {
            parts.append(appState.switchKeyName)
        }
        return parts.isEmpty ? "Chưa đặt" : parts.joined()
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                SettingsHeaderView(
                    title: "Phím tắt",
                    subtitle: "Tùy chỉnh phím tắt để chuyển chế độ gõ và mở PHTV Picker nhanh.",
                    icon: "command.circle.fill",
                    accent: .orange
                ) {
                    SettingsStatusPill(
                        text: "Chuyển chế độ: \(hotkeyString)",
                        color: hotkeyString == "Chưa đặt" ? .secondary : .accentColor
                    )
                }

                // Hotkey Configuration
                SettingsCard(
                    title: "Chuyển chế độ gõ",
                    subtitle: "Đổi nhanh giữa Tiếng Việt và Tiếng Anh",
                    icon: "command.circle.fill"
                ) {
                    HotkeyConfigView()
                }

                // Restore to Raw Keys Feature
                SettingsCard(
                    title: "Khôi phục ký tự",
                    subtitle: "Hoàn tác nhanh khi gõ sai",
                    icon: "arrow.uturn.backward.circle.fill"
                ) {
                    VStack(spacing: 16) {
                        SettingsToggleRow(
                            icon: "arrow.uturn.backward.circle.fill",
                            iconColor: .accentColor,
                            title: "Hoàn tác về ký tự gốc",
                            subtitle: "Dùng phím hoàn tác để trả về ký tự trước khi biến đổi",
                            isOn: $appState.restoreOnEscape
                        )

                        if appState.restoreOnEscape {
                            Divider()

                            VStack(alignment: .leading, spacing: 12) {
                                Text("Chọn phím hoàn tác")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)

                                // Grid of restore keys (3 columns, 3 keys total)
                                LazyVGrid(columns: [
                                    GridItem(.flexible(), spacing: 10),
                                    GridItem(.flexible(), spacing: 10),
                                    GridItem(.flexible(), spacing: 10)
                                ], spacing: 10) {
                                    ForEach(RestoreKey.allCases) { key in
                                        RestoreKeyButton(
                                            key: key,
                                            isSelected: appState.restoreKey == key,
                                            themeColor: .accentColor
                                        ) {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                appState.restoreKey = key
                                            }
                                        }
                                    }
                                }

                                // Conflict warning
                                if hasRestoreHotkeyConflict {
                                    HStack(spacing: 10) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundStyle(.orange)
                                            .font(.system(size: 14))

                                        Text("Phím hoàn tác trùng với phím bổ trợ của phím tắt chuyển chế độ")
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

                // Pause Key Configuration
                SettingsCard(
                    title: "Tạm dừng gõ tiếng Việt",
                    subtitle: "Tạm ngưng bộ gõ khi cần nhập liệu đặc biệt",
                    icon: "pause.circle.fill"
                ) {
                    PauseKeyConfigView()
                }

                // PHTV Picker Hotkey
                SettingsCard(
                    title: "PHTV Picker",
                    subtitle: "Mở nhanh bảng emoji/sticker/GIF",
                    icon: "smiley.fill"
                ) {
                    EmojiHotkeyConfigView()
                }

                Spacer(minLength: 20)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
        }
        .settingsBackground()
    }
}

#Preview {
    HotkeySettingsView()
        .environmentObject(AppState.shared)
        .frame(width: 500, height: 700)
}
