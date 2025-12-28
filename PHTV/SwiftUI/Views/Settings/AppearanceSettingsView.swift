//
//  AppearanceSettingsView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

struct AppearanceSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Theme Colors
                SettingsCard(title: "Màu chủ đạo", icon: "paintpalette.fill") {
                    VStack(spacing: 16) {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                        ], spacing: 12) {
                            ForEach(themeManager.predefinedColors) { themeColor in
                                ThemeColorButton(
                                    themeColor: themeColor,
                                    isSelected: isSameColor(themeColor.color, themeManager.themeColor)
                                ) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        themeManager.themeColor = themeColor.color
                                    }
                                }
                            }
                        }
                    }
                }

                // Menu Bar Appearance
                SettingsCard(title: "Thanh menu", icon: "menubar.rectangle") {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            icon: "flag.fill",
                            iconColor: themeManager.themeColor,
                            title: "Hiển thị icon chữ V",
                            subtitle: "Dùng icon chữ V khi đang ở chế độ tiếng Việt",
                            isOn: $appState.useVietnameseMenubarIcon
                        )

                        SettingsDivider()

                        VStack(spacing: 8) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(themeManager.themeColor.opacity(0.12))
                                        .frame(width: 36, height: 36)

                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(themeManager.themeColor)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Kích cỡ icon")
                                        .font(.body)
                                        .foregroundStyle(.primary)

                                    Text("Điều chỉnh kích thước icon trên thanh menu")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text(String(format: "%.0f px", appState.menuBarIconSize))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.tint)
                                    .frame(minWidth: 40, alignment: .trailing)
                            }

                            CustomSlider(
                                value: $appState.menuBarIconSize,
                                range: 12.0...20.0,
                                step: 0.01,
                                tintColor: themeManager.themeColor
                            )
                        }
                        .padding(.vertical, 6)
                    }
                }

                // Dock
                SettingsCard(title: "Dock", icon: "dock.rectangle") {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            icon: "app.fill",
                            iconColor: themeManager.themeColor,
                            title: "Hiển thị icon trên Dock",
                            subtitle: "Hiện icon PHTV khi mở cài đặt",
                            isOn: $appState.showIconOnDock
                        )
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(20)
        }
        .settingsBackground()
    }

    private func isSameColor(_ color1: Color, _ color2: Color) -> Bool {
        let nsColor1 = NSColor(color1)
        let nsColor2 = NSColor(color2)

        guard let rgb1 = nsColor1.usingColorSpace(.deviceRGB),
              let rgb2 = nsColor2.usingColorSpace(.deviceRGB) else {
            return false
        }

        return abs(rgb1.redComponent - rgb2.redComponent) < 0.01 &&
               abs(rgb1.greenComponent - rgb2.greenComponent) < 0.01 &&
               abs(rgb1.blueComponent - rgb2.blueComponent) < 0.01
    }
}

#Preview {
    AppearanceSettingsView()
        .environmentObject(AppState.shared)
        .environmentObject(ThemeManager.shared)
        .frame(width: 500, height: 600)
}
