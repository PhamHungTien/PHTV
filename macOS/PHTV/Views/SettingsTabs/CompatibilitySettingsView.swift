//
//  CompatibilitySettingsView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

struct CompatibilitySettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                SettingsHeaderView(
                    title: "Tương thích nâng cao",
                    subtitle: "Tinh chỉnh cho bố cục đặc biệt và công cụ bên thứ ba.",
                    icon: "puzzlepiece.extension.fill"
                )

                // Keyboard Layout Compatibility
                SettingsCard(
                    title: "Bàn phím",
                    subtitle: "Hỗ trợ bố cục đặc biệt",
                    icon: "keyboard.fill"
                ) {
                    SettingsToggleRow(
                        icon: "keyboard.fill",
                        iconColor: .accentColor,
                        title: "Tương thích bố cục bàn phím",
                        subtitle: "Hỗ trợ Dvorak, Colemak và các bố cục đặc biệt",
                        isOn: $appState.performLayoutCompat
                    )
                }

                // Safe Mode
                SettingsCard(
                    title: "Chế độ an toàn",
                    subtitle: "Tự phục hồi khi API gặp lỗi",
                    icon: "shield.lefthalf.filled"
                ) {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            icon: "shield.fill",
                            iconColor: .accentColor,
                            title: "Bật chế độ an toàn",
                            subtitle: "Tự phục hồi khi Accessibility API gặp lỗi",
                            isOn: $appState.safeMode
                        )

                        if appState.safeMode {
                            SettingsDivider()

                            HStack(spacing: 14) {
                                SettingsIconTile(color: .accentColor) {
                                    Image(systemName: "info.circle.fill")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(Color.accentColor)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Gợi ý cho máy Mac cũ")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)

                                    Text("Khuyến nghị cho Mac chạy OpenCore Legacy Patcher (OCLP) hoặc gặp vấn đề ổn định với Accessibility API.")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
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
    CompatibilitySettingsView()
        .environmentObject(AppState.shared)
        .frame(width: 500, height: 600)
}
