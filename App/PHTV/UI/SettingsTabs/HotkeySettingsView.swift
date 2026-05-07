//
//  HotkeySettingsView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import Observation

struct HotkeySettingsView: View {
    @Environment(AppState.self) private var appState
    private var bindable: Bindable<AppState> { Bindable(appState) }

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

    var body: some View {
        ScrollView {
            LazyVStack(spacing: SettingsLayout.sectionSpacing) {
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
                    VStack(spacing: 12) {
                        SettingsToggleRow(
                            icon: "arrow.uturn.backward.circle.fill",
                            iconColor: .accentColor,
                            title: "Hoàn tác về ký tự gốc",
                            subtitle: "Dùng phím hoàn tác để trả về ký tự trước khi biến đổi",
                            isOn: bindable.restoreOnEscape
                        )

                        if appState.restoreOnEscape {
                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                // Grid of restore keys (3 columns, 3 keys total)
                                LazyVGrid(columns: [
                                    GridItem(.flexible(), spacing: 10),
                                    GridItem(.flexible(), spacing: 10),
                                    GridItem(.flexible(), spacing: 10)
                                ], spacing: 10) {
                                    ForEach(RestoreKey.allCases) { key in
                                        RestoreKeyButton(
                                            key: key,
                                            isSelected: bindable.restoreKey.wrappedValue == key,
                                            themeColor: .accentColor
                                        ) {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                bindable.restoreKey.wrappedValue = key
                                            }
                                        }
                                    }
                                }

                                // Conflict warning
                                if hasRestoreHotkeyConflict {
                                    Label("Phím hoàn tác trùng với phím bổ trợ của phím tắt chuyển chế độ", systemImage: "exclamationmark.triangle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
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

                Spacer(minLength: SettingsLayout.sectionSpacing)
            }
            .frame(maxWidth: .infinity)
            .padding(SettingsLayout.contentPadding)
        }
        .settingsBackground()
    }
}

#Preview {
    HotkeySettingsView()
        .environment(AppState.shared)
        .frame(width: 500, height: 700)
}
